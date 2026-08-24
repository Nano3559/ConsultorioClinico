<<<<<<< HEAD
const { medicos, horarios, citas } = require('../data/mockData');
const { sendSuccess, sendError, nextId, formatDate } = require('../utils/helpers');
const { ESTADOS_CITA } = require('../utils/constants');
=======
const { getSupabase } = require('../config/supabase');
const { sendSuccess, sendError } = require('../utils/helpers');
>>>>>>> 3b4875435caf1037dbf2038e764fd35db6f300a0

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

    if (error) throw error;
    return sendSuccess(res, data);
  } catch (error) {
    console.error('medicos.getAll:', error);
    return sendError(res, 'Error al listar médicos', 500);
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
    console.error('medicos.getById:', error);
    return sendError(res, 'Error al obtener médico', 500);
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
    console.error('medicos.create:', error);
    return sendError(res, 'Error al crear médico', 500);
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
    console.error('medicos.update:', error);
    return sendError(res, 'Error al actualizar médico', 500);
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
    console.error('medicos.toggleEstado:', error);
    return sendError(res, 'Error al cambiar estado del médico', 500);
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
    const index = medicos.findIndex((m) => m.id === parseInt(req.params.id));
    if (index === -1) {
      return sendError(res, 'Médico no encontrado', 404);
    }
    const medico = medicos[index];

    // No permitir eliminar si tiene citas activas (no canceladas) hoy o futuras
    const hoy = formatDate(new Date());
    const tieneCitasActivas = citas.some(
      (c) =>
        c.medico_id === medico.id &&
        c.estado !== ESTADOS_CITA.CANCELADA &&
        c.fecha >= hoy
    );
    if (tieneCitasActivas) {
      return sendError(res, 'No se puede eliminar: el médico tiene citas activas pendientes', 409);
    }

    // Eliminar también sus horarios
    for (let i = horarios.length - 1; i >= 0; i--) {
      if (horarios[i].medico_id === medico.id) {
        horarios.splice(i, 1);
      }
    }

    medicos.splice(index, 1);
    return sendSuccess(res, null, 'Médico eliminado exitosamente');
  } catch (error) {
    return sendError(res, 'Error al eliminar médico', 500);
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
