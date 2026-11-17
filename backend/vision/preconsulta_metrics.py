"""Funciones puras de la PreConsulta IA (sin OpenCV ni MediaPipe).

Aquí vive la matemática del análisis:
  - rPPG POS (Plane-Orthogonal-to-Skin) para estimar la frecuencia cardíaca.
  - HRV aproximada (RMSSD/SDNN/pNN50) a partir de los picos de la señal.
  - Frecuencia respiratoria por banda 0.1-0.5 Hz.
  - Índices faciales relativos (tensión/dolor, estrés, fatiga, parpadeo,
    expresiones) calculados con geometría de landmarks ya extraída.

Al no importar cv2/mediapipe se puede testear con `python -m unittest` en
cualquier equipo con NumPy. La captura y la inferencia viven en
`preconsulta_service.py`.

AVISO CLÍNICO: estas estimaciones son de apoyo al triage. No son un
dispositivo médico, no miden SpO2 ni presión arterial y no emiten
diagnósticos.
"""

from __future__ import annotations

import math
from typing import Iterable, Optional

import numpy as np

# Frecuencia cardíaca admisible (adultos y pediatría): 42-190 lpm.
HR_MIN_HZ = 0.70
HR_MAX_HZ = 3.16
# Respiración: 6-30 rpm.
RR_MIN_HZ = 0.10
RR_MAX_HZ = 0.50

# Duración mínima para intentar rPPG (segundos).
MIN_SEGUNDOS_VITALES = 8.0
MIN_SEGUNDOS_HRV = 12.0


def _serie(valores: Iterable[float]) -> np.ndarray:
    arr = np.asarray(list(valores), dtype=np.float64)
    return np.nan_to_num(arr, nan=0.0, posinf=0.0, neginf=0.0)


def _fps_valido(fps: float) -> float:
    try:
        f = float(fps)
    except (TypeError, ValueError):
        return 0.0
    if not math.isfinite(f) or f <= 0:
        return 0.0
    return float(min(max(f, 5.0), 120.0))


def _detrend(x: np.ndarray) -> np.ndarray:
    """Elimina tendencia lineal (barata y estable para ventanas cortas)."""
    n = x.size
    if n < 3:
        return x - np.mean(x)
    t = np.linspace(-1.0, 1.0, n)
    coef = np.polyfit(t, x, 1)
    return x - np.polyval(coef, t)


def _normalizar_ventana(c: np.ndarray) -> np.ndarray:
    """Normaliza cada canal por su media temporal (POS exige Cn = C/media)."""
    medias = np.mean(c, axis=1, keepdims=True)
    medias = np.where(np.abs(medias) < 1e-6, 1e-6, medias)
    return c / medias


def pos_signal(rgb: np.ndarray, fps: float) -> np.ndarray:
    """Extrae la señal de pulso con POS (Wang et al., 2017).

    :param rgb: matriz (N, 3) con la media RGB (0-255) de la ROI por frame.
    :param fps: fotogramas por segundo efectivos.

    Implementación:
      1. Cn = C / media(C) por canal.
      2. Ventana deslizante de 1.6 s con solape (paso 1).
      3. Proyección POS: S = H @ Cn con H = [[0,1,-1],[-2,1,1]].
      4. h = S0 + (std(S0)/std(S1)) * S1.
      5. Suma con solape (overlap-add) y normalización final.

    Devuelve una señal 1-D de la misma longitud que la entrada. Si no hay
    datos suficientes devuelve ceros (el llamador decide la confianza).
    """
    c = np.asarray(rgb, dtype=np.float64)
    if c.ndim != 2 or c.shape[0] < 8 or c.shape[1] != 3:
        return np.zeros(max(0, c.shape[0] if c.ndim == 2 else 0), dtype=np.float64)
    f = _fps_valido(fps)
    if f <= 0:
        return np.zeros(c.shape[0], dtype=np.float64)

    n = c.shape[0]
    cn = _normalizar_ventana(c.T)  # (3, N)
    largo = int(round(max(8, min(n, f * 1.6))))
    if largo >= n:
        largo = max(8, n - 1)
    if largo < 8:
        return np.zeros(n, dtype=np.float64)

    h_matriz = np.array([[0.0, 1.0, -1.0], [-2.0, 1.0, 1.0]], dtype=np.float64)
    salida = np.zeros(n, dtype=np.float64)
    pesos = np.zeros(n, dtype=np.float64)
    peso_ventana = np.hanning(largo)
    if not np.any(peso_ventana):
        peso_ventana = np.ones(largo, dtype=np.float64)

    for inicio in range(0, n - largo + 1):
        ventana = cn[:, inicio:inicio + largo]
        ventana = ventana - np.mean(ventana, axis=1, keepdims=True)
        s = h_matriz @ ventana
        std0 = float(np.std(s[0]))
        std1 = float(np.std(s[1]))
        if std1 < 1e-9:
            continue
        h = s[0] + (std0 / std1) * s[1]
        salida[inicio:inicio + largo] += h * peso_ventana
        pesos[inicio:inicio + largo] += peso_ventana

    pesos = np.where(pesos < 1e-9, 1.0, pesos)
    salida = salida / pesos
    salida = _detrend(salida)
    desv = float(np.std(salida))
    if desv < 1e-9:
        return np.zeros(n, dtype=np.float64)
    return (salida - np.mean(salida)) / desv


