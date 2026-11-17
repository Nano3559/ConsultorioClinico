"""Pruebas de la matemática de la PreConsulta IA (sin OpenCV/MediaPipe).

Se ejecutan con NumPy instalado:

    cd backend/vision
    python -m unittest test_preconsulta_metrics -v

Cubren rPPG (POS), HRV, respiración, calidad de captura y geometría facial
con señales sintéticas de frecuencia conocida. No sustituyen una validación
clínica: verifican que el pipeline no invente valores y que respete los
límites del contrato.
"""

from __future__ import annotations

import unittest

import numpy as np

import preconsulta_metrics as metrics


FPS = 30.0


def serie_rgb(bpm=72.0, segundos=30.0, fps=FPS, ruido=0.2, semilla=7):
    """Serie RGB sintética con pulso en los tres canales y ruido gaussiano."""
    n = int(fps * segundos)
    t = np.arange(n) / fps
    base = np.array([185.0, 130.0, 120.0])
    rgb = np.zeros((n, 3), dtype=np.float64)
    for canal, (amplitud, fase) in enumerate([(2.0, 0.0), (1.2, 0.4), (0.8, 0.9)]):
        rgb[:, canal] = base[canal] + amplitud * np.sin(2 * np.pi * (bpm / 60.0) * t + fase)
    rgb += np.random.default_rng(semilla).normal(0, ruido, rgb.shape)
    return rgb


def serie_respiratoria(rpm=15.0, segundos=30.0, fps=FPS, profundidad=0.01, semilla=3):
    """Luminancia con modulación respiratoria conocida (común a los canales)."""
    n = int(fps * segundos)
    t = np.arange(n) / fps
    base = np.array([185.0, 130.0, 120.0])
    rgb = np.tile(base, (n, 1)) * (1.0 + profundidad * np.sin(2 * np.pi * (rpm / 60.0) * t))[:, None]
    rgb += np.random.default_rng(semilla).normal(0, 0.8, rgb.shape)
    return rgb


def landmarks_sinteticos(ear_escala=1.0):
    """468 landmarks con geometría facial plausible (no realista)."""
    angulos = np.linspace(0, 2 * np.pi, 468, endpoint=False)
    puntos = [(0.5 + 0.28 * np.cos(a), 0.5 + 0.34 * np.sin(a)) for a in angulos]
    # Ojos separados (interocular > 0) y párpados con apertura controlable.
    puntos[33] = (0.40, 0.50)
    puntos[263] = (0.60, 0.50)
    puntos[133] = (0.44, 0.50)
    puntos[362] = (0.56, 0.50)
    # Nariz centrada (puente/punta) para que yaw = 0 en pose frontal.
    puntos[168] = (0.50, 0.47)
    puntos[1] = (0.50, 0.53)
    apertura = 0.018 * ear_escala
    # Párpado izquierdo (arriba = y menor).
    puntos[160] = (0.41, 0.50 - apertura)
    puntos[144] = (0.41, 0.50 + apertura)
    puntos[158] = (0.43, 0.50 - apertura)
    puntos[153] = (0.43, 0.50 + apertura)
    # Párpado derecho (espejo).
    puntos[385] = (0.59, 0.50 - apertura)
    puntos[380] = (0.59, 0.50 + apertura)
    puntos[387] = (0.57, 0.50 - apertura)
    puntos[373] = (0.57, 0.50 + apertura)
    return puntos


class PruebasSenal(unittest.TestCase):
    def test_pos_conserva_longitud_y_es_finito(self):
        rgb = serie_rgb()
        senal = metrics.pos_signal(rgb, FPS)
        self.assertEqual(senal.shape[0], rgb.shape[0])
        self.assertTrue(np.all(np.isfinite(senal)))
        self.assertGreater(float(np.std(senal)), 0.1)

    def test_pos_sin_datos_devuelve_ceros(self):
        senal = metrics.pos_signal(np.zeros((5, 3)), FPS)
        self.assertEqual(senal.shape[0], 5)
        self.assertFalse(np.any(senal))

    def test_bandpass_elimina_dc_y_conserva_la_banda(self):
        n = 900
        t = np.arange(n) / FPS
        x = 5.0 + np.sin(2 * np.pi * 1.2 * t)
        filtrada = metrics.bandpass(x, FPS, 0.7, 3.0)
        self.assertLess(abs(float(np.mean(filtrada))), 0.2)
        self.assertGreater(float(np.std(filtrada)), 0.3)

    def test_senal_pulso_acepta_serie_1d(self):
        x = np.sin(np.linspace(0, 12, 300))
        self.assertAlmostEqual(float(np.std(metrics.senal_pulso(x, FPS))), float(np.std(x)), places=6)


