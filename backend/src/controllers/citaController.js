const { getSupabase } = require('../config/supabase');
const {
  sendSuccess,
  sendError,
  formatDate,
  obtenerDiaSemana,
  horaAMinutos,
} = require('../utils/helpers');
const { ESTADOS_CITA } = require('../utils/constants');

// Columnas embebidas (relaciones) para enriquecer las citas con datos legibles
// de paciente y médico en todas las consultas de la API.
const SELECT_CITA_RELACIONES =
  '*, pacientes(id, nombre, apellido, telefono, email), medicos(id, nombre, apellido, especialidad, activo)';

/**
 * Lee el id de params soportando los aliases de ruta:
 * :id, :medicoId, :pacienteId
 */
const idDeParams = (req) => req.params.id || req.params.medicoId || req.params.pacienteId;

/**
 * Valida el query param opcional ?estado= contra los estados permitidos.
 * Retorna false y envía la respuesta de error si es inválido.
 */
const validarEstadoQuery = (req, res) => {
  const { estado } = req.query;
  const permitidos = Object.values(ESTADOS_CITA);
  if (estado !== undefined && !permitidos.includes(estado)) {
    sendError(res, `Estado inválido. Valores permitidos: ${permitidos.join(', ')}`, 400);
    return false;
  }
  return true;
};

/**
 * Verifica contra la BD que el médico atienda en la fecha/hora indicada
 * según sus horarios registrados.
 */
const medicoAtiendeEnSlot = async (supabase, medicoId, fecha, hora) => {
  const diaSemana = obtenerDiaSemana(fecha);
  const mins = horaAMinutos(hora);

  const { data: horarios, error } = await supabase
    .from('horarios')
    .select('dia_semana, hora_inicio, hora_fin')
    .eq('medico_id', medicoId)
    .eq('activo', true)
    .eq('dia_semana', diaSemana);

  if (error || !horarios || horarios.length === 0) return false;

  return horarios.some(
    (h) => mins >= horaAMinutos(h.hora_inicio) && mins < horaAMinutos(h.hora_fin)
  );
};

/**
 * Verifica que la fecha no sea pasada
 */
const esFechaValida = (fecha) => fecha >= formatDate(new Date());

/**
 * Valida que un médico atienda en el tramo solicitado y que no haya otra cita
 * no cancelada en el mismo médico/fecha/hora (evita doble agenda).
 * Devuelve { ok: true } o { ok: false, error }.
 */
const verificarDisponibilidad = async (supabase, medicoId, fecha, hora, citaIdExcluir = null) => {
  const atiende = await medicoAtiendeEnSlot(supabase, medicoId, fecha, hora);
  if (!atiende) {
    return { ok: false, error: 'El médico no atiende en esa fecha u hora según su horario' };
  }

  let query = supabase
    .from('citas')
    .select('id')
    .eq('medico_id', medicoId)
    .eq('fecha', fecha)
    .eq('hora', hora)
    .neq('estado', ESTADOS_CITA.CANCELADA);
  if (citaIdExcluir) query = query.neq('id', citaIdExcluir);
  query = query.limit(1);

  const { data: ocupadas } = await query;
  if (ocupadas && ocupadas.length > 0) {
    return { ok: false, error: 'El médico ya tiene una cita programada en esa fecha y hora' };
  }

  return { ok: true };
};

/**
 * GET /api/citas
 * Listar todas las citas (admin/recepción)
 * Filtros opcionales: ?estado=, ?medico_id=, ?paciente_id=
 */
const getAll = async (req, res) => {
  try {
    if (!validarEstadoQuery(req, res)) return;

    const { estado, medico_id, paciente_id } = req.query;
    const supabase = getSupabase();

    let query = supabase
      .from('citas')
      .select(SELECT_CITA_RELACIONES)
      .order('fecha', { ascending: true })
      .order('hora', { ascending: true });

    if (estado) query = query.eq('estado', estado);
    if (medico_id) query = query.eq('medico_id', medico_id);
    if (paciente_id) query = query.eq('paciente_id', paciente_id);

    const { data, error } = await query;
    if (error) throw error;

    return sendSuccess(res, {
      total: (data || []).length,
      citas: data || [],
    });
  } catch (error) {
    console.error('citas.getAll:', error);
    return sendError(res, 'Error al listar citas', 500);
  }
};