def chrom_signal(rgb: np.ndarray, fps: float) -> np.ndarray:
    """Señal CHROM de respaldo (de Haan & Jeanne, 2013).

    Se usa solo si POS devuelve una señal degenerada. Es más sensible a
    cambios de iluminación, por eso no es la vía principal.
    """
    c = np.asarray(rgb, dtype=np.float64)
    if c.ndim != 2 or c.shape[0] < 8 or c.shape[1] != 3:
        return np.zeros(max(0, c.shape[0] if c.ndim == 2 else 0), dtype=np.float64)
    cn = _normalizar_ventana(c.T)
    x = 3.0 * cn[0] - 2.0 * cn[1]
    y = 1.5 * cn[0] + cn[1] - 1.5 * cn[2]
    std_x = float(np.std(x))
    std_y = float(np.std(y))
    if std_y < 1e-9:
        return np.zeros(c.shape[0], dtype=np.float64)
    salida = x + (std_x / std_y) * y
    salida = _detrend(salida)
    desv = float(np.std(salida))
    if desv < 1e-9:
        return np.zeros(c.shape[0], dtype=np.float64)
    return (salida - np.mean(salida)) / desv


def bandpass(signal: np.ndarray, fps: float, low: float, high: float) -> np.ndarray:
    """Filtro pasa-banda por FFT (sin SciPy).

    En señales cortas un Butterworth IIR distorsiona la fase; enmascarar
    bins en frecuencia es estable, determinista y suficiente para localizar
    el pico.
    """
    x = np.asarray(signal, dtype=np.float64)
    n = x.size
    f = _fps_valido(fps)
    if n < 8 or f <= 0:
        return np.zeros(n, dtype=np.float64)
    x = np.nan_to_num(x - np.mean(x), nan=0.0)
    ventana = np.hanning(n)
    espectro = np.fft.rfft(x * ventana)
    freqs = np.fft.rfftfreq(n, d=1.0 / f)
    mascara = (freqs >= low) & (freqs <= high)
    espectro = np.where(mascara, espectro, 0.0)
    salida = np.fft.irfft(espectro, n=n)
    return np.nan_to_num(salida, nan=0.0)


def _espectro_potencia(signal: np.ndarray, fps: float, nfft_min: int = 4096):
    x = np.asarray(signal, dtype=np.float64)
    n = x.size
    if n < 8:
        return np.array([]), np.array([])
    x = x - np.mean(x)
    x = x * np.hanning(n)
    nfft = 1
    while nfft < max(nfft_min, n * 4):
        nfft *= 2
    espectro = np.fft.rfft(x, n=nfft)
    potencia = (np.abs(espectro) ** 2) / max(nfft, 1)
    freqs = np.fft.rfftfreq(nfft, d=1.0 / _fps_valido(fps))
    return freqs, potencia


