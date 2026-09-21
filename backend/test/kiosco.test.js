'use strict';

/**
 * Suite de pruebas QA para el kiosco de auto-check-in (API /api/kiosco).
 *
 * - verificar-rostro: validación, éxito (proxy al microservicio de visión
 *   mockeado con fetch), rostro no reconocido y error de conexión.
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

before(async () => {
  supabaseMock.reset();
  app = getApp();
});

after(() => {
  global.fetch = fetchOriginal;
  restore();
});

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
    global.fetch = async () =>
      new Response(
        JSON.stringify({
          success: true,
          message: 'Rostro reconocido',
          data: {
            paciente_id: 7,
            nombre: 'Ana López',
            confianza: 42.5,
            cita: { id: 99, fecha: '2026-09-21', hora: '10:00', estado: 'programada' },
          },
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );

    const res = await request(app)
      .post('/api/kiosco/verificar-rostro')
      .send({ imagen: 'aW1hZ2VuLWJhc2U2NA==' });

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.equal(res.body.message, 'Rostro reconocido');
    assert.equal(res.body.data.paciente_id, 7);
    assert.equal(res.body.data.nombre, 'Ana López');
    assert.ok(res.body.data.cita);
  });

  test('200 - rostro no reconocido', async () => {
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
      .send({ imagen: 'aW1hZ2VuLWJhc2U2NA==' });

    assert.equal(res.status, 200);
    assert.equal(res.body.success, false);
    assert.equal(res.body.data.paciente_id, null);
  });

  test('502 - no se puede conectar con el servicio de visión', async () => {
    global.fetch = async () => {
      throw new Error('ECONNREFUSED');
    };

    const res = await request(app)
      .post('/api/kiosco/verificar-rostro')
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
      .send({ imagen: 'aW1hZ2VuLWJhc2U2NA==' });

    assert.equal(res.status, 504);
    assert.equal(res.body.success, false);
  });

  test('503 - error el microservicio devuelve estado de error propio', async () => {
    global.fetch = async () =>
      new Response(
        JSON.stringify({ success: false, message: 'Error interno del microservicio de visión' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );

    const res = await request(app)
      .post('/api/kiosco/verificar-rostro')
      .send({ imagen: 'aW1hZ2VuLWJhc2U2NA==' });

    assert.equal(res.status, 500);
    assert.ok(/Error interno del microservicio/i.test(res.body.message));
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
      fecha: '2026-09-21',
      hora: '09:00',
      estado: 'programada',
      confirmada_por_kiosco: false,
    });
    const res = await request(app)
      .post('/api/kiosco/confirmar-cita')
      .send({ paciente_id: 7, cita_id: 10 });
    assert.equal(res.status, 400);
    assert.equal(res.body.message, 'La cita no pertenece al paciente indicado');
  });

  test('400 - cita en estado final (completada/cancelada/no_show)', async () => {
    supabaseMock.seedCita({
      id: 11,
      paciente_id: 7,
      medico_id: 1,
      fecha: '2026-09-21',
      hora: '09:00',
      estado: 'cancelada',
      confirmada_por_kiosco: false,
    });
    const res = await request(app)
      .post('/api/kiosco/confirmar-cita')
      .send({ paciente_id: 7, cita_id: 11 });
    assert.equal(res.status, 400);
    assert.ok(/No se puede confirmar/i.test(res.body.message));
  });

  test('400 - cita ya confirmada por el kiosco', async () => {
    supabaseMock.seedCita({
      id: 12,
      paciente_id: 7,
      medico_id: 1,
      fecha: '2026-09-21',
      hora: '09:00',
      estado: 'confirmada',
      confirmada_por_kiosco: true,
      hora_checkin: '2026-09-21T08:58:00Z',
    });
    const res = await request(app)
      .post('/api/kiosco/confirmar-cita')
      .send({ paciente_id: 7, cita_id: 12 });
    assert.equal(res.status, 400);
    assert.ok(/ya fue confirmada/i.test(res.body.message));
  });

  test('200 - check-in exitoso: confirmada, confirmada_por_kiosco y hora_checkin', async () => {
    supabaseMock.seedCita({
      id: 13,
      paciente_id: 7,
      medico_id: 1,
      fecha: '2026-09-21',
      hora: '09:00',
      estado: 'programada',
      confirmada_por_kiosco: false,
    });
    const res = await request(app)
      .post('/api/kiosco/confirmar-cita')
      .send({ paciente_id: 7, cita_id: 13 });

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.equal(res.body.data.estado, 'confirmada');
    assert.equal(res.body.data.confirmada_por_kiosco, true);
    assert.ok(res.body.data.hora_checkin, 'debe registrar hora_checkin');
  });
});