/**
 * GET /api/citas/agenda/hoy
 * Citas del día actual para la agenda de recepción/médico.
 * Filtros opcionales: ?estado=, ?medico_id=
 */
const getHoy = async (req, res) => {
  try {
    if (!validarEstadoQuery(req, res)) return;

    const { estado, medico_id } = req.query;
    const hoy = formatDate(new Date());
    const supabase = getSupabase();

    let query = supabase
      .from('citas')
      .select(SELECT_CITA_RELACIONES)
      .eq('fecha', hoy)
      .order('hora', { ascending: true });

    if (estado) query = query.eq('estado', estado);
    if (medico_id) query = query.eq('medico_id', medico_id);

    const { data, error } = await query;
    if (error) throw error;

    const citas = data || [];
    const conteoPorEstado = citas.reduce((acc, c) => {
      acc[c.estado] = (acc[c.estado] || 0) + 1;
      return acc;
    }, {});

    return sendSuccess(res, {
      fecha: hoy,
      dia_semana: obtenerDiaSemana(hoy),
      total_pendientes: citas.filter((c) => c.estado === ESTADOS_CITA.PROGRAMADA).length,
      conteo_por_estado: conteoPorEstado,
      citas,
    });
  } catch (error) {
    console.error('citas.getHoy:', error);
    return sendError(res, 'Error al obtener citas del día', 500);
  }
};

/**
 * GET /api/citas/medico/:medicoId  (alias: /medico/:id)
 * Citas por médico, con datos del médico y de los pacientes.
 * Filtros opcionales: ?estado=
 */
const getByMedico = async (req, res) => {
  try {
    if (!validarEstadoQuery(req, res)) return;

    const medicoId = idDeParams(req);
    const { estado } = req.query;
    const supabase = getSupabase();

    const { data: medicos } = await supabase
      .from('medicos')
      .select('id, nombre, apellido, especialidad, consulorio, telefono, email, activo')
      .eq('id', medicoId)
      .limit(1);
    const medico = medicos && medicos[0];

    if (!medico) {
      return sendError(res, 'Médico no encontrado', 404);
    }

    let query = supabase
      .from('citas')
      .select(SELECT_CITA_RELACIONES)
      .eq('medico_id', medicoId)
      .order('fecha', { ascending: true })
      .order('hora', { ascending: true });

    if (estado) query = query.eq('estado', estado);

    const { data, error } = await query;
    if (error) throw error;

    return sendSuccess(res, {
      medico_id: medico.id,
      medico: `${medico.nombre} ${medico.apellido}`,
      total: (data || []).length,
      citas: data || [],
    });
  } catch (error) {
    console.error('citas.getByMedico:', error);
    return sendError(res, 'Error al obtener citas del médico', 500);
  }
};

/**
 * GET /api/citas/paciente/:pacienteId  (alias: /paciente/:id)
 * Citas por paciente, con datos del paciente y del médico.
 * Filtros opcionales: ?estado=
 */
const getByPaciente = async (req, res) => {
  try {
    if (!validarEstadoQuery(req, res)) return;

    const pacienteId = idDeParams(req);
    const { estado } = req.query;
    const supabase = getSupabase();

    const { data: pacientes } = await supabase
      .from('pacientes')
      .select('id, nombre, apellido, cedula, telefono, email')
      .eq('id', pacienteId)
      .limit(1);
    const paciente = pacientes && pacientes[0];

    if (!paciente) {
      return sendError(res, 'Paciente no encontrado', 404);
    }

    let query = supabase
      .from('citas')
      .select(SELECT_CITA_RELACIONES)
      .eq('paciente_id', pacienteId)
      .order('fecha', { ascending: true })
      .order('hora', { ascending: true });

    if (estado) query = query.eq('estado', estado);

    const { data, error } = await query;
    if (error) throw error;

    return sendSuccess(res, {
      paciente_id: paciente.id,
      paciente: `${paciente.nombre} ${paciente.apellido}`,
      total: (data || []).length,
      citas: data || [],
    });
  } catch (error) {
    console.error('citas.getByPaciente:', error);
    return sendError(res, 'Error al obtener citas del paciente', 500);
  }
};

