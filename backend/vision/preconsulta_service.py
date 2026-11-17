"""Pipeline de visión de la PreConsulta IA.

Recibe una secuencia de fotogramas JPEG (web) o un video corto (Android) y
devuelve métricas derivadas del rostro:

  - rPPG (POS/CHROM) sobre frente y mejillas: FC, HRV aproximada, respiración.
  - Geometría facial: índice de tensión/dolor, estrés, fatiga, parpadeo,
    expresión dominante y estabilidad de pose.
  - Identidad opcional (SFace) contra la plantilla del paciente, SIN bloquear
    la pre-consulta si no coincide.

Privacidad: los fotogramas se procesan en memoria y se descartan. No se
guardan imágenes, recortes ni video. Solo se devuelven números.

El análisis es de APOYO al triage: no mide SpO2 ni presión arterial y no
emite diagnósticos.
"""

from __future__ import annotations

import base64
import binascii
import math
import os
import tempfile
import threading
from typing import Optional

import cv2
import numpy as np

import preconsulta_metrics as metrics
from face_service import face_service

MODELO_VERSION = os.getenv('PRECONSULTA_MODELO_VERSION', 'preconsulta-vision-1.0.0')

MIN_FRAMES = int(os.getenv('PRECONSULTA_MIN_FRAMES', '60'))
MAX_FRAMES = int(os.getenv('PRECONSULTA_MAX_FRAMES', '600'))
MIN_SEGUNDOS = float(os.getenv('PRECONSULTA_MIN_SEGUNDOS', '10'))
LADO_MAX = int(os.getenv('PRECONSULTA_LADO_MAX', '480'))
MAX_BYTES_FRAME = int(os.getenv('PRECONSULTA_MAX_BYTES_FRAME', '1200000'))
COBERTURA_MINIMA = float(os.getenv('PRECONSULTA_COBERTURA_MINIMA', '0.60'))

# MediaPipe FaceMesh no es thread-safe: una sola inferencia a la vez.
_LOCK = threading.Lock()

SUPABASE_URL = os.getenv('SUPABASE_URL', '')
SUPABASE_KEY = os.getenv('SUPABASE_SERVICE_ROLE_KEY') or os.getenv('SUPABASE_ANON_KEY', '')
_cliente_supabase = None


def _cliente():
    global _cliente_supabase
    if _cliente_supabase is None:
        if not SUPABASE_URL or not SUPABASE_KEY:
            return None
        try:
            from supabase import create_client

            _cliente_supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
        except Exception as exc:  # pragma: no cover - depende del entorno
            print(f'[preconsulta] sin Supabase para identidad: {exc}', flush=True)
            return None
    return _cliente_supabase


def _b64_a_bytes(valor: str) -> bytes:
    texto = (valor or '').strip()
    if not texto:
        raise ValueError('Fotograma vacío')
    if texto.startswith('data:'):
        texto = texto.split(',', 1)[-1]
    try:
        datos = base64.b64decode(texto, validate=False)
    except (binascii.Error, ValueError) as exc:
        raise ValueError('Fotograma con base64 inválido') from exc
    if not datos:
        raise ValueError('Fotograma vacío')
    if len(datos) > MAX_BYTES_FRAME:
        raise ValueError('Fotograma demasiado grande')
    return datos


def _decodificar(valor: str) -> Optional[np.ndarray]:
    datos = _b64_a_bytes(valor)
    arreglo = np.frombuffer(datos, dtype=np.uint8)
    imagen = cv2.imdecode(arreglo, cv2.IMREAD_COLOR)
    return imagen


def _redimensionar(imagen: np.ndarray) -> np.ndarray:
    if imagen is None:
        return imagen
    alto, ancho = imagen.shape[:2]
    mayor = max(alto, ancho)
    if mayor <= LADO_MAX:
        return imagen
    escala = LADO_MAX / float(mayor)
    return cv2.resize(imagen, (max(1, int(ancho * escala)), max(1, int(alto * escala))), interpolation=cv2.INTER_AREA)


def _fps_de_timestamps(timestamps: list) -> float:
    try:
        valores = sorted(float(t) for t in timestamps if t is not None)
    except (TypeError, ValueError):
        return 0.0
    if len(valores) < 2:
        return 0.0
    diffs = np.diff(valores)
    diffs = diffs[diffs > 0]
    if diffs.size == 0:
        return 0.0
    dt = float(np.median(diffs))
    # Acepta milisegundos o segundos según la magnitud.
    if dt <= 0:
        return 0.0
    return 1000.0 / dt if dt > 1.0 else 1.0 / dt


