const { medicos, horarios, citas, especialidades } = require('../data/mockData');
const {
  sendSuccess,
  sendError,
  formatDate,
  normalizarTexto,
  obtenerDiaSemana,
  horaAMinutos,
  minutosAHora,
} = require('../utils/helpers');
const { INTERVALO_CITA_MINUTOS, ESTADOS_CITA } = require('../utils/constants');

/**
 * Genera los slots libres de un médico en una fecha,
 * según sus horarios activos y las citas ya tomadas.
 */
const generarSlotsDisponibles = (medicoId, fecha) => {
  const diaSemana = obtenerDiaSemana(fecha);
  const esHoy = fecha === formatDate(new Date());
  const ahoraMinutos = new Date().getHours() * 60 + new Date().getMinutes();

  const bloques = horarios.filter(
    (h) => h.medico_id === medicoId && h.activo && h.dia_semana === diaSemana
  );

  const citasOcupadas = citas.filter(
    (c) =>
      c.medico_id === medicoId &&
      c.fecha === fecha &&
      c.estado !== ESTADOS_CITA.CANCELADA
  );

  const slots = [];

  for (const bloque of bloques) {
    for (
      let mins = horaAMinutos(bloque.hora_inicio);
      mins + INTERVALO_CITA_MINUTOS <= horaAMinutos(bloque.hora_fin);
      mins += INTERVALO_CITA_MINUTOS
    ) {
      const slot = minutosAHora(mins);

      // Descartar horas pasadas si la consulta es para hoy
      if (esHoy && mins <= ahoraMinutos) continue;

      // Descartar slots ya reservados
      const ocupado = citasOcupadas.some((c) => c.hora === slot);
      if (ocupado) continue;

      if (!slots.includes(slot)) slots.push(slot);
    }
  }

  return { diaSemana, slots: slots.sort() };
};

/**
 * GET /api/disponibilidad/medico/:medicoId/fecha/:fecha
 * Ver horarios disponibles de un médico en una fecha (público)
 */
const getPorMedicoYFecha = async (req, res) => {
  try {
    const medicoId = parseInt(req.params.medicoId);
    const fecha = req.params.fecha;

    const medico = medicos.find((m) => m.id === medicoId);
    if (!medico) {
      return sendError(res, 'Médico no encontrado', 404);
    }
    if (!medico.activo) {
      return sendError(res, 'El médico no está activo actualmente', 400);
    }

    const hoy = formatDate(new Date());
    if (fecha < hoy) {
      return sendError(res, 'No se puede consultar disponibilidad de fechas pasadas', 400);
    }

    const { diaSemana, slots } = generarSlotsDisponibles(medicoId, fecha);

    return sendSuccess(res, {
      medico_id: medicoId,
      medico: `${medico.nombre} ${medico.apellido}`,
      fecha,
      dia_semana: diaSemana,
      intervalo_minutos: INTERVALO_CITA_MINUTOS,
      slots_disponibles: slots,
      total_disponibles: slots.length,
    });
  } catch (error) {
    return sendError(res, 'Error al consultar disponibilidad del médico', 500);
  }
};

/**
 * GET /api/disponibilidad/especialidad/:especialidadId
 * Médicos disponibles por especialidad con sus días de atención (público)
 */
const getMedicosPorEspecialidad = async (req, res) => {
  try {
    const especialidad = especialidades.find((e) => e.id === parseInt(req.params.especialidadId));
    if (!especialidad) {
      return sendError(res, 'Especialidad no encontrada', 404);
    }
    if (!especialidad.activo) {
      return sendError(res, 'La especialidad no está activa actualmente', 400);
    }

    const medicosDisponibles = medicos
      .filter(
        (m) =>
          m.activo &&
          normalizarTexto(m.especialidad) === normalizarTexto(especialidad.nombre)
      )
      .map((m) => ({
        id: m.id,
        nombre: m.nombre,
        apellido: m.apellido,
        consulorio: m.consulorio,
        tarifa_consulta: m.tarifa_consulta,
        dias_atencion: [
          ...new Set(
            horarios
              .filter((h) => h.medico_id === m.id && h.activo)
              .map((h) => h.dia_semana)
          ),
        ],
      }));

    return sendSuccess(res, {
      especialidad_id: especialidad.id,
      especialidad: especialidad.nombre,
      medicos_disponibles: medicosDisponibles,
      total_medicos: medicosDisponibles.length,
    });
  } catch (error) {
    return sendError(res, 'Error al consultar médicos por especialidad', 500);
  }
};

module.exports = {
  getPorMedicoYFecha,
  getMedicosPorEspecialidad,
};