def _pico_con_interpolacion(freqs: np.ndarray, potencia: np.ndarray, low: float, high: float):
    """Pico espectral en [low, high] con interpolación parabólica.

    Devuelve (frecuencia, concentración, relación señal/resto, snr_db).
    """
    if freqs.size == 0 or potencia.size == 0:
        return 0.0, 0.0, 1.0, 0.0
    mascara = (freqs >= low) & (freqs <= high)
    if not np.any(mascara):
        return 0.0, 0.0, 1.0, 0.0
    idx = np.where(mascara)[0]
    pot_banda = potencia[idx]
    if pot_banda.size == 0 or float(np.sum(pot_banda)) <= 0:
        return 0.0, 0.0, 1.0, 0.0
    rel = int(np.argmax(pot_banda))
    i = int(idx[rel])
    f0 = float(freqs[i])

    # Interpolación parabólica en escala logarítmica (más estable).
    if 0 < i < freqs.size - 1:
        y0 = math.log(max(float(potencia[i - 1]), 1e-18))
        y1 = math.log(max(float(potencia[i]), 1e-18))
        y2 = math.log(max(float(potencia[i + 1]), 1e-18))
        denom = (y0 - 2.0 * y1 + y2)
        if abs(denom) > 1e-12:
            delta = 0.5 * (y0 - y2) / denom
            delta = max(-0.5, min(0.5, delta))
            paso = float(freqs[1] - freqs[0]) if freqs.size > 1 else 0.0
            f0 = f0 + delta * paso

    # Concentración: energía en ±0.10 Hz alrededor del pico / energía de banda.
    ancho = 0.10
    vecindad = (freqs >= f0 - ancho) & (freqs <= f0 + ancho)
    pot_pico = float(np.sum(potencia[vecindad]))
    pot_total = float(np.sum(pot_banda))
    concentracion = float(np.clip(pot_pico / max(pot_total, 1e-18), 0.0, 1.0))
    resto = max(pot_total - pot_pico, 1e-18)
    snr = pot_pico / resto
    snr_db = 10.0 * math.log10(max(snr, 1e-9))
    return f0, concentracion, snr, snr_db


def _senal_y_metodo(rgb, fps: float):
    """Devuelve (señal de pulso, método) eligiendo POS o CHROM."""
    senal = pos_signal(rgb, fps)
    if not np.any(senal) or float(np.std(senal)) < 1e-6:
        return chrom_signal(rgb, fps), 'chrom'
    return senal, 'pos'


def senal_pulso(rgb, fps: float) -> np.ndarray:
    """Señal de pulso 1-D a partir de la serie RGB o de una señal ya extraída.

    POS es la vía principal; CHROM solo si POS degenera. Acepta también una
    señal 1-D (útil cuando el llamador ya calculó el pulso) para que HRV y
    respiración compartan exactamente la misma serie.
    """
    c = np.asarray(rgb, dtype=np.float64)
    f = _fps_valido(fps)
    if c.ndim == 1:
        return np.nan_to_num(c, nan=0.0)
    if c.ndim != 2 or c.shape[1] != 3 or f <= 0:
        return np.zeros(c.shape[0] if c.ndim == 2 else 0, dtype=np.float64)
    return _senal_y_metodo(c, f)[0]


def estimar_hr(rgb: np.ndarray, fps: float) -> dict:
    """Estima frecuencia cardíaca, SNR y confianza a partir de la serie RGB.

    Devuelve claves vacías/None cuando no hay señal suficiente para no
    inventar un valor clínico.
    """
    n = int(np.asarray(rgb).shape[0]) if np.asarray(rgb).ndim == 2 else 0
    segundos = n / fps if fps and fps > 0 else 0.0
    vacio = {
        'hr_bpm': None,
        'hr_confianza': 0.0,
        'senal_snr_db': None,
        'senal_confianza': 0.0,
        'concentracion': 0.0,
        'fps_efectivo': round(fps, 2) if fps else 0.0,
        'duracion_seg': round(segundos, 2),
        'metodo': 'ninguno',
    }
    if n < 8 or _fps_valido(fps) <= 0 or segundos < MIN_SEGUNDOS_VITALES:
        return vacio

    f = _fps_valido(fps)
    senal, metodo = _senal_y_metodo(rgb, f)
    if float(np.std(senal)) < 1e-6:
        return vacio

    filtrada = bandpass(senal, f, HR_MIN_HZ, HR_MAX_HZ)
    if float(np.std(filtrada)) < 1e-9:
        return vacio
    freqs, potencia = _espectro_potencia(filtrada, f)
    f0, concentracion, snr, snr_db = _pico_con_interpolacion(freqs, potencia, HR_MIN_HZ, HR_MAX_HZ)
    if f0 <= 0:
        return vacio

    # Confianza: concentración espectral + SNR + duración. Es una confianza
    # de SEÑAL, no probabilidad clínica. Tope 0.95 por honestidad.
    bonus_duracion = 0.08 if segundos >= 18 else (0.04 if segundos >= 12 else 0.0)
    confianza = 0.15 + 0.55 * concentracion + 0.22 * math.tanh(snr / 2.0) + bonus_duracion
    confianza = float(np.clip(confianza, 0.0, 0.95))

    bpm = f0 * 60.0
    if bpm < 30 or bpm > 220:
        return vacio
    return {
        'hr_bpm': round(float(bpm), 1),
        'hr_confianza': round(confianza, 3),
        'senal_snr_db': round(float(snr_db), 2),
        'senal_confianza': round(confianza, 3),
        'concentracion': round(float(concentracion), 3),
        'fps_efectivo': round(f, 2),
        'duracion_seg': round(segundos, 2),
        'metodo': metodo,
    }


