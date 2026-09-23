'use strict';

/**
 * Suite de pruebas QA para los endpoints de VISIÓN (API /api/vision).
 *
 * - POST /api/vision/registrar-rostro/:pacienteId (KIO-10): validación
 *   (imagenes ausentes), autenticación (401), roles (403), paciente no
 *   encontrado (404), éxito (proxy al microservicio mockeado con fetch +
 *   guardado de rostro_embedding), y errores del microservicio (502/504).
 * - GET /api/vision/rostro/:pacienteId (KIO-07): consulta del descriptor.
 *
 * Supabase y el microservicio de visión se simulan (sin base de datos real).
 */

const { test, before, after, describe } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const supabaseMock = require('./mocks/supabaseMock');
const { getApp, restore } = require('./helpers/loadApp');

const fetchOriginal = global.fetch;

let app;
let tokenAdmin;
let tokenRecepcion;
let tokenMedico;
let tokenPaciente;
let ipCounter = 0;
const nuevaIp = () => `198.51.100.${++ipCounter}`;

async function loginToken(email, password) {
  const res = await request(app)
    .post('/api/auth/login')
    .set('x-forwarded-for', nuevaIp())
    .send({ email, password });
  assert.equal(res.status, 200, `login falló: ${JSON.stringify(res.body)}`);
  return res.body.data.token;
}

before(async () => {
  supabaseMock.reset();
  await supabaseMock.seedUsuarioConHash({
    id: 1,
    email: 'adminvision@test.com',
    password: 'AdminPass1',
    rol: 'admin',
    activo: true,
    nombre: 'Admin Visión',
  });
  await supabaseMock.seedUsuarioConHash({
    id: 2,
    email: 'rec@test.com',
    password: 'RecPass1',
    rol: 'recepcion',
    activo: true,
    nombre: 'Recepción',
  });
  await supabaseMock.seedUsuarioConHash({
    id: 3,
    email: 'medico@test.com',
    password: 'MedPass1',
    rol: 'medico',
    activo: true,
    nombre: 'Médico',
  });
  await supabaseMock.seedUsuarioConHash({
    id: 4,
    email: 'paciente@test.com',
    password: 'PacPass1',
    rol: 'paciente',
    activo: true,
    nombre: 'Paciente',
  });
  app = getApp();
  tokenAdmin = await loginToken('adminvision@test.com', 'AdminPass1');
  tokenRecepcion = await loginToken('rec@test.com', 'RecPass1');
  tokenMedico = await loginToken('medico@test.com', 'MedPass1');
  tokenPaciente = await loginToken('paciente@test.com', 'PacPass1');
});

after(() => {
  global.fetch = fetchOriginal;
  restore();
});

function embedding128() {
  return Array.from({ length: 128 }, (_, i) => (i + 1) / 128);
}

