const config = require('../config/config');
const { getSupabase } = require('../config/supabase');
const { sendSuccess, sendError } = require('../utils/helpers');
const { ESTADOS_CITA } = require('../utils/constants');
const { llamarVision } = require('../services/visionService');
const {
  hashPlantilla,
  rostroVigente,
  parseEmbedding,
  procesarPaquete,
} = require('../services/rostroService');

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
    // KIO-16: si el reconocimiento facial está deshabilitado (VISION_ENABLED
    // = false) el kiosco no puede auto-verificar; se deriva a recepción con un
    // mensaje claro y el intento queda auditado (KIO-19).
    if (!config.vision.enabled) {
      await registrarIntento(supabase, {
        tipo: 'kiosco_verificacion', ip, exitoso: false, detalle: 'vision_deshabilitada',
      });
      return sendError(res, 'El reconocimiento facial del kiosco está deshabilitado. Pase a recepción para confirmar su turno', 503);
    }

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

    // Kiosco Windows (reconocimiento local, offline): si trae la clave
    // compartida válida en x-kiosk-key, el rostro ya fue verificado en el
    // equipo y se puede confirmar sin la verificación en nube.
    const kioskKey = String(req.headers['x-kiosk-key'] || '');
    const kioskOk = config.kiosco.apiKey !== '' && kioskKey === config.kiosco.apiKey;

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
    if (!kioskOk && (!intentos || intentos.length === 0)) {
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

/**
 * GET /api/kiosco/manifest?limit=500&offset=0
 * Manifiesto de sincronización del kiosco: versión del pack de modelos +
 * lista de pacientes con plantilla (hash md5 para comparar sin descargar).
 *
 * El kiosco lo pide cada KIOSCO_SYNC_MINUTOS: compara hashes con su caché
 * local y solo descarga los paquetes que cambiaron (ver obtenerPaquete).
 * Si `modelo_version` difiere de la local, actualiza sus modelos.
 * Protegido con kioskAuth (nunca público: son datos biométricos en lote).
 */
const obtenerManifest = async (req, res) => {
  try {
    const supabase = getSupabase();
    const limite = Math.min(Math.max(parseInt(req.query.limit, 10) || 500, 1), 2000);
    const offset = Math.max(parseInt(req.query.offset, 10) || 0, 0);

    const { data, error, count } = await supabase
      .from('pacientes')
      .select('id, cedula, nombre, apellido, rostro_embedding, rostro_actualizado_en', { count: 'exact' })
      .not('rostro_embedding', 'is', null)
      .eq('activo', true)
      .order('id')
      .range(offset, offset + limite - 1);

    if (error) throw error;

    const pacientes = (data || []).map((p) => ({
      paciente_id: p.id,
      cedula: p.cedula,
      nombre: `${p.nombre || ''} ${p.apellido || ''}`.trim(),
      rostro_actualizado_en: p.rostro_actualizado_en,
      rostro_vigente: rostroVigente(p),
      template_hash: hashPlantilla(p.rostro_embedding),
    }));

    return sendSuccess(res, {
      modelo_version: config.vision.modelVersion,
      modelo_pack: config.vision.modelPack,
      sync_minutos: config.kiosco.syncMinutos,
      total: count ?? pacientes.length,
      limit: limite,
      offset,
      pacientes,
    }, 'Manifiesto de sincronización');
  } catch (error) {
    console.error('kiosco.obtenerManifest:', error.message);
    return sendError(res, 'Error al generar el manifiesto', 500);
  }
};

/**
 * GET /api/kiosco/paquete/:pacienteId
 * Descarga el paquete completo de un paciente para el kiosco: plantilla
 * principal 512-d, embeddings por pose y URLs firmadas (10 min) de sus
 * fotos de referencia. Protegido con kioskAuth.
 */
const obtenerPaquete = async (req, res) => {
  try {
    const supabase = getSupabase();
    const pacienteId = parseInt(req.params.pacienteId, 10);

    const { data: pacientes, error: errorPaciente } = await supabase
      .from('pacientes')
      .select('id, cedula, nombre, apellido, rostro_embedding, rostro_actualizado_en')
      .eq('id', pacienteId)
      .limit(1);
    if (errorPaciente) throw errorPaciente;
    if (!pacientes || pacientes.length === 0) {
      return sendError(res, 'Paciente no encontrado', 404);
    }
    const paciente = pacientes[0];
    const embedding = parseEmbedding(paciente.rostro_embedding);
    if (!embedding) {
      return sendError(res, 'El paciente no tiene rostro registrado', 404);
    }

    const { data: muestras, error: errorMuestras } = await supabase
      .from('rostro_muestras')
      .select('pose, storage_path, embedding, calidad')
      .eq('paciente_id', pacienteId);
    if (errorMuestras) throw errorMuestras;

    const bucket = config.kiosco.rostroBucket;
    const rutas = (muestras || [])
      .map((m) => String(m.storage_path || '').replace(`${bucket}/`, ''))
      .filter(Boolean);
    let firmadas = {};
    if (rutas.length > 0) {
      const { data: urls, error: errorUrls } = await supabase.storage
        .from(bucket)
        .createSignedUrls(rutas, 600);
      if (errorUrls) throw errorUrls;
      for (const u of urls || []) {
        if (u && u.path) firmadas[u.path] = u.signedUrl;
      }
    }

    const poses = (muestras || []).map((m) => {
      const ruta = String(m.storage_path || '').replace(`${bucket}/`, '');
      return {
        pose: m.pose,
        embedding: parseEmbedding(m.embedding),
        calidad: m.calidad,
        foto_url: firmadas[ruta] || null,
      };
    });

    return sendSuccess(res, {
      paciente_id: paciente.id,
      nombre: `${paciente.nombre || ''} ${paciente.apellido || ''}`.trim(),
      rostro_embedding: embedding,
      rostro_actualizado_en: paciente.rostro_actualizado_en,
      template_hash: hashPlantilla(embedding),
      poses,
    }, 'Paquete del paciente');
  } catch (error) {
    console.error('kiosco.obtenerPaquete:', error.message);
    return sendError(res, 'Error al descargar el paquete', 500);
  }
};

/**
 * GET /api/kiosco/modelo
 * Versión del pack de modelos que el kiosco debe tener. Si difiere de la
 * local, el kiosco descarga el pack (InsightFace lo obtiene de su CDN en el
 * primer uso) y reinicia su reconocedor. Protegido con kioskAuth.
 */
const obtenerModelo = async (req, res) =>
  sendSuccess(res, {
    version: config.vision.modelVersion,
    pack: config.vision.modelPack,
    umbral_similitud: config.vision.similarityThreshold,
    notas: 'El sidecar Python del kiosco descarga el pack en el primer uso; ante cambio de versión, purgar el caché local y reiniciar.',
  }, 'Modelo de visión vigente');

/**
 * POST /api/kiosco/paquete-rostro (público, rate limit 5/h por IP)
 * Puente de la reserva online: crea el paciente del backend por cédula si no
 * existe (solo datos mínimos) y registra su pack de fotos multi-pose con el
 * mismo pipeline de recepción (procesarPaquete).
 *
 * Body: { cedula, nombre, apellido, telefono?, email?, fecha_nacimiento?, muestras: [{imagen, pose}] }
 * Respuesta: { paciente_id, rostro_registrado, rostro_vigente }
 */
const ingestarPaquete = async (req, res) => {
  const supabase = getSupabase();
  try {
    const { cedula, nombre, apellido, telefono, email, fecha_nacimiento, muestras } = req.body;

    let paciente;
    const { data: existentes, error: errorBuscar } = await supabase
      .from('pacientes')
      .select('id, cedula, nombre, apellido, rostro_embedding, rostro_actualizado_en')
      .eq('cedula', String(cedula).trim())
      .limit(1);
    if (errorBuscar) throw errorBuscar;

    if (existentes && existentes.length > 0) {
      paciente = existentes[0];
    } else {
      const { data: creado, error: errorCrear } = await supabase
        .from('pacientes')
        .insert({
          nombre: String(nombre).trim(),
          apellido: String(apellido).trim(),
          cedula: String(cedula).trim(),
          telefono: telefono ? String(telefono).trim() : null,
          email: email ? String(email).trim().toLowerCase() : null,
          fecha_nacimiento: fecha_nacimiento || null,
          activo: true,
        })
        .select('id, cedula, nombre, apellido, rostro_embedding, rostro_actualizado_en')
        .single();
      if (errorCrear) throw errorCrear;
      paciente = creado;
    }

    const resultado = await procesarPaquete(supabase, paciente, muestras);

    await registrarIntento(supabase, {
      tipo: 'kiosco_verificacion',
      referencia_id: paciente.id,
      ip: obtenerIp(req),
      userAgent: req.headers['user-agent'],
      exitoso: resultado.rostro_registrado,
      detalle: 'paquete_online',
    });

    return sendSuccess(res, {
      paciente_id: paciente.id,
      guardadas: resultado.guardadas,
      por_pose: resultado.porPose,
      rostro_registrado: resultado.rostro_registrado,
      rostro_vigente: true,
    }, 'Pack facial registrado');
  } catch (error) {
    console.error('kiosco.ingestarPaquete:', error.message);
    if (error.statusCode) {
      return sendError(res, error.message, error.statusCode);
    }
    return sendError(res, 'No se pudo registrar el pack facial', 500);
  }
};
module.exports = { verificarRostro, confirmarCita, listarIntentos, obtenerManifest, obtenerPaquete, obtenerModelo, ingestarPaquete };
