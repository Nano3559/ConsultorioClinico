const { citas, pacientes, medicos, counters } = require('../data/mockData');
const { sendSuccess, sendError, nextId, formatDate } = require('../utils/helpers');
const { ESTADOS_CITA } = require('../utils/constants');

/**
 * GET /api/citas
 * Listar todas las citas
 */
const getAll = async (req, res) => {
  try {
    return sendSuccess(res, citas);
  } catch (error) {
    return sendError(res, 'Error al listar citas', 500);
  }
};

/**
 * GET /api/citas/agenda/hoy
 * Obtener citas del día actual
 */
const getHoy = async (req, res) => {
  try {
    const hoy = formatDate(new Date());
    const citasHoy = citas.filter((c) => c.fecha === hoy);
    return sendSuccess(res, citasHoy);
  } catch (error) {
    return sendError(res, 'Error al obtener citas del día', 500);
  }
};

/**
 * GET /api/citas/medico/:id
 * Obtener citas por médico
 */
const getByMedico = async (req, res) => {
  try {
    const medico = medicos.find((m) => m.id === parseInt(req.params.id));
    if (!medico) {
      return sendError(res, 'Médico no encontrado', 404);
    }

    const citasMedico = citas.filter((c) => c.medico_id === medico.id);
    return sendSuccess(res, citasMedico);
  } catch (error) {
    return sendError(res, 'Error al obtener citas del médico', 500);
  }
};

/**
 * GET /api/citas/paciente/:id
 * Obtener citas por paciente
 */
const getByPaciente = async (req, res) => {
  try {
    const paciente = pacientes.find((p) => p.id === parseInt(req.params.id));
    if (!paciente) {
      return sendError(res, 'Paciente no encontrado', 404);
    }

    const citasPaciente = citas.filter((c) => c.paciente_id === paciente.id);
    return sendSuccess(res, citasPaciente);
  } catch (error) {
    return sendError(res, 'Error al obtener citas del paciente', 500);
  }
};

/**
 * GET /api/citas/:id
 * Obtener cita por ID
 */
const getById = async (req, res) => {
  try {
    const cita = citas.find((c) => c.id === parseInt(req.params.id));
    if (!cita) {
      return sendError(res, 'Cita no encontrada', 404);
    }
    return sendSuccess(res, cita);
  } catch (error) {
    return sendError(res, 'Error al obtener cita', 500);
  }
};

/**
 * POST /api/citas
 * Crear nueva cita
 */
const create = async (req, res) => {
  try {
    const { paciente_id, medico_id, fecha, hora, motivo, observaciones } = req.body;

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

    // Verificar que el médico esté activo
    if (!medico.activo) {
      return sendError(res, 'El médico seleccionado no está activo', 400);
    }

    // Verificar disponibilidad (no doble agenda)
    const existeCita = citas.find(
      (c) =>
        c.medico_id === parseInt(medico_id) &&
        c.fecha === fecha &&
        c.hora === hora &&
        c.estado !== 'cancelada'
    );

    if (existeCita) {
      return sendError(res, 'El médico ya tiene una cita programada en esa fecha y hora', 400);
    }

    const nuevaCita = {
      id: nextId(citas),
      paciente_id: parseInt(paciente_id),
      medico_id: parseInt(medico_id),
      fecha,
      hora,
      motivo,
      estado: ESTADOS_CITA.PROGRAMADA,
      observaciones: observaciones || '',
      creado_en: new Date().toISOString(),
      actualizado_en: new Date().toISOString(),
    };

    citas.push(nuevaCita);
    return sendSuccess(res, nuevaCita, 'Cita creada exitosamente', 201);
  } catch (error) {
    return sendError(res, 'Error al crear cita', 500);
  }
};

/**
 * PUT /api/citas/:id
 * Reprogramar cita (cambiar fecha/hora)
 */
const update = async (req, res) => {
  try {
    const index = citas.findIndex((c) => c.id === parseInt(req.params.id));
    if (index === -1) {
      return sendError(res, 'Cita no encontrada', 404);
    }

    if (citas[index].estado === 'completada' || citas[index].estado === 'cancelada') {
      return sendError(res, 'No se puede reprogramar una cita completada o cancelada', 400);
    }

    const { fecha, hora, motivo, observaciones } = req.body;

    // Verificar disponibilidad si cambia fecha/hora
    if (fecha || hora) {
      const nuevaFecha = fecha || citas[index].fecha;
      const nuevaHora = hora || citas[index].hora;

      const existeCita = citas.find(
        (c) =>
          c.medico_id === citas[index].medico_id &&
          c.fecha === nuevaFecha &&
          c.hora === nuevaHora &&
          c.id !== citas[index].id &&
          c.estado !== 'cancelada'
      );

      if (existeCita) {
        return sendError(res, 'El médico ya tiene una cita programada en esa fecha y hora', 400);
      }
    }

    citas[index] = {
      ...citas[index],
      fecha: fecha || citas[index].fecha,
      hora: hora || citas[index].hora,
      motivo: motivo || citas[index].motivo,
      observaciones: observaciones !== undefined ? observaciones : citas[index].observaciones,
      actualizado_en: new Date().toISOString(),
    };

    return sendSuccess(res, citas[index], 'Cita reprogramada exitosamente');
  } catch (error) {
    return sendError(res, 'Error al actualizar cita', 500);
  }
};

/**
 * PATCH /api/citas/:id/estado
 * Cambiar estado de la cita
 */
const updateEstado = async (req, res) => {
  try {
    const cita = citas.find((c) => c.id === parseInt(req.params.id));
    if (!cita) {
      return sendError(res, 'Cita no encontrada', 404);
    }

    const { estado } = req.body;

    // Validar transición de estados
    const estadosPermitidos = Object.values(ESTADOS_CITA);
    if (!estadosPermitidos.includes(estado)) {
      return sendError(res, `Estado inválido. Valores permitidos: ${estadosPermitidos.join(', ')}`, 400);
    }

    cita.estado = estado;
    cita.actualizado_en = new Date().toISOString();

    return sendSuccess(res, cita, 'Estado de cita actualizado');
  } catch (error) {
    return sendError(res, 'Error al actualizar estado', 500);
  }
};

/**
 * DELETE /api/citas/:id
 * Cancelar cita
 */
const remove = async (req, res) => {
  try {
    const cita = citas.find((c) => c.id === parseInt(req.params.id));
    if (!cita) {
      return sendError(res, 'Cita no encontrada', 404);
    }

    if (cita.estado === 'cancelada') {
      return sendError(res, 'La cita ya está cancelada', 400);
    }

    cita.estado = 'cancelada';
    cita.actualizado_en = new Date().toISOString();

    return sendSuccess(res, null, 'Cita cancelada exitosamente');
  } catch (error) {
    return sendError(res, 'Error al cancelar cita', 500);
  }
};

module.exports = {
  getAll,
  getById,
  create,
  update,
  updateEstado,
  remove,
  getHoy,
  getByMedico,
  getByPaciente,
};