def _cargar_frames(payload: dict):
    """Devuelve (frames BGR, fps declarado, advertencias)."""
    advertencias: list[str] = []
    fps = float(payload.get('fps') or 0)
    timestamps = payload.get('timestamps') or []
    fps_ts = _fps_de_timestamps(timestamps) if timestamps else 0.0
    if fps_ts > 0:
        fps = fps_ts

    frames: list[np.ndarray] = []
    video = payload.get('video') or ''
    if video:
        frames, fps_video = _frames_de_video(video)
        fps = fps or fps_video
        advertencias.append('analisis_desde_video')
    else:
        crudos = payload.get('frames') or []
        if not isinstance(crudos, list):
            raise ValueError('Los fotogramas deben enviarse como lista')
        for indice, item in enumerate(crudos):
            try:
                imagen = _decodificar(item)
            except ValueError as exc:
                raise ValueError(f'Fotograma {indice + 1}: {exc}') from exc
            if imagen is None:
                raise ValueError(f'Fotograma {indice + 1}: no se pudo decodificar (¿JPEG válido?)')
            frames.append(_redimensionar(imagen))

    if len(frames) > MAX_FRAMES:
        # Muestreo uniforme: se conserva la duración y se ajusta el fps.
        indices = np.linspace(0, len(frames) - 1, MAX_FRAMES).round().astype(int)
        fps = fps * (len(indices) / float(len(frames))) if fps else fps
        frames = [frames[i] for i in indices]
        advertencias.append('secuencia_reducida')

    if fps and fps > 120:
        fps = 120.0
    if not fps:
        fps = 20.0
        advertencias.append('fps_asumido_20')

    return frames, float(fps), advertencias