def _picos(x: np.ndarray, fps: float, distancia_min_s: float, prominencia: float) -> np.ndarray:
    """Detección de picos sin SciPy (máximos locales + separación mínima)."""
    if x.size < 3:
        return np.array([], dtype=int)
    distancia = max(1, int(round(distancia_min_s * max(fps, 1.0))))
    candidatos = np.where((x[1:-1] > x[:-2]) & (x[1:-1] >= x[2:]))[0] + 1
    if candidatos.size == 0:
        return np.array([], dtype=int)
    umbral = float(np.std(x)) * float(prominencia)
    orden = candidatos[np.argsort(x[candidatos])[::-1]]
    elegidos: list[int] = []
    for idx in orden:
        if x[idx] < umbral:
            continue
        if all(abs(int(idx) - j) >= distancia for j in elegidos):
            elegidos.append(int(idx))
    return np.array(sorted(elegidos), dtype=int)


def estimar_hrv(senal: np.ndarray, fps: float) -> dict:
    """HRV aproximada desde la señal de pulso (1-D) o la serie RGB.

    rPPG tiene jitter de picos: el RMSSD resultante es una APROXIMACIÓN con
    confianza limitada (tope 0.70). Se descartan intervalos fuera de
    300-1500 ms y a más de 25% de la mediana.
    """
    vacio = {
        'rmssd_ms': None,
        'sdnn_ms': None,
        'pnn50': None,
        'hrv_confianza': 0.0,
        'latidos': 0,
    }
    x = np.asarray(senal, dtype=np.float64)
    f = _fps_valido(fps)
    if x.ndim == 2:
        x = senal_pulso(x, f)
    if x.size < 8 or f <= 0 or x.size / f < MIN_SEGUNDOS_HRV:
        return vacio
    filtrada = bandpass(x, f, 0.8, 3.3)
    if float(np.std(filtrada)) < 1e-9:
        return vacio
    picos = _picos(filtrada, f, 0.40, 0.35)
    if picos.size < 8:
        return vacio
    ibi = np.diff(picos) * 1000.0 / f
    ibi = ibi[(ibi >= 300.0) & (ibi <= 1500.0)]
    if ibi.size < 7:
        return vacio
    mediana = float(np.median(ibi))
    ibi = ibi[np.abs(ibi - mediana) <= 0.25 * mediana]
    if ibi.size < 7:
        return vacio
    diffs = np.diff(ibi)
    rmssd = float(np.sqrt(np.mean(diffs ** 2))) if diffs.size else 0.0
    sdnn = float(np.std(ibi))
    pnn50 = float(np.mean(np.abs(diffs) > 50.0) * 100.0) if diffs.size else 0.0
    # Confianza: cantidad de latidos y estabilidad de los intervalos.
    cv = float(np.std(ibi) / max(np.mean(ibi), 1e-6))
    confianza = 0.20 + min(0.35, ibi.size * 0.015) + max(0.0, 0.20 - cv)
    return {
        'rmssd_ms': round(rmssd, 1),
        'sdnn_ms': round(sdnn, 1),
        'pnn50': round(pnn50, 1),
        'hrv_confianza': round(float(np.clip(confianza, 0.0, 0.70)), 3),
        'latidos': int(ibi.size + 1),
    }


