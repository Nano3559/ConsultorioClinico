'use strict';

const config = require('../config/config');

/**
 * Tiempo máximo de espera (ms) para cada llamada HTTP al microservicio de
 * visión (Python + FastAPI), 5 segundos por defecto (dia21.txt).
 * Configurable con VISION_TIMEOUT_MS.
 * @type {number}
 */
const TIMEOUT_MS = Number(process.env.VISION_TIMEOUT_MS) || 5000;

/**
 * Cantidad de reintentos ante fallos de red/timeout con el microservicio de
 * visión, 3 por defecto (dia21.txt). Configurable con VISION_RETRIES.
 * NOTA: solo se reintenta cuando fetch lanza (fallo de conexión o timeout);
 * si el microservicio responde HTTP (2xx/4xx/5xx) se respeta su estado tal
 * cual, sin reintentar, para no duplicar operaciones ni enmascarar errores.
 * @type {number}
 */
const MAX_REINTENTOS = Number(process.env.VISION_RETRIES) || 3;

/**
 * Espera entre reintentos (ms), backoff exponencial leve (base 300 ms).
 * @type {number}
 */
const BACKOFF_BASE_MS = 300;

/**
 * Llama a un endpoint del microservicio de visión (Python + FastAPI).
 *
 * @param {string} endpoint Ruta absoluta del microservicio,
 *                          p.ej. '/api/kiosco/verificar-rostro'.
 * @param {object} data     Cuerpo JSON a enviar (p.ej. { imagen }).
 * @returns {Promise<Response>} Devuelve la Response real de fetch:
 *   - Si el microservicio responde (2xx/4xx/5xx) se devuelve la Response tal
 *     cual y el controller decide la traducción (passthrough del estado HTTP
 *     propio del micro para 400/404/500, o mapeo a 200 para éxito).
 *   - Ante fallos de red o timeout (fetch lanza) se reintenta hasta
 *     MAX_REINTENTOS intentos con backoff; si todos fallan se re-lanza el
 *     último error conservando su `name` (TimeoutError → 504, genérico → 502).
 * @throws {Error} timeout (TimeoutError) o de conexión (genérico), y un
 *                 Error con `statusCode=503` si el servicio no está
 *                 configurado.
 */
const llamarVision = async (endpoint, data) => {
  const { visionServiceUrl } = config;
  if (!visionServiceUrl) {
    const error = new Error('Microservicio de visi\u00f3n no configurado');
    error.statusCode = 503;
    throw error;
  }

  const base = visionServiceUrl.replace(/\/+$/, '');
  const url = `${base}${endpoint}`;
  let ultimoError = null;

  for (let intento = 1; intento <= MAX_REINTENTOS; intento++) {
    try {
      const respuesta = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
        signal: AbortSignal.timeout(TIMEOUT_MS),
      });
      return respuesta;
    } catch (error) {
      ultimoError = error;
      if (intento < MAX_REINTENTOS) {
        const espera = BACKOFF_BASE_MS * 2 ** (intento - 1);
        await new Promise((resolver) => setTimeout(resolver, espera));
      }
    }
  }

  throw ultimoError;
};

module.exports = { llamarVision };
