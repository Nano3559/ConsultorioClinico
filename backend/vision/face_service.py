"""Servicio de reconocimiento facial liviano: YuNet + SFace (OpenCV Zoo).

Diseñado para correr en plan free (512 MB RAM): los modelos pesan ~40 MB
y en RAM usan ~200 MB, contra ~1 GB de ArcFace (que hace OOM en free).

  - Detección: YuNet (rápido en CPU, 5 landmarks incluidos).
  - Identidad: SFace, embedding 128-d L2-normalizado; comparación por
    similitud coseno con umbral configurable (VISION_SIMILARITY_THRESHOLD).
  - Liveness (estilo Binance): desafío de parpadeo + giro de cabeza medidos
    con MediaPipe Face Mesh sobre 2-3 frames (carga perezosa, solo al usar).
  - Calidad: tamaño, brillo, nitidez (Laplacian), un solo rostro.
  - Foto liviana: recorte JPEG máx 640px q80 (~30-60 KB).

Los .onnx se descargan solos al primer uso desde el zoo oficial de OpenCV
(a /root/.insightface o VISION_MODEL_DIR; en hosting efímero se re-descargan
en cada cold start: ~40 MB, segundos).

Variables (.env del microservicio):
  VISION_MODEL_DIR=dir local de modelos (defecto: ~/.insightface/models/sface)
  VISION_SIMILARITY_THRESHOLD=0.5 (umbral coseno para reconocer)
"""

import base64
import os

import cv2
import numpy as np
from dotenv import load_dotenv

load_dotenv()

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATASET_DIR = os.path.join(BASE_DIR, 'dataset')

# Pack lógico (para el manifest/sync del kiosco y el campo `modelo`).
MODEL_PACK = os.getenv('VISION_MODEL_PACK', 'sface')
MODEL_DIR = os.getenv(
    'VISION_MODEL_DIR',
    os.path.join(os.path.expanduser('~'), '.insightface', 'models', 'sface'),
)

# Modelos desde los mirrors OFICIALES de OpenCV en HuggingFace (binarios
# reales; el zoo de GitHub guarda los .onnx en Git LFS y el raw solo entrega
# el puntero).
YUNET_URL = (
    'https://huggingface.co/opencv/face_detection_yunet/resolve/main/'
    'face_detection_yunet_2023mar.onnx'
)
SFACE_URL = (
    'https://huggingface.co/opencv/face_recognition_sface/resolve/main/'
    'face_recognition_sface_2021dec.onnx'
)
YUNET_PATH = os.path.join(MODEL_DIR, 'face_detection_yunet_2023mar.onnx')
SFACE_PATH = os.path.join(MODEL_DIR, 'face_recognition_sface_2021dec.onnx')

UMBRAL_SIMILITUD = float(os.getenv('VISION_SIMILARITY_THRESHOLD', '0.5'))

# Calidad mínima por muestra (0-100) para aceptarla en el registro.
UMBRAL_CALIDAD = float(os.getenv('VISION_QUALITY_THRESHOLD', '55'))

# Foto liviana: lado mayor máximo + calidad JPEG (poco peso por diseño).
LADO_MAX_FOTO = int(os.getenv('VISION_FOTO_MAX_LADO', '640'))
CALIDAD_JPEG = int(os.getenv('VISION_FOTO_JPEG_Q', '80'))

# Liveness: EAR bajo este valor = ojo cerrado (parpadeo).
UMBRAL_EAR_PARPADEO = 0.21
# Giro de cabeza: el yaw debe variar al menos esto entre frames.
UMBRAL_YAW_CAMBIO = 0.25

# Landmarks MediaPipe (ojos para EAR, mejillas/nariz para yaw).
OJO_IZQ = [33, 160, 158, 133, 153, 144]
OJO_DER = [362, 385, 387, 263, 373, 380]
NARIZ = 1
MEJILLA_IZQ = 234
MEJILLA_DER = 454