class PruebasFrecuenciaCardiaca(unittest.TestCase):
    def test_estima_72_lpm_con_confianza_util(self):
        resultado = metrics.estimar_hr(serie_rgb(bpm=72.0), FPS)
        self.assertIsNotNone(resultado['hr_bpm'])
        self.assertAlmostEqual(resultado['hr_bpm'], 72.0, delta=4.0)
        self.assertGreater(resultado['hr_confianza'], 0.4)
        self.assertEqual(resultado['metodo'], 'pos')

    def test_estima_108_lpm(self):
        resultado = metrics.estimar_hr(serie_rgb(bpm=108.0, ruido=0.1, semilla=11), FPS)
        self.assertAlmostEqual(resultado['hr_bpm'], 108.0, delta=5.0)

    def test_no_inventa_fc_en_senal_plana(self):
        plano = np.tile([180.0, 130.0, 120.0], (600, 1))
        resultado = metrics.estimar_hr(plano, FPS)
        self.assertIsNone(resultado['hr_bpm'])
        self.assertEqual(resultado['metodo'], 'ninguno')

    def test_captura_corta_no_estima(self):
        resultado = metrics.estimar_hr(serie_rgb(segundos=5.0), FPS)
        self.assertIsNone(resultado['hr_bpm'])

    def test_fps_invalido_no_estima(self):
        resultado = metrics.estimar_hr(serie_rgb(segundos=5.0), 0)
        self.assertIsNone(resultado['hr_bpm'])


class PruebasHRV(unittest.TestCase):
    def test_acepta_la_serie_rgb_y_devuelve_rangos(self):
        resultado = metrics.estimar_hrv(serie_rgb(bpm=72.0, segundos=30.0), FPS)
        self.assertIsNotNone(resultado['rmssd_ms'])
        self.assertGreaterEqual(resultado['rmssd_ms'], 0)
        self.assertLess(resultado['rmssd_ms'], 500)
        self.assertLessEqual(resultado['hrv_confianza'], 0.7)
        self.assertGreater(resultado['latidos'], 5)

    def test_captura_corta_no_estima_hrv(self):
        resultado = metrics.estimar_hrv(serie_rgb(segundos=8.0), FPS)
        self.assertIsNone(resultado['rmssd_ms'])
        self.assertEqual(resultado['latidos'], 0)

    def test_senal_plana_no_estima_hrv(self):
        plano = np.tile([180.0, 130.0, 120.0], (900, 1))
        resultado = metrics.estimar_hrv(plano, FPS)
        self.assertIsNone(resultado['rmssd_ms'])


class PruebasRespiracion(unittest.TestCase):
    def test_estima_15_rpm(self):
        resultado = metrics.estimar_respiracion(serie_respiratoria(rpm=15.0), FPS)
        self.assertIsNotNone(resultado['respiraciones_rpm'])
        self.assertAlmostEqual(resultado['respiraciones_rpm'], 15.0, delta=2.0)
        self.assertLessEqual(resultado['rr_confianza'], 0.5)

    def test_estima_20_rpm(self):
        resultado = metrics.estimar_respiracion(serie_respiratoria(rpm=20.0, semilla=5), FPS)
        self.assertAlmostEqual(resultado['respiraciones_rpm'], 20.0, delta=2.0)

    def test_ruido_blanco_no_produce_respiracion(self):
        n = 900
        ruido = np.tile([185.0, 130.0, 120.0], (n, 1))
        ruido += np.random.default_rng(21).normal(0, 3.0, ruido.shape)
        resultado = metrics.estimar_respiracion(ruido, FPS)
        self.assertIsNone(resultado['respiraciones_rpm'])
        self.assertEqual(resultado['rr_confianza'], 0.0)

    def test_captura_corta_no_estima_respiracion(self):
        resultado = metrics.estimar_respiracion(serie_respiratoria(segundos=10.0), FPS)
        self.assertIsNone(resultado['respiraciones_rpm'])