def estimar_respiracion(senal: np.ndarray, fps: float) -> dict:
    """Frecuencia respiratoria aproximada desde la serie RGB o una señal 1-D.

    La respiración modula la intensidad media del rostro (movimiento de la
    caja torácica y cambios de perfusión). Con RGB se usa el canal verde
    normalizado, que es el más estable. La ventana corta (20-30 s) da una
    resolución de ~2 rpm; por eso la confianza se mantiene baja y el dato es
    opcional en la UI.
    """
    vacio = {'respiraciones_rpm': None, 'rr_confianza': 0.0}
    x = np.asarray(senal, dtype=np.float64)
    f = _fps_valido(fps)
    if x.ndim == 2 and x.shape[1] == 3:
        # Luminancia media SIN normalizar por el color: la respiración modula
        # la intensidad de forma común a los tres canales y una normalización
        # cromática la cancelaría.
        x = np.mean(x, axis=1)
    if x.size < 8 or f <= 0 or x.size / f < 15.0:
        return vacio
    filtrada = bandpass(x, f, RR_MIN_HZ, RR_MAX_HZ)
    if float(np.std(filtrada)) < 1e-9:
        return vacio

    # Autocorrelación: exige periodicidad real, no un pico cualquiera del
    # espectro. En ventanas de 20-30 s la banda 0.1-0.5 Hz tiene muy pocos
    # bins y un pico espectral aislado no distingue señal de ruido.
    centro = filtrada - float(np.mean(filtrada))
    desv = float(np.std(centro))
    if desv < 1e-12:
        return vacio
    centro = centro / desv
    corr = np.correlate(centro, centro, mode='full')[centro.size - 1:]
    corr = corr / max(float(corr[0]), 1e-12)
    lag_min = max(2, int(math.floor(f / RR_MAX_HZ)))
    lag_max = min(corr.size - 2, int(math.ceil(f / RR_MIN_HZ)))
    if lag_max - lag_min < 2:
        return vacio
    lags = np.arange(lag_min, lag_max + 1)
    valores = corr[lags]
    mejor = int(np.argmax(valores))
    pico = float(valores[mejor])
    if pico < 0.55:
        return vacio
    # No aceptar el extremo de la ventana: indica tendencia, no ciclo.
    if mejor == 0 or mejor == valores.size - 1:
        return vacio
    lag = float(lags[mejor])
    # Un ciclo respiratorio real repite a 2*lag; el ruido no. Exigirlo evita
    # inventar una frecuencia a partir de una ondulación casual.
    armonico = float(corr[min(int(round(2 * lag)), corr.size - 1)])
    if armonico < 0.30:
        return vacio
    # Interpolación parabólica del máximo de autocorrelación.
    y0, y1, y2 = float(valores[mejor - 1]), float(valores[mejor]), float(valores[mejor + 1])
    denom = y0 - 2.0 * y1 + y2
    if abs(denom) > 1e-12:
        delta = 0.5 * (y0 - y2) / denom
        lag += max(-0.5, min(0.5, delta))
    if lag <= 0:
        return vacio
    rpm = 60.0 * f / lag
    if rpm < 6 or rpm > 40:
        return vacio
    # Confianza baja por diseño: es un apoyo, no una medición.
    confianza = float(np.clip(0.12 + 0.40 * (pico - 0.55) / 0.40, 0.0, 0.50))
    return {'respiraciones_rpm': round(float(rpm), 1), 'rr_confianza': round(confianza, 3)}


# ---------------------------------------------------------------------------
# Índices faciales (geometría de landmarks)
# ---------------------------------------------------------------------------

# Landmarks MediaPipe usados (468 puntos estándar).
OJO_IZQ = [33, 160, 158, 133, 153, 144]
OJO_DER = [362, 385, 387, 263, 373, 380]
CEJA_IZQ = [70, 63, 105, 66, 107]
CEJA_DER = [336, 296, 334, 293, 300]
NARIZ_PUENTE = 168
NARIZ_PUNTA = 1
NARIZ_BASE = 2
LABIO_SUP = 13
LABIO_INF = 14
COMISURA_IZQ = 61
COMISURA_DER = 291
OJO_IZQ_EXT = 33
OJO_DER_EXT = 263


def _dist(a, b) -> float:
    return float(math.hypot(a[0] - b[0], a[1] - b[1]))


def _zip_landmarks(landmarks: list) -> dict:
    """Convierte una lista de tuplas normalizadas en dict indexado."""
    return {i: (float(p[0]), float(p[1])) for i, p in enumerate(landmarks)}


def _ear(puntos: dict, indices: list) -> float:
    ancho = _dist(puntos[indices[0]], puntos[indices[3]])
    alto = (_dist(puntos[indices[1]], puntos[indices[5]]) + _dist(puntos[indices[2]], puntos[indices[4]])) / 2.0
    return alto / max(ancho, 1e-6)


