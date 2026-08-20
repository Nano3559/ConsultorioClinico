const { citas, pagos, medicos } = require('../data/mockData');
const { sendSuccess, sendError } = require('../utils/helpers');

/**
 * GET /api/reportes/citas
 * Reporte de citas con filtros
 */
const reporteCitas = async (req, res) => {
  try {
    let resultado = [...citas];
    const { fecha_inicio, fecha_fin, medico_id, especialidad, estado } = req.query;

    // Filtro por rango de fechas
    if (fecha_inicio) {
      resultado = resultado.filter((c) => c.fecha >= fecha_inicio);
    }
    if (fecha_fin) {
      resultado = resultado.filter((c) => c.fecha <= fecha_fin);
    }

    // Filtro por médico
    if (medico_id) {
      resultado = resultado.filter((c) => c.medico_id === parseInt(medico_id));
    }

    // Filtro por especialidad
    if (especialidad) {
      const medicosFiltrados = medicos.filter(
        (m) => m.especialidad.toLowerCase().includes(especialidad.toLowerCase())
      );
      const idsMedicos = medicosFiltrados.map((m) => m.id);
      resultado = resultado.filter((c) => idsMedicos.includes(c.medico_id));
    }

    // Filtro por estado
    if (estado) {
      resultado = resultado.filter((c) => c.estado === estado);
    }

    // Estadísticas del reporte
    const total = resultado.length;
    const completadas = resultado.filter((c) => c.estado === 'completada').length;
    const canceladas = resultado.filter((c) => c.estado === 'cancelada').length;
    const programadas = resultado.filter((c) => c.estado === 'programada').length;

    return sendSuccess(res, {
      citas: resultado,
      estadisticas: {
        total,
        completadas,
        canceladas,
        programadas,
        tasa_completadas: total > 0 ? ((completadas / total) * 100).toFixed(1) + '%' : '0%',
      },
    });
  } catch (error) {
    return sendError(res, 'Error al generar reporte de citas', 500);
  }
};

/**
 * GET /api/reportes/ingresos
 * Reporte de ingresos por período
 */
const reporteIngresos = async (req, res) => {
  try {
    let pagosFiltrados = [...pagos];
    const { fecha_inicio, fecha_fin, metodo_pago } = req.query;

    // Filtrar solo pagos confirmados
    pagosFiltrados = pagosFiltrados.filter((p) => p.estado === 'pagado');

    // Filtro por rango de fechas
    if (fecha_inicio) {
      pagosFiltrados = pagosFiltrados.filter(
        (p) => p.fecha_pago && p.fecha_pago >= fecha_inicio
      );
    }
    if (fecha_fin) {
      pagosFiltrados = pagosFiltrados.filter(
        (p) => p.fecha_pago && p.fecha_pago <= fecha_fin
      );
    }

    // Filtro por método de pago
    if (metodo_pago) {
      pagosFiltrados = pagosFiltrados.filter((p) => p.metodo_pago === metodo_pago);
    }

    // Calcular total
    const totalIngresos = pagosFiltrados.reduce((sum, p) => sum + p.monto, 0);

    // Ingresos por método de pago
    const porMetodo = pagosFiltrados.reduce((acc, p) => {
      acc[p.metodo_pago] = (acc[p.metodo_pago] || 0) + p.monto;
      return acc;
    }, {});

    return sendSuccess(res, {
      pagos: pagosFiltrados,
      estadisticas: {
        total_ingresos: totalIngresos,
        cantidad_pagos: pagosFiltrados.length,
        promedio_pago: pagosFiltrados.length > 0
          ? (totalIngresos / pagosFiltrados.length).toFixed(2)
          : 0,
        por_metodo_pago: porMetodo,
      },
    });
  } catch (error) {
    return sendError(res, 'Error al generar reporte de ingresos', 500);
  }
};

module.exports = {
  reporteCitas,
  reporteIngresos,
};