class MotorNoDisponible(Exception):
    """Falta opencv-contrib (SFace) o no se pudieron descargar los modelos."""


def _descargar(url, destino):
    import urllib.request

    os.makedirs(os.path.dirname(destino), exist_ok=True)
    tmp = destino + '.tmp'
    urllib.request.urlretrieve(url, tmp)
    os.replace(tmp, destino)


class FaceService:
    def __init__(self):
        self._detector = None
        self._reconocedor = None
        self._mesh = None

    # -- Motores (carga perezosa) --------------------------------------------

    def _asegurar_modelos(self):
        try:
            if not os.path.isfile(YUNET_PATH):
                _descargar(YUNET_URL, YUNET_PATH)
            if not os.path.isfile(SFACE_PATH):
                _descargar(SFACE_URL, SFACE_PATH)
        except Exception as exc:
            raise MotorNoDisponible(f'no se pudieron descargar los modelos: {exc}') from exc

    def _detector_yunet(self):
        if self._detector is None:
            self._asegurar_modelos()
            try:
                # Umbral 0.8 (no 0.9): con 0.9 se pierden rostros levemente
                # rotados o con luz lateral; el filtro fino lo hace calidad().
                self._detector = cv2.FaceDetectorYN_create(
                    YUNET_PATH, '', (320, 320), 0.8, 0.3, 5000
                )
            except AttributeError as exc:
                raise MotorNoDisponible(
                    'Falta opencv-contrib-python (FaceDetectorYN)'
                ) from exc
        return self._detector

    def _reconocedor_sface(self):
        if self._reconocedor is None:
            self._asegurar_modelos()
            try:
                self._reconocedor = cv2.FaceRecognizerSF_create(SFACE_PATH, '')
            except AttributeError as exc:
                raise MotorNoDisponible(
                    'Falta opencv-contrib-python (FaceRecognizerSF)'
                ) from exc
        return self._reconocedor

    def _facemesh(self):
        if self._mesh is None:
            try:
                import mediapipe as mp
            except ImportError as exc:
                raise MotorNoDisponible(
                    'MediaPipe no instalado (pip install mediapipe)'
                ) from exc
            self._mesh = mp.solutions.face_mesh.FaceMesh(
                static_image_mode=True,
                max_num_faces=1,
                refine_landmarks=True,
                min_detection_confidence=0.5,
            )
        return self._mesh

    # -- Detección + embedding -------------------------------------------------

    def detectar(self, imagen):
        """Devuelve lista de dicts {bbox(4), landmarks(5x2)} con YuNet."""
        if imagen is None:
            return []
        h, w = imagen.shape[:2]
        det = self._detector_yunet()
        det.setInputSize((w, h))
        _, caras = det.detect(imagen)
        if caras is None:
            return []
        out = []
        for c in caras:
            x, y, wbox, hbox = [float(v) for v in c[0:4]]
            lms = [[float(c[4 + i * 2]), float(c[4 + i * 2 + 1])] for i in range(5)]
            out.append({'bbox': [x, y, wbox, hbox], 'landmarks': lms})
        return out

    def embedding_de(self, imagen):
        """Embedding SFace 128-d L2-normalizado del rostro principal, o None."""
        caras = self.detectar(imagen)
        if not caras:
            return None
        mejor = max(caras, key=lambda c: c['bbox'][2] * c['bbox'][3])
        return self._embedding_de_cara(imagen, mejor)

    def _embedding_de_cara(self, imagen, cara):
        """Embedding de una cara ya detectada (evita detectar dos veces)."""
        rec = self._reconocedor_sface()
        alineado = cv2.cvtColor(imagen, cv2.COLOR_BGR2RGB)
        try:
            feat = rec.feature(alineado, np.asarray(cara['landmarks'], dtype=np.float32))
        except cv2.error:
            return None
        emb = np.asarray(feat, dtype=np.float64).flatten()
        norma = np.linalg.norm(emb)
        if norma == 0 or emb.shape[0] != 128:
            return None
        return [round(float(x), 6) for x in (emb / norma)]

    @staticmethod
    def similitud(a, b):
        """Similitud coseno entre dos embeddings normalizados."""
        va = np.asarray(a, dtype=np.float64)
        vb = np.asarray(b, dtype=np.float64)
        denom = np.linalg.norm(va) * np.linalg.norm(vb)
        if denom == 0:
            return 0.0
        return round(float(np.dot(va, vb) / denom), 4)

    def comparar(self, sonda, plantillas, umbral=UMBRAL_SIMILITUD):
        """Compara la sonda contra {clave: embedding}; mejor match sobre el
        umbral o None."""
        mejor_clave, mejor_sim = None, -1.0
        for clave, emb in (plantillas or {}).items():
            if not emb:
                continue
            sim = self.similitud(sonda, emb)
            if sim > mejor_sim:
                mejor_clave, mejor_sim = clave, sim
        if mejor_clave is None or mejor_sim < umbral:
            return {'clave': None, 'similitud': round(float(mejor_sim), 4)}
        return {'clave': mejor_clave, 'similitud': round(float(mejor_sim), 4)}

    # -- Calidad de muestra ----------------------------------------------------

    def calidad(self, imagen, caras=None):
        """Puntaje 0-100 de una muestra + motivos de rechazo.
        Acepta caras pre-detectadas para no repetir la inferencia en CPU.
        """
        if imagen is None:
            return {'puntaje': 0.0, 'ok': False, 'motivo': 'imagen_vacia'}
        if caras is None:
            caras = self.detectar(imagen)
        if len(caras) == 0:
            return {'puntaje': 0.0, 'ok': False, 'motivo': 'sin_rostro'}
        if len(caras) > 1:
            return {'puntaje': 0.0, 'ok': False, 'motivo': 'varios_rostros'}
        x, y, wbox, hbox = caras[0]['bbox']
        h_img, w_img = imagen.shape[:2]
        x1, y1 = max(0, int(x)), max(0, int(y))
        x2, y2 = min(w_img, int(x + wbox)), min(h_img, int(y + hbox))
        recorte = imagen[y1:y2, x1:x2]
        if recorte.size == 0:
            return {'puntaje': 0.0, 'ok': False, 'motivo': 'recorte_vacio'}
        gris = cv2.cvtColor(recorte, cv2.COLOR_BGR2GRAY)
        alto = y2 - y1
        brillo = float(np.mean(gris))
        nitidez = float(cv2.Laplacian(gris, cv2.CV_64F).var())
        # Tamaño RELATIVO al frame: un rostro real en selfie ocupa una
        # fracción importante; un falso positivo pequeño (esquina, objeto)
        # debe rechazarse aunque la foto sea nítida.
        alto_relativo = alto / max(h_img, 1)
        # Cobertura COMPLETA: el rostro no debe tocar los bordes del encuadre
        # (mínimo 8% de margen por lado). Si sale cortado, la plantilla sale
        # parcial y no sirve: se pide repetir centrando la cara en el óvalo.
        margen_min = min(x1, y1, w_img - x2, h_img - y2)
        margen_relativo = margen_min / max(min(h_img, w_img), 1)

        puntaje = 100.0
        motivo = None
        if alto < 100:
            puntaje -= 45.0
            motivo = 'rostro_muy_lejos'
        if alto_relativo < 0.20:
            puntaje -= 40.0
            motivo = motivo or 'rostro_muy_pequeno'
        if margen_relativo < 0.08:
            puntaje -= 50.0
            motivo = motivo or 'rostro_cortado'
        # Cobertura FACIAL (no solo del recuadro): los 5 landmarks deben
        # estar interiores con margen. En una cara cortada por el borde,
        # YuNet igual encierra lo visible, pero los landmarks caen al filo
        # o fuera -> se rechaza aunque el bbox parezca sano.
        lms = caras[0].get('landmarks') or []
        if len(lms) >= 5:
            xs = [p[0] / max(w_img, 1) for p in lms[:5]]
            ys = [p[1] / max(h_img, 1) for p in lms[:5]]
            if min(xs) < 0.06 or max(xs) > 0.94 or min(ys) < 0.06 or max(ys) > 0.94:
                puntaje -= 50.0
                motivo = motivo or 'rostro_cortado'
        if brillo < 40 or brillo > 220:
            puntaje -= 30.0
            motivo = motivo or 'mala_iluminacion'
        if nitidez < 60:
            puntaje -= 25.0
            motivo = motivo or 'foto_borrosa'
        puntaje = round(max(0.0, min(100.0, puntaje)), 1)
        return {'puntaje': puntaje, 'ok': puntaje >= UMBRAL_CALIDAD, 'motivo': motivo}

    # -- Foto liviana ----------------------------------------------------------

    @staticmethod
    def foto_liviana(imagen):
        """Codifica la foto COMPLETA (sin recortes) a JPEG liviano en base64.

        Decisión de diseño: lo que se guarda en Storage es EXACTAMENTE lo que
        capturó la cámara (limitado a 640px q80, ~30-80 KB). El recorte por
        bbox se eliminó: si el detector se equivoca de zona, el recorte
        guardaba fragmentos irreconocibles y nadie podía auditar la captura
        real. El embedding se sigue calculando con landmarks (sin cambios).
        """
        if imagen is None:
            return None
        h, w = imagen.shape[:2]
        mayor = max(h, w)
        if mayor > LADO_MAX_FOTO:
            escala = LADO_MAX_FOTO / float(mayor)
            imagen = cv2.resize(imagen, (int(w * escala), int(h * escala)))
        ok, buf = cv2.imencode('.jpg', imagen, [cv2.IMWRITE_JPEG_QUALITY, CALIDAD_JPEG])
        if not ok:
            return None
        return base64.b64encode(buf.tobytes()).decode('ascii')

    # -- Liveness (desafío estilo Binance) -------------------------------------

    @staticmethod
    def _ear(puntos, ojo):
        def d(a, b):
            return float(np.linalg.norm(np.array(a) - np.array(b)))

        p = [puntos[i] for i in ojo]
        return (d(p[1], p[5]) + d(p[2], p[4])) / (2.0 * max(d(p[0], p[3]), 1e-6))

    @staticmethod
    def _yaw(puntos):
        nx = puntos[NARIZ][0]
        izq = puntos[MEJILLA_IZQ][0]
        der = puntos[MEJILLA_DER][0]
        return (nx - izq) / max(der - nx, 1e-6)

    def liveness(self, frames):
        """Verifica vida en una secuencia de 2+ frames (parpadeo o giro).
        Con una sola imagen NO se puede probar vida: se reporta honestamente.
        """
        if not frames or len(frames) < 2:
            return {'ok': False, 'metodo': 'ninguno', 'detalle': 'se_requiere_secuencia'}
        try:
            mesh = self._facemesh()
        except MotorNoDisponible:
            return {'ok': False, 'metodo': 'no_disponible', 'detalle': 'mediapipe_no_instalado'}

        ears, yaws = [], []
        for fr in frames:
            if fr is None:
                continue
            rgb = cv2.cvtColor(fr, cv2.COLOR_BGR2RGB)
            res = mesh.process(rgb)
            if not res.multi_face_landmarks:
                continue
            lm = res.multi_face_landmarks[0].landmark
            pts = [(p.x, p.y) for p in lm]
            ear = min(self._ear(pts, OJO_IZQ), self._ear(pts, OJO_DER))
            ears.append(ear)
            yaws.append(self._yaw(pts))
        if len(ears) < 2:
            return {'ok': False, 'metodo': 'sin_rostro', 'detalle': 'no_se_vio_rostro_en_secuencia'}
        parpadeo = any(e < UMBRAL_EAR_PARPADEO for e in ears) and max(ears) > UMBRAL_EAR_PARPADEO + 0.05
        giro = (max(yaws) - min(yaws)) > UMBRAL_YAW_CAMBIO
        if parpadeo or giro:
            metodo = 'parpadeo+yaw' if (parpadeo and giro) else ('parpadeo' if parpadeo else 'giro_cabeza')
            return {'ok': True, 'metodo': metodo, 'detalle': 'vida_confirmada'}
        return {'ok': False, 'metodo': 'sin_movimiento', 'detalle': 'no_se_detecto_parpadeo_ni_giro'}

    # -- Registro multi-pose ----------------------------------------------------

    def registrar(self, paciente_id, muestras):
        """Procesa [{imagen, pose}]: calidad + embedding 128-d + foto liviana
        por muestra. Guarda el recorte en dataset/paciente_{id}/ y devuelve el
        promedio normalizado (plantilla del paciente)."""
        resultados = []
        directorio = os.path.join(DATASET_DIR, f'paciente_{paciente_id}')
        os.makedirs(directorio, exist_ok=True)
        for m in muestras or []:
            imagen = m.get('imagen') if isinstance(m, dict) else m
            pose = m.get('pose', 'frontal') if isinstance(m, dict) else 'frontal'
            if imagen is None:
                resultados.append({'pose': pose, 'guardada': False, 'motivo': 'imagen_vacia'})
                continue
            try:
                caras = self.detectar(imagen)
            except MotorNoDisponible as exc:
                return {'muestras': [], 'rostro_embedding': None, 'error': str(exc)}
            if len(caras) != 1:
                resultados.append({
                    'pose': pose, 'guardada': False,
                    'motivo': 'sin_rostro' if len(caras) == 0 else 'varios_rostros',
                })
                continue
            cara = caras[0]
            q = self.calidad(imagen, caras)
            emb = self._embedding_de_cara(imagen, cara)
            foto = self.foto_liviana(imagen)
            if emb is None or not q['ok'] or foto is None:
                resultados.append({'pose': pose, 'guardada': False, 'motivo': q.get('motivo') or 'foto_invalida', 'calidad': q['puntaje']})
                continue
            ruta = os.path.join(directorio, f'{pose}.jpg')
            with open(ruta, 'wb') as fh:
                fh.write(base64.b64decode(foto))
            resultados.append({
                'pose': pose, 'guardada': True, 'calidad': q['puntaje'],
                'foto': foto, 'embedding': emb,
            })
        plantilla = None
        # Consistencia: todas las muestras deben ser la MISMA persona. Con 3+
        # muestras se expulsa a la que no se parezca al resto (foto ajena,
        # falso positivo, cara tapada). Umbral 0.35: muy por encima del azar
        # (~0.0) y por debajo del umbral de reconocimiento (0.5).
        validas = [r for r in resultados if r.get('guardada')]
        if len(validas) >= 3:
            for r in validas:
                otras = [o['embedding'] for o in validas if o is not r]
                mejor = max((self.similitud(r['embedding'], o) for o in otras), default=0.0)
                if mejor < 0.35:
                    r['guardada'] = False
                    r['motivo'] = 'no_coincide'
                    r.pop('foto', None)
                    r.pop('embedding', None)
        validas = [r for r in resultados if r.get('guardada')]
        # Plantilla válida solo con frontal + al menos 3 poses: con menos no
        # hay diversidad suficiente y una sola foto nunca registra.
        tiene_frontal = any(r.get('pose') == 'frontal' for r in validas)
        if validas and tiene_frontal and len(validas) >= 3:
            embeddings = [
                np.asarray(r['embedding'], dtype=np.float64) for r in validas
            ]
            promedio = np.mean(np.stack(embeddings), axis=0)
            norma = np.linalg.norm(promedio)
            if norma > 0:
                plantilla = [round(float(x), 6) for x in (promedio / norma)]
        return {'muestras': resultados, 'rostro_embedding': plantilla}


face_service = FaceService()
