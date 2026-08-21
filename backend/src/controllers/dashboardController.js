const { pacientes, medicos, citas, pagos } = require('../data/mockData');
const { sendSuccess, sendError, formatDate } = require('../utils/helpers');

/**
 * GET /api/dashboard
 * Resumen general del dashboard
 */
const getResumen = async (req, res) => {
  try {
    const hoy = formatDate(new Date());
    const mesActual = new Date().toISOString().slice(0, 7); // YYYY-MM

    // Total de pacientes activos
    const totalPacientes = pacientes.filter((p) => p.activo).length;

    // Citas de hoy
    const citasHoy = citas.filter((c) => c.fecha === hoy);
    const totalCitasHoy = citasHoy.length;
    const citasHoyCompletadas = citasHoy.filter((c) => c.estado === 'completada').length;
    const citasHoyPendientes = citasHoy.filter((c) => c.estado === 'programada').length;

    // Médicos activos
    const medicosActivos = medicos.filter((m) => m.activo).length;

    // Ingresos del mes
    const pagosMes = pagos.filter(
      (p) => p.estado === 'pagado' && p.fecha_pago && p.fecha_pago.startsWith(mesActual)
    );
    const ingresosMes = pagosMes.reduce((sum, p) => sum + p.monto, 0);

    // Citas por estado (general)
    const citasPorEstado = citas.reduce((acc, c) => {
      acc[c.estado] = (acc[c.estado] || 0) + 1;
      return acc;
    }, {});

    return sendSuccess(res, {
      total_pacientes: totalPacientes,
      citas_hoy: {
        total: totalCitasHoy,
        completadas: citasHoyCompletadas,
        pendientes: citasHoyPendientes,
      },
      medicos_activos: medicosActivos,
      ingresos_mes: {
        total: ingresosMes,
        cantidad_pagos: pagosMes.length,
      },
      citas_por_estado: citasPorEstado,
    });
  } catch (error) {
    return sendError(res, 'Error al obtener resumen del dashboard', 500);
  }
};

module.exports = {
  getResumen,
};
