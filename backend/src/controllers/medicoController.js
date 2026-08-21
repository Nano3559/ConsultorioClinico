const { medicos, horarios } = require('../data/mockData');
const { sendSuccess, sendError, nextId } = require('../utils/helpers');

/**
 * GET /api/medicos
 * Listar todos los médicos activos
 */
const getAll = async (req, res) => {
  try {
    const activos = medicos.filter((m) => m.activo);
    return sendSuccess(res, activos);
  } catch (error) {
    return sendError(res, 'Error al listar médicos', 500);
  }
};

/**
 * GET /api/medicos/:id
 * Obtener médico por ID
 */
const getById = async (req, res) => {
  try {
    const medico = medicos.find((m) => m.id === parseInt(req.params.id));
    if (!medico) {
      return sendError(res, 'Médico no encontrado', 404);
    }
    return sendSuccess(res, medico);
  } catch (error) {
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

    // Verificar cédula duplicada
    const existeCedula = medicos.find((m) => m.cedula === cedula);
    if (existeCedula) {
      return sendError(res, 'Ya existe un médico con esa cédula', 400);
    }

    const nuevoMedico = {
      id: nextId(medicos),
      usuario_id: null,
      nombre,
      apellido,
      cedula,
      especialidad,
      telefono,
      email,
      consulorio,
      tarifa_consulta: parseFloat(tarifa_consulta) || 0,
      activo: true,
      creado_en: new Date().toISOString(),
      actualizado_en: new Date().toISOString(),
    };

    medicos.push(nuevoMedico);
    return sendSuccess(res, nuevoMedico, 'Médico creado exitosamente', 201);
  } catch (error) {
    return sendError(res, 'Error al crear médico', 500);
  }
};

/**
 * PUT /api/medicos/:id
 * Actualizar médico
 */
const update = async (req, res) => {
  try {
    const index = medicos.findIndex((m) => m.id === parseInt(req.params.id));
    if (index === -1) {
      return sendError(res, 'Médico no encontrado', 404);
    }

    const { nombre, apellido, cedula, especialidad, telefono, email, consulorio, tarifa_consulta } = req.body;

    medicos[index] = {
      ...medicos[index],
      nombre: nombre || medicos[index].nombre,
      apellido: apellido || medicos[index].apellido,
      cedula: cedula || medicos[index].cedula,
      especialidad: especialidad || medicos[index].especialidad,
      telefono: telefono || medicos[index].telefono,
      email: email || medicos[index].email,
      consulorio: consulorio || medicos[index].consulorio,
      tarifa_consulta: tarifa_consulta !== undefined ? parseFloat(tarifa_consulta) : medicos[index].tarifa_consulta,
      actualizado_en: new Date().toISOString(),
    };

    return sendSuccess(res, medicos[index], 'Médico actualizado exitosamente');
  } catch (error) {
    return sendError(res, 'Error al actualizar médico', 500);
  }
};

/**
 * PATCH /api/medicos/:id/estado
 * Activar/desactivar médico
 */
const toggleEstado = async (req, res) => {
  try {
    const medico = medicos.find((m) => m.id === parseInt(req.params.id));
    if (!medico) {
      return sendError(res, 'Médico no encontrado', 404);
    }

    medico.activo = !medico.activo;
    medico.actualizado_en = new Date().toISOString();

    const estado = medico.activo ? 'activado' : 'desactivado';
    return sendSuccess(res, medico, `Médico ${estado} exitosamente`);
  } catch (error) {
    return sendError(res, 'Error al cambiar estado del médico', 500);
  }
};

/**
 * GET /api/medicos/:id/horarios
 * Obtener horarios de un médico
 */
const getHorarios = async (req, res) => {
  try {
    const medico = medicos.find((m) => m.id === parseInt(req.params.id));
    if (!medico) {
      return sendError(res, 'Médico no encontrado', 404);
    }

    const horariosMedico = horarios.filter((h) => h.medico_id === medico.id && h.activo);
    return sendSuccess(res, horariosMedico);
  } catch (error) {
    return sendError(res, 'Error al obtener horarios', 500);
  }
};

module.exports = {
  getAll,
  getById,
  create,
  update,
  toggleEstado,
  getHorarios,
};
