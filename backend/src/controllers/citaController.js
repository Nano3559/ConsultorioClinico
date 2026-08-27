const { getSupabase } = require('../config/supabase');
const {
  sendSuccess,
  sendError,
  formatDate,
  obtenerDiaSemana,
  horaAMinutos,
} = require('../utils/helpers');
const { ESTADOS_CITA } = require('../utils/constants');

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
 * GET /api/citas
 * Listar todas las citas (admin/recepción)
 */
const getAll = async (req, res) => {
  try {
    const supabase = getSupabase();
    const { data, error } = await supabase
      .from('citas')
      .select('*')
      .order('fecha')
      .order('hora');

    if (error) throw error;
    return sendSuccess(res, data);
  } catch (error) {
    console.error('citas.getAll:', error);
    return sendError(res, 'Error al listar citas', 500);
  }
};

/**
 * GET /api/citas/agenda/hoy
 * Obtener citas del día actual
 */
const getHoy = async (req, res) => {
  try {
    const hoy = formatDate(new Date());
    const supabase = getSupabase();
    const { data, error } = await supabase
      .from('citas')
      .select('*')
      .eq('fecha', hoy)
      .order('hora');

    if (error) throw error;
    return sendSuccess(res, data);
  } catch (error) {
    console.error('citas.getHoy:', error);
    return sendError(res, 'Error al obtener citas del día', 500);
  }
};

/**
 * GET /api/citas/medico/:id
 * Obtener citas por médico
 */
const getByMedico = async (req, res) => {
  try {
    const supabase = getSupabase();

    const { data: medicos } = await supabase
      .from('medicos')
      .select('id')
      .eq('id', req.params.id)
      .limit(1);
    if (!medicos || medicos.length === 0) {
      return sendError(res, 'Médico no encontrado', 404);
    }

    const { data, error } = await supabase
      .from('citas')
      .select('*')
      .eq('medico_id', req.params.id)
      .order('fecha')
      .order('hora');

    if (error) throw error;
    return sendSuccess(res, data);
  } catch (error) {
    console.error('citas.getByMedico:', error);
    return sendError(res, 'Error al obtener citas del médico', 500);
  }
};

/**
 * GET /api/citas/paciente/:id
 * Obtener citas por paciente
 */
const getByPaciente = async (req, res) => {
  try {
    const supabase = getSupabase();

    const { data: pacientes } = await supabase
      .from('pacientes')
      .select('id')
      .eq('id', req.params.id)
      .limit(1);
    if (!pacientes || pacientes.length === 0) {
      return sendError(res, 'Paciente no encontrado', 404);
    }

    const { data, error } = await supabase
      .from('citas')
      .select('*')
      .eq('paciente_id', req.params.id)
      .order('fecha')
      .order('hora');

    if (error) throw error;
    return sendSuccess(res, data);
  } catch (error) {
    console.error('citas.getByPaciente:', error);
    return sendError(res, 'Error al obtener citas del paciente', 500);
  }
};

/**
 * GET /api/citas/:id
 * Obtener cita por ID
 */
const getById = async (req, res) => {
  try {
    const supabase = getSupabase();
    const { data, error } = await supabase
      .from('citas')
      .select('*')
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

    // Verificar que el paciente exista
    const { data: pacientes } = await supabase
      .from('pacientes')
      .select('id')
      .eq('id', paciente_id)
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

    // Validar que el médico atienda en ese día y hora según su horario
    const atiende = await medicoAtiendeEnSlot(supabase, medico_id, fecha, hora);
    if (!atiende) {
      return sendError(res, 'El médico no atiende en esa fecha u hora según su horario', 400);
    }

    // Verificar disponibilidad (no doble agenda). La BD también lo garantiza
    // con un índice único parcial sobre citas no canceladas.
    const { data: ocupadas } = await supabase
      .from('citas')
      .select('id')
      .eq('medico_id', medico_id)
      .eq('fecha', fecha)
      .eq('hora', hora)
      .neq('estado', 'cancelada')
      .limit(1);
    if (ocupadas && ocupadas.length > 0) {
      return sendError(res, 'El médico ya tiene una cita programada en esa fecha y hora', 400);
    }

    const { data, error } = await supabase
      .from('citas')
      .insert({
        paciente_id,
        medico_id,
        fecha,
        hora,
        motivo,
        estado: ESTADOS_CITA.PROGRAMADA,
        observaciones: observaciones || '',
      })
      .select('*')
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
 * Reprogramar cita (cambiar fecha/hora)
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

    if (cita.estado === ESTADOS_CITA.COMPLETADA || cita.estado === ESTADOS_CITA.CANCELADA) {
      return sendError(res, 'No se puede reprogramar una cita completada o cancelada', 400);
    }

    const { fecha, hora, motivo, observaciones } = req.body;
    const nuevaFecha = fecha || cita.fecha;
    const nuevaHora = hora || cita.hora;

    // Verificar disponibilidad si cambia fecha/hora
    if (fecha || hora) {
      // Validar que la nueva fecha no sea pasada
      if (!esFechaValida(nuevaFecha)) {
        return sendError(res, 'No se puede reprogramar a una fecha pasada', 400);
      }

      // Validar que el médico atienda en el nuevo día y hora
      const atiende = await medicoAtiendeEnSlot(supabase, cita.medico_id, nuevaFecha, nuevaHora);
      if (!atiende) {
        return sendError(res, 'El médico no atiende en esa fecha u hora según su horario', 400);
      }

      const { data: ocupadas } = await supabase
        .from('citas')
        .select('id')
        .eq('medico_id', cita.medico_id)
        .eq('fecha', nuevaFecha)
        .eq('hora', nuevaHora)
        .neq('id', cita.id)
        .neq('estado', 'cancelada')
        .limit(1);
      if (ocupadas && ocupadas.length > 0) {
        return sendError(res, 'El médico ya tiene una cita programada en esa fecha y hora', 400);
      }
    }

    const cambios = {};
    if (fecha) cambios.fecha = fecha;
    if (hora) cambios.hora = hora;
    if (motivo !== undefined) cambios.motivo = motivo || '';
    if (observaciones !== undefined) cambios.observaciones = observaciones || '';

    const { data, error } = await supabase
      .from('citas')
      .update(cambios)
      .eq('id', cita.id)
      .select('*')
      .single();

    if (error) throw error;
    return sendSuccess(res, data, 'Cita reprogramada exitosamente');
  } catch (error) {
    console.error('citas.update:', error);
    return sendError(res, 'Error al actualizar cita', 500);
  }
};

/**
 * PATCH /api/citas/:id/estado
 * Cambiar estado de la cita
 */
const TRANSICIONES_ESTADO = {
  programada: ['en_curso', 'cancelada', 'no_show'],
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
      .select('*');

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

    const { error } = await supabase
      .from('citas')
      .update({ estado: ESTADOS_CITA.CANCELADA })
      .eq('id', req.params.id);

    if (error) throw error;
    return sendSuccess(res, null, 'Cita cancelada exitosamente');
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
    const { data, error } = await supabase
      .from('citas')
      .select('*')
      .eq('paciente_id', req.user.id)
      .order('fecha')
      .order('hora');

    if (error) throw error;
    return sendSuccess(res, data);
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
};