/**
 * GET /api/citas/:id
 * Obtener cita por ID (con relaciones de paciente y médico)
 */
const getById = async (req, res) => {
  try {
    const supabase = getSupabase();
    const { data, error } = await supabase
      .from('citas')
      .select(SELECT_CITA_RELACIONES)
      .eq('id', req.params.id)
      .limit(1);

    if (error) throw error;
    if (!data || data.length === 0) {
      return sendError(res, 'Cita no encontrada', 404);
    }
    return sendSuccess(res, data[0]);
  } catch (error) {
    console.error('citas.getById:', error);
    return sendError(res, 'Error al obtener cita', 500);
  }
};

/**
 * POST /api/citas
 * Crear nueva cita (paciente/admin/recepción)
 */
const create = async (req, res) => {
  try {
    const { paciente_id, medico_id, fecha, hora, motivo, observaciones } = req.body;
    const supabase = getSupabase();

    // Un paciente autenticado solo puede crear citas para sí mismo.
    let pacienteId = paciente_id;
    if (req.user && req.user.rol === 'paciente') {
      if (req.user.perfilTipo !== 'paciente' || !req.user.perfilId) {
        return sendError(res, 'Perfil de paciente no encontrado. Contacte a recepción', 403);
      }
      pacienteId = req.user.perfilId;
    }

    // Verificar que el paciente exista
    const { data: pacientes } = await supabase
      .from('pacientes')
      .select('id')
      .eq('id', pacienteId)
      .limit(1);
    if (!pacientes || pacientes.length === 0) {
      return sendError(res, 'Paciente no encontrado', 404);
    }

    // Verificar que el médico exista y esté activo
    const { data: medicos } = await supabase
      .from('medicos')
      .select('id, activo')
      .eq('id', medico_id)
      .limit(1);
    if (!medicos || medicos.length === 0) {
      return sendError(res, 'Médico no encontrado', 404);
    }
    if (!medicos[0].activo) {
      return sendError(res, 'El médico seleccionado no está activo', 400);
    }

    // Validar que la fecha no sea pasada
    if (!esFechaValida(fecha)) {
      return sendError(res, 'No se pueden crear citas en fechas pasadas', 400);
    }

    // Validar horario del médico y que el tramo esté libre
    const tramo = await verificarDisponibilidad(supabase, medico_id, fecha, hora);
    if (!tramo.ok) {
      return sendError(res, tramo.error, 400);
    }

    const { data, error } = await supabase
      .from('citas')
      .insert({
        paciente_id: pacienteId,
        medico_id,
        fecha,
        hora,
        motivo,
        estado: ESTADOS_CITA.PROGRAMADA,
        observaciones: observaciones || '',
      })
      .select(SELECT_CITA_RELACIONES)
      .single();

    if (error) {
      if (error.code === '23505') {
        return sendError(res, 'El médico ya tiene una cita programada en esa fecha y hora', 400);
      }
      throw error;
    }
    return sendSuccess(res, data, 'Cita creada exitosamente', 201);
  } catch (error) {
    console.error('citas.create:', error);
    return sendError(res, 'Error al crear cita', 500);
  }
};

/**
 * PUT /api/citas/:id
 * Reprogramar cita (cambiar fecha/hora). Valida disponibilidad y horario.
 * Al reprogramar, la cita vuelve a "programada" para requerir confirmación.
 */