// ============================================================================
// POST /api/vision/registrar-rostro/:pacienteId
// ============================================================================
describe('POST /api/vision/registrar-rostro/:pacienteId', () => {
  test('401 - sin token', async () => {
    const res = await request(app)
      .post('/api/vision/registrar-rostro/7')
      .send({ imagenes: ['aG9sYQ=='] });
    assert.equal(res.status, 401);
  });

  test('403 - rol paciente no autorizado', async () => {
    const res = await request(app)
      .post('/api/vision/registrar-rostro/7')
      .set('Authorization', `Bearer ${tokenPaciente}`)
      .send({ imagenes: ['aG9sYQ=='] });
    assert.equal(res.status, 403);
    assert.ok(/Acceso denegado/i.test(res.body.message));
  });

  test('403 - rol medico no autorizado para registrar', async () => {
    const res = await request(app)
      .post('/api/vision/registrar-rostro/7')
      .set('Authorization', `Bearer ${tokenMedico}`)
      .send({ imagenes: ['aG9sYQ=='] });
    assert.equal(res.status, 403);
  });

  test('422 - pacienteId inválido', async () => {
    const res = await request(app)
      .post('/api/vision/registrar-rostro/abc')
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({ imagenes: ['aG9sYQ=='] });
    assert.equal(res.status, 422);
    assert.equal(res.body.message, 'Errores de validación');
    assert.ok(Array.isArray(res.body.errors));
  });

  test('422 - imagenes ausentes', async () => {
    const res = await request(app)
      .post('/api/vision/registrar-rostro/7')
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({});
    assert.equal(res.status, 422);
    assert.ok(Array.isArray(res.body.errors));
  });

  test('422 - imagenes no es array', async () => {
    const res = await request(app)
      .post('/api/vision/registrar-rostro/7')
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({ imagenes: 'no-array' });
    assert.equal(res.status, 422);
  });

  test('404 - paciente no encontrado', async () => {
    const res = await request(app)
      .post('/api/vision/registrar-rostro/999')
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({ imagenes: ['aG9sYQ=='] });
    assert.equal(res.status, 404);
    assert.equal(res.body.message, 'Paciente no encontrado');
  });

  test('200 - rostro registrado: guarda muestras, reentrena y persiste embedding', async () => {
    supabaseMock.seedPaciente({ id: 7, nombre: 'Ana', apellido: 'López' });

    global.fetch = async () =>
      new Response(
        JSON.stringify({
          success: true,
          message: 'Rostro registrado y modelo reentrenado',
          data: {
            paciente_id: 7,
            guardadas: 5,
            entrenamiento: { imagenes: 5, pacientes: 1, modelo: 'modelo_lbph.yml' },
            rostro_embedding: embedding128(),
          },
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );

    const res = await request(app)
      .post('/api/vision/registrar-rostro/7')
      .set('Authorization', `Bearer ${tokenRecepcion}`)
      .send({ imagenes: ['aG9sYQ==', 'bXVuZG8='] });

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.equal(res.body.data.paciente_id, 7);
    assert.equal(res.body.data.imagenes_guardadas, 5);
    assert.equal(res.body.data.rostro_registrado, true);

    // El embedding debe quedar persistido en el paciente (mock)
    const pacientes = supabaseMock.getPacientes();
    const p = pacientes.find((x) => x.id === 7);
    assert.ok(p.rostro_embedding, 'debe guardar rostro_embedding');
    assert.ok(String(p.rostro_embedding).startsWith('['));
    assert.match(p.rostro_embedding, /0\.0078125/); // (1+1)/128
  });

  test('200 - sin embedding válido: rostro_registrado false', async () => {
    supabaseMock.seedPaciente({ id: 8, nombre: 'Bea', apellido: 'Mora' });

    global.fetch = async () =>
      new Response(
        JSON.stringify({
          success: true,
          message: 'Rostro registrado y modelo reentrenado',
          data: { paciente_id: 8, guardadas: 0, entrenamiento: null, rostro_embedding: null },
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );

    const res = await request(app)
      .post('/api/vision/registrar-rostro/8')
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({ imagenes: ['aG9sYQ=='] });

    assert.equal(res.status, 200);
    assert.equal(res.body.data.rostro_registrado, false);
  });

  test('502 - no se puede conectar con el servicio de visión', async () => {
    global.fetch = async () => {
      throw new Error('ECONNREFUSED');
    };

    const res = await request(app)
      .post('/api/vision/registrar-rostro/7')
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({ imagenes: ['aG9sYQ=='] });

    assert.equal(res.status, 502);
    assert.equal(res.body.success, false);
    assert.ok(/servicio de visión/i.test(res.body.message));
  });

  test('504 - el servicio de visión no responde a tiempo', async () => {
    global.fetch = async () => {
      throw new DOMException('', 'TimeoutError');
    };

    const res = await request(app)
      .post('/api/vision/registrar-rostro/7')
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({ imagenes: ['aG9sYQ=='] });

    assert.equal(res.status, 504);
    assert.equal(res.body.success, false);
  });

  test('500 - el microservicio devuelve estado de error propio', async () => {
    global.fetch = async () =>
      new Response(
        JSON.stringify({ success: false, message: 'No se pudo decodificar la imagen' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );

    const res = await request(app)
      .post('/api/vision/registrar-rostro/7')
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({ imagenes: ['aW52YWxpZG8='] });

    assert.equal(res.status, 500);
    assert.ok(/No se pudo decodificar/i.test(res.body.message));
  });
});

// ============================================================================
// GET /api/vision/rostro/:pacienteId
// ============================================================================
describe('GET /api/vision/rostro/:pacienteId', () => {
  test('401 - sin token', async () => {
    const res = await request(app).get('/api/vision/rostro/7');
    assert.equal(res.status, 401);
  });

  test('403 - rol paciente no autorizado', async () => {
    const res = await request(app)
      .get('/api/vision/rostro/7')
      .set('Authorization', `Bearer ${tokenPaciente}`);
    assert.equal(res.status, 403);
  });

  test('404 - paciente no encontrado', async () => {
    const res = await request(app)
      .get('/api/vision/rostro/999')
      .set('Authorization', `Bearer ${tokenAdmin}`);
    assert.equal(res.status, 404);
    assert.equal(res.body.message, 'Paciente no encontrado');
  });

  test('200 - paciente con rostro registrado', async () => {
    supabaseMock.seedPaciente({
      id: 9,
      nombre: 'Carlos',
      apellido: 'Ruiz',
      rostro_embedding: embedding128(),
    });

    const res = await request(app)
      .get('/api/vision/rostro/9')
      .set('Authorization', `Bearer ${tokenAdmin}`);

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.equal(res.body.data.paciente_id, 9);
    assert.equal(res.body.data.rostro_registrado, true);
    assert.equal(res.body.data.dimensiones, 128);
    assert.equal(res.body.data.embedding_resumen.length, 3);
  });

  test('200 - paciente sin rostro registrado', async () => {
    supabaseMock.seedPaciente({ id: 10, nombre: 'Diana', apellido: 'Peña' });

    const res = await request(app)
      .get('/api/vision/rostro/10')
      .set('Authorization', `Bearer ${tokenMedico}`);

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.equal(res.body.data.rostro_registrado, false);
    assert.equal(res.body.data.dimensiones, 0);
  });
});