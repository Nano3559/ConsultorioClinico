const app = require('./app');
const config = require('./config/config');

const PORT = config.port || 3000;

const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`✅ Servidor corriendo en http://localhost:${PORT}`);
  console.log(`✅ Health check: http://localhost:${PORT}/api/health`);
  console.log(`✅ Presiona Ctrl+C para detener`);
});

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`❌ El puerto ${PORT} ya está en uso. Cierra el proceso o usa otro PORT.`);
    process.exit(1);
  } else {
    console.error('Error del servidor:', err);
    process.exit(1);
  }
});