const update = async (req, res) => {
  try {
    const supabase = getSupabase();

    const { data: actuales } = await supabase
      .from('citas')
      .select('*')
      .eq('id', req.params.id)
      .limit(1);
    if (!actuales || actuales.length === 0) {
      return sendError(res, 'Cita no encontrada', 404);
    }
    const cita = actuales[0];

    // Un paciente solo puede reprogramar sus propias citas
    if (
      req.user &&
      req.user.rol === 'paciente' &&
      cita.paciente_id !== req.user.perfilId
    ) {
      return sendError(res, 'No tiene permiso para modificar esta cita', 403);
    }

    const estadosBloqueados = [
      ESTADOS_CITA.COMPLETADA,
      ESTADOS_CITA.CANCELADA,
      ESTADOS_CITA.NO_SHOW,
      ESTADOS_CITA.EN_CURSO,
    ];
    if (estadosBloqueados.includes(cita.estado)) {
      return sendError(res, 'No se puede reprogramar una cita en curso, completada, cancelada o sin asistir', 400);
    }

    const { fecha, hora, motivo, observaciones } = req.body;
    const nuevaFecha = fecha || cita.fecha;
    const nuevaHora = hora || cita.hora;

    const cambiaTramo = Boolean(fecha || hora);

    // Verificar disponibilidad si cambia fecha/hora
    if (cambiaTramo) {
      // Validar que la nueva fecha no sea pasada
      if (!esFechaValida(nuevaFecha)) {
        return sendError(res, 'No se puede reprogramar a una fecha pasada', 400);
      }

      const tramo = await verificarDisponibilidad(
        supabase,
        cita.medico_id,
        nuevaFecha,
        nuevaHora,
        cita.id
      );
      if (!tramo.ok) {
        return sendError(res, tramo.error, 400);
      }
    }

    const cambios = {};
    if (fecha) cambios.fecha = fecha;
    if (hora) cambios.hora = hora;
    if (motivo !== undefined) cambios.motivo = motivo || '';
    if (observaciones !== undefined) cambios.observaciones = observaciones || '';
    // Un cambio de fecha/hora invalida la confirmación previa
    if (cambiaTramo && cita.estado === ESTADOS_CITA.CONFIRMADA) {
      cambios.estado = ESTADOS_CITA.PROGRAMADA;
    }

    const { data, error } = await supabase
      .from('citas')
      .update(cambios)
      .eq('id', cita.id)
      .select(SELECT_CITA_RELACIONES)
      .single();

    if (error) {
      if (error.code === '23505') {
        return sendError(res, 'El médico ya tiene una cita programada en esa fecha y hora', 400);
      }
      throw error;
    }
    return sendSuccess(res, data, 'Cita reprogramada exitosamente');
  } catch (error) {
    console.error('citas.update:', error);
    return sendError(res, 'Error al actualizar cita', 500);
  }
};

/**
 * POST /api/citas/:id/confirmar
 * Confirmar cita: pasa el estado a "confirmada".
 * Solo se puede confirmar una cita programada (o en curso como reafirmación).
 */
const confirmar = async (req, res) => {
  try {
    const supabase = getSupabase();

    const { data: actuales } = await supabase
      .from('citas')
      .select('*')
      .eq('id', req.params.id)
      .limit(1);
    if (!actuales || actuales.length === 0) {
      return sendError(res, 'Cita no encontrada', 404);
    }
    const cita = actuales[0];

    if (cita.estado === ESTADOS_CITA.CONFIRMADA) {
      return sendError(res, 'La cita ya está confirmada', 400);
    }

    const estadosFinales = [
      ESTADOS_CITA.COMPLETADA,
      ESTADOS_CITA.CANCELADA,
      ESTADOS_CITA.NO_SHOW,
    ];
    if (estadosFinales.includes(cita.estado)) {
      return sendError(res, 'No se puede confirmar una cita completada, cancelada o sin asistir', 400);
    }

    const { data, error } = await supabase
      .from('citas')
      .update({ estado: ESTADOS_CITA.CONFIRMADA })
      .eq('id', cita.id)
      .select(SELECT_CITA_RELACIONES)
      .single();

    if (error) throw error;
    return sendSuccess(res, data, 'Cita confirmada exitosamente');
  } catch (error) {
    console.error('citas.confirmar:', error);
    return sendError(res, 'Error al confirmar cita', 500);
  }
};

/**
 * PATCH /api/citas/:id/estado
 * Cambiar estado de la cita (con máquina de transiciones)
 */