class PruebasCalidad(unittest.TestCase):
    def test_captura_buena_supera_80(self):
        calidad = metrics.puntuar_calidad(
            cobertura=0.98,
            brillo=120.0,
            nitidez=150.0,
            estabilidad=0.92,
            tamano_rostro=0.18,
            duracion_seg=24.0,
        )
        self.assertGreaterEqual(calidad['puntaje'], 80)
        self.assertEqual(calidad['motivos'], [])

    def test_captura_mala_explica_los_motivos(self):
        calidad = metrics.puntuar_calidad(
            cobertura=0.4,
            brillo=20.0,
            nitidez=10.0,
            estabilidad=0.2,
            tamano_rostro=0.05,
            duracion_seg=8.0,
        )
        self.assertLess(calidad['puntaje'], 40)
        for motivo in ['cobertura_rostro_baja', 'mala_iluminacion', 'imagen_borrosa', 'movimiento_excesivo', 'rostro_muy_pequeno', 'captura_corta']:
            self.assertIn(motivo, calidad['motivos'])

    def test_puntaje_siempre_en_rango(self):
        alta = metrics.puntuar_calidad(
            cobertura=2.0,
            brillo=120.0,
            nitidez=500.0,
            estabilidad=2.0,
            tamano_rostro=1.0,
            duracion_seg=60.0,
        )
        self.assertLessEqual(alta['puntaje'], 100)
        baja = metrics.puntuar_calidad(
            cobertura=-1.0,
            brillo=0.0,
            nitidez=-5.0,
            estabilidad=-1.0,
            tamano_rostro=-1.0,
            duracion_seg=0.0,
        )
        self.assertGreaterEqual(baja['puntaje'], 0)


class PruebasRostro(unittest.TestCase):
    def test_extraer_features_normaliza_por_interocular(self):
        features = metrics.extraer_features(landmarks_sinteticos())
        self.assertIsNotNone(features)
        self.assertGreater(features['interocular'], 0.1)
        for clave in ['ear', 'brow_eye', 'nose_width', 'mouth_open', 'mouth_width', 'yaw', 'pitch']:
            self.assertTrue(np.isfinite(features[clave]), clave)
        self.assertAlmostEqual(features['yaw'], 0.0, delta=0.05)

    def test_landmarks_insuficientes_devuelven_none(self):
        self.assertIsNone(metrics.extraer_features(None))
        self.assertIsNone(metrics.extraer_features([(0.5, 0.5)] * 10))

    def test_analizar_rostro_devuelve_rangos_y_expresion(self):
        features = [metrics.extraer_features(landmarks_sinteticos()) for _ in range(100)]
        resultado = metrics.analizar_rostro(features, 5.0, {'hr_bpm': 78.0, 'rmssd_ms': 40.0})
        self.assertGreaterEqual(resultado['pain_score'], 0)
        self.assertLessEqual(resultado['pain_score'], 10)
        for clave in ['stress_score', 'fatigue_score']:
            self.assertGreaterEqual(resultado[clave], 0)
            self.assertLessEqual(resultado[clave], 100)
        self.assertIsNotNone(resultado['blink_rate'])
        self.assertIn(
            resultado['expresion_dominante'],
            ['sonrisa', 'sorpresa', 'tristeza', 'enfado', 'dolor', 'neutral'],
        )
        self.assertLessEqual(resultado['pose_estabilidad'], 1)

    def test_pocos_frames_devuelven_vacio(self):
        resultado = metrics.analizar_rostro([metrics.extraer_features(landmarks_sinteticos())] * 3, FPS)
        self.assertIsNone(resultado['pain_score'])
        self.assertIsNone(resultado['stress_score'])

    def test_parpadeo_se_detecta_con_ojos_cerrados(self):
        abiertos = [metrics.extraer_features(landmarks_sinteticos(1.0)) for _ in range(100)]
        cerrados = [metrics.extraer_features(landmarks_sinteticos(0.2)) for _ in range(2)]
        # Dos parpadeos breves en 20 s (fps 10 => 200 frames).
        features = abiertos + cerrados + abiertos[:48] + cerrados + abiertos[:48]
        resultado = metrics.analizar_rostro(features, 10.0)
        self.assertIsNotNone(resultado['blink_rate'])
        self.assertGreater(resultado['blink_rate'], 0)
        self.assertLessEqual(resultado['blink_rate'], 60)


if __name__ == '__main__':
    unittest.main()
