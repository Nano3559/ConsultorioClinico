const { pagos, pacientes, citas } = require('../data/mockData');
const { sendSuccess, sendError, nextId } = require('../utils/helpers');

/**
 * GET /api/pagos
 * Listar todos los pagos
 */
const getAll = async (req, res) => {
  try {
    return sendSuccess(res, pagos);
  } catch (error) {
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

    // Verificar que el paciente exista
    const paciente = pacientes.find((p) => p.id === parseInt(paciente_id));
    if (!paciente) {
      return sendError(res, 'Paciente no encontrado', 404);
    }

    // Si se proporciona cita_id, verificar que exista
    if (cita_id) {
      const cita = citas.find((c) => c.id === parseInt(cita_id));
      if (!cita) {
        return sendError(res, 'Cita no encontrada', 404);
      }
    }

    const nuevoPago = {
      id: nextId(pagos),
      paciente_id: parseInt(paciente_id),
      cita_id: cita_id ? parseInt(cita_id) : null,
      monto: parseFloat(monto),
      metodo_pago,
      estado: 'pagado',
      descripcion: descripcion || '',
      fecha_pago: new Date().toISOString(),
      creado_en: new Date().toISOString(),
    };

    pagos.push(nuevoPago);
    return sendSuccess(res, nuevoPago, 'Pago registrado exitosamente', 201);
  } catch (error) {
    return sendError(res, 'Error al registrar pago', 500);
  }
};

/**
 * GET /api/pagos/paciente/:id
 * Obtener pagos por paciente
 */
const getByPaciente = async (req, res) => {
  try {
    const paciente = pacientes.find((p) => p.id === parseInt(req.params.id));
    if (!paciente) {
      return sendError(res, 'Paciente no encontrado', 404);
    }

    const pagosPaciente = pagos.filter((p) => p.paciente_id === paciente.id);
    return sendSuccess(res, pagosPaciente);
  } catch (error) {
    return sendError(res, 'Error al obtener pagos del paciente', 500);
  }
};

module.exports = {
  getAll,
  create,
  getByPaciente,
};
