const app = require('./app');

// Usa puerto 0 para que Node.js asigne uno automáticamente
const PORT = 0;

const server = app.listen(PORT, '127.0.0.1', () => {
    const actualPort = server.address().port;
    console.log(`✅ Servidor corriendo en http://localhost:${actualPort}`);
    console.log(`✅ Health check: http://localhost:${actualPort}/api/health`);
    console.log(`✅ Presiona Ctrl+C para detener`);
});

server.on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
        console.log('❌ Puerto ocupado, reintentando...');
    } else {
        console.error('Error:', err);
    }
});