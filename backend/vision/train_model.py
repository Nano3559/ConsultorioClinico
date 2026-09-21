"""Entrena el modelo LBPH con todas las imágenes del dataset.

Uso:
    python train_model.py
"""

import os

import cv2

from face_service import DATASET_DIR, MODELO_PATH


def entrenar():
    rostros = []
    ids = []

    if not os.path.exists(DATASET_DIR):
        print('Error: no existe el directorio dataset')
        return

    for nombre in os.listdir(DATASET_DIR):
        ruta_carpeta = os.path.join(DATASET_DIR, nombre)
        if not os.path.isdir(ruta_carpeta):
            continue
        try:
            paciente_id = int(nombre.split('_')[1])
        except (IndexError, ValueError):
            print(f'Saltando carpeta inválida: {nombre}')
            continue

        for archivo in os.listdir(ruta_carpeta):
            ruta_imagen = os.path.join(ruta_carpeta, archivo)
            gris = cv2.imread(ruta_imagen, cv2.IMREAD_GRAYSCALE)
            if gris is None:
                continue
            rostros.append(gris)
            ids.append(paciente_id)

    if len(rostros) == 0:
        print('No hay imágenes para entrenar')
        return

    modelo = cv2.face.LBPHFaceRecognizer_create()
    modelo.train(rostros, ids)
    modelo.write(MODELO_PATH)
    print(f'Modelo entrenado con {len(rostros)} imágenes de {len(set(ids))} pacientes')
    print(f'Guardado en: {MODELO_PATH}')


if __name__ == '__main__':
    entrenar()