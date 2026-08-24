const { horarios, medicos } = require('../data/mockData');
const {
  sendSuccess,
  sendError,
  nextId,
  horaAMinutos,
} = require('../utils/helpers');

/**
 * Verifica si un horario se solapa con otro del mismo médico y día
 */
const existeSolapamiento = (medicoId, diaSemana, horaInicio, horaFin, idExcluido = null) =>
  horarios.some(
    (h) =>
      h.medico_id === medicoId &&
      h.dia_semana === diaSemana &&
      h.id !== idExcluido &&
      horaAMinutos(horaInicio) < horaAMinutos(h.hora_fin) &&
      horaAMinutos(horaFin) > horaAMinutos(h.hora_inicio)
  );

/**
 * GET /api/horarios
 * Listar todos los horarios (público)
 */
const getAll = async (req, res) => {
  try {
    return sendSuccess(res, horarios);
  } catch (error) {
    return sendError(res, 'Error al listar horarios', 500);
  }
};

/**
 * GET /api/horarios/medico/:medicoId
 * Horarios por médico (público)
 */
const getByMedico = async (req, res) => {
  try {
    const medico = medicos.find((m) => m.id === parseInt(req.params.medicoId));
    if (!medico) {
      return sendError(res, 'Médico no encontrado', 404);
    }

    const horariosMedico = horarios.filter((h) => h.medico_id === medico.id);
    return sendSuccess(res, horariosMedico);
  } catch (error) {
    return sendError(res, 'Error al obtener horarios del médico', 500);
  }
};

/**
 * GET /api/horarios/disponibles
 * Horarios disponibles (activos y de médicos activos) - público
 */
const getDisponibles = async (req, res) => {
  try {
    const idsMedicosActivos = medicos
      .filter((m) => m.activo)
      .map((m) => m.id);

    const disponibles = horarios.filter(
      (h) => h.activo && idsMedicosActivos.includes(h.medico_id)
    );
    return sendSuccess(res, disponibles);
  } catch (error) {
    return sendError(res, 'Error al obtener horarios disponibles', 500);
  }
};

/**
 * POST /api/horarios
 * Crear horario (admin)
 */
const create = async (req, res) => {
  try {
    const { medico_id, dia_semana, hora_inicio, hora_fin } = req.body;

    // Verificar que el médico exista
    const medico = medicos.find((m) => m.id === parseInt(medico_id));
    if (!medico) {
      return sendError(res, 'Médico no encontrado', 404);
    }

    // Validar coherencia de horas
    if (horaAMinutos(hora_inicio) >= horaAMinutos(hora_fin)) {
      return sendError(res, 'La hora de inicio debe ser menor a la hora de fin', 400);
    }

    // Validar que no se solape con otro horario del mismo médico y día
    if (existeSolapamiento(medico.id, dia_semana, hora_inicio, hora_fin)) {
      return sendError(res, 'El médico ya tiene un horario que se solapa en ese día', 409);
    }

    const nuevoHorario = {
      id: nextId(horarios),
      medico_id: medico.id,
      dia_semana,
      hora_inicio,
      hora_fin,
      activo: true,
    };

    horarios.push(nuevoHorario);
    return sendSuccess(res, nuevoHorario, 'Horario creado exitosamente', 201);
  } catch (error) {
    return sendError(res, 'Error al crear horario', 500);
  }
};

/**
 * PUT /api/horarios/:id
 * Actualizar horario (admin)
 */
const update = async (req, res) => {
  try {
    const index = horarios.findIndex((h) => h.id === parseInt(req.params.id));
    if (index === -1) {
      return sendError(res, 'Horario no encontrado', 404);
    }

    const { medico_id, dia_semana, hora_inicio, hora_fin } = req.body;

    // Verificar que el médico (nuevo o actual) exista
    if (medico_id) {
      const medico = medicos.find((m) => m.id === parseInt(medico_id));
      if (!medico) {
        return sendError(res, 'Médico no encontrado', 404);
      }
    }

    const datosFinales = {
      medico_id: medico_id ? parseInt(medico_id) : horarios[index].medico_id,
      dia_semana: dia_semana || horarios[index].dia_semana,
      hora_inicio: hora_inicio || horarios[index].hora_inicio,
      hora_fin: hora_fin || horarios[index].hora_fin,
    };

    // Validar coherencia de horas
    if (horaAMinutos(datosFinales.hora_inicio) >= horaAMinutos(datosFinales.hora_fin)) {
      return sendError(res, 'La hora de inicio debe ser menor a la hora de fin', 400);
    }

    // Validar solapamiento excluyendo el horario actual
    if (
      existeSolapamiento(
        datosFinales.medico_id,
        datosFinales.dia_semana,
        datosFinales.hora_inicio,
        datosFinales.hora_fin,
        horarios[index].id
      )
    ) {
      return sendError(res, 'El médico ya tiene un horario que se solapa en ese día', 409);
    }

    horarios[index] = {
      ...horarios[index],
      ...datosFinales,
    };

    return sendSuccess(res, horarios[index], 'Horario actualizado exitosamente');
  } catch (error) {
    return sendError(res, 'Error al actualizar horario', 500);
  }
};

/**
 * DELETE /api/horarios/:id
 * Eliminar horario (admin)
 */
const remove = async (req, res) => {
  try {
    const index = horarios.findIndex((h) => h.id === parseInt(req.params.id));
    if (index === -1) {
      return sendError(res, 'Horario no encontrado', 404);
    }

    horarios.splice(index, 1);
    return sendSuccess(res, null, 'Horario eliminado exitosamente');
  } catch (error) {
    return sendError(res, 'Error al eliminar horario', 500);
  }
};

module.exports = {
  getAll,
  getByMedico,
  getDisponibles,
  create,
  update,
  remove,
};
