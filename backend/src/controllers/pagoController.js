const { getSupabase } = require('../config/supabase');
const { sendSuccess, sendError } = require('../utils/helpers');
const { ESTADOS_PAGO } = require('../utils/constants');

/**
 * GET /api/pagos
 * Listar todos los pagos
 */
const getAll = async (req, res) => {
  try {
    const supabase = getSupabase();
    const { data, error } = await supabase
      .from('pagos')
      .select('*')
      .order('creado_en', { ascending: false });

    if (error) throw error;
    return sendSuccess(res, data);
  } catch (error) {
    console.error('pagos.getAll:', error);
    return sendError(res, 'Error al listar pagos', 500);
  }
};

/**
 * POST /api/pagos
 * Registrar nuevo pago
 */
const create = async (req, res) => {
  try {
    const { paciente_id, cita_id, monto, metodo_pago, descripcion } = req.body;
    const supabase = getSupabase();

    // Verificar que el paciente exista
    const { data: pacientes } = await supabase
      .from('pacientes')
      .select('id')
      .eq('id', paciente_id)
      .limit(1);
    if (!pacientes || pacientes.length === 0) {
      return sendError(res, 'Paciente no encontrado', 404);
    }

    // Si se proporciona cita_id, verificar que exista
    if (cita_id) {
      const { data: citas } = await supabase
        .from('citas')
        .select('id')
        .eq('id', cita_id)
        .limit(1);
      if (!citas || citas.length === 0) {
        return sendError(res, 'Cita no encontrada', 404);
      }
    }

    const { data, error } = await supabase
      .from('pagos')
      .insert({
        paciente_id,
        cita_id: cita_id ? parseInt(cita_id) : null,
        monto: parseFloat(monto),
        metodo_pago,
        estado: ESTADOS_PAGO.PAGADO,
        descripcion: descripcion || '',
        fecha_pago: new Date().toISOString(),
      })
      .select('*')
      .single();

    if (error) throw error;
    return sendSuccess(res, data, 'Pago registrado exitosamente', 201);
  } catch (error) {
    console.error('pagos.create:', error);
    return sendError(res, 'Error al registrar pago', 500);
  }
};

/**
 * GET /api/pagos/paciente/:id
 * Obtener pagos por paciente
 */
const getByPaciente = async (req, res) => {
  try {
    const supabase = getSupabase();

    const { data: pacientes } = await supabase
      .from('pacientes')
      .select('id')
      .eq('id', req.params.id)
      .limit(1);
    if (!pacientes || pacientes.length === 0) {
      return sendError(res, 'Paciente no encontrado', 404);
    }

    const { data, error } = await supabase
      .from('pagos')
      .select('*')
      .eq('paciente_id', req.params.id)
      .order('creado_en', { ascending: false });

    if (error) throw error;
    return sendSuccess(res, data);
  } catch (error) {
    console.error('pagos.getByPaciente:', error);
    return sendError(res, 'Error al obtener pagos del paciente', 500);
  }
};

module.exports = {
  getAll,
  create,
  getByPaciente,
};
