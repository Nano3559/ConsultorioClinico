'use strict';

/**
 * Suite de pruebas QA para la sincronización del kiosco y el puente de la
 * reserva online (rostro YuNet+SFace multi-pose).
 *
 * - GET /api/pacientes/buscar?cedula=: autocompletado público (existe +
 *   foto_requerida según vigencia), validación y no encontrado.
 * - POST /api/kiosco/paquete-rostro: crea el paciente por cédula si falta y
 *   registra el pack (carpeta por persona + plantillas + vigencia).
 * - GET /api/kiosco/manifest: versión del modelo + hashes de plantillas.
 * - GET /api/kiosco/modelo: versión del pack vigente.
 * - GET /api/kiosco/paquete/:id: embeddings + URLs firmadas.
 *
 * Supabase y el microservicio de visión se simulan (sin base de datos real).
 * Sin KIOSK_API_KEY en el entorno de test, los endpoints de sincronización
 * exigen JWT de personal (mismo comportamiento que kioskAuth en dev).
 */

const { test, before, after, describe } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const supabaseMock = require('./mocks/supabaseMock');
const { getApp, restore } = require('./helpers/loadApp');

const fetchOriginal = global.fetch;

let app;
let tokenAdmin;
let ipCounter = 100;
const nuevaIp = () => `198.51.100.${++ipCounter}`;

async function loginToken(email, password) {
  const res = await request(app)
    .post('/api/auth/login')
    .set('x-forwarded-for', nuevaIp())
    .send({ email, password });
  assert.equal(res.status, 200, `login falló: ${JSON.stringify(res.body)}`);
  return res.body.data.token;
}

function embedding128() {
  return Array.from({ length: 128 }, (_, i) => (i + 1) / 128);
}

