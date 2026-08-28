const crypto = require('crypto');
const { getSupabase } = require('../config/supabase');
const { sendSuccess, sendError, formatDate, normalizarTexto, horaAMinutos } = require('../utils/helpers');
const { ESTADOS_CITA } = require('../utils/constants');

/**
 * Resuelve especialidad_id a partir del nombre (normalizado), buscando en la
 * tabla catálogo especialidades. Devuelve { id, nombre } o { id: null, nombre }.
 * Es la única fuente de verdad para evitar desnormalización (texto vs. FK).
 */
const resolverEspecialidad = async (supabase, nombreEspecialidad) => {
  const nombre = (nombreEspecialidad || '').trim();
  if (!nombre) return { id: null, nombre };

  const { data: rows, error } = await supabase
    .from('especialidades')
    .select('id, nombre')
    .eq('activo', true);
  if (error) {
    if (error.code === '42P01') return { id: null, nombre }; // tabla aún no existe
    throw error;
  }
  const match = (rows || []).find(
    (e) => normalizarTexto(e.nombre) === normalizarTexto(nombre)
  );
  return match ? { id: match.id, nombre: match.nombre } : { id: null, nombre };
};

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
    const { nombre, apellido, cedula, especialidad, telefono, email, consulorio, tarifa_consulta, titulo, descripcion, anios_experiencia } = req.body;
    const supabase = getSupabase();

    // La cédula es única; si el formulario no la envía, generamos un marcador
    // con sufijo aleatorio para evitar colisiones con el UNIQUE de la BD.
    const cedulaFinal = cedula && String(cedula).trim()
      ? String(cedula).trim()
      : `M${Date.now()}${crypto.randomBytes(4).toString('hex')}`;

    const { data: existentes } = await supabase
      .from('medicos')
      .select('id')
      .eq('cedula', cedulaFinal)
      .limit(1);
    if (existentes && existentes.length > 0) {
      return sendError(res, 'Ya existe un médico con esa cédula', 400);
    }

    // Normalizar: resolver especialidad_id desde el catálogo por nombre.
    const esp = await resolverEspecialidad(supabase, especialidad);

    const { data, error } = await supabase
      .from('medicos')
      .insert({
        nombre,
        apellido,
        cedula: cedulaFinal,
        especialidad: esp.nombre,
        especialidad_id: esp.id,
        telefono,
        email: email && String(email).trim() ? email : null,
        consulorio,
        tarifa_consulta: parseFloat(tarifa_consulta) || 0,
        titulo: (titulo && String(titulo).trim()) ? String(titulo).trim() : 'Dr./Dra.',
        descripcion: descripcion || '',
        anios_experiencia: parseInt(anios_experiencia, 10) || 0,
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
    const permitidos = ['nombre', 'apellido', 'cedula', 'especialidad', 'telefono', 'email', 'consulorio', 'titulo', 'descripcion'];
    const cambios = {};
    for (const campo of permitidos) {
      if (req.body[campo] !== undefined) cambios[campo] = req.body[campo];
    }
    if (req.body.tarifa_consulta !== undefined) {
      cambios.tarifa_consulta = parseFloat(req.body.tarifa_consulta);
    }
    if (req.body.anios_experiencia !== undefined) {
      cambios.anios_experiencia = parseInt(req.body.anios_experiencia, 10) || 0;
    }

    // Mantener especialidad_id en sincronía con el texto de especialidad.
    if (cambios.especialidad !== undefined) {
      const esp = await resolverEspecialidad(supabase, cambios.especialidad);
      cambios.especialidad = esp.nombre;
      cambios.especialidad_id = esp.id;
    }

    if (Object.keys(cambios).length === 0) {
      return sendError(res, 'No hay campos para actualizar', 400);
    }

    const { data, error } = await supabase
      .from('medicos')
      .update(cambios)
      .eq('id', req.params.id)
      .select('*');

    if (error) {
      if (error.code === '23505') {
        return sendError(res, 'Ya existe un médico con esa cédula', 400);
      }
      throw error;
    }
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
 * POST /api/medicos/:id/horarios
 * Agregar un horario de atención al médico (solo admin)
 */
const createHorario = async (req, res) => {
  try {
    const { dia_semana, hora_inicio, hora_fin } = req.body;
    const supabase = getSupabase();

    // Validar que la hora de fin sea posterior a la de inicio.
    if (horaAMinutos(hora_fin) <= horaAMinutos(hora_inicio)) {
      return sendError(res, 'La hora de fin debe ser posterior a la de inicio', 400);
    }

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
      .insert({
        medico_id: req.params.id,
        dia_semana,
        hora_inicio,
        hora_fin,
        activo: true,
      })
      .select('*')
      .single();

    if (error) throw error;
    return sendSuccess(res, data, 'Horario agregado exitosamente', 201);
  } catch (error) {
    console.error('medicos.createHorario:', error);
    return sendError(res, 'Error al agregar horario', 500);
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
  createHorario,
};
