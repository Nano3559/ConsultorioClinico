const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const dotenv = require('dotenv');

dotenv.config();

const config = require('./config/config');
const app = express();

// Middlewares generales
app.use(helmet());
app.use(compression());

// CORS restringido: solo orígenes explícitamente permitidos (CORS_ORIGINS).
// - Con Origin presente (navegador) y no permitido => se bloquea.
// - Sin Origin (server-to-server, curl, postman) => se permite sin cabecera.
app.use(
  cors({
    origin(origin, callback) {
      if (!origin) return callback(null, true);
      if (config.corsOrigins.length === 0) {
        return callback(null, false);
      }
      if (config.corsOrigins.includes(origin)) {
        return callback(null, true);
      }
      return callback(null, false);
    },
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    maxAge: 86400,
  })
);

app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));
app.use(morgan('dev'));

// Ruta raíz
app.get('/', (req, res) => {
  res.json({
    status: 'OK',
    message: 'API del Consultorio Clínico funcionando',
    endpoints: {
      health: '/api/health',
      auth: '/api/auth',
      pacientes: '/api/pacientes',
      medicos: '/api/medicos',
      especialidades: '/api/especialidades',
      horarios: '/api/horarios',
      citas: '/api/citas',
      disponibilidad: '/api/disponibilidad',
      consultas: '/api/consultas',
      pagos: '/api/pagos',
      reportes: '/api/reportes',
      dashboard: '/api/dashboard'
    }
  });
});

// Rutas de diagnóstico: SOLO disponibles en desarrollo (evita fugas de info
// de configuración en producción).
if (config.nodeEnv === 'development') {
  app.use('/api/test', require('./routes/testRoutes'));
}

// Rutas
app.use('/api/auth', require('./routes/authRoutes'));
app.use('/api/pacientes', require('./routes/pacienteRoutes'));
app.use('/api/medicos', require('./routes/medicoRoutes'));
app.use('/api/especialidades', require('./routes/especialidadRoutes'));
app.use('/api/horarios', require('./routes/horarioRoutes'));
app.use('/api/citas', require('./routes/citaRoutes'));
app.use('/api/disponibilidad', require('./routes/disponibilidadRoutes'));
app.use('/api/consultas', require('./routes/consultaRoutes'));
app.use('/api/pagos', require('./routes/pagoRoutes'));
app.use('/api/reportes', require('./routes/reporteRoutes'));
app.use('/api/dashboard', require('./routes/dashboardRoutes'));

// Health check (info mínima, sin datos sensibles)
app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', message: 'API funcionando' });
});

// 404 para rutas no encontradas
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: 'Ruta no encontrada',
  });
});

// Manejador global de errores
app.use((err, req, res, next) => {
  if (err && err.message === 'Not allowed by CORS') {
    return res.status(403).json({
      success: false,
      message: 'Origen no permitido por política CORS',
    });
  }
  console.error(err.stack);
  res.status(err.status || 500).json({
    success: false,
    message: err.message || 'Error interno del servidor',
    error: config.nodeEnv === 'development' ? err : {},
  });
});

// Exportar app para Vercel y para server.js
module.exports = app;