def _frames_de_video(video_b64: str):
    """Decodifica un video base64 (mp4/webm) con OpenCV/FFmpeg."""
    datos = _b64_a_bytes(video_b64)
    if len(datos) > 30 * 1024 * 1024:
        raise ValueError('El video supera el límite de 30 MB')
    ruta = None
    try:
        with tempfile.NamedTemporaryFile(suffix='.mp4', delete=False) as archivo:
            archivo.write(datos)
            ruta = archivo.name
        captura = cv2.VideoCapture(ruta)
        if not captura.isOpened():
            raise ValueError('No se pudo abrir el video enviado')
        fps = float(captura.get(cv2.CAP_PROP_FPS) or 0.0)
        if not math.isfinite(fps) or fps <= 0 or fps > 120:
            fps = 20.0
        total = int(captura.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
        paso = 1
        if total > MAX_FRAMES * 1.4:
            paso = int(math.ceil(total / float(MAX_FRAMES)))
            fps = fps / paso
        frames: list[np.ndarray] = []
        indice = 0
        while True:
            ok, frame = captura.read()
            if not ok:
                break
            if indice % paso == 0:
                frames.append(_redimensionar(frame))
                if len(frames) >= MAX_FRAMES:
                    break
            indice += 1
        captura.release()
        if not frames:
            raise ValueError('El video no contiene fotogramas legibles')
        return frames, float(fps)
    finally:
        if ruta:
            try:
                os.unlink(ruta)
            except OSError:
                pass


def _rois(forma, landmarks) -> list[tuple[int, int, int, int]]:
    """Cajas de frente y mejillas relativas al rostro detectado."""
    alto, ancho = forma[:2]
    xs = [p[0] for p in landmarks]
    ys = [p[1] for p in landmarks]
    x1, x2 = max(0.0, min(xs)), min(1.0, max(xs))
    y1, y2 = max(0.0, min(ys)), min(1.0, max(ys))
    ancho_rostro = max(x2 - x1, 1e-3)
    alto_rostro = max(y2 - y1, 1e-3)

    def caja(fx1, fx2, fy1, fy2):
        return (
            int(max(0, (x1 + fx1 * ancho_rostro) * ancho)),
            int(max(0, (y1 + fy1 * alto_rostro) * alto)),
            int(min(ancho, (x1 + fx2 * ancho_rostro) * ancho)),
            int(min(alto, (y1 + fy2 * alto_rostro) * alto)),
        )

    return [
        caja(0.28, 0.72, 0.04, 0.26),  # frente
        caja(0.08, 0.34, 0.42, 0.66),  # mejilla izquierda
        caja(0.66, 0.92, 0.42, 0.66),  # mejilla derecha
    ]


def _media_roi(imagen_bgr: np.ndarray, cajas) -> Optional[np.ndarray]:
    """Media RGB robusta de las ROIs, con máscara de piel en YCrCb."""
    canales = []
    pixeles_totales = 0
    for (x1, y1, x2, y2) in cajas:
        if x2 - x1 < 8 or y2 - y1 < 8:
            continue
        recorte = imagen_bgr[y1:y2, x1:x2]
        if recorte.size == 0:
            continue
        ycrcb = cv2.cvtColor(recorte, cv2.COLOR_BGR2YCrCb)
        y = ycrcb[:, :, 0]
        cr = ycrcb[:, :, 1]
        cb = ycrcb[:, :, 2]
        mascara = (cr >= 133) & (cr <= 178) & (cb >= 75) & (cb <= 130) & (y >= 35) & (y <= 245)
        if int(np.count_nonzero(mascara)) < 25:
            mascara = np.ones_like(y, dtype=bool)
        pixeles = recorte[mascara]
        if pixeles.size == 0:
            continue
        # Descartar brillos especulares (percentil 98) que no llevan pulso.
        luminancia = pixeles.mean(axis=1)
        limite = float(np.percentile(luminancia, 98))
        pixeles = pixeles[luminancia <= limite]
        if pixeles.size == 0:
            continue
        canales.append((pixeles.mean(axis=0), pixeles.shape[0]))
        pixeles_totales += pixeles.shape[0]
    if not canales or pixeles_totales == 0:
        return None
    suma = np.zeros(3, dtype=np.float64)
    for media_bgr, n in canales:
        suma += media_bgr[::-1] * n  # BGR -> RGB
    return suma / pixeles_totales


def _parse_vector(valor):
    if valor is None:
        return None
    if isinstance(valor, str):
        texto = valor.strip().strip('[]{}')
        if not texto:
            return None
        try:
            return np.asarray([float(x) for x in texto.split(',') if x.strip()], dtype=np.float64)
        except ValueError:
            return None
    if isinstance(valor, (list, tuple)):
        try:
            return np.asarray([float(x) for x in valor], dtype=np.float64)
        except (TypeError, ValueError):
            return None
    return None


def _identidad(paciente_id, frame_bgr) -> Optional[dict]:
    if not paciente_id or frame_bgr is None:
        return None
    cliente = _cliente()
    if cliente is None:
        return None
    try:
        respuesta = (
            cliente.table('pacientes')
            .select('rostro_embedding')
            .eq('id', int(paciente_id))
            .limit(1)
            .execute()
        )
        filas = getattr(respuesta, 'data', None) or []
        if not filas:
            return None
        plantilla = _parse_vector(filas[0].get('rostro_embedding'))
        if plantilla is None or plantilla.size == 0:
            return {'disponible': False, 'motivo': 'paciente_sin_rostro_registrado'}
        sonda = face_service.embedding_de(frame_bgr)
        if not sonda:
            return {'disponible': False, 'motivo': 'sin_rostro_en_mejor_frame'}
        similitud = face_service.similitud(sonda, plantilla.tolist())
        umbral = 0.5
        return {
            'disponible': True,
            'similitud': similitud,
            'coincide': bool(similitud >= umbral),
            'umbral': umbral,
        }
    except Exception as exc:  # la identidad nunca bloquea la pre-consulta
        print(f'[preconsulta] identidad no disponible: {exc}', flush=True)
        return {'disponible': False, 'motivo': 'error_consulta_identidad'}


def analizar(payload: dict) -> dict:
    """Analiza la captura y devuelve el contrato acordado con Node.

    Lanza ValueError para entradas inválidas (FastAPI responde 422).
    """
    frames, fps, advertencias = _cargar_frames(payload)
    if len(frames) < MIN_FRAMES:
        raise ValueError(
            f'Captura insuficiente: se recibieron {len(frames)} fotogramas y se requieren al menos {MIN_FRAMES}'
        )

    duracion = len(frames) / fps if fps else 0.0
    if duracion < MIN_SEGUNDOS:
        raise ValueError(
            f'La captura dura {duracion:.1f} s; se requieren al menos {MIN_SEGUNDOS:.0f} s para estimar signos'
        )

    rgb_series: list[np.ndarray] = []
    features: list[Optional[dict]] = []
    brillos: list[float] = []
    nitideces: list[float] = []
    mejor_frame = None
    mejor_puntaje = -1.0

    with _LOCK:
        try:
            mesh = face_service._facemesh()
        except Exception as exc:
            raise RuntimeError(f'MediaPipe no disponible: {exc}') from exc

        for frame in frames:
            alto, ancho = frame.shape[:2]
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            resultado = mesh.process(rgb)
            if not resultado.multi_face_landmarks:
                features.append(None)
                continue
            landmarks_raw = resultado.multi_face_landmarks[0].landmark
            landmarks = [(float(p.x), float(p.y)) for p in landmarks_raw]
            features.append(metrics.extraer_features(landmarks))

            cajas = _rois(frame.shape, landmarks)
            media_rgb = _media_roi(frame, cajas)
            if media_rgb is not None:
                rgb_series.append(media_rgb)
            else:
                rgb_series.append(np.array([0.0, 0.0, 0.0], dtype=np.float64))

            # Calidad por frame: brillo del rostro y nitidez del recorte.
            xs = [p[0] for p in landmarks]
            ys = [p[1] for p in landmarks]
            bx1 = int(max(0, min(xs) * ancho))
            bx2 = int(min(ancho, max(xs) * ancho))
            by1 = int(max(0, min(ys) * alto))
            by2 = int(min(alto, max(ys) * alto))
            if bx2 - bx1 > 10 and by2 - by1 > 10:
                rostro = frame[by1:by2, bx1:bx2]
                gris = cv2.cvtColor(rostro, cv2.COLOR_BGR2GRAY)
                brillo = float(np.mean(gris))
                nitidez = float(cv2.Laplacian(gris, cv2.CV_64F).var())
                brillos.append(brillo)
                nitideces.append(nitidez)
                # Mejor frame para identidad: nítido, frontal y grande.
                feat = features[-1] or {}
                frontal = 1.0 - min(1.0, abs(feat.get('yaw', 0.0)) / 0.20)
                puntaje = min(nitidez / 220.0, 1.5) + frontal + min(feat.get('interocular', 0.0) / 0.20, 1.0)
                if puntaje > mejor_puntaje:
                    mejor_puntaje = puntaje
                    mejor_frame = rostro.copy()

    analizados = sum(1 for f in features if f)
    cobertura = analizados / float(len(frames)) if frames else 0.0
    base = {
        'ok': False,
        'modelo_version': MODELO_VERSION,
        'frames_recibidos': len(frames),
        'frames_analizados': analizados,
        'duracion_seg': round(duracion, 2),
        'fps_efectivo': round(fps, 2),
        'no_es_diagnostico': True,
        'advertencias': list(advertencias),
    }
    if cobertura < COBERTURA_MINIMA:
        base['motivo'] = 'rostro_insuficiente'
        base['detalle'] = (
            f'Solo se detectó un rostro en {cobertura * 100:.0f}% de los fotogramas '
            f'(mínimo {COBERTURA_MINIMA * 100:.0f}%). Repita la captura con el rostro centrado y buena luz.'
        )
        return base

    # Completar la serie RGB para frames sin rostro interpolando (evita
    # huecos que rompen el muestreo uniforme del rPPG).
    serie = np.asarray(rgb_series, dtype=np.float64)
    validos = np.where(serie.sum(axis=1) > 0)[0]
    if validos.size >= 2:
        for canal in range(3):
            serie[:, canal] = np.interp(
                np.arange(serie.shape[0]), validos, serie[validos, canal]
            )

    vitales = metrics.estimar_hr(serie, fps)
    hrv = metrics.estimar_hrv(serie, fps)
    respiracion = metrics.estimar_respiracion(serie, fps)
    rostro = metrics.analizar_rostro(features, fps, {**vitales, **hrv})

    pose_estabilidad = rostro.get('pose_estabilidad')
    interocular = float(np.median([f['interocular'] for f in features if f])) if analizados else 0.0
    calidad = metrics.puntuar_calidad(
        cobertura=cobertura,
        brillo=float(np.mean(brillos)) if brillos else 0.0,
        nitidez=float(np.mean(nitideces)) if nitideces else 0.0,
        estabilidad=pose_estabilidad if pose_estabilidad is not None else 0.5,
        tamano_rostro=interocular,
        duracion_seg=duracion,
    )

    if vitales.get('hr_confianza', 0) < 0.35:
        advertencias.append('senal_cardíaca_debil')
    if calidad['puntaje'] < 55:
        advertencias.append('calidad_baja')
    if not respiracion.get('respiraciones_rpm'):
        advertencias.append('respiracion_no_concluyente')

    identidad = None
    if payload.get('identidad', True):
        identidad = _identidad(payload.get('paciente_id'), mejor_frame)

    base.update(
        {
            'ok': True,
            'rostro_detectado': True,
            'fps_efectivo': vitales.get('fps_efectivo') or round(fps, 2),
            'calidad': calidad,
            'vitales': {
                **vitales,
                **{k: v for k, v in hrv.items() if k != 'hr_confianza'},
                **respiracion,
            },
            'rostro': rostro,
            'identidad': identidad,
            'advertencias': sorted(set(advertencias)),
            'no_es_diagnostico': True,
        }
    )
    return base


def version() -> dict:
    return {
        'modelo_version': MODELO_VERSION,
        'metricas_version': 'rppg-pos-chrom-1.0.0',
        'rostro_version': 'facemesh-geometria-1.0.0',
        'min_frames': MIN_FRAMES,
        'max_frames': MAX_FRAMES,
        'no_es_diagnostico': True,
    }
