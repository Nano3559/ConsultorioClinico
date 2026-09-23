import base64
import os
from datetime import date

import cv2
import numpy as np
from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from supabase import create_client

from face_service import face_service

load_dotenv()

app = FastAPI(title='Vision Service - Consultorio Clínico', version='0.2.0')

app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
    allow_methods=['*'],
    allow_headers=['*'],
)

SUPABASE_URL = os.getenv('SUPABASE_URL', '')
SUPABASE_KEY = os.getenv('SUPABASE_SERVICE_ROLE_KEY') or os.getenv('SUPABASE_ANON_KEY', '')


class VerificarRostroRequest(BaseModel):
    imagen: str


class RegistrarRostroRequest(BaseModel):
    imagenes: list[str] = []


def _cliente_supabase():
    if not SUPABASE_URL or not SUPABASE_KEY:
        return None
    return create_client(SUPABASE_URL, SUPABASE_KEY)


def _decodificar_imagen(base64_img):
    try:
        if ',' in base64_img:
            base64_img = base64_img.split(',', 1)[1]
        binario = base64.b64decode(base64_img)
        arreglo = np.frombuffer(binario, dtype=np.uint8)
        return cv2.imdecode(arreglo, cv2.IMREAD_COLOR)
    except Exception:
        return None


def _cita_del_dia(supabase, paciente_id):
    try:
        hoy = date.today().isoformat()
        data_citas = (
            supabase.from_('citas')
            .select('*, pacientes(id, nombre, apellido), medicos(id, nombre, apellido, especialidad)')
            .eq('paciente_id', paciente_id)
            .eq('fecha', hoy)
            .order('hora', desc=False)
            .limit(1)
            .execute()
        )
        citas = data_citas.data or []
        return citas[0] if citas else None
    except Exception:
        return None


@app.get('/health')
def health():
    return {'status': 'OK'}


@app.post('/api/kiosco/verificar-rostro')
def verificar_rostro(payload: VerificarRostroRequest):
    if not payload.imagen:
        return {
            'success': False,
            'message': 'La imagen es obligatoria',
            'data': None,
        }

    imagen = _decodificar_imagen(payload.imagen)
    if imagen is None:
        return {
            'success': False,
            'message': 'No se pudo decodificar la imagen',
            'data': None,
        }

    resultado = face_service.reconocer_rostro(imagen)
    paciente_id = resultado.get('paciente_id')
    confianza = resultado.get('confianza')

    if paciente_id is None:
        return {
            'success': False,
            'message': 'Rostro no reconocido',
            'data': {'paciente_id': None, 'nombre': None, 'confianza': confianza, 'cita': None},
        }

    supabase = _cliente_supabase()
    nombre = None
    cita = None

    if supabase:
        try:
            data_pacientes = (
                supabase.from_('pacientes')
                .select('id, nombre, apellido')
                .eq('id', paciente_id)
                .limit(1)
                .execute()
            )
            pacientes = data_pacientes.data or []
            if pacientes:
                p = pacientes[0]
                nombre = f"{p.get('nombre', '')} {p.get('apellido', '')}".strip()
            cita = _cita_del_dia(supabase, paciente_id)
        except Exception:
            pass

    return {
        'success': True,
        'message': 'Rostro reconocido',
        'data': {
            'paciente_id': paciente_id,
            'nombre': nombre,
            'confianza': confianza,
            'cita': cita,
        },
    }


@app.post('/api/vision/registrar-rostro/{paciente_id}')
def registrar_rostro(paciente_id: int, payload: RegistrarRostroRequest):
    """Registra el rostro de un paciente (KIO-10): guarda las muestras
    recibidas en base64, reentrena el modelo LBPH y genera el descriptor
    vectorial de 128 dimensiones (KIO-07) para `pacientes.rostro_embedding`.

    El frontend envía varias imágenes del rostro; aquí se detecta, se recorta
    y se guardan en el dataset, y luego se vuelve a entrenar el modelo.
    """
    if not payload.imagenes:
        return {
            'success': False,
            'message': 'Al menos una imagen es obligatoria',
            'data': None,
        }

    imagenes = [_decodificar_imagen(b64) for b64 in payload.imagenes]
    if not any(img is not None for img in imagenes):
        return {
            'success': False,
            'message': 'No se pudo decodificar ninguna imagen',
            'data': None,
        }

    # Guardar las muestras detectadas del paciente
    registrado = face_service.registrar_rostro(
        paciente_id, [img for img in imagenes if img is not None]
    )

    # Reentrenar el modelo LBPH con todo el dataset
    entrenamiento = face_service.entrenar_modelo()

    # Descriptor de 128 dimensiones para almacenar en pgvector (KIO-07)
    descriptor = face_service.obtener_descriptor(paciente_id)

    return {
        'success': True,
        'message': 'Rostro registrado y modelo reentrenado',
        'data': {
            'paciente_id': paciente_id,
            'guardadas': registrado['guardados'],
            'entrenamiento': entrenamiento,
            'rostro_embedding': descriptor,
        },
    }