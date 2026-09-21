"""Servicio de reconocimiento facial con OpenCV (Haar Cascade + LBPH).

Provee detección de rostros con Haar Cascade, reconocimiento con LBPH,
registro de pacientes y entrenamiento del modelo.
"""

import os

import cv2

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CASCADE_PATH = os.path.join(
    BASE_DIR, 'haarcascade_frontalface_default.xml'
)
CASCADE_OPENCV = os.path.join(
    cv2.data.haarcascades, 'haarcascade_frontalface_default.xml'
)
MODELO_PATH = os.path.join(BASE_DIR, 'modelo_lbph.yml')
DATASET_DIR = os.path.join(BASE_DIR, 'dataset')

UMBRAL_CONFIANZA = 80
TAMANO_ROSTRO = (200, 200)


class FaceService:
    def __init__(self):
        ruta_cascade = (
            CASCADE_PATH
            if os.path.exists(CASCADE_PATH)
            else CASCADE_OPENCV
        )
        self.cascade = cv2.CascadeClassifier(ruta_cascade)
        self.modelo = None

    def _cargar_modelo(self):
        if not os.path.exists(MODELO_PATH):
            return None
        modelo = cv2.face.LBPHFaceRecognizer_create()
        modelo.read(MODELO_PATH)
        return modelo

    def detectar_rostro(self, imagen):
        if isinstance(imagen, str):
            imagen = cv2.imread(imagen)
        if imagen is None:
            return []
        gray = cv2.cvtColor(imagen, cv2.COLOR_BGR2GRAY)
        return self.cascade.detectMultiScale(
            gray, scaleFactor=1.1, minNeighbors=5, minSize=(100, 100)
        )

    def extraer_rostro(self, imagen):
        rostros = self.detectar_rostro(imagen)
        if len(rostros) == 0:
            return None
        (x, y, w, h) = rostros[0]
        if isinstance(imagen, str):
            imagen = cv2.imread(imagen)
        gray = cv2.cvtColor(imagen, cv2.COLOR_BGR2GRAY)
        rostro = gray[y : y + h, x : x + w]
        return cv2.resize(rostro, TAMANO_ROSTRO)

    def reconocer_rostro(self, imagen):
        if self.modelo is None:
            self.modelo = self._cargar_modelo()
        if self.modelo is None:
            return {'paciente_id': None, 'confianza': 100.0}
        rostro = self.extraer_rostro(imagen)
        if rostro is None:
            return {'paciente_id': None, 'confianza': 100.0}
        paciente_id, confianza = self.modelo.predict(rostro)
        if confianza > UMBRAL_CONFIANZA:
            paciente_id = None
        return {'paciente_id': paciente_id, 'confianza': round(float(confianza), 2)}

    def registrar_rostro(self, paciente_id, imagenes):
        guardados = 0
        directorio = os.path.join(DATASET_DIR, f'paciente_{paciente_id}')
        os.makedirs(directorio, exist_ok=True)
        for imagen in imagenes:
            if guardados >= 20:
                break
            rostro = self.extraer_rostro(imagen)
            if rostro is None:
                continue
            ruta = os.path.join(directorio, f'{len(os.listdir(directorio)) + 1}.png')
            cv2.imwrite(ruta, rostro)
            guardados += 1
        return {'paciente_id': paciente_id, 'guardados': guardados}

    def entrenar_modelo(self):
        rostros = []
        ids = []
        if not os.path.exists(DATASET_DIR):
            return {'error': 'El directorio dataset no existe'}
        for nombre in os.listdir(DATASET_DIR):
            ruta_carpeta = os.path.join(DATASET_DIR, nombre)
            if not os.path.isdir(ruta_carpeta):
                continue
            try:
                paciente_id = int(nombre.split('_')[1])
            except (IndexError, ValueError):
                continue
            for archivo in os.listdir(ruta_carpeta):
                ruta_imagen = os.path.join(ruta_carpeta, archivo)
                gray = cv2.imread(ruta_imagen, cv2.IMREAD_GRAYSCALE)
                if gray is None:
                    continue
                rostros.append(gray)
                ids.append(paciente_id)
        if len(rostros) == 0:
            return {'error': 'No hay imágenes para entrenar'}

        modelo = cv2.face.LBPHFaceRecognizer_create()
        modelo.train(rostros, ids)
        modelo.write(MODELO_PATH)
        self.modelo = modelo
        return {
            'imagenes': len(rostros),
            'pacientes': len(set(ids)),
            'modelo': MODELO_PATH,
        }


face_service = FaceService()