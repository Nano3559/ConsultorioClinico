const { getSupabase, dbErrorMessage } = require('../config/supabase');
const { sendSuccess, sendError } = require('../utils/helpers');

// Normaliza nombres para comparación insensible a mayúsculas y tildes
const normalizar = (texto) =>
  texto.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();

const TABLA_FALTA = '42P01';
// Supabase/PostgREST devuelve PGRST205 cuando la tabla no existe en cache.
const TABLA_FALTA_PGRST = 'PGRST205';

const esTablaFalta = (error) =>
  error && (error.code === TABLA_FALTA || error.code === TABLA_FALTA_PGRST);

const mensajeMigracion =
  'La tabla especialidades no existe. Ejecuta db/migrations/002_especialidades.sql en el SQL Editor de Supabase.';

/**
 * Fallback: deriva las especialidades desde los médicos activos cuando la
 * tabla catálogo aún no fue creada (permite que la API funcione igual).
 */
async function derivarDeMedicos(supabase) {
  const { data: meds, error } = await supabase
    .from('medicos')
    .select('especialidad')
    .eq('activo', true);
  if (error) throw error;
  const unicas = [...new Set((meds || []).map((m) => m.especialidad).filter(Boolean))];
  return unicas.map((nombre, i) => ({
    id: i + 1,
    nombre,
    descripcion: '',
    activo: true,
    derivada_de_medicos: true,
  }));
}

/**
 * GET /api/especialidades
 * Listar todas las especialidades activas
 */
const getEspecialidades = async (req, res) => {
  try {
    const supabase = getSupabase();
    const { data, error } = await supabase
      .from('especialidades')
      .select('*')
      .eq('activo', true)
      .order('id');

    if (error) {
      if (esTablaFalta(error)) {
        const derivadas = await derivarDeMedicos(supabase);
        return sendSuccess(res, derivadas);
      }
      throw error;
    }
    return sendSuccess(res, data);
  } catch (error) {
    console.error('getEspecialidades:', error);
    return sendError(res, dbErrorMessage(error) || 'Error al listar especialidades', 500);
  }
};

/**
 * GET /api/especialidades/medico/:medicoId
 * Obtener las especialidades asociadas a un médico
 */
const getEspecialidadesByMedico = async (req, res) => {
  try {
    const medicoId = parseInt(req.params.medicoId, 10);
    if (Number.isNaN(medicoId)) {
      return sendError(res, 'ID de médico inválido', 400);
    }

    const supabase = getSupabase();
    const { data: medicos, error: medError } = await supabase
      .from('medicos')
      .select('id, nombre, apellido, especialidad')
      .eq('id', medicoId)
      .limit(1);

    if (medError) throw medError;
    const medico = medicos && medicos[0];
    if (!medico) {
      return sendError(res, 'Médico no encontrado', 404);
    }

    const { data, error } = await supabase
      .from('especialidades')
      .select('*')
      .eq('activo', true)
      .order('id');

    if (error && !esTablaFalta(error)) throw error;
    const lista = error ? await derivarDeMedicos(supabase) : data;
    const resultado = lista.filter(
      (e) => normalizar(e.nombre) === normalizar(medico.especialidad)
    );
    return sendSuccess(res, resultado);
  } catch (error) {
    console.error('getEspecialidadesByMedico:', error);
    return sendError(
      res,
      dbErrorMessage(error) || 'Error al obtener especialidades del médico',
      500
    );
  }
};

/**
 * GET /api/especialidades/:id
 * Obtener especialidad por ID
 */
const getEspecialidadById = async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    if (Number.isNaN(id)) {
      return sendError(res, 'ID inválido', 400);
    }

    const supabase = getSupabase();
    const { data, error } = await supabase
      .from('especialidades')
      .select('*')
      .eq('id', id)
      .limit(1);

    if (error) {
      if (esTablaFalta(error)) {
        const derivadas = await derivarDeMedicos(supabase);
        const encontrada = derivadas.find((e) => e.id === id);
        if (!encontrada) return sendError(res, 'Especialidad no encontrada', 404);
        return sendSuccess(res, encontrada);
      }
      throw error;
    }
    if (!data || data.length === 0) {
      return sendError(res, 'Especialidad no encontrada', 404);
    }
    return sendSuccess(res, data[0]);
  } catch (error) {
    console.error('getEspecialidadById:', error);
    return sendError(res, dbErrorMessage(error) || 'Error al obtener especialidad', 500);
  }
};

