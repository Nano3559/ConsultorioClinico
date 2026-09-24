const config = require('../config/config');
const { getSupabase } = require('../config/supabase');
const { sendSuccess, sendError } = require('../utils/helpers');
const { ESTADOS_CITA } = require('../utils/constants');
const { llamarVision } = require('../services/visionService');

/**
 * Devuelve la IP real del cliente detrás de proxies (x-forwarded-for).
 * @param {object} req Request de Express.
 * @returns {string}
 */
const obtenerIp = (req) => {
  const fwd = req.headers['x-forwarded-for'];
  if (fwd) return String(fwd).split(',')[0].trim();
  return req.ip || req.socket?.remoteAddress || 'desconocida';
};

/**
 * Devuelve la fecha de hoy en el formato YYYY-MM-DD del servidor.
 * El kiosco confirma SOLO citas cuya fecha coincide con el día actual (KIO-15).
 * @returns {string}
 */
const fechaDeHoy = () => {
  const ahora = new Date();
  const mes = String(ahora.getMonth() + 1).padStart(2, '0');
  const dia = String(ahora.getDate()).padStart(2, '0');
  return `${ahora.getFullYear()}-${mes}-${dia}`;
};

/**
 * Registra un intento de acceso en la auditoría `intentos_acceso` (KIO-19).
 * Los intentos del kiosco de auto-check-in se guardan con tipo
 * 'kiosco_verificacion' y referencia_id = id del paciente. Un fallo de BD en
 * la auditoría NO debe bloquear el check-in: se registra en el log y se sigue.
 * @param {object} supabase  Cliente Supabase.
 * @param {object} datos     { tipo, referencia_id, ip, userAgent, exitoso, detalle }
 */
const registrarIntento = async (supabase, datos) => {
  try {
    const fila = {
      tipo_acceso: datos.tipo || 'login',
      ip_address: datos.ip,
      user_agent: (datos.userAgent || '').slice(0, 255),
      exitoso: datos.exitoso,
      detalle: (datos.detalle || '').slice(0, 200),
    };
    // referencia_id solo en verificaciones del kiosco; null en credenciales
    if (datos.referencia_id != null) fila.referencia_id = datos.referencia_id;
    await supabase.from('intentos_acceso').insert(fila);
  } catch (error) {
    console.error('kiosco.registrarIntento:', error.message);
  }
};

/**
 * POST /api/kiosco/verificar-rostro
 * Recibe una imagen base64, la envía al microservicio de visión (Python +
 * FastAPI) para reconocimiento facial y devuelve el paciente + su cita del día.
 *
 * Acceso: ruta pública de la tablet del kiosco, protegida con rate limit por
 * IP (KIO-20). Cada intento queda auditado en `intentos_acceso` (KIO-19).
 * Respuesta: { success, data, message }
 */
const verificarRostro = async (req, res) => {
  const ip = obtenerIp(req);
  const supabase = getSupabase();
  try {
    const { imagen } = req.body;
    if (!imagen || typeof imagen !== 'string') {
      await registrarIntento(supabase, {
        tipo: 'kiosco_verificacion', ip, exitoso: false, detalle: 'imagen_ausente',
      });
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
      await registrarIntento(supabase, {
        tipo: 'kiosco_verificacion', ip, exitoso: false, detalle: 'error_vision',
      });
      return sendError(res, dato.message || 'Error interno del microservicio de visión', respuesta.status);
    }

    const pacienteId = dato.data?.paciente_id;
    const reconocido = dato.success !== false && pacienteId != null;
    await registrarIntento(supabase, {
      tipo: 'kiosco_verificacion',
      referencia_id: pacienteId,
      ip,
      userAgent: req.headers['user-agent'],
      exitoso: reconocido,
      detalle: reconocido ? 'reconocido' : 'no_reconocido',
    });

    const body = { success: dato.success !== false };
    if (dato.data !== undefined) body.data = dato.data;
    body.message = dato.message || 'Rostro verificado';
    return res.status(200).json(body);
  } catch (error) {
    if (error.name === 'TimeoutError') {
      await registrarIntento(supabase, {
        tipo: 'kiosco_verificacion', ip, exitoso: false, detalle: 'timeout',
      });
      return sendError(res, 'El servicio de visión tardó demasiado en responder', 504);
    }
    if (error.statusCode) {
      await registrarIntento(supabase, {
        tipo: 'kiosco_verificacion', ip, exitoso: false, detalle: 'indisponible',
      });
      return sendError(res, error.message, error.statusCode, error.tipo);
    }
    console.error('kiosco.verificarRostro:', error.message);
    await registrarIntento(supabase, {
      tipo: 'kiosco_verificacion', ip, exitoso: false, detalle: 'conexion_vision',
    });
    return sendError(res, 'No se pudo conectar con el servicio de visión', 502);
  }
};

