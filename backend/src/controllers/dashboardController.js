const { getSupabase } = require('../config/supabase');
const { sendSuccess, sendError, formatDate } = require('../utils/helpers');

/**
 * GET /api/dashboard
 * Resumen general del dashboard
 */
const getResumen = async (req, res) => {
  try {
    const hoy = formatDate(new Date());
    const mesActual = new Date().toISOString().slice(0, 7); // YYYY-MM
    const supabase = getSupabase();

    const [pacientesRes, citasHoyRes, medicosRes, pagosMesRes, citasEstadoRes] = await Promise.all([
      supabase.from('pacientes').select('id', { count: 'exact', head: true }).eq('activo', true),
      supabase.from('citas').select('estado').eq('fecha', hoy),
      supabase.from('medicos').select('id', { count: 'exact', head: true }).eq('activo', true),
      supabase
        .from('pagos')
        .select('monto')
        .eq('estado', 'pagado')
        .gte('fecha_pago', `${mesActual}-01T00:00:00`),
      supabase.from('citas').select('estado'),
    ]);

    if (pacientesRes.error) throw pacientesRes.error;
    if (citasHoyRes.error) throw citasHoyRes.error;
    if (medicosRes.error) throw medicosRes.error;
    if (pagosMesRes.error) throw pagosMesRes.error;

    const citasHoy = citasHoyRes.data || [];
    const pagosMes = pagosMesRes.data || [];
    const ingresosMes = pagosMes.reduce((sum, p) => sum + parseFloat(p.monto), 0);

    const citasPorEstado = (citasEstadoRes.data || []).reduce((acc, c) => {
      acc[c.estado] = (acc[c.estado] || 0) + 1;
      return acc;
    }, {});

    return sendSuccess(res, {
      total_pacientes: pacientesRes.count,
      citas_hoy: {
        total: citasHoy.length,
        completadas: citasHoy.filter((c) => c.estado === 'completada').length,
        pendientes: citasHoy.filter((c) => c.estado === 'programada').length,
      },
      medicos_activos: medicosRes.count,
      ingresos_mes: {
        total: ingresosMes,
        cantidad_pagos: pagosMes.length,
      },
      citas_por_estado: citasPorEstado,
    });
  } catch (error) {
    console.error('dashboard.getResumen:', error);
    return sendError(res, 'Error al obtener resumen del dashboard', 500);
  }
};

module.exports = {
  getResumen,
};
