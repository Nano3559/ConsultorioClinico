'use strict';

/**
 * Controlador de PreConsulta IA (migración 015).
 *
 * Principios:
 *  - Autorización explícita: el personal (admin/médico/recepción) ve la cola;
 *    el paciente solo sus propias pre-consultas.
 *  - El análisis de visión corre en el microservicio Python; aquí se fusiona
 *    con el cuestionario mediante reglas explicables (`preconsultaTriage`).
 *  - Todo cambio de estado deja un evento de auditoría.
 *  - Nunca se persisten imágenes ni video: solo métricas derivadas.
 *  - La IA no decide: `requiere_revision` queda en true hasta que un médico
 *    o admin revisa el nivel.
 */

const crypto = require('crypto');
const { getSupabase, dbErrorMessage } = require('../config/supabase');
const config = require('../config/config');
const { sendSuccess, sendError, formatDate } = require('../utils/helpers');
const { llamarVision } = require('../services/visionService');
const { CONSENTIMIENTO, TEXTO_HASH } = require('../services/preconsultaContenido');
const {
  CATALOGO_PREGUNTAS,
  SECCIONES,
  NIVELES_TRIAGE,
  PREGUNTAS_POR_CODIGO,
  validarRespuestas,
  etiquetaRespuesta,
  evaluarTriage,
  TRIAGE_VERSION,
} = require('../services/preconsultaTriage');

const SELECT_DETALLE =
  '*, pacientes(id, nombre, apellido, cedula, fecha_nacimiento, sexo, telefono, email, antecedentes, alergias), ' +
  'medicos(id, nombre, apellido, especialidad), citas(id, fecha, hora, estado), ' +
  'preconsulta_respuestas(*), preconsulta_revisiones(*)';

const SELECT_COLA =
  '*, pacientes(id, nombre, apellido, cedula, fecha_nacimiento), ' +
  'medicos(id, nombre, apellido, especialidad), citas(id, fecha, hora, estado)';

const ROLES_STAFF = ['admin', 'medico', 'recepcion'];

// ---------------------------------------------------------------------------
// Utilidades
// ---------------------------------------------------------------------------

const numero = (valor, decimales = 1) => {
  const n = Number(valor);
  if (!Number.isFinite(n)) return null;
  const factor = 10 ** decimales;
  return Math.round(n * factor) / factor;
};

const acotar = (valor, min, max, decimales = 1) => {
  const n = numero(valor, decimales);
  if (n == null) return null;
  return Math.min(max, Math.max(min, n));
};

const esStaff = (req) => ROLES_STAFF.includes(req.user && req.user.rol);

