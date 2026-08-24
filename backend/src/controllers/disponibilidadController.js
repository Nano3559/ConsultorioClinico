const { getSupabase } = require('../config/supabase');
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
 * según sus horarios activos en la BD y las citas ya tomadas.
 */
async function generarSlotsDisponibles(supabase, medicoId, fecha) {
  const diaSemana = obtenerDiaSemana(fecha);
  const esHoy = fecha === formatDate(new Date());
  const ahoraMinutos = new Date().getHours() * 60 + new Date().getMinutes();

  const { data: bloques, error: horError } = await supabase
    .from('horarios')
    .select('hora_inicio, hora_fin')
    .eq('medico_id', medicoId)
    .eq('activo', true)
    .eq('dia_semana', diaSemana);
  if (horError) throw horError;

  const { data: citasOcupadas, error: citaError } = await supabase
    .from('citas')
    .select('hora')
    .eq('medico_id', medicoId)
    .eq('fecha', fecha)
    .neq('estado', ESTADOS_CITA.CANCELADA);
  if (citaError) throw citaError;

  const horasOcupadas = new Set((citasOcupadas || []).map((c) => c.hora.slice(0, 5)));
  const slots = [];

  for (const bloque of bloques || []) {
    for (
      let mins = horaAMinutos(bloque.hora_inicio);
      mins + INTERVALO_CITA_MINUTOS <= horaAMinutos(bloque.hora_fin);
      mins += INTERVALO_CITA_MINUTOS
    ) {
      const slot = minutosAHora(mins);

      // Descartar horas pasadas si la consulta es para hoy
      if (esHoy && mins <= ahoraMinutos) continue;

      // Descartar slots ya reservados
      if (horasOcupadas.has(slot)) continue;

      if (!slots.includes(slot)) slots.push(slot);
    }
  }

  return { diaSemana, slots: slots.sort() };
}

/**
 * GET /api/disponibilidad/medico/:medicoId/fecha/:fecha
 * Ver horarios disponibles de un médico en una fecha (público)
 */
const getPorMedicoYFecha = async (req, res) => {
  try {
    const supabase = getSupabase();
    const fecha = req.params.fecha;

    const { data: medicos } = await supabase
      .from('medicos')
      .select('id, nombre, apellido, activo')
      .eq('id', req.params.medicoId)
      .limit(1);
    const medico = medicos && medicos[0];

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

    const { diaSemana, slots } = await generarSlotsDisponibles(supabase, medico.id, fecha);

    return sendSuccess(res, {
      medico_id: medico.id,
      medico: `${medico.nombre} ${medico.apellido}`,
      fecha,
      dia_semana: diaSemana,
      intervalo_minutos: INTERVALO_CITA_MINUTOS,
      slots_disponibles: slots,
      total_disponibles: slots.length,
    });
  } catch (error) {
    console.error('disponibilidad.getPorMedicoYFecha:', error);
    return sendError(res, 'Error al consultar disponibilidad del médico', 500);
  }
};

/**
 * GET /api/disponibilidad/especialidad/:especialidadId
 * Médicos disponibles por especialidad con sus días de atención (público)
 */
const getMedicosPorEspecialidad = async (req, res) => {
  try {
    const supabase = getSupabase();

    const { data: especialidades } = await supabase
      .from('especialidades')
      .select('*')
      .eq('id', req.params.especialidadId)
      .limit(1);
    const especialidad = especialidades && especialidades[0];

    if (!especialidad) {
      return sendError(res, 'Especialidad no encontrada', 404);
    }
    if (!especialidad.activo) {
      return sendError(res, 'La especialidad no está activa actualmente', 400);
    }

    const { data: medicosCoincidentes, error: medError } = await supabase
      .from('medicos')
      .select('id, nombre, apellido, consulorio, tarifa_consulta')
      .eq('activo', true)
      .ilike('especialidad', especialidad.nombre);
    if (medError) throw medError;

    const idsMedicos = (medicosCoincidentes || []).map((m) => m.id);

    let diasPorMedico = {};
    if (idsMedicos.length > 0) {
      const { data: horariosMedicos, error: horError } = await supabase
        .from('horarios')
        .select('medico_id, dia_semana')
        .eq('activo', true)
        .in('medico_id', idsMedicos);
      if (horError) throw horError;

      for (const h of horariosMedicos || []) {
        if (!diasPorMedico[h.medico_id]) diasPorMedico[h.medico_id] = new Set();
        diasPorMedico[h.medico_id].add(h.dia_semana);
      }
    }

    const medicosDisponibles = (medicosCoincidentes || []).map((m) => ({
      id: m.id,
      nombre: m.nombre,
      apellido: m.apellido,
      consulorio: m.consulorio,
      tarifa_consulta: m.tarifa_consulta,
      dias_atencion: diasPorMedico[m.id] ? [...diasPorMedico[m.id]].sort() : [],
    }));

    return sendSuccess(res, {
      especialidad_id: especialidad.id,
      especialidad: especialidad.nombre,
      medicos_disponibles: medicosDisponibles,
      total_medicos: medicosDisponibles.length,
    });
  } catch (error) {
    console.error('disponibilidad.getMedicosPorEspecialidad:', error);
    return sendError(res, 'Error al consultar médicos por especialidad', 500);
  }
};

module.exports = {
  getPorMedicoYFecha,
  getMedicosPorEspecialidad,
};
