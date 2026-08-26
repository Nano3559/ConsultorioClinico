const express = require('express');
const router = express.Router();

router.get('/env', (req, res) => {
  const envInfo = {
    SUPABASE_URL: process.env.SUPABASE_URL ? '✅ Configurada' : '❌ NO configurada',
    SUPABASE_URL_VALUE: process.env.SUPABASE_URL || 'vacío',
    SUPABASE_ANON_KEY: process.env.SUPABASE_ANON_KEY ? '✅ Configurada' : '❌ NO configurada',
    SUPABASE_ANON_KEY_PREFIX: process.env.SUPABASE_ANON_KEY
      ? process.env.SUPABASE_ANON_KEY.substring(0, 30) + '...'
      : 'N/A',
    SUPABASE_SERVICE_ROLE_KEY: process.env.SUPABASE_SERVICE_ROLE_KEY
      ? '✅ Configurada'
      : '❌ NO configurada',
    JWT_SECRET: process.env.JWT_SECRET ? '✅ Configurada' : '❌ NO configurada',
    NODE_ENV: process.env.NODE_ENV || 'no definido',
  };
  res.json({ success: true, data: envInfo });
});

router.get('/db', async (req, res) => {
  try {
    const { getSupabase } = require('../config/supabase');
    const supabase = getSupabase();

    const { data, error, count } = await supabase
      .from('medicos')
      .select('*', { count: 'exact', head: true });

    if (error) {
      return res.json({
        success: false,
        message: 'Error al conectar con la tabla medicos',
        error: {
          code: error.code,
          message: error.message,
          details: error.details,
          hint: error.hint,
        },
      });
    }

    res.json({
      success: true,
      message: 'Conexión exitosa con tabla medicos',
      totalRegistros: count,
    });
  } catch (err) {
    res.json({
      success: false,
      message: 'Excepción al conectar',
      error: {
        name: err.name,
        message: err.message,
        stack: process.env.NODE_ENV === 'development' ? err.stack : undefined,
      },
    });
  }
});

module.exports = router;