const claveDia = (valor) => {
  const fecha = valor instanceof Date ? valor : new Date(valor);
  if (Number.isNaN(fecha.getTime())) return null;
  const y = fecha.getFullYear();
  const m = String(fecha.getMonth() + 1).padStart(2, '0');
  const d = String(fecha.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
};

const hashIp = (req) => {
  try {
    const fwd = req.headers['x-forwarded-for'];
    const ip = fwd ? String(fwd).split(',')[0].trim() : req.ip || req.socket?.remoteAddress || '';
    const sal = config.preconsulta.ipSalt || config.jwtSecret || 'preconsulta';
    return crypto.createHash('sha256').update(`${sal}:${ip}`).digest('hex');
  } catch (_e) {
    return '';
  }
};

/** Resuelve el id de paciente del usuario autenticado (paciente). */
const pacientePropio = async (req) => {
  if (!req.user || req.user.rol !== 'paciente') return null;
  if (req.user.perfilId != null) return Number(req.user.perfilId);
  try {
    const { data } = await getSupabase()
      .from('pacientes')
      .select('id')
      .eq('usuario_id', req.user.id)
      .limit(1);
    return data && data[0] ? Number(data[0].id) : null;
  } catch (_e) {
    return null;
  }
};

/** Autoriza el acceso a una fila concreta. */
const autorizarFila = async (req, fila) => {
  if (!fila) return { ok: false, status: 404, message: 'Preconsulta no encontrada' };
  if (esStaff(req)) return { ok: true };
  const propio = await pacientePropio(req);
  if (propio == null) {
    return {
      ok: false,
      status: 403,
      message: 'Perfil de paciente no encontrado. Contacte a recepción.',
    };
  }
  if (Number(fila.paciente_id) !== Number(propio)) {
    return { ok: false, status: 403, message: 'No tiene acceso a esta preconsulta' };
  }
  return { ok: true };
};

const cargarPreconsulta = async (id) => {
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from('preconsultas')
    .select(SELECT_DETALLE)
    .eq('id', id)
    .single();
  if (error || !data) return null;
  return data;
};

const registrarEvento = async (preconsultaId, tipo, detalle, usuarioId) => {
  try {
    await getSupabase()
      .from('preconsulta_eventos')
      .insert({
        preconsulta_id: preconsultaId,
        tipo,
        detalle: detalle || {},
        usuario_id: usuarioId || null,
      });
  } catch (error) {
    // La auditoría nunca debe tumbar la operación clínica.
    console.error('[preconsulta] evento no registrado:', error.message);
  }
};

const serializarRespuesta = (codigo, valor) => {
  const pregunta = PREGUNTAS_POR_CODIGO.get(codigo);
  if (!pregunta) return null;
  let texto = '';
  let valorNum = null;
  switch (pregunta.tipo) {
    case 'escala':
      texto = String(valor);
      valorNum = Number(valor);
      break;
    case 'si_no':
      texto = valor ? 'si' : 'no';
      valorNum = valor ? 1 : 0;
      break;
    case 'multiopcion':
      texto = JSON.stringify(Array.isArray(valor) ? valor : []);
      break;
    default:
      texto = String(valor == null ? '' : valor);
  }
  return {
    codigo,
    pregunta: pregunta.pregunta,
    respuesta: texto,
    valor_num: valorNum,
  };
};

const deserializarRespuesta = (codigo, texto, valorNum) => {
  const pregunta = PREGUNTAS_POR_CODIGO.get(codigo);
  if (!pregunta) return texto;
  switch (pregunta.tipo) {
    case 'escala': {
      const n = Number(valorNum != null ? valorNum : texto);
      return Number.isFinite(n) ? n : null;
    }
    case 'si_no':
      return texto === 'si' || Number(valorNum) === 1;
    case 'multiopcion':
      try {
        const lista = JSON.parse(texto);
        return Array.isArray(lista) ? lista : [];
      } catch (_e) {
        return [];
      }
    default:
      return texto;
  }
};

const edadDe = (fechaNacimiento) => {
  if (!fechaNacimiento) return null;
  const nacimiento = new Date(fechaNacimiento);
  if (Number.isNaN(nacimiento.getTime())) return null;
  const hoy = new Date();
  let edad = hoy.getFullYear() - nacimiento.getFullYear();
  const mes = hoy.getMonth() - nacimiento.getMonth();
  if (mes < 0 || (mes === 0 && hoy.getDate() < nacimiento.getDate())) edad -= 1;
  return edad >= 0 && edad < 130 ? edad : null;
};

const nivelMeta = (nivel) => NIVELES_TRIAGE.find((n) => n.nivel === Number(nivel)) || null;

/** Resumen para la cola (ligero). */
const mapResumen = (fila) => {
  const paciente = fila.pacientes || null;
  const meta = nivelMeta(fila.triage_nivel);
  return {
    id: Number(fila.id),
    paciente_id: Number(fila.paciente_id),
    paciente: paciente
      ? {
          id: Number(paciente.id),
          nombre: `${paciente.nombre || ''} ${paciente.apellido || ''}`.trim(),
          cedula: paciente.cedula || '',
          edad: edadDe(paciente.fecha_nacimiento),
        }
      : null,
    medico: fila.medicos
      ? {
          id: Number(fila.medicos.id),
          nombre: `${fila.medicos.nombre || ''} ${fila.medicos.apellido || ''}`.trim(),
          especialidad: fila.medicos.especialidad || '',
        }
      : null,
    cita: fila.citas
      ? { id: Number(fila.citas.id), fecha: fila.citas.fecha, hora: fila.citas.hora, estado: fila.citas.estado }
      : null,
    estado: fila.estado,
    canal: fila.canal,
    motivo: fila.motivo || '',
    creado_en: fila.creado_en,
    analizado_en: fila.analizado_en,
    triage: {
      nivel: fila.triage_nivel != null ? Number(fila.triage_nivel) : null,
      nivel_etiqueta: meta ? meta.etiqueta : null,
      confianza: numero(fila.triage_confianza, 3),
      resumen: fila.triage_resumen || '',
      banderas: Array.isArray(fila.banderas) ? fila.banderas : [],
    },
    calidad_captura: numero(fila.calidad_captura, 1),
    rostro_detectado: fila.rostro_detectado === true,
    requiere_revision: fila.requiere_revision === true,
    revisado_en: fila.revisado_en,
    no_es_diagnostico: true,
  };
};

/** Detalle completo para la ficha clínica. */
const mapDetalle = (fila) => {
  const paciente = fila.pacientes || null;
  const meta = nivelMeta(fila.triage_nivel);
  const respuestas = (fila.preconsulta_respuestas || [])
    .slice()
    .sort((a, b) => {
      const pa = PREGUNTAS_POR_CODIGO.get(a.codigo);
      const pb = PREGUNTAS_POR_CODIGO.get(b.codigo);
      return (pa ? pa.orden : 999) - (pb ? pb.orden : 999);
    })
    .map((r) => {
      const pregunta = PREGUNTAS_POR_CODIGO.get(r.codigo);
      const valor = deserializarRespuesta(r.codigo, r.respuesta, r.valor_num);
      return {
        codigo: r.codigo,
        pregunta: (pregunta && pregunta.pregunta) || r.pregunta || r.codigo,
        seccion: (pregunta && pregunta.seccion) || 'otras',
        tipo: (pregunta && pregunta.tipo) || 'texto',
        valor,
        etiqueta: etiquetaRespuesta(r.codigo, valor),
      };
    });

  const revisiones = (fila.preconsulta_revisiones || [])
    .slice()
    .sort((a, b) => String(b.creado_en).localeCompare(String(a.creado_en)))
    .map((r) => ({
      id: Number(r.id),
      nivel_anterior: r.nivel_anterior != null ? Number(r.nivel_anterior) : null,
      nivel_nuevo: Number(r.nivel_nuevo),
      nota: r.nota || '',
      usuario_id: r.usuario_id != null ? Number(r.usuario_id) : null,
      creado_en: r.creado_en,
    }));

  return {
    id: Number(fila.id),
    estado: fila.estado,
    canal: fila.canal,
    motivo: fila.motivo || '',
    creado_en: fila.creado_en,
    actualizado_en: fila.actualizado_en,
    analizado_en: fila.analizado_en,
    paciente: paciente
      ? {
          id: Number(paciente.id),
          nombre: `${paciente.nombre || ''} ${paciente.apellido || ''}`.trim(),
          nombres: paciente.nombre || '',
          apellidos: paciente.apellido || '',
          cedula: paciente.cedula || '',
          edad: edadDe(paciente.fecha_nacimiento),
          sexo: paciente.sexo || '',
          telefono: paciente.telefono || '',
          email: paciente.email || '',
          antecedentes: paciente.antecedentes || '',
          alergias: paciente.alergias || '',
        }
      : null,
    medico: fila.medicos
      ? {
          id: Number(fila.medicos.id),
          nombre: `${fila.medicos.nombre || ''} ${fila.medicos.apellido || ''}`.trim(),
          especialidad: fila.medicos.especialidad || '',
        }
      : null,
    cita: fila.citas
      ? { id: Number(fila.citas.id), fecha: fila.citas.fecha, hora: fila.citas.hora, estado: fila.citas.estado }
      : null,
    captura: {
      duracion_seg: numero(fila.duracion_captura_seg, 1),
      frames: fila.frames_enviados != null ? Number(fila.frames_enviados) : null,
      calidad: numero(fila.calidad_captura, 1),
      rostro_detectado: fila.rostro_detectado === true,
      detalle: fila.captura_detalle || {},
    },
    vitales: {
      hr_bpm: numero(fila.hr_bpm, 1),
      hr_confianza: numero(fila.hr_confianza, 3),
      rmssd_ms: numero(fila.rmssd_ms, 1),
      sdnn_ms: numero(fila.sdnn_ms, 1),
      pnn50: numero(fila.pnn50, 1),
      hrv_confianza: numero(fila.hrv_confianza, 3),
      respiraciones_rpm: numero(fila.respiraciones_rpm, 1),
      senal_snr_db: numero(fila.senal_snr_db, 2),
      senal_confianza: numero(fila.senal_confianza, 3),
    },
    rostro: {
      pain_score: numero(fila.pain_score, 1),
      pain_confianza: numero(fila.pain_confianza, 3),
      stress_score: numero(fila.stress_score, 1),
      fatigue_score: numero(fila.fatigue_score, 1),
      blink_rate: numero(fila.blink_rate, 1),
      expresion_dominante: fila.expresion_dominante || null,
      microexpresiones: Array.isArray(fila.microexpresiones) ? fila.microexpresiones : [],
      pose_estabilidad: numero(fila.pose_estabilidad, 3),
    },
    identidad:
      fila.identidad_similitud != null
        ? {
            similitud: numero(fila.identidad_similitud, 4),
            coincide: fila.identidad_coincide === true,
            disponible: true,
          }
        : null,
    triage: {
      nivel: fila.triage_nivel != null ? Number(fila.triage_nivel) : null,
      nivel_etiqueta: meta ? meta.etiqueta : null,
      nivel_clave: meta ? meta.clave : null,
      color: meta ? meta.color : null,
      confianza: numero(fila.triage_confianza, 3),
      motivos: Array.isArray(fila.triage_motivos) ? fila.triage_motivos : [],
      recomendaciones: Array.isArray(fila.triage_recomendaciones) ? fila.triage_recomendaciones : [],
      banderas: Array.isArray(fila.banderas) ? fila.banderas : [],
      resumen: fila.triage_resumen || '',
      version: fila.triage_version || '',
      requiere_revision: fila.requiere_revision === true,
      revisado_por_usuario_id:
        fila.revisado_por_usuario_id != null ? Number(fila.revisado_por_usuario_id) : null,
      revisado_en: fila.revisado_en,
      nivel_revisado: fila.nivel_revisado != null ? Number(fila.nivel_revisado) : null,
      nota_revision: fila.nota_revision || '',
    },
    respuestas,
    revisiones,
    modelo_version: fila.modelo_version || '',
    no_es_diagnostico: true,
    requiere_revision_humana: true,
  };
};

/** Construye el objeto de respuestas (crudo) desde las filas de la BD. */
const respuestasDesdeFilas = (filas) => {
  const respuestas = {};
  for (const fila of filas || []) {
    if (!PREGUNTAS_POR_CODIGO.has(fila.codigo)) continue;
    respuestas[fila.codigo] = deserializarRespuesta(fila.codigo, fila.respuesta, fila.valor_num);
  }
  return respuestas;
};

const metricasDeFila = (fila) => ({
  rostro_detectado: fila.rostro_detectado === true,
  calidad_captura: numero(fila.calidad_captura, 1),
  senal_confianza: numero(fila.senal_confianza, 3),
  hr_bpm: numero(fila.hr_bpm, 1),
  hr_confianza: numero(fila.hr_confianza, 3),
  rmssd_ms: numero(fila.rmssd_ms, 1),
  hrv_confianza: numero(fila.hrv_confianza, 3),
  pain_score: numero(fila.pain_score, 1),
  pain_confianza: numero(fila.pain_confianza, 3),
  stress_score: numero(fila.stress_score, 1),
  fatigue_score: numero(fila.fatigue_score, 1),
});

const camposTriage = (resultado) => ({
  triage_nivel: resultado.nivel,
  triage_confianza: resultado.confianza,
  triage_motivos: resultado.motivos,
  triage_recomendaciones: resultado.recomendaciones,
  banderas: resultado.banderas,
  triage_resumen: resultado.resumen,
  triage_version: resultado.version,
  requiere_revision: true,
});

/**
 * Recalcula el triage con las respuestas actuales y las métricas guardadas.
 * Se usa cuando el cuestionario se envía después del análisis (orden libre).
 */
const recalcularTriage = async (fila) => {
  if (fila.triage_nivel == null && fila.rostro_detectado !== true) return null;
  const supabase = getSupabase();
  const [{ data: respuestasFilas }, { data: paciente }] = await Promise.all([
    supabase.from('preconsulta_respuestas').select('*').eq('preconsulta_id', fila.id),
    supabase
      .from('pacientes')
      .select('fecha_nacimiento, antecedentes')
      .eq('id', fila.paciente_id)
      .limit(1),
  ]);
  const resultado = evaluarTriage({
    metricas: metricasDeFila(fila),
    respuestas: respuestasDesdeFilas(respuestasFilas),
    paciente: paciente && paciente[0] ? paciente[0] : null,
  });
  await supabase.from('preconsultas').update(camposTriage(resultado)).eq('id', fila.id);
  return resultado;
};

/**
 * Persiste el cuestionario recibido: upsert de las respuestas y limpieza de
 * los códigos que ya no vienen en el envío. Las respuestas previas quedan
 * intactas si el upsert falla.
 */
const persistirRespuestas = async (preconsultaId, respuestas) => {
  const supabase = getSupabase();
  const filas = Object.entries(respuestas)
    .map(([codigo, valor]) => serializarRespuesta(codigo, valor))
    .filter(Boolean)
    .map((f) => ({ ...f, preconsulta_id: preconsultaId }));

  const { data: existentes, error: errorLeer } = await supabase
    .from('preconsulta_respuestas')
    .select('codigo')
    .eq('preconsulta_id', preconsultaId);
  if (errorLeer) {
    console.error('[preconsulta] leer respuestas:', errorLeer.message);
    return { ok: false, status: 500, message: dbErrorMessage(errorLeer) || 'No se pudieron leer las respuestas' };
  }

  if (filas.length > 0) {
    const { error: errorUpsert } = await supabase
      .from('preconsulta_respuestas')
      .upsert(filas, { onConflict: 'preconsulta_id,codigo' });
    if (errorUpsert) {
      console.error('[preconsulta] upsert respuestas:', errorUpsert.message);
      return { ok: false, status: 500, message: dbErrorMessage(errorUpsert) || 'No se pudieron guardar las respuestas' };
    }
  }

  const codigosNuevos = new Set(filas.map((f) => f.codigo));
  const sobrantes = (existentes || [])
    .map((f) => f.codigo)
    .filter((codigo) => !codigosNuevos.has(codigo));
  if (sobrantes.length > 0) {
    const { error: errorBorrar } = await supabase
      .from('preconsulta_respuestas')
      .delete()
      .eq('preconsulta_id', preconsultaId)
      .in('codigo', sobrantes);
    if (errorBorrar) {
      console.error('[preconsulta] borrar respuestas:', errorBorrar.message);
      return { ok: false, status: 500, message: dbErrorMessage(errorBorrar) || 'No se pudieron guardar las respuestas' };
    }
  }

  return { ok: true, filas };
};

// ---------------------------------------------------------------------------
// Endpoints
// ---------------------------------------------------------------------------

/** GET /api/preconsulta/consentimiento */
const getConsentimiento = async (req, res) => {
  try {
    let yaAceptado = false;
    let aceptadoEn = null;
    let pacienteId = null;

    if (req.user.rol === 'paciente') {
      pacienteId = await pacientePropio(req);
    } else if (req.query.paciente_id && /^\d+$/.test(String(req.query.paciente_id))) {
      pacienteId = Number(req.query.paciente_id);
    }

    if (pacienteId != null) {
      const { data } = await getSupabase()
        .from('consentimientos_preconsulta')
        .select('aceptado_en')
        .eq('paciente_id', pacienteId)
        .eq('version', CONSENTIMIENTO.version)
        .eq('aceptado', true)
        .order('aceptado_en', { ascending: false })
        .limit(1);
      if (data && data[0]) {
        yaAceptado = true;
        aceptadoEn = data[0].aceptado_en;
      }
    }

    return sendSuccess(
      res,
      {
        habilitado: config.preconsulta.enabled,
        consentimiento: CONSENTIMIENTO,
        secciones: SECCIONES,
        preguntas: CATALOGO_PREGUNTAS,
        niveles: NIVELES_TRIAGE,
        version: CONSENTIMIENTO.version,
        ya_aceptado: yaAceptado,
        aceptado_en: aceptadoEn,
        paciente_id: pacienteId,
      },
      'Consentimiento y cuestionario'
    );
  } catch (error) {
    console.error('[preconsulta] consentimiento:', error.message);
    return sendError(res, 'No se pudo cargar el consentimiento', 500);
  }
};

/** POST /api/preconsulta */
const crear = async (req, res) => {
  try {
    if (!config.preconsulta.enabled) {
      return sendError(res, 'La PreConsulta IA está deshabilitada en este entorno', 503);
    }
    const supabase = getSupabase();
    const version = String(req.body.consentimiento_version || '').trim();
    if (version !== CONSENTIMIENTO.version) {
      return sendError(
        res,
        'El consentimiento cambió. Actualice la pantalla y vuelva a aceptarlo.',
        409
      );
    }

    let pacienteId = Number(req.body.paciente_id);
    if (req.user.rol === 'paciente') {
      const propio = await pacientePropio(req);
      if (propio == null) {
        return sendError(res, 'Perfil de paciente no encontrado. Contacte a recepción.', 403);
      }
      pacienteId = propio;
    }
    if (!Number.isInteger(pacienteId) || pacienteId <= 0) {
      return sendError(res, 'El paciente es obligatorio', 422);
    }

    const { data: paciente, error: errorPaciente } = await supabase
      .from('pacientes')
      .select('id, nombre, apellido, activo')
      .eq('id', pacienteId)
      .single();
    if (errorPaciente || !paciente) {
      return sendError(res, 'Paciente no encontrado', 404);
    }
    if (paciente.activo === false) {
      return sendError(res, 'El paciente está inactivo', 400);
    }

    let medicoId = req.body.medico_id ? Number(req.body.medico_id) : null;
    let citaId = req.body.cita_id ? Number(req.body.cita_id) : null;
    if (citaId != null) {
      const { data: cita } = await supabase
        .from('citas')
        .select('id, paciente_id, medico_id, estado')
        .eq('id', citaId)
        .single();
      if (!cita) return sendError(res, 'Cita no encontrada', 404);
      if (Number(cita.paciente_id) !== pacienteId) {
        return sendError(res, 'La cita no pertenece al paciente indicado', 400);
      }
      if (['cancelada', 'no_show'].includes(cita.estado)) {
        return sendError(res, 'La cita está cancelada o no asistió', 409);
      }
      medicoId = medicoId || Number(cita.medico_id);
    }
    if (medicoId != null) {
      const { data: medico } = await supabase
        .from('medicos')
        .select('id, activo')
        .eq('id', medicoId)
        .single();
      if (!medico) return sendError(res, 'Médico no encontrado', 404);
      if (medico.activo === false) return sendError(res, 'El médico está inactivo', 400);
    }

    // 1) Consentimiento versionado (con hash de IP, nunca la IP en claro).
    const { data: consentimiento, error: errorConsentimiento } = await supabase
      .from('consentimientos_preconsulta')
      .insert({
        paciente_id: pacienteId,
        usuario_id: req.user.id || null,
        version,
        aceptado: true,
        texto_hash: TEXTO_HASH,
        ip_hash: hashIp(req),
        user_agent: String(req.headers['user-agent'] || '').slice(0, 300),
      })
      .select('id')
      .single();
    if (errorConsentimiento || !consentimiento) {
      console.error('[preconsulta] consentimiento:', errorConsentimiento?.message);
      return sendError(
        res,
        dbErrorMessage(errorConsentimiento) || 'No se pudo registrar el consentimiento',
        500
      );
    }

    // 2) Preconsulta en estado pendiente (aún sin captura).
    const canal = req.body.canal || (req.user.rol === 'paciente' ? 'web' : 'recepcion');
    const { data: creada, error: errorCrear } = await supabase
      .from('preconsultas')
      .insert({
        paciente_id: pacienteId,
        medico_id: medicoId,
        cita_id: citaId,
        consentimiento_id: consentimiento.id,
        creada_por_usuario_id: req.user.id || null,
        estado: 'pendiente',
        canal,
        motivo: req.body.motivo || '',
        triage_version: TRIAGE_VERSION,
      })
      .select('id')
      .single();
    if (errorCrear || !creada) {
      console.error('[preconsulta] crear:', errorCrear?.message);
      return sendError(res, dbErrorMessage(errorCrear) || 'No se pudo crear la preconsulta', 500);
    }

    await registrarEvento(creada.id, 'creada', { canal, cita_id: citaId }, req.user.id);
    const detalle = await cargarPreconsulta(creada.id);
    if (!detalle) {
      return sendError(res, 'Preconsulta creada, pero no se pudo cargar el detalle', 500);
    }
    return sendSuccess(res, mapDetalle(detalle), 'Preconsulta creada', 201);
  } catch (error) {
    console.error('[preconsulta] crear:', error.message);
    return sendError(res, 'Error al crear la preconsulta', 500);
  }
};

/** POST /api/preconsulta/:id/analizar */
const analizar = async (req, res) => {
  try {
    if (!config.preconsulta.enabled) {
      return sendError(res, 'La PreConsulta IA está deshabilitada en este entorno', 503);
    }
    const supabase = getSupabase();
    const fila = await cargarPreconsulta(req.params.id);
    if (!fila) return sendError(res, 'Preconsulta no encontrada', 404);

    const autorizacion = await autorizarFila(req, fila);
    if (!autorizacion.ok) return sendError(res, autorizacion.message, autorizacion.status);
    if (['revisada', 'cancelada'].includes(fila.estado)) {
      return sendError(res, 'La preconsulta ya fue cerrada y no admite nuevos análisis', 409);
    }

    const frames = Array.isArray(req.body.frames) ? req.body.frames : [];
    const video = req.body.video || '';
    const duracionSeg = req.body.duracion_seg != null ? Number(req.body.duracion_seg) : null;

    await supabase.from('preconsultas').update({ estado: 'analizando' }).eq('id', fila.id);

    let respuesta;
    try {
      respuesta = await llamarVision(
        config.preconsulta.visionEndpoint,
        {
          frames,
          video,
          fps: req.body.fps || 0,
          timestamps: Array.isArray(req.body.timestamps) ? req.body.timestamps : [],
          espejado: req.body.espejado === true,
          paciente_id: Number(fila.paciente_id),
          identidad: req.body.identidad !== false,
        },
        {
          timeoutMs: config.preconsulta.analysisTimeoutMs,
          retries: 1, // el análisis es caro: no duplicar si el cliente ya espera
        }
      );
    } catch (error) {
      await supabase.from('preconsultas').update({ estado: 'fallida' }).eq('id', fila.id);
      await registrarEvento(fila.id, 'error_vision', { mensaje: String(error.message).slice(0, 200) }, req.user.id);
      if (error.name === 'TimeoutError' || error.name === 'AbortError') {
        return sendError(
          res,
          'El análisis tardó demasiado. Intente con una captura más corta o repita en unos minutos.',
          504
        );
      }
      return sendError(
        res,
        'No se pudo contactar el servicio de análisis. Verifique que esté disponible e intente de nuevo.',
        502
      );
    }

    let datos = null;
    try {
      datos = await respuesta.json();
    } catch (_e) {
      datos = null;
    }
    if (!respuesta.ok) {
      await supabase.from('preconsultas').update({ estado: 'fallida' }).eq('id', fila.id);
      const detalle = datos && typeof datos.detail === 'string' ? datos.detail : 'No se pudo analizar la captura';
      const status = respuesta.status === 422 ? 422 : respuesta.status === 503 ? 503 : 502;
      await registrarEvento(fila.id, 'error_vision', { status: respuesta.status, detalle }, req.user.id);
      return sendError(res, detalle, status);
    }
    if (!datos || datos.ok !== true) {
      await supabase.from('preconsultas').update({ estado: 'fallida' }).eq('id', fila.id);
      const detalle =
        (datos && datos.detalle) || 'No se pudo analizar la captura. Repita la captura con el rostro centrado.';
      await registrarEvento(fila.id, 'captura_no_valida', { motivo: datos && datos.motivo }, req.user.id);
      return sendError(res, detalle, 422);
    }

    const calidad = datos.calidad || {};
    const vitales = datos.vitales || {};
    const rostro = datos.rostro || {};
    const identidad = datos.identidad && datos.identidad.disponible ? datos.identidad : null;

    const campos = {
      estado: 'completada',
      analizado_en: new Date().toISOString(),
      duracion_captura_seg: acotar(datos.duracion_seg != null ? datos.duracion_seg : duracionSeg, 0, 180, 1),
      frames_enviados: frames.length || Number(datos.frames_recibidos) || null,
      calidad_captura: acotar(calidad.puntaje, 0, 100, 1),
      rostro_detectado: datos.rostro_detectado === true,
      captura_detalle: {
        calidad,
        expresiones: rostro.expresiones || {},
        microexpresiones: rostro.microexpresiones || [],
        tension_facial: rostro.tension_facial,
        metodo_rppg: vitales.metodo || null,
        latidos: vitales.latidos || null,
        advertencias: datos.advertencias || [],
        identidad: identidad
          ? { disponible: true, similitud: identidad.similitud, coincide: identidad.coincide }
          : datos.identidad || null,
      },
      hr_bpm: acotar(vitales.hr_bpm, 1, 259, 1),
      hr_confianza: acotar(vitales.hr_confianza, 0, 1, 3),
      rmssd_ms: acotar(vitales.rmssd_ms, 0, 4999, 1),
      sdnn_ms: acotar(vitales.sdnn_ms, 0, 4999, 1),
      pnn50: acotar(vitales.pnn50, 0, 100, 2),
      hrv_confianza: acotar(vitales.hrv_confianza, 0, 1, 3),
      respiraciones_rpm: acotar(vitales.respiraciones_rpm, 0, 119, 1),
      senal_snr_db: acotar(vitales.senal_snr_db, -50, 100, 2),
      senal_confianza: acotar(vitales.senal_confianza, 0, 1, 3),
      pain_score: acotar(rostro.pain_score, 0, 10, 1),
      pain_confianza: acotar(rostro.pain_confianza, 0, 1, 3),
      stress_score: acotar(rostro.stress_score, 0, 100, 1),
      fatigue_score: acotar(rostro.fatigue_score, 0, 100, 1),
      blink_rate: acotar(rostro.blink_rate, 0, 200, 1),
      expresion_dominante: rostro.expresion_dominante || null,
      microexpresiones: rostro.microexpresiones || [],
      pose_estabilidad: acotar(rostro.pose_estabilidad, 0, 1, 3),
      identidad_similitud: identidad ? acotar(identidad.similitud, 0, 1, 4) : null,
      identidad_coincide: identidad ? identidad.coincide === true : null,
      modelo_version: datos.modelo_version || 'preconsulta-vision-1.0.0',
      requiere_revision: true,
    };

    // Fusión con el cuestionario (puede haberse enviado antes o después).
    const { data: respuestasFilas } = await supabase
      .from('preconsulta_respuestas')
      .select('*')
      .eq('preconsulta_id', fila.id);
    const { data: paciente } = await supabase
      .from('pacientes')
      .select('fecha_nacimiento, antecedentes')
      .eq('id', fila.paciente_id)
      .limit(1);

    const resultado = evaluarTriage({
      metricas: {
        rostro_detectado: campos.rostro_detectado,
        calidad_captura: campos.calidad_captura,
        senal_confianza: campos.senal_confianza,
        hr_bpm: campos.hr_bpm,
        hr_confianza: campos.hr_confianza,
        rmssd_ms: campos.rmssd_ms,
        hrv_confianza: campos.hrv_confianza,
        pain_score: campos.pain_score,
        pain_confianza: campos.pain_confianza,
        stress_score: campos.stress_score,
        fatigue_score: campos.fatigue_score,
      },
      respuestas: respuestasDesdeFilas(respuestasFilas),
      paciente: paciente && paciente[0] ? paciente[0] : null,
    });

    const { error: errorUpdate } = await supabase
      .from('preconsultas')
      .update({ ...campos, ...camposTriage(resultado) })
      .eq('id', fila.id);
    if (errorUpdate) {
      console.error('[preconsulta] guardar análisis:', errorUpdate.message);
      return sendError(res, dbErrorMessage(errorUpdate) || 'No se pudo guardar el análisis', 500);
    }

    await registrarEvento(
      fila.id,
      'analizada',
      {
        nivel: resultado.nivel,
        score: resultado.score,
        calidad: campos.calidad_captura,
        modelo_version: campos.modelo_version,
        banderas: resultado.banderas.map((b) => b.codigo),
      },
      req.user.id
    );

    const detalle = await cargarPreconsulta(fila.id);
    if (!detalle) {
      return sendError(res, 'Análisis guardado, pero no se pudo cargar el detalle', 500);
    }
    return sendSuccess(res, mapDetalle(detalle), 'Análisis completado');
  } catch (error) {
    console.error('[preconsulta] analizar:', error.message);
    return sendError(res, 'Error al analizar la preconsulta', 500);
  }
};

/** PUT /api/preconsulta/:id/respuestas */
const guardarRespuestas = async (req, res) => {
  try {
    if (!config.preconsulta.enabled) {
      return sendError(res, 'La PreConsulta IA está deshabilitada en este entorno', 503);
    }
    const supabase = getSupabase();
    const fila = await cargarPreconsulta(req.params.id);
    if (!fila) return sendError(res, 'Preconsulta no encontrada', 404);
    const autorizacion = await autorizarFila(req, fila);
    if (!autorizacion.ok) return sendError(res, autorizacion.message, autorizacion.status);
    if (['revisada', 'cancelada'].includes(fila.estado)) {
      return sendError(res, 'La preconsulta ya fue cerrada y no admite cambios', 409);
    }

    const validacion = validarRespuestas(req.body.respuestas);
    if (!validacion.ok) {
      return sendError(res, 'Errores de validación', 422, validacion.errores);
    }

    const guardado = await persistirRespuestas(fila.id, validacion.respuestas);
    if (!guardado.ok) {
      return sendError(res, guardado.message, guardado.status);
    }
    const filas = guardado.filas;

    await registrarEvento(
      fila.id,
      'respuestas',
      { total: filas.length, codigos: filas.map((f) => f.codigo) },
      req.user.id
    );

    // Si ya había análisis, el triage se recalcula con las respuestas nuevas.
    const recalculado = await recalcularTriage(fila);
    const detalle = await cargarPreconsulta(fila.id);
    if (!detalle) {
      return sendError(res, 'Respuestas guardadas, pero no se pudo cargar el detalle', 500);
    }
    return sendSuccess(
      res,
      { ...mapDetalle(detalle), triage_recalculado: recalculado != null },
      'Respuestas guardadas'
    );
  } catch (error) {
    console.error('[preconsulta] respuestas:', error.message);
    return sendError(res, 'Error al guardar las respuestas', 500);
  }
};

/** POST /api/preconsulta/:id/finalizar (sin captura) */
const finalizarSinCaptura = async (req, res) => {
  try {
    if (!config.preconsulta.enabled) {
      return sendError(res, 'La PreConsulta IA está deshabilitada en este entorno', 503);
    }
    const supabase = getSupabase();
    const fila = await cargarPreconsulta(req.params.id);
    if (!fila) return sendError(res, 'Preconsulta no encontrada', 404);
    const autorizacion = await autorizarFila(req, fila);
    if (!autorizacion.ok) return sendError(res, autorizacion.message, autorizacion.status);
    if (['revisada', 'cancelada'].includes(fila.estado)) {
      return sendError(res, 'La preconsulta ya fue cerrada', 409);
    }
    if (fila.rostro_detectado === true && fila.triage_nivel != null) {
      return sendError(res, 'La preconsulta ya tiene un análisis facial', 409);
    }

    // Permite enviar el cuestionario completo en la misma llamada (el asistente
    // web lo hace así al finalizar sin cámara). Si ya estaba guardado, se puede
    // omitir y se usa lo que hay en la base.
    if (req.body.respuestas != null) {
      const validacion = validarRespuestas(req.body.respuestas);
      if (!validacion.ok) {
        return sendError(res, 'Errores de validación', 422, validacion.errores);
      }
      const guardado = await persistirRespuestas(fila.id, validacion.respuestas);
      if (!guardado.ok) {
        return sendError(res, guardado.message, guardado.status);
      }
      await registrarEvento(
        fila.id,
        'respuestas',
        { total: guardado.filas.length, codigos: guardado.filas.map((f) => f.codigo) },
        req.user.id
      );
    }

    const [{ data: respuestasFilas }, { data: paciente }] = await Promise.all([
      supabase.from('preconsulta_respuestas').select('*').eq('preconsulta_id', fila.id),
      supabase
        .from('pacientes')
        .select('fecha_nacimiento, antecedentes')
        .eq('id', fila.paciente_id)
        .limit(1),
    ]);

    if (!respuestasFilas || respuestasFilas.length === 0) {
      return sendError(
        res,
        'Complete el cuestionario antes de finalizar sin captura',
        422
      );
    }

    const resultado = evaluarTriage({
      metricas: { rostro_detectado: false, calidad_captura: 0 },
      respuestas: respuestasDesdeFilas(respuestasFilas),
      paciente: paciente && paciente[0] ? paciente[0] : null,
    });

    const { error } = await supabase
      .from('preconsultas')
      .update({
        estado: 'completada',
        analizado_en: new Date().toISOString(),
        rostro_detectado: false,
        calidad_captura: 0,
        captura_detalle: {
          motivo: req.body.motivo || 'sin_captura',
          advertencias: ['captura_omitida_por_el_paciente'],
        },
        requiere_revision: true,
        ...camposTriage(resultado),
      })
      .eq('id', fila.id);
    if (error) {
      console.error('[preconsulta] finalizar:', error.message);
      return sendError(res, dbErrorMessage(error) || 'No se pudo finalizar la preconsulta', 500);
    }

    await registrarEvento(
      fila.id,
      'finalizada_sin_captura',
      { motivo: req.body.motivo || 'sin_captura', nivel: resultado.nivel },
      req.user.id
    );
    const detalle = await cargarPreconsulta(fila.id);
    if (!detalle) {
      return sendError(res, 'Preconsulta finalizada, pero no se pudo cargar el detalle', 500);
    }
    return sendSuccess(res, mapDetalle(detalle), 'Preconsulta finalizada sin captura');
  } catch (error) {
    console.error('[preconsulta] finalizar:', error.message);
    return sendError(res, 'Error al finalizar la preconsulta', 500);
  }
};

/** GET /api/preconsulta/:id */
const getById = async (req, res) => {
  try {
    const fila = await cargarPreconsulta(req.params.id);
    if (!fila) return sendError(res, 'Preconsulta no encontrada', 404);
    const autorizacion = await autorizarFila(req, fila);
    if (!autorizacion.ok) return sendError(res, autorizacion.message, autorizacion.status);
    return sendSuccess(res, mapDetalle(fila), 'Preconsulta');
  } catch (error) {
    console.error('[preconsulta] getById:', error.message);
    return sendError(res, 'Error al obtener la preconsulta', 500);
  }
};

/** GET /api/preconsulta/cita/:citaId */
const getByCita = async (req, res) => {
  try {
    const supabase = getSupabase();
    let consulta = supabase
      .from('preconsultas')
      .select(SELECT_DETALLE)
      .eq('cita_id', req.params.citaId)
      .order('creado_en', { ascending: false })
      .limit(1);
    if (!esStaff(req)) {
      const propio = await pacientePropio(req);
      if (propio == null) {
        return sendError(res, 'Perfil de paciente no encontrado. Contacte a recepción.', 403);
      }
      consulta = consulta.eq('paciente_id', propio);
    }
    const { data, error } = await consulta;
    if (error) {
      console.error('[preconsulta] getByCita:', error.message);
      return sendError(res, 'Error al obtener la preconsulta de la cita', 500);
    }
    if (!data || data.length === 0) {
      return sendSuccess(res, null, 'La cita no tiene preconsulta');
    }
    return sendSuccess(res, mapDetalle(data[0]), 'Preconsulta de la cita');
  } catch (error) {
    console.error('[preconsulta] getByCita:', error.message);
    return sendError(res, 'Error al obtener la preconsulta de la cita', 500);
  }
};

/** GET /api/preconsulta/cola */
const getCola = async (req, res) => {
  try {
    const supabase = getSupabase();
    const fecha = req.query.fecha || formatDate(new Date());
    const inicio = new Date(`${fecha}T00:00:00`);
    if (Number.isNaN(inicio.getTime())) {
      return sendError(res, 'Fecha inválida', 422);
    }
    const fin = new Date(inicio);
    fin.setDate(fin.getDate() + 1);

    let consulta = supabase
      .from('preconsultas')
      .select(SELECT_COLA)
      .gte('creado_en', inicio.toISOString())
      .lt('creado_en', fin.toISOString());
    if (req.query.estado) consulta = consulta.eq('estado', req.query.estado);
    if (req.query.nivel) consulta = consulta.eq('triage_nivel', Number(req.query.nivel));

    const { data, error } = await consulta.limit(Number(req.query.limit) || 150);
    if (error) {
      console.error('[preconsulta] cola:', error.message);
      return sendError(res, dbErrorMessage(error) || 'Error al obtener la cola', 500);
    }

    const filas = (data || []).slice().sort((a, b) => {
      const pa = a.triage_nivel != null ? Number(a.triage_nivel) : 6;
      const pb = b.triage_nivel != null ? Number(b.triage_nivel) : 6;
      if (pa !== pb) return pa - pb;
      return String(b.creado_en).localeCompare(String(a.creado_en));
    });

    const porNivel = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
    let pendientes = 0;
    let completadas = 0;
    let sinRevisar = 0;
    let criticas = 0;
    for (const fila of filas) {
      if (fila.estado === 'pendiente' || fila.estado === 'analizando') pendientes += 1;
      if (fila.estado === 'completada' || fila.estado === 'revisada') completadas += 1;
      if (fila.requiere_revision === true && fila.triage_nivel != null) sinRevisar += 1;
      if (fila.triage_nivel != null) {
        const nivel = Number(fila.triage_nivel);
        porNivel[nivel] = (porNivel[nivel] || 0) + 1;
        if (nivel <= 2) criticas += 1;
      }
    }

    return sendSuccess(
      res,
      {
        fecha,
        preconsultas: filas.map(mapResumen),
        stats: {
          total: filas.length,
          pendientes,
          completadas,
          sin_revisar: sinRevisar,
          criticas,
          por_nivel: porNivel,
        },
        no_es_diagnostico: true,
      },
      'Cola de preconsultas'
    );
  } catch (error) {
    console.error('[preconsulta] cola:', error.message);
    return sendError(res, 'Error al obtener la cola', 500);
  }
};

/** GET /api/preconsulta/metricas */
const getMetricas = async (req, res) => {
  try {
    const supabase = getSupabase();
    const dias = Number(req.query.dias) || 30;
    const hasta = req.query.hasta ? new Date(`${req.query.hasta}T23:59:59.999`) : new Date();
    const desde = req.query.desde
      ? new Date(`${req.query.desde}T00:00:00`)
      : new Date(hasta.getTime() - (dias - 1) * 24 * 60 * 60 * 1000);
    if (Number.isNaN(desde.getTime()) || Number.isNaN(hasta.getTime()) || desde > hasta) {
      return sendError(res, 'Rango de fechas inválido', 422);
    }
    if ((hasta - desde) / (24 * 60 * 60 * 1000) > 366) {
      return sendError(res, 'El rango máximo es de 366 días', 422);
    }

    const { data, error } = await supabase
      .from('preconsultas')
      .select(
        'id, creado_en, analizado_en, estado, canal, triage_nivel, triage_confianza, ' +
          'triage_motivos, banderas, calidad_captura, requiere_revision, revisado_en, rostro_detectado'
      )
      .gte('creado_en', desde.toISOString())
      .lte('creado_en', hasta.toISOString())
      .limit(5000);
    if (error) {
      console.error('[preconsulta] metricas:', error.message);
      return sendError(res, dbErrorMessage(error) || 'Error al obtener métricas', 500);
    }

    const filas = data || [];
    const porNivel = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
    const porCanal = {};
    const motivos = new Map();
    const banderas = new Map();
    const serieMap = new Map();
    let completadas = 0;
    let revisadas = 0;
    let conBanderas = 0;
    let criticas = 0;
    let sumaNivel = 0;
    let cuentaNivel = 0;
    let sumaCalidad = 0;
    let cuentaCalidad = 0;
    let sumaConfianza = 0;
    let cuentaConfianza = 0;
    let sumaAnalisis = 0;
    let cuentaAnalisis = 0;

    for (let i = 0; i <= Math.floor((hasta - desde) / (24 * 60 * 60 * 1000)); i++) {
      const fecha = new Date(desde.getTime() + i * 24 * 60 * 60 * 1000);
      const clave = claveDia(fecha);
      if (clave) serieMap.set(clave, { fecha: clave, total: 0, completadas: 0, criticas: 0, revisadas: 0, suma_nivel: 0, cuenta_nivel: 0 });
    }

    for (const fila of filas) {
      if (fila.estado === 'completada' || fila.estado === 'revisada') completadas += 1;
      if (fila.revisado_en) revisadas += 1;
      const canal = fila.canal || 'web';
      porCanal[canal] = (porCanal[canal] || 0) + 1;
      if (fila.triage_nivel != null) {
        const nivel = Number(fila.triage_nivel);
        porNivel[nivel] = (porNivel[nivel] || 0) + 1;
        sumaNivel += nivel;
        cuentaNivel += 1;
        if (nivel <= 2) criticas += 1;
      }
      if (fila.calidad_captura != null) {
        sumaCalidad += Number(fila.calidad_captura);
        cuentaCalidad += 1;
      }
      if (fila.triage_confianza != null) {
        sumaConfianza += Number(fila.triage_confianza);
        cuentaConfianza += 1;
      }
      const listaBanderas = Array.isArray(fila.banderas) ? fila.banderas : [];
      if (listaBanderas.length > 0) conBanderas += 1;
      for (const b of listaBanderas) {
        const clave = b.codigo || b.texto || 'otra';
        const actual = banderas.get(clave) || { codigo: clave, texto: b.texto || clave, total: 0 };
        actual.total += 1;
        banderas.set(clave, actual);
      }
      for (const motivo of Array.isArray(fila.triage_motivos) ? fila.triage_motivos : []) {
        const clave = motivo.codigo || motivo.etiqueta;
        if (!clave) continue;
        const actual = motivos.get(clave) || { codigo: clave, etiqueta: motivo.etiqueta || clave, total: 0 };
        actual.total += 1;
        motivos.set(clave, actual);
      }
      if (fila.analizado_en && fila.creado_en) {
        const segundos = (new Date(fila.analizado_en) - new Date(fila.creado_en)) / 1000;
        if (Number.isFinite(segundos) && segundos >= 0 && segundos < 3600) {
          sumaAnalisis += segundos;
          cuentaAnalisis += 1;
        }
      }
      const clave = claveDia(fila.creado_en);
      if (clave && serieMap.has(clave)) {
        const dia = serieMap.get(clave);
        dia.total += 1;
        if (fila.estado === 'completada' || fila.estado === 'revisada') dia.completadas += 1;
        if (fila.revisado_en) dia.revisadas += 1;
        if (fila.triage_nivel != null) {
          const nivel = Number(fila.triage_nivel);
          if (nivel <= 2) dia.criticas += 1;
          dia.suma_nivel += nivel;
          dia.cuenta_nivel += 1;
        }
      }
    }

    const total = filas.length;
    const distribucion = NIVELES_TRIAGE.map((n) => ({
      nivel: n.nivel,
      etiqueta: n.etiqueta,
      color: n.color,
      total: porNivel[n.nivel] || 0,
      porcentaje: cuentaNivel > 0 ? Math.round((((porNivel[n.nivel] || 0) / cuentaNivel) * 100 + Number.EPSILON) * 10) / 10 : 0,
    }));

    const serie = Array.from(serieMap.values())
      .sort((a, b) => a.fecha.localeCompare(b.fecha))
      .map((d) => ({
        fecha: d.fecha,
        total: d.total,
        completadas: d.completadas,
        criticas: d.criticas,
        revisadas: d.revisadas,
        promedio_nivel: d.cuenta_nivel ? Math.round((d.suma_nivel / d.cuenta_nivel) * 10) / 10 : null,
      }));

    return sendSuccess(
      res,
      {
        rango: { desde: claveDia(desde), hasta: claveDia(hasta), dias: serie.length },
        total,
        completadas,
        pendientes: total - completadas,
        revisadas,
        tasa_revision: completadas > 0 ? Math.round((revisadas / completadas) * 1000) / 10 : 0,
        sin_revision: Math.max(0, completadas - revisadas),
        criticas,
        con_banderas: conBanderas,
        promedio_nivel: cuentaNivel ? Math.round((sumaNivel / cuentaNivel) * 100) / 100 : null,
        promedio_calidad: cuentaCalidad ? Math.round((sumaCalidad / cuentaCalidad) * 10) / 10 : null,
        promedio_confianza: cuentaConfianza ? Math.round((sumaConfianza / cuentaConfianza) * 1000) / 1000 : null,
        tiempo_promedio_analisis_seg: cuentaAnalisis ? Math.round((sumaAnalisis / cuentaAnalisis) * 10) / 10 : null,
        distribucion,
        por_canal: porCanal,
        top_motivos: Array.from(motivos.values()).sort((a, b) => b.total - a.total).slice(0, 8),
        top_banderas: Array.from(banderas.values()).sort((a, b) => b.total - a.total).slice(0, 8),
        serie_diaria: serie,
        no_es_diagnostico: true,
      },
      'Métricas de PreConsulta IA'
    );
  } catch (error) {
    console.error('[preconsulta] metricas:', error.message);
    return sendError(res, 'Error al obtener métricas', 500);
  }
};

/** GET /api/preconsulta/paciente/:pacienteId/tendencias */
const getTendenciasPaciente = async (req, res) => {
  try {
    const pacienteId = Number(req.params.pacienteId);
    if (!Number.isInteger(pacienteId) || pacienteId <= 0) {
      return sendError(res, 'Paciente inválido', 422);
    }
    if (!esStaff(req)) {
      const propio = await pacientePropio(req);
      if (propio == null || Number(propio) !== pacienteId) {
        return sendError(res, 'No tiene acceso a las tendencias de este paciente', 403);
      }
    }

    const { data, error } = await getSupabase()
      .from('preconsultas')
      .select(
        'id, creado_en, hr_bpm, hr_confianza, rmssd_ms, pain_score, stress_score, fatigue_score, ' +
          'triage_nivel, triage_resumen, calidad_captura, rostro_detectado'
      )
      .eq('paciente_id', pacienteId)
      .in('estado', ['completada', 'revisada'])
      .order('creado_en', { ascending: false })
      .limit(30);
    if (error) {
      console.error('[preconsulta] tendencias:', error.message);
      return sendError(res, dbErrorMessage(error) || 'Error al obtener tendencias', 500);
    }

    const puntos = (data || [])
      .slice()
      .reverse()
      .map((fila) => ({
        id: Number(fila.id),
        fecha: fila.creado_en,
        hr_bpm: numero(fila.hr_bpm, 1),
        hr_confianza: numero(fila.hr_confianza, 3),
        rmssd_ms: numero(fila.rmssd_ms, 1),
        pain_score: numero(fila.pain_score, 1),
        stress_score: numero(fila.stress_score, 1),
        fatigue_score: numero(fila.fatigue_score, 1),
        triage_nivel: fila.triage_nivel != null ? Number(fila.triage_nivel) : null,
        resumen: fila.triage_resumen || '',
        calidad_captura: numero(fila.calidad_captura, 1),
        rostro_detectado: fila.rostro_detectado === true,
      }));

    const promediar = (clave) => {
      const valores = puntos.map((p) => p[clave]).filter((v) => v != null && Number.isFinite(Number(v)));
      if (valores.length === 0) return null;
      return Math.round((valores.reduce((a, b) => a + Number(b), 0) / valores.length) * 10) / 10;
    };

    return sendSuccess(
      res,
      {
        paciente_id: pacienteId,
        puntos,
        resumen: {
          total: puntos.length,
          promedio_hr: promediar('hr_bpm'),
          promedio_rmssd: promediar('rmssd_ms'),
          promedio_dolor: promediar('pain_score'),
          promedio_estres: promediar('stress_score'),
          promedio_nivel: promediar('triage_nivel'),
        },
        no_es_diagnostico: true,
      },
      'Tendencias del paciente'
    );
  } catch (error) {
    console.error('[preconsulta] tendencias:', error.message);
    return sendError(res, 'Error al obtener tendencias', 500);
  }
};

/** PATCH /api/preconsulta/:id/revision */
const revisar = async (req, res) => {
  try {
    const supabase = getSupabase();
    const fila = await cargarPreconsulta(req.params.id);
    if (!fila) return sendError(res, 'Preconsulta no encontrada', 404);
    if (fila.estado === 'cancelada') {
      return sendError(res, 'La preconsulta está cancelada', 409);
    }
    if (fila.triage_nivel == null) {
      return sendError(res, 'La preconsulta aún no tiene un triage que revisar', 409);
    }

    const nivelNuevo = Number(req.body.nivel_revisado);
    const nivelAnterior = fila.triage_nivel != null ? Number(fila.triage_nivel) : null;
    const nota = req.body.nota || '';

    const { error: errorRevision } = await supabase.from('preconsulta_revisiones').insert({
      preconsulta_id: fila.id,
      usuario_id: req.user.id || null,
      nivel_anterior: nivelAnterior,
      nivel_nuevo: nivelNuevo,
      nota,
    });
    if (errorRevision) {
      console.error('[preconsulta] revisión:', errorRevision.message);
      return sendError(res, dbErrorMessage(errorRevision) || 'No se pudo registrar la revisión', 500);
    }

    const { error } = await supabase
      .from('preconsultas')
      .update({
        estado: 'revisada',
        revisado_por_usuario_id: req.user.id || null,
        revisado_en: new Date().toISOString(),
        nivel_revisado: nivelNuevo,
        nota_revision: nota,
        requiere_revision: false,
      })
      .eq('id', fila.id);
    if (error) {
      console.error('[preconsulta] revisión update:', error.message);
      return sendError(res, dbErrorMessage(error) || 'No se pudo guardar la revisión', 500);
    }

    await registrarEvento(
      fila.id,
      'revisada',
      { nivel_anterior: nivelAnterior, nivel_nuevo: nivelNuevo, nota },
      req.user.id
    );

    const detalle = await cargarPreconsulta(fila.id);
    if (!detalle) {
      return sendError(res, 'Revisión guardada, pero no se pudo cargar el detalle', 500);
    }
    return sendSuccess(res, mapDetalle(detalle), 'Triage revisado');
  } catch (error) {
    console.error('[preconsulta] revisar:', error.message);
    return sendError(res, 'Error al revisar el triage', 500);
  }
};

/** GET /api/preconsulta/:id/eventos */
const getEventos = async (req, res) => {
  try {
    const fila = await cargarPreconsulta(req.params.id);
    if (!fila) return sendError(res, 'Preconsulta no encontrada', 404);
    const autorizacion = await autorizarFila(req, fila);
    if (!autorizacion.ok) return sendError(res, autorizacion.message, autorizacion.status);
    if (!esStaff(req)) {
      return sendError(res, 'Acceso reservado al personal del consultorio', 403);
    }
    const { data, error } = await getSupabase()
      .from('preconsulta_eventos')
      .select('id, tipo, detalle, usuario_id, creado_en')
      .eq('preconsulta_id', fila.id)
      .order('creado_en', { ascending: false })
      .limit(100);
    if (error) {
      console.error('[preconsulta] eventos:', error.message);
      return sendError(res, dbErrorMessage(error) || 'Error al obtener la auditoría', 500);
    }
    return sendSuccess(res, { eventos: data || [] }, 'Auditoría de la preconsulta');
  } catch (error) {
    console.error('[preconsulta] eventos:', error.message);
    return sendError(res, 'Error al obtener la auditoría', 500);
  }
};

module.exports = {
  getConsentimiento,
  crear,
  analizar,
  guardarRespuestas,
  finalizarSinCaptura,
  getById,
  getByCita,
  getCola,
  getMetricas,
  getTendenciasPaciente,
  revisar,
  getEventos,
};
