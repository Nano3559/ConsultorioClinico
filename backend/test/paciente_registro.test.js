/**
 * Pruebas de registro de pacientes (Hito 5)
 * Verifica que el módulo de pacientes funcione correctamente:
 * - POST /api/pacientes permite rol medico
 * - Validaciones de campos obligatorios
 * - Backend y servicio IA responden
 */

const fs = require('fs');
const http = require('http');
const test = require('node:test');
const assert = require('node:assert/strict');

const BASE_URL = 'http://localhost:3000';

function request(path, options = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const reqOptions = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      method: options.method || 'GET',
      headers: options.headers || {},
      timeout: 10000,
    };
    if (options.body) {
      reqOptions.headers['Content-Type'] = 'application/json';
      reqOptions.headers['Content-Length'] = Buffer.byteLength(options.body);
    }
    const req = http.request(reqOptions, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        try {
          resolve({ statusCode: res.statusCode, body: JSON.parse(data) });
        } catch {
          resolve({ statusCode: res.statusCode, body: data });
        }
      });
    });
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('timeout')); });
    if (options.body) req.write(options.body);
    req.end();
  });
}

test('POST /api/pacientes permite rol medico (verificacion de configuracion)', async () => {
  const contenido = fs.readFileSync('./src/routes/pacienteRoutes.js', 'utf-8');
  assert.ok(
    contenido.includes("checkRole('admin', 'recepcion', 'medico')"),
    'La ruta POST /api/pacientes debe incluir el rol medico'
  );
  assert.ok(
    contenido.includes("router.post('/', verifyFlexible, checkRole('admin', 'recepcion', 'medico')"),
    'La ruta POST debe tener verifyFlexible y checkRole con medico'
  );
});

test('Validaciones de campos obligatorios en POST /api/pacientes', async () => {
  const contenido = fs.readFileSync('./src/routes/pacienteRoutes.js', 'utf-8');
  assert.ok(contenido.includes("body('nombre')"), 'Falta validacion de nombre');
  assert.ok(contenido.includes("body('apellido')"), 'Falta validacion de apellido');
  assert.ok(contenido.includes("body('cedula')"), 'Falta validacion de cedula');
});

test('Backend responde en localhost:3000', async () => {
  const res = await request('/api/health');
  assert.strictEqual(res.statusCode, 200);
  assert.ok(res.body.status === 'OK' || res.body.status === 'ok');
});

test('Servicio IA Cardiologia responde en localhost:8000', async () => {
  const res = await request('http://127.0.0.1:8000/health');
  assert.strictEqual(res.statusCode, 200);
});
