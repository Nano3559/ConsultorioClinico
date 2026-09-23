"""Captura imágenes del rostro con la cámara para un paciente.

Cantidad configurable con VISION_CAPTURE_COUNT (KIO-16), 20 por defecto.

Uso:
    python capture_faces.py <paciente_id>
"""

import os
import sys

import cv2
from dotenv import load_dotenv

from face_service import DATASET_DIR, TAMANO_ROSTRO, face_service

load_dotenv()

CANTIDAD_IMAGENES = int(os.getenv('VISION_CAPTURE_COUNT', '20'))


def capturar(paciente_id):
    directorio = os.path.join(DATASET_DIR, f'paciente_{paciente_id}')
    os.makedirs(directorio, exist_ok=True)

    camara = cv2.VideoCapture(0)
    if not camara.isOpened():
        print('Error: no se pudo abrir la cámara')
        return

    contador = 0
    print('Mira directo a la cámara. Presiona ESC para cancelar.')
    while contador < CANTIDAD_IMAGENES:
        ret, frame = camara.read()
        if not ret:
            print('Error: no se pudo leer el frame')
            break

        gris = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        rostros = face_service.detectar_rostro(gris)

        for (x, y, w, h) in rostros:
            contador += 1
            rostro = cv2.resize(
                gris[y : y + h, x : x + w], TAMANO_ROSTRO
            )
            ruta = os.path.join(directorio, f'{contador}.png')
            cv2.imwrite(ruta, rostro)
            print(f'Guardada imagen {contador}/{CANTIDAD_IMAGENES}: {ruta}')
            if contador >= CANTIDAD_IMAGENES:
                break

        if len(rostros) > 0:
            (x, y, w, h) = rostros[0]
            cv2.rectangle(
                frame, (x, y), (x + w, y + h), (0, 255, 0), 2
            )
        cv2.putText(
            frame,
            f'{contador}/{CANTIDAD_IMAGENES}',
            (10, 30),
            cv2.FONT_HERSHEY_SIMPLEX,
            1,
            (0, 255, 0),
            2,
        )
        cv2.imshow('Captura de rostro', frame)

        if cv2.waitKey(1) & 0xFF == 27:
            break

    camara.release()
    cv2.destroyAllWindows()
    print(f'Finalizado. {contador} imágenes guardadas en {directorio}')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        print('Uso: python capture_faces.py <paciente_id>')
        sys.exit(1)
    capturar(int(sys.argv[1]))