/**
 * POST /api/especialidades
 * Crear nueva especialidad
 */
const createEspecialidad = async (req, res) => {
  try {
    const { nombre, descripcion } = req.body;
    const supabase = getSupabase();

    const { data: existentes, error: dupError } = await supabase
      .from('especialidades')
      .select('id, nombre');
    if (dupError) {
      if (esTablaFalta(dupError)) return sendError(res, mensajeMigracion, 503);
      throw dupError;
    }
    const existeNombre = (existentes || []).find(
      (e) => normalizar(e.nombre) === normalizar(nombre)
    );
    if (existeNombre) {
      return sendError(res, 'Ya existe una especialidad con ese nombre', 400);
    }

    const { data, error } = await supabase
      .from('especialidades')
      .insert({ nombre, descripcion: descripcion || '', activo: true })
      .select('*')
      .single();

    if (error) throw error;
    return sendSuccess(res, data, 'Especialidad creada exitosamente', 201);
  } catch (error) {
    console.error('createEspecialidad:', error);
    return sendError(res, dbErrorMessage(error) || 'Error al crear especialidad', 500);
  }
};

/**
 * PUT /api/especialidades/:id
 * Actualizar especialidad
 */
const updateEspecialidad = async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    if (Number.isNaN(id)) {
      return sendError(res, 'ID inválido', 400);
    }

    const { nombre, descripcion, activo } = req.body;
    const supabase = getSupabase();

    if (nombre) {
      const { data: existentes, error: dupError } = await supabase
        .from('especialidades')
        .select('id, nombre')
        .neq('id', id);
      if (dupError) {
        if (esTablaFalta(dupError)) return sendError(res, mensajeMigracion, 503);
        throw dupError;
      }
      const duplicada = (existentes || []).find(
        (e) => normalizar(e.nombre) === normalizar(nombre)
      );
      if (duplicada) {
        return sendError(res, 'Ya existe una especialidad con ese nombre', 400);
      }
    }

    const cambios = {};
    if (nombre !== undefined) cambios.nombre = nombre;
    if (descripcion !== undefined) cambios.descripcion = descripcion;
    if (activo !== undefined) cambios.activo = activo;

    if (Object.keys(cambios).length === 0) {
      return sendError(res, 'No hay campos para actualizar', 400);
    }

    const { data, error } = await supabase
      .from('especialidades')
      .update(cambios)
      .eq('id', id)
      .select('*');

    if (error) throw error;
    if (!data || data.length === 0) {
      return sendError(res, 'Especialidad no encontrada', 404);
    }
    return sendSuccess(res, data[0], 'Especialidad actualizada exitosamente');
  } catch (error) {
    console.error('updateEspecialidad:', error);
    return sendError(res, dbErrorMessage(error) || 'Error al actualizar especialidad', 500);
  }
};

/**
 * DELETE /api/especialidades/:id
 * Eliminar especialidad
 */
const deleteEspecialidad = async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    if (Number.isNaN(id)) {
      return sendError(res, 'ID inválido', 400);
    }

    const supabase = getSupabase();
    const { data: rows, error: findError } = await supabase
      .from('especialidades')
      .select('id, nombre')
      .eq('id', id)
      .limit(1);
    if (findError) {
      if (esTablaFalta(findError)) return sendError(res, mensajeMigracion, 503);
      throw findError;
    }
    if (!rows || rows.length === 0) {
      return sendError(res, 'Especialidad no encontrada', 404);
    }

    // No permitir eliminar si hay médicos con esa especialidad (por FK)
    const { count, error: usoError } = await supabase
      .from('medicos')
      .select('id', { count: 'exact', head: true })
      .eq('especialidad_id', id)
      .eq('activo', true);
    if (usoError) throw usoError;
    if (count > 0) {
      return sendError(
        res,
        'No se puede eliminar: hay médicos asignados a esta especialidad',
        409
      );
    }

    const { error } = await supabase.from('especialidades').delete().eq('id', id);
    if (error) throw error;
    return sendSuccess(res, null, 'Especialidad eliminada exitosamente');
  } catch (error) {
    console.error('deleteEspecialidad:', error);
    return sendError(res, dbErrorMessage(error) || 'Error al eliminar especialidad', 500);
  }
};

module.exports = {
  getEspecialidades,
  getEspecialidadById,
  createEspecialidad,
  updateEspecialidad,
  deleteEspecialidad,
  getEspecialidadesByMedico,
};
