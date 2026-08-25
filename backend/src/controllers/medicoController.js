const { getSupabase } = require('../config/supabase');
const { sendSuccess, sendError, formatDate } = require('../utils/helpers');
const { ESTADOS_CITA } = require('../utils/constants');

/**
 * GET /api/medicos
 * Listar todos los médicos activos
 */
const getAll = async (req, res) => {
  try {
    const supabase = getSupabase();
    const { data, error } = await supabase
      .from('medicos')
      .select('*')
      .eq('activo', true)
      .order('id');

    if (error) {
      console.error('medicos.getAll SUPABASE ERROR:', JSON.stringify(error, null, 2));
      throw error;
    }
    console.log('medicos.getAll OK, registros:', data ? data.length : 0);
    return sendSuccess(res, data);
  } catch (error) {
    console.error('medicos.getAll ERROR:', JSON.stringify(error, null, 2));
    return sendError(res, `Error al listar médicos: ${error.message || 'desconocido'}`, 500);
  }
};

/**
 * GET /api/medicos/:id
 * Obtener médico por ID
 */
const getById = async (req, res) => {
  try {
    const supabase = getSupabase();
    const { data, error } = await supabase
      .from('medicos')
      .select('*')
      .eq('id', req.params.id)
      .limit(1);

    if (error) throw error;
    if (!data || data.length === 0) {
      return sendError(res, 'Médico no encontrado', 404);
    }
    return sendSuccess(res, data[0]);
  } catch (error) {
    console.error('medicos.getById ERROR:', JSON.stringify(error, null, 2));
    return sendError(res, `Error al obtener médico: ${error.message || 'desconocido'}`, 500);
  }
};

/**
 * POST /api/medicos
 * Crear nuevo médico
 */
const create = async (req, res) => {
  try {
    const { nombre, apellido, cedula, especialidad, telefono, email, consulorio, tarifa_consulta } = req.body;
    const supabase = getSupabase();

    const { data: existentes } = await supabase
      .from('medicos')
      .select('id')
      .eq('cedula', cedula)
      .limit(1);
    if (existentes && existentes.length > 0) {
      return sendError(res, 'Ya existe un médico con esa cédula', 400);
    }

    const { data, error } = await supabase
      .from('medicos')
      .insert({
        nombre,
        apellido,
        cedula,
        especialidad,
        telefono,
        email,
        consulorio,
        tarifa_consulta: parseFloat(tarifa_consulta) || 0,
      })
      .select('*')
      .single();

    if (error) {
      if (error.code === '23505') {
        return sendError(res, 'Ya existe un médico con esa cédula', 400);
      }
      throw error;
    }
    return sendSuccess(res, data, 'Médico creado exitosamente', 201);
  } catch (error) {
    console.error('medicos.create ERROR:', JSON.stringify(error, null, 2));
    return sendError(res, `Error al crear médico: ${error.message || 'desconocido'}`, 500);
  }
};

/**
 * PUT /api/medicos/:id
 * Actualizar médico
 */
const update = async (req, res) => {
  try {
    const supabase = getSupabase();
    const permitidos = ['nombre', 'apellido', 'cedula', 'especialidad', 'telefono', 'email', 'consulorio'];
    const cambios = {};
    for (const campo of permitidos) {
      if (req.body[campo] !== undefined) cambios[campo] = req.body[campo];
    }
    if (req.body.tarifa_consulta !== undefined) {
      cambios.tarifa_consulta = parseFloat(req.body.tarifa_consulta);
    }
    if (Object.keys(cambios).length === 0) {
      return sendError(res, 'No hay campos para actualizar', 400);
    }

    const { data, error } = await supabase
      .from('medicos')
      .update(cambios)
      .eq('id', req.params.id)
      .select('*');

    if (error) throw error;
    if (!data || data.length === 0) {
      return sendError(res, 'Médico no encontrado', 404);
    }
    return sendSuccess(res, data[0], 'Médico actualizado exitosamente');
  } catch (error) {
    console.error('medicos.update ERROR:', JSON.stringify(error, null, 2));
    return sendError(res, `Error al actualizar médico: ${error.message || 'desconocido'}`, 500);
  }
};

/**
 * PATCH /api/medicos/:id/estado
 * Activar/desactivar médico
 */
const toggleEstado = async (req, res) => {
  try {
    const supabase = getSupabase();

    const { data: actuales } = await supabase
      .from('medicos')
      .select('activo')
      .eq('id', req.params.id)
      .limit(1);
    if (!actuales || actuales.length === 0) {
      return sendError(res, 'Médico no encontrado', 404);
    }

    const nuevoEstado = !actuales[0].activo;
    const { data, error } = await supabase
      .from('medicos')
      .update({ activo: nuevoEstado })
      .eq('id', req.params.id)
      .select('*')
      .single();

    if (error) throw error;
    const estado = nuevoEstado ? 'activado' : 'desactivado';
    return sendSuccess(res, data, `Médico ${estado} exitosamente`);
  } catch (error) {
    console.error('medicos.toggleEstado ERROR:', JSON.stringify(error, null, 2));
    return sendError(res, `Error al cambiar estado del médico: ${error.message || 'desconocido'}`, 500);
  }
};

/**
 * GET /api/medicos/:id/horarios
 * Obtener horarios de un médico
 */
const getHorarios = async (req, res) => {
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
      .from('horarios')
      .select('*')
      .eq('medico_id', req.params.id)
      .eq('activo', true)
      .order('id');

    if (error) throw error;
    return sendSuccess(res, data || []);
  } catch (error) {
    console.error('medicos.getHorarios:', error);
    return sendError(res, 'Error al obtener horarios', 500);
  }
};

/**
 * DELETE /api/medicos/:id
 * Eliminar médico
 */
const remove = async (req, res) => {
  try {
    const supabase = getSupabase();

    const { data: actuales } = await supabase
      .from('medicos')
      .select('id')
      .eq('id', req.params.id)
      .limit(1);
    if (!actuales || actuales.length === 0) {
      return sendError(res, 'Médico no encontrado', 404);
    }
    const medicoId = actuales[0].id;

    // No permitir eliminar si tiene citas activas (no canceladas) hoy o futuras
    const hoy = formatDate(new Date());
    const { data: citasActivas } = await supabase
      .from('citas')
      .select('id')
      .eq('medico_id', medicoId)
      .neq('estado', ESTADOS_CITA.CANCELADA)
      .gte('fecha', hoy)
      .limit(1);
    if (citasActivas && citasActivas.length > 0) {
      return sendError(res, 'No se puede eliminar: el médico tiene citas activas pendientes', 409);
    }

    // Los horarios y citas históricas se eliminan en cascada por FK
    const { error } = await supabase.from('medicos').delete().eq('id', medicoId);
    if (error) throw error;

    return sendSuccess(res, null, 'Médico eliminado exitosamente');
  } catch (error) {
    console.error('medicos.remove ERROR:', JSON.stringify(error, null, 2));
    return sendError(res, `Error al eliminar médico: ${error.message || 'desconocido'}`, 500);
  }
};

module.exports = {
  getAll,
  getById,
  create,
  update,
  toggleEstado,
  remove,
  getHorarios,
};
