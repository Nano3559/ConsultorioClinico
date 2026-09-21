const config = require('../config/config');
const { sendError } = require('../utils/helpers');

/**
 * POST /api/kiosco/verificar-rostro
 * Recibe una imagen base64, la envía al microservicio de visión (Python +
 * FastAPI) para reconocimiento facial y devuelve el paciente + su cita del día.
 * Respuesta: { success, data, message }
 */
const verificarRostro = async (req, res) => {
  try {
    const { imagen } = req.body;
    if (!imagen || typeof imagen !== 'string') {
      return sendError(res, 'La imagen es obligatoria', 400);
    }

    const visionUrl = config.visionServiceUrl;
    if (!visionUrl) {
      return sendError(res, 'Microservicio de visión no configurado', 503);
    }

    const respuesta = await fetch(`${visionUrl.replace(/\/+$/, '')}/api/kiosco/verificar-rostro`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ imagen }),
      signal: AbortSignal.timeout(15000),
    });

    let dato;
    try {
      dato = await respuesta.json();
    } catch (err) {
      dato = {};
    }

    if (!respuesta.ok) {
      return sendError(
        res,
        dato.message || 'Error interno del microservicio de visión',
        respuesta.status
      );
    }

    const body = { success: dato.success !== false };
    if (dato.data !== undefined) body.data = dato.data;
    body.message = dato.message || 'Rostro verificado';
    return res.status(200).json(body);
  } catch (error) {
    if (error.name === 'TimeoutError') {
      return sendError(res, 'El servicio de visión tardó demasiado en responder', 504);
    }
    console.error('kiosco.verificarRostro:', error.message);
    return sendError(res, 'No se pudo conectar con el servicio de visión', 502);
  }
};

module.exports = { verificarRostro };