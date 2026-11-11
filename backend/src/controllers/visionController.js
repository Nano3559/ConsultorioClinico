const config = require('../config/config');
const { getSupabase } = require('../config/supabase');
const { sendSuccess, sendError } = require('../utils/helpers');
const { procesarPaquete, rostroVigente, parseEmbedding } = require('../services/rostroService');
const { llamarVision } = require('../services/visionService');

/**
 * POST /api/vision/registrar-rostro/:pacienteId
 * Registra el rostro de un paciente (multi-pose, YuNet+SFace):
 * recibe las muestras en base64 etiquetadas por pose, el microservicio
 * Python detecta + mide calidad + genera embeddings 128-d, y aquí se suben
 * las fotos livianas al bucket privado `rostros/{cedula}_{nombre}/`, se
 * guardan las plantillas por pose (`rostro_muestras`) y se marca la vigencia
 * (`pacientes.rostro_actualizado_en`).
 *
 * Body: { imagenes: [{ imagen, pose }] } (también acepta [base64, ...]).
 * Acceso: solo admin/recepcion (verifyToken + checkRole).
 * Respuesta: { success, data, message }
 */
const registrarRostro = async (req, res) => {
  try {
    if (!config.vision.enabled) {
      return sendError(res, 'El servicio de visión está deshabilitado', 503);
    }

    const pacienteId = parseInt(req.params.pacienteId, 10);
    const { imagenes = [], espejado } = req.body;
    const supabase = getSupabase();

    // Verificamos que el paciente exista para no registrar un rostro huérfano
    const { data: pacientes, error: errorConsulta } = await supabase
      .from('pacientes')
      .select('id, cedula, nombre, apellido')
      .eq('id', pacienteId)
      .limit(1);

    if (errorConsulta) throw errorConsulta;
    if (!pacientes || pacientes.length === 0) {
      return sendError(res, 'Paciente no encontrado', 404);
    }

    // Pipeline compartido: Python (YuNet+SFace + calidad) -> Storage privado
    // -> rostro_muestras + plantilla 128-d + vigencia.
    const resultado = await procesarPaquete(supabase, pacientes[0], imagenes, espejado === true);

    const body = {
      success: true,
      data: {
        paciente_id: pacienteId,
        imagenes_guardadas: resultado.guardadas,
        por_pose: resultado.porPose,
        rechazadas: resultado.rechazadas,
        carpeta: resultado.carpeta,
        rostro_registrado: resultado.rostro_registrado,
      },
      message: 'Rostro registrado (multi-pose)',
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
      .select('id, nombre, apellido, rostro_embedding, rostro_actualizado_en')
      .eq('id', pacienteId)
      .limit(1);

    if (errorConsulta) throw errorConsulta;
    if (!pacientes || pacientes.length === 0) {
      return sendError(res, 'Paciente no encontrado', 404);
    }

    const paciente = pacientes[0];
    const embedding = parseEmbedding(paciente.rostro_embedding);
    const registrado = embedding !== null && embedding.length === 128;

    return sendSuccess(res, {
      paciente_id: paciente.id,
      nombre: `${paciente.nombre || ''} ${paciente.apellido || ''}`.trim(),
      rostro_registrado: registrado,
      rostro_vigente: rostroVigente(paciente),
      rostro_actualizado_en: paciente.rostro_actualizado_en || null,
      dimensiones: embedding ? embedding.length : 0,
      embedding_resumen: embedding ? embedding.slice(0, 3) : null,
    }, 'Estado del rostro consultado');
  } catch (error) {
    console.error('vision.consultarRostro:', error.message);
    return sendError(res, 'Error al consultar el rostro del paciente', 500);
  }
};

/**
 * POST /api/vision/evaluar-gesto (público con rate limit)
 * Guía en vivo para la captura automática: evalúa UN frame SIN registrar
 * nada (sin writes, sin paciente). Puro passthrough al microservicio
 * Python (YuNet): el servidor decide con landmarks reales.
 *
 * Body: { imagen (base64), pose?, yaw_ref?, pitch_ref?, espejado? }
 * Respuesta: { success, data: { tiene_rostro, yaw, pitch, calidad,
 *   gesto_ok }, message }
 */
const evaluarGesto = async (req, res) => {
  try {
    if (!config.vision.enabled) {
      return sendError(res, 'El servicio de visión está deshabilitado', 503);
    }
    const { imagen, pose, yaw_ref, pitch_ref, espejado } = req.body;
    const respuesta = await llamarVision('/api/vision/evaluar-gesto', {
      imagen,
      pose: pose || 'frontal',
      yaw_ref: yaw_ref ?? null,
      pitch_ref: pitch_ref ?? null,
      espejado: espejado === true,
    });
    let dato;
    try {
      dato = await respuesta.json();
    } catch (err) {
      dato = {};
    }
    if (!respuesta.ok) {
      return sendError(res, dato.message || 'Error del microservicio de visión', respuesta.status);
    }
    const body = { success: dato.success !== false };
    if (dato.data !== undefined) body.data = dato.data;
    body.message = dato.message || 'Frame evaluado';
    return res.status(200).json(body);
  } catch (error) {
    if (error.name === 'TimeoutError') {
      return sendError(res, 'El servicio de visión tardó demasiado en responder', 504);
    }
    if (error.statusCode) {
      return sendError(res, error.message, error.statusCode);
    }
    console.error('vision.evaluarGesto:', error.message);
    return sendError(res, 'No se pudo conectar con el servicio de visión', 502);
  }
};

module.exports = { registrarRostro, consultarRostro, evaluarGesto };