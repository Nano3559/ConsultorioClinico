const config = require('../config/config');
const { sendError } = require('../utils/helpers');
const { verifyToken } = require('./auth');
const { checkRole } = require('./roles');

/**
 * Autenticación para los endpoints de sincronización del kiosco
 * (manifest / paquete / modelo) y la ingesta pública de packs.
 *
 * Dos caminos válidos:
 *   1. Kiosco físico: header `x-kiosk-key` igual a KIOSK_API_KEY.
 *      (El kiosco descarga plantillas biométricas en lote: nunca público.)
 *   2. Personal: JWT válido con rol admin/recepcion (para operar o depurar
 *      la sincronización desde el panel).
 *
 * Si KIOSK_API_KEY está vacío (desarrollo sin kiosco físico), se exige JWT
 * de personal: la descarga masiva de plantillas jamás queda abierta.
 */
const kioskAuth = (req, res, next) => {
  const clave = String(req.headers['x-kiosk-key'] || '');
  // Camino 1: Kiosco físico con clave compartida (acceso directo, sin JWT)
  if (config.kiosco.apiKey !== '' && clave === config.kiosco.apiKey) {
    req.kiosco = true;
    return next();
  }
  // Camino 2: Personal autenticado con JWT (admin/recepcion) — siempre disponible
  // para operar/depurar la sincronización desde el panel, independientemente de
  // si existe KIOSK_API_KEY. Sigue exigiendo JWT válido con roles autorizados.
  return verifyToken(req, res, (err) => {
    if (err) return next(err);
    return checkRole('admin', 'recepcion')(req, res, next);
  });
};

module.exports = { kioskAuth };