const TRANSICIONES_ESTADO = {
  programada: ['confirmada', 'en_curso', 'completada', 'cancelada', 'no_show'],
  confirmada: ['en_curso', 'completada', 'cancelada', 'no_show'],
  en_curso: ['completada', 'cancelada'],
  completada: [],
  cancelada: ['programada'],
  no_show: ['programada'],
};

const updateEstado = async (req, res) => {
  try {
    const { estado } = req.body;
    const estadosPermitidos = Object.values(ESTADOS_CITA);
    if (!estadosPermitidos.includes(estado)) {
      return sendError(res, `Estado inválido. Valores permitidos: ${estadosPermitidos.join(', ')}`, 400);
    }

    const supabase = getSupabase();
    const { data: actuales } = await supabase
      .from('citas')
      .select('estado')
      .eq('id', req.params.id)
      .limit(1);

    if (!actuales || actuales.length === 0) {
      return sendError(res, 'Cita no encontrada', 404);
    }

    const estadoActual = actuales[0].estado;
    if (estadoActual === estado) {
      return sendError(res, 'La cita ya tiene ese estado', 400);
    }

    const transicionesValidas = TRANSICIONES_ESTADO[estadoActual] || [];
    if (!transicionesValidas.includes(estado)) {
      return sendError(
        res,
        `No se puede cambiar de "${estadoActual}" a "${estado}". Transiciones permitidas: ${transicionesValidas.join(', ') || 'ninguna'}`,
        400
      );
    }

    const { data, error } = await supabase
      .from('citas')
      .update({ estado })
      .eq('id', req.params.id)
      .select(SELECT_CITA_RELACIONES);

    if (error) throw error;
    return sendSuccess(res, data[0], 'Estado de cita actualizado');
  } catch (error) {
    console.error('citas.updateEstado:', error);
    return sendError(res, 'Error al actualizar estado', 500);
  }
};

/**
 * DELETE /api/citas/:id
 * Cancelar cita
 */
const remove = async (req, res) => {
  try {
    const supabase = getSupabase();
    const { data: actuales } = await supabase
      .from('citas')
      .select('estado')
      .eq('id', req.params.id)
      .limit(1);

    if (!actuales || actuales.length === 0) {
      return sendError(res, 'Cita no encontrada', 404);
    }
    if (actuales[0].estado === ESTADOS_CITA.CANCELADA) {
      return sendError(res, 'La cita ya está cancelada', 400);
    }
    if (actuales[0].estado === ESTADOS_CITA.COMPLETADA) {
      return sendError(res, 'No se puede cancelar una cita completada', 400);
    }

    const { data, error } = await supabase
      .from('citas')
      .update({ estado: ESTADOS_CITA.CANCELADA })
      .eq('id', req.params.id)
      .select(SELECT_CITA_RELACIONES)
      .single();

    if (error) throw error;
    return sendSuccess(res, data, 'Cita cancelada exitosamente');
  } catch (error) {
    console.error('citas.remove:', error);
    return sendError(res, 'Error al cancelar cita', 500);
  }
};

/**
 * GET /api/citas/mis-citas
 * Obtener citas del paciente autenticado
 */
const getMisCitas = async (req, res) => {
  try {
    const supabase = getSupabase();

    // El ID de paciente está en el perfil del token, no en req.user.id
    // (req.user.id corresponde a usuarios.id).
    const pacienteId =
      req.user.perfilTipo === 'paciente' ? req.user.perfilId : null;

    if (!pacienteId) {
      return sendError(res, 'Solo el paciente puede consultar sus citas', 403);
    }

    const { data, error } = await supabase
      .from('citas')
      .select(SELECT_CITA_RELACIONES)
      .eq('paciente_id', pacienteId)
      .order('fecha', { ascending: true })
      .order('hora', { ascending: true });

    if (error) throw error;
    return sendSuccess(res, {
      total: (data || []).length,
      citas: data || [],
    });
  } catch (error) {
    console.error('citas.getMisCitas:', error);
    return sendError(res, 'Error al obtener tus citas', 500);
  }
};

module.exports = {
  getAll,
  getById,
  create,
  update,
  updateEstado,
  remove,
  getHoy,
  getByMedico,
  getByPaciente,
  getMisCitas,
  confirmar,
};