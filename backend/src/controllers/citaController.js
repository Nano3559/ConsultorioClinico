const { getSupabase } = require('../config/supabase');
const { sendSuccess, sendError, formatDate } = require('../utils/helpers');
const { ESTADOS_CITA } = require('../utils/constants');

/**
 * GET /api/citas
 * Listar todas las citas
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
 * Crear nueva cita
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

    if (cita.estado === 'completada' || cita.estado === 'cancelada') {
      return sendError(res, 'No se puede reprogramar una cita completada o cancelada', 400);
    }

    const { fecha, hora, motivo, observaciones } = req.body;
    const nuevaFecha = fecha || cita.fecha;
    const nuevaHora = hora || cita.hora;

    // Verificar disponibilidad si cambia fecha/hora
    if (fecha || hora) {
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
    if (motivo) cambios.motivo = motivo;
    if (observaciones !== undefined) cambios.observaciones = observaciones;

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
const updateEstado = async (req, res) => {
  try {
    const { estado } = req.body;
    const estadosPermitidos = Object.values(ESTADOS_CITA);
    if (!estadosPermitidos.includes(estado)) {
      return sendError(res, `Estado inválido. Valores permitidos: ${estadosPermitidos.join(', ')}`, 400);
    }

    const supabase = getSupabase();
    const { data, error } = await supabase
      .from('citas')
      .update({ estado })
      .eq('id', req.params.id)
      .select('*');

    if (error) throw error;
    if (!data || data.length === 0) {
      return sendError(res, 'Cita no encontrada', 404);
    }
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
    if (actuales[0].estado === 'cancelada') {
      return sendError(res, 'La cita ya está cancelada', 400);
    }

    const { error } = await supabase
      .from('citas')
      .update({ estado: 'cancelada' })
      .eq('id', req.params.id);

    if (error) throw error;
    return sendSuccess(res, null, 'Cita cancelada exitosamente');
  } catch (error) {
    console.error('citas.remove:', error);
    return sendError(res, 'Error al cancelar cita', 500);
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
};
