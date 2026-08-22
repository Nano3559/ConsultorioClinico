const { getSupabase } = require('../config/supabase');
const { sendSuccess, sendError } = require('../utils/helpers');

/**
 * GET /api/consultas/paciente/:id
 * Obtener historial clínico de un paciente
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
      .from('consultas')
      .select('*')
      .eq('paciente_id', req.params.id)
      .order('fecha', { ascending: false });

    if (error) throw error;
    return sendSuccess(res, data);
  } catch (error) {
    console.error('consultas.getByPaciente:', error);
    return sendError(res, 'Error al obtener historial', 500);
  }
};

/**
 * GET /api/consultas/:id
 * Obtener consulta por ID
 */
const getById = async (req, res) => {
  try {
    const supabase = getSupabase();
    const { data, error } = await supabase
      .from('consultas')
      .select('*')
      .eq('id', req.params.id)
      .limit(1);

    if (error) throw error;
    if (!data || data.length === 0) {
      return sendError(res, 'Consulta no encontrada', 404);
    }
    return sendSuccess(res, data[0]);
  } catch (error) {
    console.error('consultas.getById:', error);
    return sendError(res, 'Error al obtener consulta', 500);
  }
};

/**
 * POST /api/consultas
 * Crear nueva consulta (registro de historia clínica)
 */
const create = async (req, res) => {
  try {
    const { cita_id, paciente_id, medico_id, diagnostico, tratamiento, notas_clinicas, signos_vitales } = req.body;
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

    // Verificar que el médico exista
    const { data: medicos } = await supabase
      .from('medicos')
      .select('id')
      .eq('id', medico_id)
      .limit(1);
    if (!medicos || medicos.length === 0) {
      return sendError(res, 'Médico no encontrado', 404);
    }

    // Si se proporciona cita_id, verificar que exista
    if (cita_id) {
      const { data: citas } = await supabase
        .from('citas')
        .select('id')
        .eq('id', cita_id)
        .limit(1);
      if (!citas || citas.length === 0) {
        return sendError(res, 'Cita no encontrada', 404);
      }
    }

    const { data, error } = await supabase
      .from('consultas')
      .insert({
        cita_id: cita_id ? parseInt(cita_id) : null,
        paciente_id,
        medico_id,
        diagnostico,
        tratamiento,
        notas_clinicas: notas_clinicas || '',
        signos_vitales: signos_vitales || null,
      })
      .select('*')
      .single();

    if (error) throw error;
    return sendSuccess(res, data, 'Consulta registrada exitosamente', 201);
  } catch (error) {
    console.error('consultas.create:', error);
    return sendError(res, 'Error al crear consulta', 500);
  }
};

/**
 * PUT /api/consultas/:id
 * Actualizar consulta existente
 */
const update = async (req, res) => {
  try {
    const supabase = getSupabase();
    const cambios = {};
    if (req.body.diagnostico !== undefined) cambios.diagnostico = req.body.diagnostico;
    if (req.body.tratamiento !== undefined) cambios.tratamiento = req.body.tratamiento;
    if (req.body.notas_clinicas !== undefined) cambios.notas_clinicas = req.body.notas_clinicas;
    if (req.body.signos_vitales !== undefined) cambios.signos_vitales = req.body.signos_vitales;

    if (Object.keys(cambios).length === 0) {
      return sendError(res, 'No hay campos para actualizar', 400);
    }

    const { data, error } = await supabase
      .from('consultas')
      .update(cambios)
      .eq('id', req.params.id)
      .select('*');

    if (error) throw error;
    if (!data || data.length === 0) {
      return sendError(res, 'Consulta no encontrada', 404);
    }
    return sendSuccess(res, data[0], 'Consulta actualizada exitosamente');
  } catch (error) {
    console.error('consultas.update:', error);
    return sendError(res, 'Error al actualizar consulta', 500);
  }
};

module.exports = {
  getByPaciente,
  getById,
  create,
  update,
};