def extraer_features(landmarks: list) -> Optional[dict]:
    """Extrae métricas geométricas de un frame (landmarks normalizados).

    Normaliza por la distancia interocular para que la escala del rostro y
    la distancia a la cámara no contaminen las comparaciones.
    """
    if not landmarks or len(landmarks) < 468:
        return None
    p = _zip_landmarks(landmarks)
    ojo_izq = ((p[33][0] + p[133][0]) / 2.0, (p[33][1] + p[133][1]) / 2.0)
    ojo_der = ((p[362][0] + p[263][0]) / 2.0, (p[362][1] + p[263][1]) / 2.0)
    interocular = _dist(p[OJO_IZQ_EXT], p[OJO_DER_EXT])
    if interocular < 1e-6:
        return None
    ceja_izq_y = sum(p[i][1] for i in CEJA_IZQ) / len(CEJA_IZQ)
    ceja_der_y = sum(p[i][1] for i in CEJA_DER) / len(CEJA_DER)
    ceja_y = (ceja_izq_y + ceja_der_y) / 2.0
    ojo_y = (ojo_izq[1] + ojo_der[1]) / 2.0
    boca_centro_y = (p[LABIO_SUP][1] + p[LABIO_INF][1]) / 2.0
    comisuras_y = (p[COMISURA_IZQ][1] + p[COMISURA_DER][1]) / 2.0
    nariz_x = (p[NARIZ_PUENTE][0] + p[NARIZ_PUNTA][0]) / 2.0

    return {
        'ear': min(_ear(p, OJO_IZQ), _ear(p, OJO_DER)),
        'ear_izq': _ear(p, OJO_IZQ),
        'ear_der': _ear(p, OJO_DER),
        'brow_eye': (ojo_y - ceja_y) / interocular,
        'nose_width': _dist(p[129], p[358]) / interocular,
        'nose_length': _dist(p[NARIZ_PUENTE], p[NARIZ_PUNTA]) / interocular,
        'lip_raise': (p[NARIZ_BASE][1] - p[LABIO_SUP][1]) / interocular,
        'mouth_open': _dist(p[LABIO_SUP], p[LABIO_INF]) / interocular,
        'mouth_width': _dist(p[COMISURA_IZQ], p[COMISURA_DER]) / interocular,
        'mouth_corner': (comisuras_y - boca_centro_y) / interocular,
        'yaw': (nariz_x - (ojo_izq[0] + ojo_der[0]) / 2.0) / interocular,
        'pitch': (boca_centro_y - ojo_y) / interocular,
        'interocular': interocular,
    }


def _z_positivo(valores: np.ndarray, lineas_base: float = 25.0) -> np.ndarray:
    """Desviación positiva respecto al percentil bajo (estado relajado).

    Tension features: más valor = más tensión. La línea base es el
    percentil 20 de la propia captura, una referencia individual que evita
    comparar con una población no validada.
    """
    x = _serie(valores)
    if x.size == 0:
        return x
    base = float(np.percentile(x, lineas_base))
    escala = float(np.std(x))
    escala = max(escala, 1e-3)
    return np.clip((x - base) / escala, 0.0, None)


def _media(x: np.ndarray, defecto: float = 0.0) -> float:
    return float(np.mean(x)) if x.size else defecto


