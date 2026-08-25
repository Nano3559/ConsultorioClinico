const { getSupabase } = require('../config/supabase');
const { sendSuccess, sendError, horaAMinutos } = require('../utils/helpers');

/**
 * Verifica si un horario se solapa con otro del mismo médico y día.
 * Consulta los horarios actuales del médico en la BD.
 */
async function existeSolapamiento(supabase, medicoId, diaSemana, horaInicio, horaFin, idExcluido = null) {
  let query = supabase
    .from('horarios')
    .select('id, hora_inicio, hora_fin')
    .eq('medico_id', medicoId)
    .eq('dia_semana', diaSemana);

  if (idExcluido) query = query.neq('id', idExcluido);

  const { data: existentes, error } = await query;
  if (error) throw error;

  return (existentes || []).some(
    (h) =>
      horaAMinutos(horaInicio) < horaAMinutos(h.hora_fin) &&
      horaAMinutos(horaFin) > horaAMinutos(h.hora_inicio)
  );
}

/**
 * GET /api/horarios
 * Listar todos los horarios (público)
 */
const getAll = async (req, res) => {
  try {
    const supabase = getSupabase();
    const { data, error } = await supabase.from('horarios').select('*').order('id');

    if (error) throw error;
    return sendSuccess(res, data || []);
  } catch (error) {
    console.error('horarios.getAll:', error);
    return sendError(res, 'Error al listar horarios', 500);
  }
};

/**
 * GET /api/horarios/medico/:medicoId
 * Horarios por médico (público)
 */
const getByMedico = async (req, res) => {
  try {
    const supabase = getSupabase();

    const { data: medicos } = await supabase
      .from('medicos')
      .select('id')
      .eq('id', req.params.medicoId)
      .limit(1);
    if (!medicos || medicos.length === 0) {
      return sendError(res, 'Médico no encontrado', 404);
    }

    const { data, error } = await supabase
      .from('horarios')
      .select('*')
      .eq('medico_id', req.params.medicoId)
      .order('id');

    if (error) throw error;
    return sendSuccess(res, data || []);
  } catch (error) {
    console.error('horarios.getByMedico:', error);
    return sendError(res, 'Error al obtener horarios del médico', 500);
  }
};

/**
 * GET /api/horarios/disponibles
 * Horarios disponibles (activos y de médicos activos) - público
 */
const getDisponibles = async (req, res) => {
  try {
    const supabase = getSupabase();

    const { data: idsActivos, error: medError } = await supabase
      .from('medicos')
      .select('id')
      .eq('activo', true);
    if (medError) throw medError;

    const idsMedicosActivos = (idsActivos || []).map((m) => m.id);
    if (idsMedicosActivos.length === 0) return sendSuccess(res, []);

    const { data, error } = await supabase
      .from('horarios')
      .select('*')
      .eq('activo', true)
      .in('medico_id', idsMedicosActivos)
      .order('id');

    if (error) throw error;
    return sendSuccess(res, data || []);
  } catch (error) {
    console.error('horarios.getDisponibles:', error);
    return sendError(res, 'Error al obtener horarios disponibles', 500);
  }
};

/**
 * POST /api/horarios
 * Crear horario (admin)
 */
const create = async (req, res) => {
  try {
    const { medico_id, dia_semana, hora_inicio, hora_fin } = req.body;
    const supabase = getSupabase();

    // Verificar que el médico exista
    const { data: medicos } = await supabase
      .from('medicos')
      .select('id')
      .eq('id', medico_id)
      .limit(1);
    if (!medicos || medicos.length === 0) {
      return sendError(res, 'Médico no encontrado', 404);
    }

    // Validar coherencia de horas
    if (horaAMinutos(hora_inicio) >= horaAMinutos(hora_fin)) {
      return sendError(res, 'La hora de inicio debe ser menor a la hora de fin', 400);
    }

    // Validar que no se solape con otro horario del mismo médico y día
    const solapa = await existeSolapamiento(supabase, medico_id, dia_semana, hora_inicio, hora_fin);
    if (solapa) {
      return sendError(res, 'El médico ya tiene un horario que se solapa en ese día', 409);
    }

    const { data, error } = await supabase
      .from('horarios')
      .insert({ medico_id, dia_semana, hora_inicio, hora_fin, activo: true })
      .select('*')
      .single();

    if (error) throw error;
    return sendSuccess(res, data, 'Horario creado exitosamente', 201);
  } catch (error) {
    console.error('horarios.create:', error);
    return sendError(res, 'Error al crear horario', 500);
  }
};

