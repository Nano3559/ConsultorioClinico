'use strict';

/**
 * Suite de pruebas QA para el kiosco de auto-check-in (API /api/kiosco).
 *
 * - verificar-rostro: validación, éxito (proxy al microservicio de visión
 *   mockeado con fetch), rostro no reconocido, errores de conexión, rate
 *   limit por IP (KIO-20) y auditoría de intentos en intentos_acceso (KIO-19).
 * - confirmar-cita: validación, cita de HOY (KIO-15), verificación facial
 *   reciente del mismo paciente/IP (KIO-20), estados finales y check-in.
 * - intentos (GET): auditoría restringida a admin/recepcion (KIO-19).
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
let tokenPaciente;
let contadorIp = 0;
const nuevaIp = () => `198.51.100.${++contadorIp}`;
const fechaHoy = () => {
  const a = new Date();
  const m = String(a.getMonth() + 1).padStart(2, '0');
  const d = String(a.getDate()).padStart(2, '0');
  return `${a.getFullYear()}-${m}-${d}`;
};

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
    email: 'kadmin@test.com',
    password: 'AdminPass1',
    rol: 'admin',
    activo: true,
    nombre: 'Admin Kiosco',
  });
  await supabaseMock.seedUsuarioConHash({
    id: 2,
    email: 'kpac@test.com',
    password: 'PacPass1',
    rol: 'paciente',
    activo: true,
    nombre: 'Paciente',
  });
  app = getApp();
  tokenAdmin = await loginToken('kadmin@test.com', 'AdminPass1');
  tokenPaciente = await loginToken('kpac@test.com', 'PacPass1');
});

after(() => {
  global.fetch = fetchOriginal;
  restore();
});

// ============================================================================
// POST /api/kiosco/verificar-rostro
// ============================================================================
describe('POST /api/kiosco/verificar-rostro', () => {
  test('422 - imagen ausente', async () => {
    const res = await request(app).post('/api/kiosco/verificar-rostro').send({});
    assert.equal(res.status, 422);
    assert.equal(res.body.success, false);
    assert.ok(Array.isArray(res.body.errors));
  });

  test('422 - imagen vacía', async () => {
    const res = await request(app)
      .post('/api/kiosco/verificar-rostro')
      .send({ imagen: '' });
    assert.equal(res.status, 422);
  });

  test('200 - rostro reconocido: devuelve data con paciente y cita', async () => {
    supabaseMock.reset();
    global.fetch = async () =>
      new Response(
        JSON.stringify({
          success: true,
          message: 'Rostro reconocido',
          data: {
            paciente_id: 7,
            nombre: 'Ana López',
            confianza: 42.5,
            cita: { id: 99, fecha: fechaHoy(), hora: '10:00', estado: 'programada' },
          },
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );

    const ip = nuevaIp();
    const res = await request(app)
      .post('/api/kiosco/verificar-rostro')
      .set('x-forwarded-for', ip)
      .send({ imagen: 'aW1hZ2VuLWJhc2U2NA==' });

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.equal(res.body.message, 'Rostro reconocido');
    assert.equal(res.body.data.paciente_id, 7);
    assert.equal(res.body.data.nombre, 'Ana López');
    assert.ok(res.body.data.cita);

    // KIO-19: la verificación exitosa queda auditada
    const intentos = supabaseMock.getIntentos();
    assert.ok(
      intentos.some((i) => i.tipo_acceso === 'kiosco_verificacion' && i.exitoso && i.referencia_id === 7 && i.ip_address === ip),
      'debe auditar la verificación exitosa con referencia_id e IP'
    );
  });

  test('200 - rostro no reconocido (auditoría con exitoso=false)', async () => {
    global.fetch = async () =>
      new Response(
        JSON.stringify({
          success: false,
          message: 'Rostro no reconocido',
          data: { paciente_id: null, nombre: null, confianza: 88.1, cita: null },
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );

    const res = await request(app)
      .post('/api/kiosco/verificar-rostro')
      .set('x-forwarded-for', nuevaIp())
      .send({ imagen: 'aW1hZ2VuLWJhc2U2NA==' });

    assert.equal(res.status, 200);
    assert.equal(res.body.success, false);
    assert.equal(res.body.data.paciente_id, null);
    assert.ok(
      supabaseMock.getIntentos().some((i) => i.tipo_acceso === 'kiosco_verificacion' && !i.exitoso),
      'debe auditar el intento fallido'
    );
  });

  test('502 - no se puede conectar con el servicio de visión', async () => {
    global.fetch = async () => {
      throw new Error('ECONNREFUSED');
    };

    const res = await request(app)
      .post('/api/kiosco/verificar-rostro')
      .set('x-forwarded-for', nuevaIp())
      .send({ imagen: 'aW1hZ2VuLWJhc2U2NA==' });

    assert.equal(res.status, 502);
    assert.equal(res.body.success, false);
    assert.ok(/servicio de visión/i.test(res.body.message));
  });

  test('504 - el servicio de visión no responde a tiempo', async () => {
    global.fetch = async () => {
      throw new DOMException('', 'TimeoutError');
    };

    const res = await request(app)
      .post('/api/kiosco/verificar-rostro')
      .set('x-forwarded-for', nuevaIp())
      .send({ imagen: 'aW1hZ2VuLWJhc2U2NA==' });

    assert.equal(res.status, 504);
    assert.equal(res.body.success, false);
  });

  test('500 - el microservicio devuelve estado de error propio', async () => {
    global.fetch = async () =>
      new Response(
        JSON.stringify({ success: false, message: 'Error interno del microservicio de visión' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );

    const res = await request(app)
      .post('/api/kiosco/verificar-rostro')
      .set('x-forwarded-for', nuevaIp())
      .send({ imagen: 'aW1hZ2VuLWJhc2U2NA==' });

    assert.equal(res.status, 500);
    assert.ok(/Error interno del microservicio/i.test(res.body.message));
  });

  test('429 - límite de verificaciones por IP (KIO-20)', async () => {
    // IP dedicada para este test: no contamina al resto de la suite.
    const ip = '203.0.113.99';
    global.fetch = async () =>
      new Response(
        JSON.stringify({
          success: false,
          message: 'Rostro no reconocido',
          data: { paciente_id: null, nombre: null, confianza: 90, cita: null },
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );

    let ultimo = null;
    // KIOSCO_VERIFY_RATE_MAX por defecto = 30; forzamos superarlo (40).
    for (let i = 0; i < 40; i++) {
      ultimo = await request(app)
        .post('/api/kiosco/verificar-rostro')
        .set('x-forwarded-for', ip)
        .send({ imagen: 'aW1hZ2VuLWJhc2U2NA==' });
    }

    assert.equal(ultimo.status, 429);
    assert.equal(ultimo.body.success, false);
    assert.ok(/Demasiadas verificaciones/i.test(ultimo.body.message));
  });
});

// ============================================================================
// CONFIRMAR-CITA
// ============================================================================
describe('POST /api/kiosco/confirmar-cita', () => {
  test('422 - campos ausentes', async () => {
    const res = await request(app).post('/api/kiosco/confirmar-cita').send({});
    assert.equal(res.status, 422);
    assert.equal(res.body.success, false);
    assert.ok(Array.isArray(res.body.errors));
  });

  test('422 - paciente_id inválido', async () => {
    const res = await request(app)
      .post('/api/kiosco/confirmar-cita')
      .send({ paciente_id: 'abc', cita_id: 1 });
    assert.equal(res.status, 422);
  });

  test('404 - cita no encontrada', async () => {
    const res = await request(app)
      .post('/api/kiosco/confirmar-cita')
      .set('x-forwarded-for', nuevaIp())
      .send({ paciente_id: 7, cita_id: 999 });
    assert.equal(res.status, 404);
    assert.equal(res.body.success, false);
    assert.equal(res.body.message, 'Cita no encontrada');
  });

  test('400 - la cita no pertenece al paciente', async () => {
    supabaseMock.seedCita({
      id: 10,
      paciente_id: 5,
      medico_id: 1,
      fecha: fechaHoy(),
      hora: '09:00',
      estado: 'programada',
      confirmada_por_kiosco: false,
    });
    const res = await request(app)
      .post('/api/kiosco/confirmar-cita')
      .set('x-forwarded-for', nuevaIp())
      .send({ paciente_id: 7, cita_id: 10 });
    assert.equal(res.status, 400);
    assert.equal(res.body.message, 'La cita no pertenece al paciente indicado');
  });

  test('400 - cita de otra fecha distinta a hoy (KIO-15)', async () => {
    supabaseMock.seedCita({
      id: 15,
      paciente_id: 7,
      medico_id: 1,
      fecha: '2099-01-01',
      hora: '09:00',
      estado: 'programada',
      confirmada_por_kiosco: false,
    });
    const res = await request(app)
      .post('/api/kiosco/confirmar-cita')
      .set('x-forwarded-for', nuevaIp())
      .send({ paciente_id: 7, cita_id: 15 });
    assert.equal(res.status, 400);
    assert.ok(/Solo se pueden confirmar citas del día de hoy/i.test(res.body.message));
  });

  test('400 - cita en estado final (completada/cancelada/no_show)', async () => {
    supabaseMock.seedCita({
      id: 11,
      paciente_id: 7,
      medico_id: 1,
      fecha: fechaHoy(),
      hora: '09:00',
      estado: 'cancelada',
      confirmada_por_kiosco: false,
    });
    const res = await request(app)
      .post('/api/kiosco/confirmar-cita')
      .set('x-forwarded-for', nuevaIp())
      .send({ paciente_id: 7, cita_id: 11 });
    assert.equal(res.status, 400);
    assert.ok(/No se puede confirmar/i.test(res.body.message));
  });

  test('400 - cita ya confirmada por el kiosco', async () => {
    supabaseMock.seedCita({
      id: 12,
      paciente_id: 7,
      medico_id: 1,
      fecha: fechaHoy(),
      hora: '09:00',
      estado: 'confirmada',
      confirmada_por_kiosco: true,
      hora_checkin: '2026-09-21T08:58:00Z',
    });
    const res = await request(app)
      .post('/api/kiosco/confirmar-cita')
      .set('x-forwarded-for', nuevaIp())
      .send({ paciente_id: 7, cita_id: 12 });
    assert.equal(res.status, 400);
    assert.ok(/ya fue confirmada/i.test(res.body.message));
  });

  test('403 - sin verificación facial reciente del mismo paciente/IP (KIO-20)', async () => {
    supabaseMock.seedCita({
      id: 14,
      paciente_id: 7,
      medico_id: 1,
      fecha: fechaHoy(),
      hora: '10:00',
      estado: 'programada',
      confirmada_por_kiosco: false,
    });
    const res = await request(app)
      .post('/api/kiosco/confirmar-cita')
      .set('x-forwarded-for', '203.0.113.200') // otra IP: sin verificación previa
      .send({ paciente_id: 7, cita_id: 14 });
    assert.equal(res.status, 403);
    assert.ok(/Debe verificar primero el rostro/i.test(res.body.message));
  });

  test('200 - check-in exitoso tras verificación válida: confirmada, confirmada_por_kiosco y hora_checkin', async () => {
    supabaseMock.seedCita({
      id: 13,
      paciente_id: 7,
      medico_id: 1,
      fecha: fechaHoy(),
      hora: '09:00',
      estado: 'programada',
      confirmada_por_kiosco: false,
    });
    const ip = nuevaIp();
    // KIO-19/20: verificación facial exitosa reciente del mismo paciente + IP.
    supabaseMock.seedIntento({
      tipo_acceso: 'kiosco_verificacion',
      referencia_id: 7,
      ip_address: ip,
      exitoso: true,
      detalle: 'reconocido',
      creado_en: new Date().toISOString(),
    });

    const res = await request(app)
      .post('/api/kiosco/confirmar-cita')
      .set('x-forwarded-for', ip)
      .send({ paciente_id: 7, cita_id: 13 });

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.equal(res.body.data.estado, 'confirmada');
    assert.equal(res.body.data.confirmada_por_kiosco, true);
    assert.ok(res.body.data.hora_checkin, 'debe registrar hora_checkin');
  });
});

// ============================================================================
// GET /api/kiosco/intentos (auditoría del kiosco, KIO-19)
// ============================================================================
describe('GET /api/kiosco/intentos', () => {
  test('401 - sin token', async () => {
    const res = await request(app).get('/api/kiosco/intentos');
    assert.equal(res.status, 401);
  });

  test('403 - rol paciente no autorizado', async () => {
    const res = await request(app)
      .get('/api/kiosco/intentos')
      .set('Authorization', `Bearer ${tokenPaciente}`);
    assert.equal(res.status, 403);
  });

  test('200 - admin consulta la auditoría del kiosco', async () => {
    const res = await request(app)
      .get('/api/kiosco/intentos')
      .set('Authorization', `Bearer ${tokenAdmin}`);
    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.ok(Array.isArray(res.body.data.intentos));
    assert.ok(res.body.data.intentos.every((i) => i.tipo_acceso === 'kiosco_verificacion'));
  });

  test('200 - filtro por resultados exitosos', async () => {
    const res = await request(app)
      .get('/api/kiosco/intentos?exitoso=true')
      .set('Authorization', `Bearer ${tokenAdmin}`);
    assert.equal(res.status, 200);
    assert.ok(res.body.data.intentos.every((i) => i.exitoso === true));
  });
});