def analizar_rostro(features: list, fps: float, vitales: Optional[dict] = None) -> dict:
    """Calcula dolor/tensión, estrés, fatiga, parpadeo y expresión dominante.

    :param features: lista de dicts devueltos por `extraer_features`.
    :param fps: fps efectivos (para tasa de parpadeo).
    :param vitales: salida de `estimar_hr`/`estimar_hrv` para fusionar estrés.
    """
    validos = [f for f in (features or []) if f]
    n = len(validos)
    vacio = {
        'pain_score': None,
        'pain_confianza': 0.0,
        'stress_score': None,
        'fatigue_score': None,
        'blink_rate': None,
        'expresion_dominante': None,
        'expresiones': {},
        'microexpresiones': [],
        'pose_estabilidad': None,
        'tension_facial': None,
    }
    if n < 10:
        return vacio

    def serie(clave: str) -> np.ndarray:
        return _serie([f[clave] for f in validos])

    ear = serie('ear')
    brow = serie('brow_eye')
    lip = serie('lip_raise')
    nariz = serie('nose_width')
    boca_abierta = serie('mouth_open')
    boca_ancho = serie('mouth_width')
    comisura = serie('mouth_corner')
    yaw = serie('yaw')
    pitch = serie('pitch')

    # --- Tensión relativa -------------------------------------------------
    tension_ear = _z_positivo(-ear)          # ojo más cerrado => tensión
    tension_brow = _z_positivo(-brow)        # ceja más baja => tensión
    tension_lip = _z_positivo(-lip)          # labio superior elevado
    tension_nose = _z_positivo(np.abs(nariz - np.median(nariz)))
    tension_mouth = _z_positivo(-boca_ancho) # boca comprimida
    componentes = np.vstack([tension_ear, tension_brow, tension_lip, tension_nose, tension_mouth])
    tension_frame = np.mean(componentes, axis=0)
    tension = float(np.mean(tension_frame))
    tension_norm = float(np.clip(tension / 2.2, 0.0, 1.0))

    # --- Componentes absolutos (patrones de dolor conocidos) --------------
    ear_med = _media(ear, 0.30)
    squint = float(np.clip((0.26 - ear_med) / 0.08, 0.0, 1.0))
    brow_med = _media(brow, 0.50)
    brow_low = float(np.clip((0.55 - brow_med) / 0.22, 0.0, 1.0))
    lip_med = _media(lip, 0.20)
    lip_up = float(np.clip((0.20 - lip_med) / 0.12, 0.0, 1.0))

    pain_raw = 10.0 * (
        0.45 * tension_norm + 0.25 * squint + 0.20 * brow_low + 0.10 * lip_up
    )
    pain_score = round(float(np.clip(pain_raw, 0.0, 10.0)), 1)

    # Confianza del índice facial: cobertura + encuadre + tamaño del rostro.
    estabilidad = 1.0 - float(np.clip((np.std(yaw) + np.std(pitch)) / 0.18, 0.0, 1.0))
    interocular = _media(serie('interocular'), 0.0)
    tamano_ok = 1.0 if interocular >= 0.12 else float(np.clip(interocular / 0.12, 0.2, 1.0))
    pain_conf = float(np.clip(0.25 + 0.35 * estabilidad + 0.25 * tamano_ok, 0.0, 0.70))

    # --- Parpadeo ---------------------------------------------------------
    fps_seguro = max(float(fps or 0.0), 1.0)
    duracion = n / fps_seguro
    umbral_parpadeo = max(0.16, min(0.24, float(np.percentile(ear, 40)) * 0.78))
    cerrados = ear < umbral_parpadeo
    # Transiciones abierto->cerrado con histéresis.
    parpadeos = 0
    en_cierre = False
    for cerrado in cerrados:
        if cerrado and not en_cierre:
            en_cierre = True
        elif not cerrado and en_cierre:
            parpadeos += 1
            en_cierre = False
    blink_rate = None
    if duracion >= 10.0:
        blink_rate = round(float(parpadeos / (duracion / 60.0)), 1)
    ojo_cerrado_ratio = float(np.mean(cerrados)) if cerrados.size else 0.0

    # --- Estrés -----------------------------------------------------------
    inestabilidad_pose = float(np.clip((np.std(yaw) + np.std(pitch)) / 0.20, 0.0, 1.0))
    stress_componentes = [
        (tension_norm * 100.0, 0.50),
        (inestabilidad_pose * 100.0, 0.20),
    ]
    if vitales:
        rmssd = vitales.get('rmssd_ms')
        if rmssd is not None:
            hrv_stress = float(np.clip((45.0 - float(rmssd)) / 35.0, 0.0, 1.0)) * 100.0
            stress_componentes.append((hrv_stress, 0.20))
        hr = vitales.get('hr_bpm')
        if hr is not None:
            hr_stress = float(np.clip((float(hr) - 75.0) / 55.0, 0.0, 1.0)) * 100.0
            stress_componentes.append((hr_stress, 0.10))
    suma_pesos = sum(p for _v, p in stress_componentes)
    stress_score = round(
        float(np.clip(sum(v * p for v, p in stress_componentes) / max(suma_pesos, 1e-6), 0.0, 100.0)),
        1,
    )

    # --- Fatiga -----------------------------------------------------------
    pitch_droop = float(np.clip((np.percentile(pitch, 70) - np.median(pitch)) / 0.12, 0.0, 1.0))
    blink_bajo = 0.0
    if blink_rate is not None:
        blink_bajo = float(np.clip((12.0 - blink_rate) / 12.0, 0.0, 1.0))
    fatigue_raw = 100.0 * (
        0.40 * ojo_cerrado_ratio + 0.25 * blink_bajo + 0.20 * pitch_droop + 0.15 * tension_norm
    )
    fatigue_score = round(float(np.clip(fatigue_raw, 0.0, 100.0)), 1)

    # --- Expresiones (relativas entre sí) ---------------------------------
    z = lambda arr: (arr - np.mean(arr)) / max(float(np.std(arr)), 1e-6)  # noqa: E731
    zm = lambda arr: float(np.mean(z(arr)))  # noqa: E731
    sonrisa = float(np.clip((zm(boca_ancho) - zm(comisura) + 0.3 * zm(boca_abierta)) / 3.4, 0.0, 1.0))
    sorpresa = float(np.clip((zm(boca_abierta) + zm(brow)) / 2.6, 0.0, 1.0))
    tristeza = float(np.clip((zm(comisura) - 0.4 * zm(brow)) / 2.0, 0.0, 1.0))
    enfado = float(np.clip((tension_norm + brow_low) / 2.0, 0.0, 1.0))
    dolor_norm = pain_score / 10.0
    scores = {
        'sonrisa': sonrisa,
        'sorpresa': sorpresa,
        'tristeza': tristeza,
        'enfado': enfado,
        'dolor': dolor_norm,
    }
    maximo = max(scores.values()) if scores else 0.0
    neutral = float(np.clip(1.0 - maximo, 0.0, 1.0))
    scores['neutral'] = neutral
    total = sum(scores.values()) or 1.0
    expresiones = {k: round(float(v / total), 3) for k, v in scores.items()}
    dominante = max(expresiones.items(), key=lambda kv: kv[1])[0]

    etiquetas = {
        'sonrisa': 'Sonrisa',
        'sorpresa': 'Sorpresa',
        'tristeza': 'Tristeza',
        'enfado': 'Tensión / enfado',
        'dolor': 'Dolor',
        'neutral': 'Neutral',
    }
    microexpresiones = [
        {'codigo': k, 'etiqueta': etiquetas[k], 'intensidad': round(float(v), 3)}
        for k, v in sorted(expresiones.items(), key=lambda kv: kv[1], reverse=True)
        if k not in ('neutral',) and v >= 0.18
    ][:3]

    return {
        'pain_score': pain_score,
        'pain_confianza': round(pain_conf, 3),
        'stress_score': stress_score,
        'fatigue_score': fatigue_score,
        'blink_rate': blink_rate,
        'expresion_dominante': dominante,
        'expresiones': expresiones,
        'microexpresiones': microexpresiones,
        'pose_estabilidad': round(float(estabilidad), 3),
        'tension_facial': round(float(tension_norm * 100.0), 1),
    }


