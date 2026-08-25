const { getSupabase } = require('../config/supabase');
const { sendSuccess, sendError, formatDate } = require('../utils/helpers');

/**
 * GET /api/disponibilidad/medico/:medicoId/fecha/:fecha
 * Ver horarios disponibles de un médico en una fecha específica
 */
const getDisponibilidadByMedico = async (req, res) => {
  try {
    const { medicoId, fecha } = req.params;
    const supabase = getSupabase();

    // Verificar que el médico existe y está activo
    const { data: medico, error: medError } = await supabase
      .from('medicos')
      .select('id, nombre, apellido, especialidad')
      .eq('id', medicoId)
      .eq('activo', true)
      .limit(1);

    if (medError) throw medError;
    if (!medico || medico.length === 0) {
      return sendError(res, 'Médico no encontrado o inactivo', 404);
    }

    // Obtener día de la semana de la fecha
    const fechaObj = new Date(fecha);
    const diasSemana = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
    const diaSemana = diasSemana[fechaObj.getDay()];

    // Obtener horarios del médico para ese día
    const { data: horarios, error: horError } = await supabase
      .from('horarios')
      .select('*')
      .eq('medico_id', medicoId)
      .eq('dia_semana', diaSemana)
      .eq('activo', true);

    if (horError) throw horError;

    // Obtener citas ocupadas para esa fecha
    const { data: citasOcupadas, error: citError } = await supabase
      .from('citas')
      .select('hora, estado')
      .eq('medico_id', medicoId)
      .eq('fecha', fecha)
      .neq('estado', 'cancelada');

    if (citError) throw citError;

    const horasOcupadas = (citasOcupadas || []).map(c => c.hora);

    // Calcular horarios disponibles (cada hora)
    const horariosDisponibles = [];
    if (horarios && horarios.length > 0) {
      for (const h of horarios) {
        // Generar horas desde hora_inicio hasta hora_fin (cada 60 minutos)
        let horaActual = h.hora_inicio;
        const horaFin = h.hora_fin;
        
        while (horaActual < horaFin) {
          const disponible = !horasOcupadas.includes(horaActual);
          horariosDisponibles.push({
            hora: horaActual,
            disponible: disponible
          });
          // Incrementar 1 hora
          const [hh, mm] = horaActual.split(':').map(Number);
          const nextHour = new Date(0, 0, 0, hh + 1, mm);
          horaActual = `${String(nextHour.getHours()).padStart(2, '0')}:${String(nextHour.getMinutes()).padStart(2, '0')}`;
        }
      }
    }

    return sendSuccess(res, {
      medico: medico[0],
      fecha,
      dia_semana: diaSemana,
      horarios: horariosDisponibles
    });

  } catch (error) {
    console.error('disponibilidad.getDisponibilidadByMedico:', error);
    return sendError(res, 'Error al obtener disponibilidad del médico', 500);
  }
};

/**
 * GET /api/disponibilidad/especialidad/:especialidadId
 * Médicos disponibles por especialidad
 */
const getMedicosByEspecialidad = async (req, res) => {
  try {
    const { especialidadId } = req.params;
    const supabase = getSupabase();

    // Obtener la especialidad
    const { data: especialidad, error: espError } = await supabase
      .from('especialidades')
      .select('id, nombre')
      .eq('id', especialidadId)
      .eq('activo', true)
      .limit(1);

    if (espError) throw espError;
    if (!especialidad || especialidad.length === 0) {
      return sendError(res, 'Especialidad no encontrada', 404);
    }

    // Obtener médicos con esa especialidad
    const { data: medicos, error: medError } = await supabase
      .from('medicos')
      .select('id, nombre, apellido, especialidad, telefono, email')
      .eq('especialidad', especialidad[0].nombre)
      .eq('activo', true);

    if (medError) throw medError;

    return sendSuccess(res, {
      especialidad: especialidad[0],
      medicos: medicos || []
    });

  } catch (error) {
    console.error('disponibilidad.getMedicosByEspecialidad:', error);
    return sendError(res, 'Error al obtener médicos por especialidad', 500);
  }
};

module.exports = {
  getDisponibilidadByMedico,
  getMedicosByEspecialidad
};
