const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middleware/auth');
const { checkRole } = require('../middleware/roles');

// Estas rutas solo se montan en desarrollo (ver app.js) y además exigen
// un token de administrador para no exponer detalles de configuración.

router.use(verifyToken);
router.use(checkRole('admin'));

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