def puntuar_calidad(
    *,
    cobertura: float,
    brillo: float,
    nitidez: float,
    estabilidad: float,
    tamano_rostro: float,
    duracion_seg: float,
) -> dict:
    """Puntaje 0-100 de la captura con motivos legibles.

    Es una compuerta de calidad: si baja, los signos se marcan como no
    concluyentes y el triage se apoya más en el cuestionario.
    """
    puntos = 0.0
    motivos: list[str] = []

    cobertura = float(np.clip(cobertura, 0.0, 1.0))
    puntos += 40.0 * cobertura
    if cobertura < 0.85:
        motivos.append('cobertura_rostro_baja')

    brillo = float(brillo)
    if 55.0 <= brillo <= 200.0:
        puntos += 20.0
    elif 40.0 <= brillo < 55.0 or 200.0 < brillo <= 225.0:
        puntos += 10.0
        motivos.append('iluminacion_mejorable')
    else:
        motivos.append('mala_iluminacion')

    nitidez = float(nitidez)
    if nitidez >= 90.0:
        puntos += 15.0
    elif nitidez >= 45.0:
        puntos += 8.0
        motivos.append('imagen_poco_nitida')
    else:
        motivos.append('imagen_borrosa')

    estabilidad = float(np.clip(estabilidad, 0.0, 1.0))
    puntos += 15.0 * estabilidad
    if estabilidad < 0.55:
        motivos.append('movimiento_excesivo')

    if tamano_rostro >= 0.14:
        puntos += 10.0
    elif tamano_rostro >= 0.10:
        puntos += 6.0
        motivos.append('rostro_pequeno')
    else:
        motivos.append('rostro_muy_pequeno')

    if duracion_seg < 15.0:
        puntos -= 10.0
        motivos.append('captura_corta')

    return {
        'puntaje': round(float(np.clip(puntos, 0.0, 100.0)), 1),
        'cobertura': round(cobertura, 3),
        'brillo': round(brillo, 1),
        'nitidez': round(nitidez, 1),
        'estabilidad': round(estabilidad, 3),
        'tamano_rostro': round(float(tamano_rostro), 3),
        'duracion_seg': round(float(duracion_seg), 2),
        'motivos': motivos,
    }
