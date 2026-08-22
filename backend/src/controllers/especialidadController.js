const { especialidades, medicos } = require('../data/mockData');
const { sendSuccess, sendError, nextId } = require('../utils/helpers');

// Normaliza nombres para comparación insensible a mayúsculas y tildes
const normalizar = (texto) =>
  texto.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();

/**
 * GET /api/especialidades
 * Listar todas las especialidades activas
 */
const getEspecialidades = async (req, res) => {
  try {
    const activas = especialidades.filter((e) => e.activo);
    return sendSuccess(res, activas);
  } catch (error) {
    return sendError(res, 'Error al listar especialidades', 500);
  }
};

/**
 * GET /api/especialidades/:id
 * Obtener especialidad por ID
 */
const getEspecialidadById = async (req, res) => {
  try {
    const especialidad = especialidades.find((e) => e.id === parseInt(req.params.id));
    if (!especialidad) {
      return sendError(res, 'Especialidad no encontrada', 404);
    }
    return sendSuccess(res, especialidad);
  } catch (error) {
    return sendError(res, 'Error al obtener especialidad', 500);
  }
};

/**
 * GET /api/especialidades/medico/:medicoId
 * Obtener las especialidades asociadas a un médico
 */
const getEspecialidadesByMedico = async (req, res) => {
  try {
    const medico = medicos.find((m) => m.id === parseInt(req.params.medicoId));
    if (!medico) {
      return sendError(res, 'Médico no encontrado', 404);
    }

    const resultado = especialidades.filter(
      (e) => normalizar(e.nombre) === normalizar(medico.especialidad)
    );
    return sendSuccess(res, resultado);
  } catch (error) {
    return sendError(res, 'Error al obtener especialidades del médico', 500);
  }
};

/**
 * POST /api/especialidades
 * Crear nueva especialidad
 */
const createEspecialidad = async (req, res) => {
  try {
    const { nombre, descripcion } = req.body;

    // Verificar nombre duplicado
    const existeNombre = especialidades.find(
      (e) => normalizar(e.nombre) === normalizar(nombre)
    );
    if (existeNombre) {
      return sendError(res, 'Ya existe una especialidad con ese nombre', 400);
    }

    const nuevaEspecialidad = {
      id: nextId(especialidades),
      nombre,
      descripcion: descripcion || '',
      activo: true,
      creado_en: new Date().toISOString(),
      actualizado_en: new Date().toISOString(),
    };

    especialidades.push(nuevaEspecialidad);
    return sendSuccess(res, nuevaEspecialidad, 'Especialidad creada exitosamente', 201);
  } catch (error) {
    return sendError(res, 'Error al crear especialidad', 500);
  }
};

/**
 * PUT /api/especialidades/:id
 * Actualizar especialidad
 */
const updateEspecialidad = async (req, res) => {
  try {
    const index = especialidades.findIndex((e) => e.id === parseInt(req.params.id));
    if (index === -1) {
      return sendError(res, 'Especialidad no encontrada', 404);
    }

    const { nombre, descripcion } = req.body;

    // Verificar nombre duplicado en otra especialidad
    if (nombre) {
      const duplicada = especialidades.find(
        (e) =>
          e.id !== especialidades[index].id &&
          normalizar(e.nombre) === normalizar(nombre)
      );
      if (duplicada) {
        return sendError(res, 'Ya existe una especialidad con ese nombre', 400);
      }
    }

    especialidades[index] = {
      ...especialidades[index],
      nombre: nombre || especialidades[index].nombre,
      descripcion: descripcion !== undefined ? descripcion : especialidades[index].descripcion,
      actualizado_en: new Date().toISOString(),
    };

    return sendSuccess(res, especialidades[index], 'Especialidad actualizada exitosamente');
  } catch (error) {
    return sendError(res, 'Error al actualizar especialidad', 500);
  }
};

/**
 * DELETE /api/especialidades/:id
 * Eliminar especialidad
 */
const deleteEspecialidad = async (req, res) => {
  try {
    const index = especialidades.findIndex((e) => e.id === parseInt(req.params.id));
    if (index === -1) {
      return sendError(res, 'Especialidad no encontrada', 404);
    }

    // No permitir eliminar si hay médicos con esa especialidad
    const enUso = medicos.some(
      (m) => normalizar(m.especialidad) === normalizar(especialidades[index].nombre)
    );
    if (enUso) {
      return sendError(res, 'No se puede eliminar: hay médicos asignados a esta especialidad', 409);
    }

    especialidades.splice(index, 1);
    return sendSuccess(res, null, 'Especialidad eliminada exitosamente');
  } catch (error) {
    return sendError(res, 'Error al eliminar especialidad', 500);
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
