const config = require('../config/config');
const { getSupabase } = require('../config/supabase');
const { sendSuccess, sendError } = require('../utils/helpers');
const { ESTADOS_CITA } = require('../utils/constants');
const { llamarVision } = require('../services/visionService');

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

    const respuesta = await llamarVision('/api/kiosco/verificar-rostro', { imagen });

    let dato;
    try {
      dato = await respuesta.json();
    } catch (err) {
      dato = {};
    }

    if (!respuesta.ok) {
      return sendError(res, dato.message || 'Error interno del microservicio de visión', respuesta.status);
    }

    const body = { success: dato.success !== false };
    if (dato.data !== undefined) body.data = dato.data;
    body.message = dato.message || 'Rostro verificado';
    return res.status(200).json(body);
  } catch (error) {
    if (error.name === 'TimeoutError') {
      return sendError(res, 'El servicio de visión tardó demasiado en responder', 504);
    }
    if (error.statusCode) {
      return sendError(res, error.message, error.statusCode, error.tipo);
    }
    console.error('kiosco.verificarRostro:', error.message);
    return sendError(res, 'No se pudo conectar con el servicio de visión', 502);
  }
};

/**
 * POST /api/kiosco/confirmar-cita
 * Confirma la cita del paciente tras el check-in facial en el kiosco:
 * setea estado='confirmada', confirmada_por_kiosco=true y hora_checkin=now().
 * Respuesta: { success, data, message }
 */
const confirmarCita = async (req, res) => {
  try {
    const { paciente_id, cita_id } = req.body;
    const supabase = getSupabase();

    const { data: citas, error: errorConsulta } = await supabase
      .from('citas')
      .select('*')
      .eq('id', cita_id)
      .limit(1);

    if (errorConsulta) throw errorConsulta;
    if (!citas || citas.length === 0) {
      return sendError(res, 'Cita no encontrada', 404);
    }
    const cita = citas[0];

    if (cita.paciente_id !== paciente_id) {
      return sendError(res, 'La cita no pertenece al paciente indicado', 400);
    }

    const estadosFinales = [
      ESTADOS_CITA.COMPLETADA,
      ESTADOS_CITA.CANCELADA,
      ESTADOS_CITA.NO_SHOW,
    ];
    if (estadosFinales.includes(cita.estado)) {
      return sendError(res, 'No se puede confirmar una cita completada, cancelada o sin asistir', 400);
    }

    if (cita.confirmada_por_kiosco) {
      return sendError(res, 'La cita ya fue confirmada por el kiosco', 400);
    }

    const horaCheckin = new Date().toISOString();

    const { data, error } = await supabase
      .from('citas')
      .update({
        estado: ESTADOS_CITA.CONFIRMADA,
        confirmada_por_kiosco: true,
        hora_checkin: horaCheckin,
      })
      .eq('id', cita_id)
      .select()
      .single();

    if (error) throw error;

    return sendSuccess(res, data, 'Check-in confirmado exitosamente');
  } catch (error) {
    console.error('kiosco.confirmarCita:', error.message);
    return sendError(res, 'Error al confirmar la cita', 500);
  }
};

module.exports = { verificarRostro, confirmarCita };
