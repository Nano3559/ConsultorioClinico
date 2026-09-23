const config = require('../config/config');
const { getSupabase } = require('../config/supabase');
const { sendSuccess, sendError } = require('../utils/helpers');
const { llamarVision } = require('../services/visionService');

/**
 * POST /api/vision/registrar-rostro/:pacienteId
 * Registra el rostro de un paciente (KIO-10): recibe las muestras en base64,
 * las envía al microservicio de visión (Python + FastAPI) para guardarlas en
 * el dataset y reentrenar el modelo LBPH, y persiste el descriptor facial
 * generado en `pacientes.rostro_embedding` (vector de 128 dims, KIO-07).
 *
 * Acceso: solo admin/recepcion (verifyToken + checkRole).
 * Respuesta: { success, data, message }
 */
const registrarRostro = async (req, res) => {
  try {
    if (!config.vision.enabled) {
      return sendError(res, 'El servicio de visión está deshabilitado', 503);
    }

    const pacienteId = parseInt(req.params.pacienteId, 10);
    const { imagenes = [] } = req.body;
    const supabase = getSupabase();

    // Verificamos que el paciente exista para no registrar un rostro huérfano
    const { data: pacientes, error: errorConsulta } = await supabase
      .from('pacientes')
      .select('id, nombre, apellido')
      .eq('id', pacienteId)
      .limit(1);

    if (errorConsulta) throw errorConsulta;
    if (!pacientes || pacientes.length === 0) {
      return sendError(res, 'Paciente no encontrado', 404);
    }

    // Ruta dentro del microservicio Python: POST /api/vision/registrar-rostro/{id}
    const respuesta = await llamarVision(
      `/api/vision/registrar-rostro/${pacienteId}`,
      { imagenes }
    );

    let dato;
    try {
      dato = await respuesta.json();
    } catch (err) {
      dato = {};
    }

    if (!respuesta.ok) {
      return sendError(res, dato.message || 'Error interno del microservicio de visión', respuesta.status);
    }

    const dataVision = dato.data || {};

    // Guardar el descriptor facial (KIO-07) como literal pgvector '[...]'
    let embedding = dataVision.rostro_embedding;
    if (Array.isArray(embedding) && embedding.length === 128) {
      const vectorLiteral = `[${embedding.join(',')}]`;
      const { error: errorUpdate } = await supabase
        .from('pacientes')
        .update({ rostro_embedding: vectorLiteral })
        .eq('id', pacienteId);
      if (errorUpdate) throw errorUpdate;
    }

    const body = {
      success: true,
      data: {
        paciente_id: pacienteId,
        imagenes_guardadas: dataVision.guardadas || 0,
        entrenamiento: dataVision.entrenamiento || null,
        rostro_registrado: Array.isArray(embedding) && embedding.length === 128,
      },
      message: dato.message || 'Rostro registrado y modelo reentrenado',
    };
    return res.status(200).json(body);
  } catch (error) {
    if (error.name === 'TimeoutError') {
      return sendError(res, 'El servicio de visión tardó demasiado en responder', 504);
    }
    if (error.statusCode) {
      return sendError(res, error.message, error.statusCode, error.tipo);
    }
    console.error('vision.registrarRostro:', error.message);
    return sendError(res, 'No se pudo conectar con el servicio de visión', 502);
  }
};

/**
 * GET /api/vision/rostro/:pacienteId
 * Consulta el estado del descriptor facial de un paciente (KIO-07): informa
 * si tiene el rostro registrado y devuelve el embedding con sus primeras
 * dimensiones para diagnóstico. Acceso: admin/recepcion.
 * Respuesta: { success, data, message }
 */
const consultarRostro = async (req, res) => {
  try {
    const pacienteId = parseInt(req.params.pacienteId, 10);
    const supabase = getSupabase();

    const { data: pacientes, error: errorConsulta } = await supabase
      .from('pacientes')
      .select('id, nombre, apellido, rostro_embedding')
      .eq('id', pacienteId)
      .limit(1);

    if (errorConsulta) throw errorConsulta;
    if (!pacientes || pacientes.length === 0) {
      return sendError(res, 'Paciente no encontrado', 404);
    }

    const paciente = pacientes[0];
    const embedding = paciente.rostro_embedding;

    return sendSuccess(res, {
      paciente_id: paciente.id,
      nombre: `${paciente.nombre || ''} ${paciente.apellido || ''}`.trim(),
      rostro_registrado: Array.isArray(embedding) && embedding.length === 128,
      dimensiones: Array.isArray(embedding) ? embedding.length : 0,
      embedding_resumen: Array.isArray(embedding) ? embedding.slice(0, 3) : null,
    }, 'Estado del rostro consultado');
  } catch (error) {
    console.error('vision.consultarRostro:', error.message);
    return sendError(res, 'Error al consultar el rostro del paciente', 500);
  }
};

module.exports = { registrarRostro, consultarRostro };