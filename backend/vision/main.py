import base64
import os
from datetime import date
from typing import Optional

import cv2
import numpy as np
from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from supabase import create_client

from face_service import face_service, UMBRAL_SIMILITUD, MODEL_PACK

load_dotenv()

# Warmup al arranque: precarga los modelos InsightFace + MediaPipe ANTES de
# aceptar requests. La primera inferencia en frío tarda 30-60s (descarga +
# carga en RAM) y reventaría el timeout del backend; con warmup el servicio
# solo marca /health OK cuando ya puede responder rápido.
from contextlib import asynccontextmanager


@asynccontextmanager
async def lifespan(app: FastAPI):
    try:
        face_service._detector_yunet()
        face_service._reconocedor_sface()
        print('[vision] modelos YuNet+SFace listos', flush=True)
    except Exception as exc:
        print(f'[vision] AVISO: modelos no cargaron al arranque: {exc}', flush=True)
    yield


app = FastAPI(
    title='Vision Service - Consultorio Clínico',
    version='0.4.0',
    lifespan=lifespan,
)

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
    # Secuencia opcional de 2+ frames (desafío de liveness del kiosco).
    secuencia: list = []
    # Umbral de similitud coseno (si no viene, usa VISION_SIMILARITY_THRESHOLD).
    umbral: Optional[float] = None


class RegistrarRostroRequest(BaseModel):
    # Acepta [{ imagen, pose }] y, por compatibilidad, [base64, ...].
    imagenes: list = []
    # True si las fotos vienen espejadas (cámara frontal web): se invierte
    # el yaw al verificar izquierda/derecha.
    espejado: bool = False


class EvaluarGestoRequest(BaseModel):
    # Un frame de la vista previa (JPEG liviano) para guía en vivo.
    imagen: str = ''
    # Pose que el paciente intenta (frontal|izquierda|derecha|arriba|abajo).
    pose: str = 'frontal'
    # Ancla frontal (yaw/pitch medidos al capturar la frontal); sin ancla
    # el pitch de arriba/abajo no se puede comparar y se aprueba.
    yaw_ref: Optional[float] = None
    pitch_ref: Optional[float] = None
    # True si el frame viene espejado (web): se invierte el yaw.
    espejado: bool = False


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


def _parse_vector(valor):
    """Normaliza un embedding pgvector a lista de floats.

    postgrest lo devuelve como string "[0.1,0.2,...]" (o lista según el
    cliente/versión): se aceptan ambas formas.
    """
    if isinstance(valor, list):
        try:
            nums = [float(x) for x in valor]
        except (TypeError, ValueError):
            return None
        return nums
    if isinstance(valor, str):
        texto = valor.strip()
        if not (texto.startswith('[') and texto.endswith(']')):
            return None
        try:
            return [float(x) for x in texto[1:-1].split(',') if x.strip() != '']
        except ValueError:
            return None
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


@app.get('/api/vision/version')
def version():
    """Versión del servicio (para verificar despliegues)."""
    return {'version': '1.1.3', 'pose_check': True, 'model': MODEL_PACK}


