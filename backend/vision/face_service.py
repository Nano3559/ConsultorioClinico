"""Servicio de reconocimiento facial con InsightFace (ArcFace) + liveness.

Reemplaza al prototipo Haar + LBPH:
  - Detección: SCRFD (incluido en el pack InsightFace), muy superior a Haar
    ante luz y ángulos.
  - Identidad: embedding ArcFace 512-d L2-normalizado; la comparación es por
    similitud coseno con umbral configurable (VISION_SIMILARITY_THRESHOLD).
  - Liveness (estilo Binance): desafío de parpadeo + giro de cabeza medidos
    con MediaPipe Face Mesh sobre una secuencia de 2-3 frames. Una foto
    impresa o una pantalla NO parpadea ni gira: sin liveness no hay check-in.
  - Calidad: cada muestra se puntúa (tamaño, brillo, nitidez, un solo rostro)
    y la foto que se guarda es LIVIANA (recorte JPEG máx 640px q80).

Variables (.env del microservicio):
  VISION_MODEL_PACK=búfalo_s (pack InsightFace: 'buffalo_s' recomendado)
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

MODEL_PACK = os.getenv('VISION_MODEL_PACK', 'buffalo_s')
UMBRAL_SIMILITUD = float(os.getenv('VISION_SIMILARITY_THRESHOLD', '0.5'))

# Calidad mínima por muestra (0-100) para aceptarla en el registro.
UMBRAL_CALIDAD = float(os.getenv('VISION_QUALITY_THRESHOLD', '55'))

# Foto liviana: lado mayor máximo + calidad JPEG (poco peso por diseño).
LADO_MAX_FOTO = int(os.getenv('VISION_FOTO_MAX_LADO', '640'))
CALIDAD_JPEG = int(os.getenv('VISION_FOTO_JPEG_Q', '80'))

# Liveness: EAR bajo este valor = ojo cerrado (parpadeo).
UMBRAL_EAR_PARPADEO = 0.21
# Giro de cabeza: el ratio de yaw debe variar al menos esto entre frames.
UMBRAL_YAW_CAMBIO = 0.25

# Landmarks MediaPipe (ojos para EAR, mejillas/nariz para yaw).
OJO_IZQ = [33, 160, 158, 133, 153, 144]
OJO_DER = [362, 385, 387, 263, 373, 380]
NARIZ = 1
MEJILLA_IZQ = 234
MEJILLA_DER = 454


class MotorNoDisponible(Exception):
    """El pack InsightFace/MediaPipe no está instalado o no descargó."""


class FaceService:
    def __init__(self):
        self._app = None
        self._mesh = None

    # -- Motores (carga perezosa: el import pesado solo al primer uso) --------

    def _insightface(self):
        if self._app is None:
            try:
                from insightface.app import FaceAnalysis
            except ImportError as exc:
                raise MotorNoDisponible(
                    'InsightFace no instalado (pip install insightface onnxruntime)'
                ) from exc
            app = FaceAnalysis(name=MODEL_PACK)
            app.prepare(ctx_id=-1)  # CPU (-1); GPU si ctx_id >= 0
            self._app = app
        return self._app

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
        """Devuelve las caras InsightFace (bbox, kps, embedding normado)."""
        app = self._insightface()
        if imagen is None:
            return []
        return app.get(imagen)

    def embedding_de(self, imagen):
        """Embedding 512-d L2-normalizado del rostro principal, o None."""
        caras = self.detectar(imagen)
        if not caras:
            return None
        mejor = max(caras, key=lambda c: (c.bbox[2] - c.bbox[0]) * (c.bbox[3] - c.bbox[1]))
        emb = np.asarray(mejor.normed_embedding, dtype=np.float64)
        return [round(float(x), 6) for x in emb]

    @staticmethod
    def similitud(a, b):
        """Similitud coseno entre dos embeddings normalizados [0-1 aprox]."""
        va = np.asarray(a, dtype=np.float64)
        vb = np.asarray(b, dtype=np.float64)
        denom = np.linalg.norm(va) * np.linalg.norm(vb)
        if denom == 0:
            return 0.0
        return round(float(np.dot(va, vb) / denom), 4)

    def comparar(self, sonda, plantillas, umbral=UMBRAL_SIMILITUD):
        """Compara la sonda contra {clave: embedding}; devuelve el mejor match
        sobre el umbral o None. Las plantillas son p.ej. {paciente_id: [...]}.
        """
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

    def calidad(self, imagen):
        """Puntaje 0-100 de una muestra + motivos de rechazo.

        Pondera: un solo rostro (excluyente), tamaño >= 100px, brillo medio
        40-220, nitidez (varianza del Laplaciano >= 60).
        """
        if imagen is None:
            return {'puntaje': 0.0, 'ok': False, 'motivo': 'imagen_vacia'}
        try:
            caras = self.detectar(imagen)
        except MotorNoDisponible:
            raise
        if len(caras) == 0:
            return {'puntaje': 0.0, 'ok': False, 'motivo': 'sin_rostro'}
        if len(caras) > 1:
            return {'puntaje': 0.0, 'ok': False, 'motivo': 'varios_rostros'}
        x1, y1, x2, y2 = [int(v) for v in caras[0].bbox]
        h_img, w_img = imagen.shape[:2]
        x1, y1 = max(0, x1), max(0, y1)
        x2, y2 = min(w_img, x2), min(h_img, y2)
        recorte = imagen[y1:y2, x1:x2]
        if recorte.size == 0:
            return {'puntaje': 0.0, 'ok': False, 'motivo': 'recorte_vacio'}
        gris = cv2.cvtColor(recorte, cv2.COLOR_BGR2GRAY)
        alto = y2 - y1
        brillo = float(np.mean(gris))
        nitidez = float(cv2.Laplacian(gris, cv2.CV_64F).var())

        puntaje = 100.0
        motivo = None
        if alto < 100:
            puntaje -= 45.0
            motivo = 'rostro_muy_lejos'
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
    def foto_liviana(imagen, bbox=None):
        """Recorta el rostro (margen 20%), limita al lado mayor y codifica
        JPEG q80 en base64. Resultado típico: 30-60 KB (poco peso por diseño).
        """
        if imagen is None:
            return None
        h, w = imagen.shape[:2]
        if bbox is not None:
            x1, y1, x2, y2 = [int(v) for v in bbox]
            dx, dy = int((x2 - x1) * 0.2), int((y2 - y1) * 0.2)
            x1, y1 = max(0, x1 - dx), max(0, y1 - dy)
            x2, y2 = min(w, x2 + dx), min(h, y2 + dy)
            imagen = imagen[y1:y2, x1:x2]
            if imagen.size == 0:
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
        """Verifica vida en una secuencia de 2+ frames (desafío del kiosco).

        OK si se detecta PARPADEO (EAR cae bajo el umbral en algún frame y
        vuelve a subir) o GIRO de cabeza (el yaw varía entre frames).
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
        """Procesa [{imagen, pose}]: calidad + embedding 512-d + foto liviana
        por muestra. Guarda el recorte liviano en dataset/paciente_{id}/
        (auditoría local) y devuelve el promedio normalizado (plantilla).
        """
        resultados = []
        embeddings = []
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
            q = self.calidad(imagen)
            emb = [round(float(x), 6) for x in np.asarray(cara.normed_embedding, dtype=np.float64)]
            foto = self.foto_liviana(imagen, cara.bbox)
            if not q['ok'] or foto is None:
                resultados.append({'pose': pose, 'guardada': False, 'motivo': q.get('motivo') or 'foto_invalida', 'calidad': q['puntaje']})
                continue
            ruta = os.path.join(directorio, f'{pose}.jpg')
            with open(ruta, 'wb') as fh:
                fh.write(base64.b64decode(foto))
            embeddings.append(np.asarray(emb, dtype=np.float64))
            resultados.append({
                'pose': pose, 'guardada': True, 'calidad': q['puntaje'],
                'foto': foto, 'embedding': emb,
            })
        plantilla = None
        if embeddings:
            promedio = np.mean(np.stack(embeddings), axis=0)
            norma = np.linalg.norm(promedio)
            if norma > 0:
                plantilla = [round(float(x), 6) for x in (promedio / norma)]
        return {'muestras': resultados, 'rostro_embedding': plantilla}


face_service = FaceService()
