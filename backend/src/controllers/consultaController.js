const { consultas, pacientes, medicos, citas } = require('../data/mockData');
const { sendSuccess, sendError, nextId } = require('../utils/helpers');

/**
 * GET /api/consultas/paciente/:id
 * Obtener historial clínico de un paciente
 */
const getByPaciente = async (req, res) => {
  try {
    const paciente = pacientes.find((p) => p.id === parseInt(req.params.id));
    if (!paciente) {
      return sendError(res, 'Paciente no encontrado', 404);
    }

    const historial = consultas.filter((c) => c.paciente_id === paciente.id);
    return sendSuccess(res, historial);
  } catch (error) {
    return sendError(res, 'Error al obtener historial', 500);
  }
};

/**
 * GET /api/consultas/:id
 * Obtener consulta por ID
 */
const getById = async (req, res) => {
  try {
    const consulta = consultas.find((c) => c.id === parseInt(req.params.id));
    if (!consulta) {
      return sendError(res, 'Consulta no encontrada', 404);
    }
    return sendSuccess(res, consulta);
  } catch (error) {
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

    // Verificar que el paciente exista
    const paciente = pacientes.find((p) => p.id === parseInt(paciente_id));
    if (!paciente) {
      return sendError(res, 'Paciente no encontrado', 404);
    }

    // Verificar que el médico exista
    const medico = medicos.find((m) => m.id === parseInt(medico_id));
    if (!medico) {
      return sendError(res, 'Médico no encontrado', 404);
    }

    // Si se proporciona cita_id, verificar que exista
    if (cita_id) {
      const cita = citas.find((c) => c.id === parseInt(cita_id));
      if (!cita) {
        return sendError(res, 'Cita no encontrada', 404);
      }
    }

    const nuevaConsulta = {
      id: nextId(consultas),
      cita_id: cita_id ? parseInt(cita_id) : null,
      paciente_id: parseInt(paciente_id),
      medico_id: parseInt(medico_id),
      fecha: new Date().toISOString().split('T')[0],
      diagnostico,
      tratamiento,
      notas_clinicas: notas_clinicas || '',
      signos_vitales: signos_vitales ? JSON.stringify(signos_vitales) : null,
      creado_en: new Date().toISOString(),
      actualizado_en: new Date().toISOString(),
    };

    consultas.push(nuevaConsulta);
    return sendSuccess(res, nuevaConsulta, 'Consulta registrada exitosamente', 201);
  } catch (error) {
    return sendError(res, 'Error al crear consulta', 500);
  }
};

/**
 * PUT /api/consultas/:id
 * Actualizar consulta existente
 */
const update = async (req, res) => {
  try {
    const index = consultas.findIndex((c) => c.id === parseInt(req.params.id));
    if (index === -1) {
      return sendError(res, 'Consulta no encontrada', 404);
    }

    const { diagnostico, tratamiento, notas_clinicas, signos_vitales } = req.body;

    consultas[index] = {
      ...consultas[index],
      diagnostico: diagnostico || consultas[index].diagnostico,
      tratamiento: tratamiento || consultas[index].tratamiento,
      notas_clinicas: notas_clinicas !== undefined ? notas_clinicas : consultas[index].notas_clinicas,
      signos_vitales: signos_vitales ? JSON.stringify(signos_vitales) : consultas[index].signos_vitales,
      actualizado_en: new Date().toISOString(),
    };

    return sendSuccess(res, consultas[index], 'Consulta actualizada exitosamente');
  } catch (error) {
    return sendError(res, 'Error al actualizar consulta', 500);
  }
};

module.exports = {
  getByPaciente,
  getById,
  create,
  update,
};