/**
 * POST /api/kiosco/confirmar-cita
 * Confirma la cita del paciente tras el check-in facial en el kiosco:
 * setea estado='confirmada', confirmada_por_kiosco=true y hora_checkin=now().
 *
 * Validaciones aplicadas (KIO-15/20):
 *   - La cita debe ser de HOY (el kiosco opera sobre las citas del día).
 *   - Debe existir una verificación facial exitosa reciente del mismo
 *     paciente desde la misma IP (ventana config [kiosco.verificationWindowMs]),
 *     de modo que nadie pueda confirmar citas ajenas a mano alzada.
 * Respuesta: { success, data, message }
 */
const confirmarCita = async (req, res) => {
  const ip = obtenerIp(req);
  const supabase = getSupabase();
  try {
    const { paciente_id, cita_id } = req.body;

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

    // KIO-15: solo se confirman citas del día actual en el kiosco.
    if (cita.fecha !== fechaDeHoy()) {
      return sendError(res, 'Solo se pueden confirmar citas del día de hoy', 400);
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

    // KIO-20: exige una verificación facial exitosa reciente (misma IP) para
    // confirmar. Así el kiosco solo confirma a quien acaba de pasar por la
    // cámara, no a cualquiera que conozca los IDs.
    const limite = new Date(Date.now() - config.kiosco.verificationWindowMs).toISOString();
    const { data: intentos, error: errorIntento } = await supabase
      .from('intentos_acceso')
      .select('id')
      .eq('tipo_acceso', 'kiosco_verificacion')
      .eq('referencia_id', paciente_id)
      .eq('ip_address', ip)
      .eq('exitoso', true)
      .gte('creado_en', limite)
      .order('creado_en', { ascending: false })
      .limit(1);

    if (errorIntento) throw errorIntento;
    if (!intentos || intentos.length === 0) {
      return sendError(res, 'Debe verificar primero el rostro en el kiosco', 403);
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

    await registrarIntento(supabase, {
      tipo: 'kiosco_verificacion',
      referencia_id: paciente_id,
      ip,
      userAgent: req.headers['user-agent'],
      exitoso: true,
      detalle: 'cita_confirmada',
    });

    return sendSuccess(res, data, 'Check-in confirmado exitosamente');
  } catch (error) {
    console.error('kiosco.confirmarCita:', error.message);
    return sendError(res, 'Error al confirmar la cita', 500);
  }
};

/**
 * GET /api/kiosco/intentos
 * Auditoría de los intentos de verificación del kiosco (KIO-19).
 * Acceso: solo admin/recepcion (checkRole en la ruta).
 * Query:  ?exitoso=true|false  ?limit=50 (máx 200)
 * Respuesta: { success, data: { intentos, total }, message }
 */
const listarIntentos = async (req, res) => {
  try {
    const supabase = getSupabase();
    const limite = Math.min(Math.max(parseInt(req.query.limit, 10) || 50, 1), 200);

    let query = supabase
      .from('intentos_acceso')
      .select('id, tipo_acceso, referencia_id, email, ip_address, user_agent, exitoso, detalle, creado_en')
      .eq('tipo_acceso', 'kiosco_verificacion');

    // Filtros ANTES del límite (el SDK de Supabase no encadena tras .limit()).
    if (req.query.exitoso === 'true' || req.query.exitoso === 'false') {
      query = query.eq('exitoso', req.query.exitoso === 'true');
    }

    const { data: intentos, error } = await query
      .order('creado_en', { ascending: false })
      .limit(limite);

    if (error) throw error;

    return sendSuccess(res, { intentos: intentos || [], total: (intentos || []).length }, 'Auditoría del kiosco consultada');
  } catch (error) {
    console.error('kiosco.listarIntentos:', error.message);
    return sendError(res, 'Error al consultar la auditoría del kiosco', 500);
  }
};

module.exports = { verificarRostro, confirmarCita, listarIntentos };