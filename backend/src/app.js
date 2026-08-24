const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const dotenv = require('dotenv');

dotenv.config();

const app = express();

// Middlewares generales
app.use(helmet());
app.use(cors());
app.use(compression());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(morgan('dev'));

// Ruta raíz - ¡NUEVA!
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

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', message: 'API funcionando' });
});

// Manejador global de errores
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(err.status || 500).json({
    success: false,
    message: err.message || 'Error interno del servidor',
    error: process.env.NODE_ENV === 'development' ? err : {},
  });
});

// Exportar app para Vercel
module.exports = app;

// Iniciar servidor solo en desarrollo
if (process.env.NODE_ENV !== 'production') {
  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () => {
    console.log(`Servidor en http://localhost:${PORT}`);
  });
}
