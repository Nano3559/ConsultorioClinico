'use strict';

/**
 * Carga la app Express con el Supabase mockeado inyectado, de modo que los
 * tests puedan golpear la API real (/api/auth/login) sin base de datos real.
 */

const path = require('path');
const mock = require('mock-require');
const supabaseMock = require('../mocks/supabaseMock');

// Ruta absoluta del módulo que los controllers requieren como '../config/supabase'
const supabasePath = path.resolve(__dirname, '../../src/config/supabase.js');

/** Devuelve la app Express lista para usar con supertest. */
function getApp() {
  mock(supabasePath, {
    getSupabase: supabaseMock.getSupabase,
    dbErrorMessage: (error) => {
      if (!error) return null;
      if (error.code === '23505' || /duplicate key/i.test(error.message || '')) {
        return 'Ya existe un registro con esos datos únicos';
      }
      if (error.code === '42P01' || /does not exist/i.test(error.message || '')) {
        return 'La tabla no existe. Ejecuta la migración en Supabase (db/migrations)';
      }
      if (error.code === '23503' || /violates foreign key/i.test(error.message || '')) {
        return 'El registro referencia a otro inexistente';
      }
      return null;
    },
  });

  // Limpiar cache del app y de authController para que re-lean el mock
  delete require.cache[path.resolve(__dirname, '../../src/app.js')];
  delete require.cache[path.resolve(__dirname, '../../src/controllers/authController.js')];
  delete require.cache[path.resolve(__dirname, '../../src/routes/authRoutes.js')];
  delete require.cache[path.resolve(__dirname, '../../src/middleware/rateLimiter.js')];

  const app = require('../../src/app');
  return app;
}

/** Restaura los módulos reales tras los tests. */
function restore() {
  mock.stopAll();
  delete require.cache[path.resolve(__dirname, '../../src/app.js')];
  delete require.cache[path.resolve(__dirname, '../../src/controllers/authController.js')];
  delete require.cache[path.resolve(__dirname, '../../src/routes/authRoutes.js')];
}

module.exports = { getApp, restore };