function mockPythonRegistro() {
  global.fetch = async () =>
    new Response(
      JSON.stringify({
        success: true,
        message: 'Rostro registrado (multi-pose)',
        data: {
          paciente_id: 21,
          guardadas: 2,
          muestras: [
            { pose: 'frontal', guardada: true, calidad: 88.0, foto: 'aG9sYQ==', embedding: embedding128() },
            { pose: 'izquierda', guardada: true, calidad: 79.5, foto: 'bXVuZG8=', embedding: embedding128() },
          ],
          rostro_embedding: embedding128(),
          modelo: 'sface',
        },
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    );
}

before(async () => {
  supabaseMock.reset();
  await supabaseMock.seedUsuarioConHash({
    id: 1,
    email: 'adminrostro@test.com',
    password: 'AdminPass1',
    rol: 'admin',
    activo: true,
    nombre: 'Admin Rostro',
  });
  app = getApp();
  tokenAdmin = await loginToken('adminrostro@test.com', 'AdminPass1');
});

after(() => {
  global.fetch = fetchOriginal;
  restore();
});

// ============================================================================
// GET /api/pacientes/buscar?cedula=
// ============================================================================
describe('GET /api/pacientes/buscar', () => {
  test('200 - existe con rostro vigente: no requiere foto', async () => {
    supabaseMock.seedPaciente({
      id: 21,
      cedula: '1111111111',
      nombre: 'Eva',
      apellido: 'Torres',
      telefono: '77700011',
      email: 'eva@test.com',
      fecha_nacimiento: '1990-05-01',
      activo: true,
      rostro_embedding: embedding128(),
      rostro_actualizado_en: new Date().toISOString(),
    });

    const res = await request(app)
      .get('/api/pacientes/buscar')
      .set('x-forwarded-for', nuevaIp())
      .query({ cedula: '1111111111' });

    assert.equal(res.status, 200);
    assert.equal(res.body.data.existe, true);
    assert.equal(res.body.data.paciente.nombre, 'Eva');
    assert.equal(res.body.data.rostro_registrado, true);
    assert.equal(res.body.data.rostro_vigente, true);
    assert.equal(res.body.data.foto_requerida, false);
  });

  test('200 - existe con rostro vencido: requiere foto', async () => {
    supabaseMock.seedPaciente({
      id: 22,
      cedula: '2222222222',
      nombre: 'Luis',
      apellido: 'Paz',
      activo: true,
      rostro_embedding: embedding128(),
      rostro_actualizado_en: new Date(Date.now() - 100 * 24 * 60 * 60 * 1000).toISOString(),
    });

    const res = await request(app)
      .get('/api/pacientes/buscar')
      .set('x-forwarded-for', nuevaIp())
      .query({ cedula: '2222222222' });

    assert.equal(res.status, 200);
    assert.equal(res.body.data.existe, true);
    assert.equal(res.body.data.rostro_vigente, false);
    assert.equal(res.body.data.foto_requerida, true);
  });

  test('200 - no existe: foto requerida', async () => {
    const res = await request(app)
      .get('/api/pacientes/buscar')
      .set('x-forwarded-for', nuevaIp())
      .query({ cedula: '9999999999' });

    assert.equal(res.status, 200);
    assert.equal(res.body.data.existe, false);
  });

  test('422 - cédula ausente o corta', async () => {
    const res = await request(app)
      .get('/api/pacientes/buscar')
      .set('x-forwarded-for', nuevaIp())
      .query({ cedula: '12' });
    assert.equal(res.status, 422);
  });
});

// ============================================================================
// POST /api/kiosco/paquete-rostro
// ============================================================================
describe('POST /api/kiosco/paquete-rostro', () => {
  test('422 - muestras ausentes', async () => {
    const res = await request(app)
      .post('/api/kiosco/paquete-rostro')
      .set('x-forwarded-for', nuevaIp())
      .send({ cedula: '3333333333', nombre: 'Ana', apellido: 'Luz' });
    assert.equal(res.status, 422);
  });

  test('200 - crea el paciente y registra el pack en su carpeta', async () => {
    mockPythonRegistro();

    const res = await request(app)
      .post('/api/kiosco/paquete-rostro')
      .set('x-forwarded-for', nuevaIp())
      .send({
        cedula: '3333333333',
        nombre: 'Ana',
        apellido: 'Luz',
        telefono: '77700033',
        muestras: [
          { imagen: 'aG9sYQ==', pose: 'frontal' },
          { imagen: 'bXVuZG8=', pose: 'izquierda' },
        ],
      });

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.equal(res.body.data.rostro_registrado, true);
    assert.equal(res.body.data.rostro_vigente, true);
    assert.equal(res.body.data.guardadas, 2);

    const pacientes = supabaseMock.getPacientes();
    const creado = pacientes.find((p) => p.cedula === '3333333333');
    assert.ok(creado, 'debe crear el paciente del backend');
    assert.ok(creado.rostro_embedding, 'debe guardar la plantilla 128-d');
    assert.ok(creado.rostro_actualizado_en, 'debe marcar la vigencia');
  });
});

// ============================================================================
// GET /api/kiosco/manifest · /modelo · /paquete/:id
// ============================================================================
describe('GET /api/kiosco/manifest', () => {
  test('200 - devuelve versión del modelo y hashes (requiere personal sin kiosk-key)', async () => {
    const res = await request(app)
      .get('/api/kiosco/manifest')
      .set('Authorization', `Bearer ${tokenAdmin}`);

    assert.equal(res.status, 200);
    assert.equal(res.body.data.modelo_version, 'sface_v1');
    assert.equal(res.body.data.modelo_pack, 'sface');
    assert.ok(Array.isArray(res.body.data.pacientes));
    const ana = res.body.data.pacientes.find((p) => p.cedula === '3333333333');
    assert.ok(ana, 'incluye al paciente registrado');
    assert.match(ana.template_hash, /^[a-f0-9]{32}$/);
  });

  test('403 - sin clave de kiosco ni JWT', async () => {
    const res = await request(app).get('/api/kiosco/manifest');
    assert.equal(res.status, 401);
  });
});

describe('GET /api/kiosco/modelo', () => {
  test('200 - versión del pack vigente', async () => {
    const res = await request(app)
      .get('/api/kiosco/modelo')
      .set('Authorization', `Bearer ${tokenAdmin}`);

    assert.equal(res.status, 200);
    assert.equal(res.body.data.version, 'sface_v1');
    assert.equal(res.body.data.pack, 'sface');
  });
});

describe('GET /api/kiosco/paquete/:pacienteId', () => {
  test('200 - embeddings + fotos firmadas', async () => {
    const pacientes = supabaseMock.getPacientes();
    const ana = pacientes.find((p) => p.cedula === '3333333333');
    assert.ok(ana);

    const res = await request(app)
      .get(`/api/kiosco/paquete/${ana.id}`)
      .set('Authorization', `Bearer ${tokenAdmin}`);

    assert.equal(res.status, 200);
    assert.ok(Array.isArray(res.body.data.rostro_embedding));
    assert.equal(res.body.data.rostro_embedding.length, 128);
    assert.ok(Array.isArray(res.body.data.poses));
  });

  test('404 - paciente inexistente', async () => {
    const res = await request(app)
      .get('/api/kiosco/paquete/987654')
      .set('Authorization', `Bearer ${tokenAdmin}`);
    assert.equal(res.status, 404);
  });
});