/**
 * PUT /api/horarios/:id
 * Actualizar horario (admin)
 */
const update = async (req, res) => {
  try {
    const supabase = getSupabase();

    const { data: actuales } = await supabase
      .from('horarios')
      .select('*')
      .eq('id', req.params.id)
      .limit(1);
    if (!actuales || actuales.length === 0) {
      return sendError(res, 'Horario no encontrado', 404);
    }
    const horario = actuales[0];

    const { medico_id, dia_semana, hora_inicio, hora_fin } = req.body;

    // Verificar que el médico (nuevo o actual) exista
    if (medico_id) {
      const { data: medicos } = await supabase
        .from('medicos')
        .select('id')
        .eq('id', medico_id)
        .limit(1);
      if (!medicos || medicos.length === 0) {
        return sendError(res, 'Médico no encontrado', 404);
      }
    }

    const datosFinales = {
      medico_id: medico_id ? parseInt(medico_id) : horario.medico_id,
      dia_semana: dia_semana || horario.dia_semana,
      hora_inicio: hora_inicio || horario.hora_inicio,
      hora_fin: hora_fin || horario.hora_fin,
    };

    // Validar coherencia de horas
    if (horaAMinutos(datosFinales.hora_inicio) >= horaAMinutos(datosFinales.hora_fin)) {
      return sendError(res, 'La hora de inicio debe ser menor a la hora de fin', 400);
    }

    // Validar solapamiento excluyendo el horario actual
    const solapa = await existeSolapamiento(
      supabase,
      datosFinales.medico_id,
      datosFinales.dia_semana,
      datosFinales.hora_inicio,
      datosFinales.hora_fin,
      horario.id
    );
    if (solapa) {
      return sendError(res, 'El médico ya tiene un horario que se solapa en ese día', 409);
    }

    const cambios = {};
    for (const campo of ['medico_id', 'dia_semana', 'hora_inicio', 'hora_fin']) {
      cambios[campo] = datosFinales[campo];
    }
    if (typeof req.body.activo === 'boolean') cambios.activo = req.body.activo;

    const { data, error } = await supabase
      .from('horarios')
      .update(cambios)
      .eq('id', horario.id)
      .select('*')
      .single();

    if (error) throw error;
    return sendSuccess(res, data, 'Horario actualizado exitosamente');
  } catch (error) {
    console.error('horarios.update:', error);
    return sendError(res, 'Error al actualizar horario', 500);
  }
};

/**
 * DELETE /api/horarios/:id
 * Eliminar horario (admin)
 */
const remove = async (req, res) => {
  try {
    const supabase = getSupabase();
    const { data: actuales } = await supabase
      .from('horarios')
      .select('id')
      .eq('id', req.params.id)
      .limit(1);

    if (!actuales || actuales.length === 0) {
      return sendError(res, 'Horario no encontrado', 404);
    }

    const { error } = await supabase.from('horarios').delete().eq('id', req.params.id);
    if (error) throw error;

    return sendSuccess(res, null, 'Horario eliminado exitosamente');
  } catch (error) {
    console.error('horarios.remove:', error);
    return sendError(res, 'Error al eliminar horario', 500);
  }
};

module.exports = {
  getAll,
  getByMedico,
  getDisponibles,
  create,
  update,
  remove,
};
