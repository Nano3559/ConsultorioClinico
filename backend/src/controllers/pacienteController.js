const { getSupabase } = require('../config/supabase');
const { sendSuccess, sendError } = require('../utils/helpers');
const { rostroVigente, parseEmbedding } = require('../services/rostroService');

/**
 * GET /api/pacientes/buscar?cedula=XXXX (público, rate limit)
 * Busca un paciente por cédula para autocompletar la reserva online.
 * Devuelve SOLO campos no sensibles + estado del registro facial:
 * si el rostro está vigente, la reserva omite la foto; si no, la pide.
 *
 * Nota de diseño: la cédula es enumerable por naturaleza (como el
 * autocompletado público de Firestore que ya existe); se mitiga con rate
 * limit estricto y respuesta mínima (sin historial clínico ni pagos).
 */

/**
 * GET /api/pacientes
 * Listar todos los pacientes activos
 */
const getAll = async (req, res) => {
  try {
    const supabase = getSupabase();
    const { data, error } = await supabase
      .from('pacientes')
      .select('*')
      .eq('activo', true)
      .order('id');

    if (error) throw error;
    return sendSuccess(res, data);
  } catch (error) {
    console.error('pacientes.getAll:', error);
    return sendError(res, 'Error al listar pacientes', 500);
  }
};

/**
 * GET /api/pacientes/:id
 * Obtener paciente por ID
 */
const getById = async (req, res) => {
  try {
    const supabase = getSupabase();
    const { data, error } = await supabase
      .from('pacientes')
      .select('*')
      .eq('id', req.params.id)
      .limit(1);

    if (error) throw error;
    if (!data || data.length === 0) {
      return sendError(res, 'Paciente no encontrado', 404);
    }
    return sendSuccess(res, data[0]);
  } catch (error) {
    console.error('pacientes.getById:', error);
    return sendError(res, 'Error al obtener paciente', 500);
  }
};

/**
 * POST /api/pacientes
 * Crear nuevo paciente
 */
const create = async (req, res) => {
  try {
    const { nombre, apellido, cedula, telefono, email, fecha_nacimiento, sexo, direccion, tipo_sangre, alergias, antecedentes, contacto_emergencia } = req.body;
    const supabase = getSupabase();

    const { data: existentes } = await supabase
      .from('pacientes')
      .select('id')
      .eq('cedula', cedula)
      .limit(1);
    if (existentes && existentes.length > 0) {
      return sendError(res, 'Ya existe un paciente con esa cédula', 400);
    }

    const { data, error } = await supabase
      .from('pacientes')
      .insert({
        nombre,
        apellido,
        cedula,
        telefono,
        email,
        fecha_nacimiento,
        sexo,
        direccion,
        tipo_sangre,
        alergias: alergias || 'Ninguna',
        antecedentes: antecedentes || '',
        contacto_emergencia,
      })
      .select('*')
      .single();

    if (error) {
      if (error.code === '23505') {
        return sendError(res, 'Ya existe un paciente con esa cédula', 400);
      }
      throw error;
    }
    return sendSuccess(res, data, 'Paciente creado exitosamente', 201);
  } catch (error) {
    console.error('pacientes.create:', error);
    return sendError(res, 'Error al crear paciente', 500);
  }
};

/**
 * PUT /api/pacientes/:id
 * Actualizar paciente (solo campos enviados; el trigger actualiza actualizado_en)
 */
const update = async (req, res) => {
  try {
    const supabase = getSupabase();
    const permitidos = ['nombre', 'apellido', 'cedula', 'telefono', 'email', 'fecha_nacimiento', 'sexo', 'direccion', 'tipo_sangre', 'alergias', 'antecedentes', 'contacto_emergencia'];
    const cambios = {};
    for (const campo of permitidos) {
      if (req.body[campo] !== undefined) cambios[campo] = req.body[campo];
    }
    if (Object.keys(cambios).length === 0) {
      return sendError(res, 'No hay campos para actualizar', 400);
    }

    const { data, error } = await supabase
      .from('pacientes')
      .update(cambios)
      .eq('id', req.params.id)
      .select('*');

    if (error) {
      if (error.code === '23505') {
        return sendError(res, 'Ya existe un paciente con esa cédula', 400);
      }
      throw error;
    }
    if (!data || data.length === 0) {
      return sendError(res, 'Paciente no encontrado', 404);
    }
    return sendSuccess(res, data[0], 'Paciente actualizado exitosamente');
  } catch (error) {
    console.error('pacientes.update:', error);
    return sendError(res, 'Error al actualizar paciente', 500);
  }
};

/**
 * DELETE /api/pacientes/:id
 * Eliminar paciente (soft delete)
 */
const remove = async (req, res) => {
  try {
    const supabase = getSupabase();
    const { data, error } = await supabase
      .from('pacientes')
      .update({ activo: false })
      .eq('id', req.params.id)
      .select('id');

    if (error) throw error;
    if (!data || data.length === 0) {
      return sendError(res, 'Paciente no encontrado', 404);
    }
    return sendSuccess(res, null, 'Paciente eliminado exitosamente');
  } catch (error) {
    console.error('pacientes.remove:', error);
    return sendError(res, 'Error al eliminar paciente', 500);
  }
};

/**
 * GET /api/pacientes/buscar?cedula=XXXX (público, rate limit 20/15min).
 * Ver descripción en el encabezado del archivo.
 */
const buscarPorCedula = async (req, res) => {
  try {
    const cedula = String(req.query.cedula || '').trim();
    if (!cedula) {
      return sendError(res, 'La cédula es obligatoria', 400);
    }
    const supabase = getSupabase();
    const { data, error } = await supabase
      .from('pacientes')
      .select('id, nombre, apellido, cedula, telefono, email, fecha_nacimiento, rostro_embedding, rostro_actualizado_en')
      .eq('cedula', cedula)
      .eq('activo', true)
      .limit(1);

    if (error) throw error;
    if (!data || data.length === 0) {
      return sendSuccess(res, { existe: false }, 'Paciente no encontrado');
    }
    const p = data[0];
    const embedding = parseEmbedding(p.rostro_embedding);
    const registrado = embedding !== null && embedding.length === 128;
    const vigente = rostroVigente(p);
    return sendSuccess(res, {
      existe: true,
      paciente: {
        id: p.id,
        nombre: p.nombre,
        apellido: p.apellido,
        cedula: p.cedula,
        telefono: p.telefono,
        email: p.email,
        fecha_nacimiento: p.fecha_nacimiento,
      },
      rostro_registrado: registrado,
      rostro_vigente: vigente,
      // La reserva pide foto solo si no hay registro vigente.
      foto_requerida: !vigente,
    }, 'Paciente encontrado');
  } catch (error) {
    console.error('pacientes.buscarPorCedula:', error.message);
    return sendError(res, 'Error al buscar paciente', 500);
  }
};

module.exports = {
  getAll,
  getById,
  buscarPorCedula,
  create,
  update,
  remove,
};