@app.post('/api/vision/evaluar-gesto')
def evaluar_gesto(payload: EvaluarGestoRequest):
    """Guía en vivo para la captura automática (estilo Binance): evalúa UN
    frame de la vista previa SIN registrar nada (sin writes, sin paciente).

    El cliente envía frames solo con encuadre decente; el servidor decide
    con landmarks reales (YuNet) si el gesto pedido se ejecutó. Los
    umbrales viven aquí (env VISION_POSE_*): se afinan sin actualizar apps.
    """

    pose = (payload.pose or 'frontal').strip().lower()
    imagen = _decodificar_imagen(payload.imagen) if payload.imagen else None
    if imagen is None:
        return {
            'success': False,
            'message': 'No se pudo decodificar la imagen',
            'data': {'tiene_rostro': False, 'gesto_ok': False},
        }
    try:
        caras = face_service.detectar(imagen)
    except Exception as exc:
        return {
            'success': False,
            'message': f'Detector no disponible: {exc}',
            'data': {'tiene_rostro': False, 'gesto_ok': False},
        }
    if len(caras) != 1:
        return {
            'success': True,
            'message': 'Ubica tu rostro dentro del óvalo',
            'data': {'tiene_rostro': False, 'gesto_ok': False},
        }
    mets = face_service.metricas_pose(caras[0].get('landmarks'))
    q = face_service.calidad(imagen, caras)
    gesto = face_service.verificar_gesto(
        pose, mets, None, payload.pitch_ref, payload.espejado)
    # El ancla de yaw no se necesita (el yaw es absoluto); el pitch sí se
    # compara contra la frontal enviada por el cliente.
    ok = bool(q['ok']) and gesto is True
    if not q['ok']:
        mensaje = {
            'rostro_muy_lejos': 'Acércate más a la cámara',
            'rostro_muy_pequeno': 'Acércate más a la cámara',
            'rostro_cortado': 'Centra tu rostro en el óvalo',
            'mala_iluminacion': 'Busca mejor luz',
            'foto_borrosa': 'Quédate quieto…',
        }.get(q.get('motivo') or '', 'Ajusta el encuadre')
    elif gesto is not True:
        mensaje = {
            'frontal': 'Mira de frente a la cámara',
            'izquierda': 'Gira más tu cara a tu izquierda',
            'derecha': 'Gira más tu cara a tu derecha',
            'arriba': 'Levanta más el mentón',
            'abajo': 'Baja más el mentón',
        }.get(pose, 'Mantén la posición')
    else:
        mensaje = '¡Perfecto!'
    return {
        'success': True,
        'message': mensaje,
        'data': {
            'tiene_rostro': True,
            'yaw': (mets or {}).get('yaw'),
            'pitch': (mets or {}).get('pitch'),
            'calidad': q['puntaje'],
            'gesto_ok': ok,
        },
    }


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

    umbral = payload.umbral if payload.umbral else UMBRAL_SIMILITUD

    # Liveness: con secuencia se exige parpadeo o giro (anti foto impresa);
    # con una sola imagen se informa y se sigue (el kiosco decide).
    frames = [_decodificar_imagen(b64) for b64 in (payload.secuencia or [])]
    frames = [f for f in frames if f is not None]
    liveness = face_service.liveness([imagen] + frames if frames else [imagen])

    sonda = face_service.embedding_de(imagen)
    if sonda is None:
        return {
            'success': False,
            'message': 'No se detectó un rostro en la imagen',
            'data': {'paciente_id': None, 'nombre': None, 'similitud': None, 'liveness': liveness, 'cita': None},
        }

    # Plantillas vigentes desde Supabase (el kiosco puede pasar su shortlist;
    # por defecto se comparan todas las registradas, límite operativo 2000).
    # NOTA: sin .not_() (cambió en postgrest-py v2): se filtra en Python y
    # el vector llega como string "[...]" (se parsea con _parse_vector).
    plantillas = {}
    supabase = _cliente_supabase()
    if supabase:
        try:
            data_emb = (
                supabase.from_('pacientes')
                .select('id, rostro_embedding')
                .limit(2000)
                .execute()
            )
            for fila in data_emb.data or []:
                emb = _parse_vector(fila.get('rostro_embedding'))
                if emb is not None and len(emb) == 128:
                    plantillas[fila['id']] = emb
        except Exception:
            plantillas = {}

    match = face_service.comparar(sonda, plantillas, umbral=umbral)
    paciente_id = match.get('clave')
    similitud = match.get('similitud')

    if paciente_id is None:
        return {
            'success': False,
            'message': 'Rostro no reconocido',
            'data': {'paciente_id': None, 'nombre': None, 'similitud': similitud, 'liveness': liveness, 'cita': None},
        }

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
            'similitud': similitud,
            'confianza': similitud,  # compat: el kiosco Flutter lee `confianza`
            'liveness': liveness,
            'cita': cita,
        },
    }


@app.post('/api/vision/registrar-rostro/{paciente_id}')
def registrar_rostro(paciente_id: int, payload: RegistrarRostroRequest):
    """Registra el rostro de un paciente (multi-pose, YuNet+SFace): por cada
    muestra se mide calidad, se genera el embedding 128-d y la foto liviana
    (recorte JPEG); el promedio normalizado es la plantilla del paciente.

    El frontend envía [{ imagen, pose }] (o [base64, ...] por compatibilidad).
    Ya NO hay reentrenamiento global: los embeddings se comparan por similitud
    coseno, así que registrar a un paciente no afecta a los demás.
    """
    if not payload.imagenes:
        return {
            'success': False,
            'message': 'Al menos una imagen es obligatoria',
            'data': None,
        }

    muestras = []
    for m in payload.imagenes:
        if isinstance(m, dict):
            b64 = m.get('imagen')
            pose = m.get('pose', 'frontal')
        else:
            b64, pose = m, 'frontal'
        img = _decodificar_imagen(b64) if isinstance(b64, str) else None
        if img is not None:
            muestras.append({'imagen': img, 'pose': pose})

    if not muestras:
        return {
            'success': False,
            'message': 'No se pudo decodificar ninguna imagen',
            'data': None,
        }

    resultado = face_service.registrar(paciente_id, muestras, espejado=payload.espejado)
    if resultado.get('error'):
        return {
            'success': False,
            'message': resultado['error'],
            'data': None,
        }

    return {
        'success': True,
        'message': 'Rostro registrado (multi-pose)',
        'data': {
            'paciente_id': paciente_id,
            'guardadas': sum(1 for m in resultado['muestras'] if m.get('guardada')),
            'muestras': resultado['muestras'],
            'rostro_embedding': resultado['rostro_embedding'],
            'modelo': MODEL_PACK,
        },
    }