const { getSupabase } = require('../config/supabase');
const { sendSuccess, sendError } = require('../utils/helpers');

/**
 * GET /api/reportes/citas
 * Reporte de citas con filtros
 */
const reporteCitas = async (req, res) => {
  try {
    const supabase = getSupabase();
    const { fecha_inicio, fecha_fin, medico_id, especialidad, estado } = req.query;

    let query = supabase.from('citas').select('*').order('fecha').order('hora');
    if (fecha_inicio) query = query.gte('fecha', fecha_inicio);
    if (fecha_fin) query = query.lte('fecha', fecha_fin);
    if (medico_id) query = query.eq('medico_id', medico_id);
    if (estado) query = query.eq('estado', estado);

    let resultado;
    if (especialidad) {
      // Filtra por especialidad a través de los médicos que coinciden
      const { data: medicos, error: medError } = await supabase
        .from('medicos')
        .select('id')
        .ilike('especialidad', `%${especialidad}%`);
      if (medError) throw medError;

      const idsMedicos = (medicos || []).map((m) => m.id);
      if (idsMedicos.length === 0) resultado = [];
      else resultado = await aplicarFiltros(query.in('medico_id', idsMedicos));
    } else {
      resultado = await aplicarFiltros(query);
    }

    async function aplicarFiltros(q) {
      const { data, error } = await q;
      if (error) throw error;
      return data || [];
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
    console.error('reportes.reporteCitas:', error);
    return sendError(res, 'Error al generar reporte de citas', 500);
  }
};

/**
 * GET /api/reportes/ingresos
 * Reporte de ingresos por período
 */
const reporteIngresos = async (req, res) => {
  try {
    const supabase = getSupabase();
    const { fecha_inicio, fecha_fin, metodo_pago } = req.query;

    let query = supabase.from('pagos').select('*').eq('estado', 'pagado');
    if (fecha_inicio) query = query.gte('fecha_pago', fecha_inicio);
    if (fecha_fin) query = query.lte('fecha_pago', `${fecha_fin}T23:59:59`);
    if (metodo_pago) query = query.eq('metodo_pago', metodo_pago);

    const { data: pagosFiltrados, error } = await query;
    if (error) throw error;

    const pagos = pagosFiltrados || [];

    // Calcular total
    const totalIngresos = pagos.reduce((sum, p) => sum + parseFloat(p.monto), 0);

    // Ingresos por método de pago
    const porMetodo = pagos.reduce((acc, p) => {
      acc[p.metodo_pago] = (acc[p.metodo_pago] || 0) + parseFloat(p.monto);
      return acc;
    }, {});

    return sendSuccess(res, {
      pagos,
      estadisticas: {
        total_ingresos: totalIngresos,
        cantidad_pagos: pagos.length,
        promedio_pago: pagos.length > 0
          ? (totalIngresos / pagos.length).toFixed(2)
          : 0,
        por_metodo_pago: porMetodo,
      },
    });
  } catch (error) {
    console.error('reportes.reporteIngresos:', error);
    return sendError(res, 'Error al generar reporte de ingresos', 500);
  }
};

module.exports = {
  reporteCitas,
  reporteIngresos,
};
