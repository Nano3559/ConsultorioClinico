const { pacientes, usuarios, counters } = require('../data/mockData');
const { sendSuccess, sendError, nextId } = require('../utils/helpers');

/**
 * GET /api/pacientes
 * Listar todos los pacientes activos
 */
const getAll = async (req, res) => {
  try {
    const activos = pacientes.filter((p) => p.activo);
    return sendSuccess(res, activos);
  } catch (error) {
    return sendError(res, 'Error al listar pacientes', 500);
  }
};

/**
 * GET /api/pacientes/:id
 * Obtener paciente por ID
 */
const getById = async (req, res) => {
  try {
    const paciente = pacientes.find((p) => p.id === parseInt(req.params.id));
    if (!paciente) {
      return sendError(res, 'Paciente no encontrado', 404);
    }
    return sendSuccess(res, paciente);
  } catch (error) {
    return sendError(res, 'Error al obtener paciente', 500);
  }
};

/**
 * POST /api/pacientes
 * Crear nuevo paciente
 */
const create = async (req, res) => {
  try {
    const { nombre, apellido, cedula, telefono, email, fecha_nacimiento, sexo, direccion, tipo_sangre, alergias, contacto_emergencia } = req.body;

    // Verificar cédula duplicada
    const existeCedula = pacientes.find((p) => p.cedula === cedula);
    if (existeCedula) {
      return sendError(res, 'Ya existe un paciente con esa cédula', 400);
    }

    const nuevoPaciente = {
      id: nextId(pacientes),
      usuario_id: null,
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
      contacto_emergencia,
      activo: true,
      creado_en: new Date().toISOString(),
      actualizado_en: new Date().toISOString(),
    };

    pacientes.push(nuevoPaciente);
    return sendSuccess(res, nuevoPaciente, 'Paciente creado exitosamente', 201);
  } catch (error) {
    return sendError(res, 'Error al crear paciente', 500);
  }
};

/**
 * PUT /api/pacientes/:id
 * Actualizar paciente
 */
const update = async (req, res) => {
  try {
    const index = pacientes.findIndex((p) => p.id === parseInt(req.params.id));
    if (index === -1) {
      return sendError(res, 'Paciente no encontrado', 404);
    }

    const { nombre, apellido, cedula, telefono, email, fecha_nacimiento, sexo, direccion, tipo_sangre, alergias, contacto_emergencia } = req.body;

    pacientes[index] = {
      ...pacientes[index],
      nombre: nombre || pacientes[index].nombre,
      apellido: apellido || pacientes[index].apellido,
      cedula: cedula || pacientes[index].cedula,
      telefono: telefono || pacientes[index].telefono,
      email: email || pacientes[index].email,
      fecha_nacimiento: fecha_nacimiento || pacientes[index].fecha_nacimiento,
      sexo: sexo || pacientes[index].sexo,
      direccion: direccion || pacientes[index].direccion,
      tipo_sangre: tipo_sangre || pacientes[index].tipo_sangre,
      alergias: alergias !== undefined ? alergias : pacientes[index].alergias,
      contacto_emergencia: contacto_emergencia || pacientes[index].contacto_emergencia,
      actualizado_en: new Date().toISOString(),
    };

    return sendSuccess(res, pacientes[index], 'Paciente actualizado exitosamente');
  } catch (error) {
    return sendError(res, 'Error al actualizar paciente', 500);
  }
};

/**
 * DELETE /api/pacientes/:id
 * Eliminar paciente (soft delete)
 */
const remove = async (req, res) => {
  try {
    const paciente = pacientes.find((p) => p.id === parseInt(req.params.id));
    if (!paciente) {
      return sendError(res, 'Paciente no encontrado', 404);
    }

    paciente.activo = false;
    paciente.actualizado_en = new Date().toISOString();

    return sendSuccess(res, null, 'Paciente eliminado exitosamente');
  } catch (error) {
    return sendError(res, 'Error al eliminar paciente', 500);
  }
};

module.exports = {
  getAll,
  getById,
  create,
  update,
  remove,
};
