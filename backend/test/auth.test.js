'use strict';

/**
 * Suite de pruebas QA para el LOGIN del backend (API /api/auth).
 *
 * - login: éxito, email inválido, campos vacíos, credenciales incorrectas,
 *          usuario inactivo, normalización de email, rate limiting.
 * - register: éxito (paciente), email duplicado, email inválido, password
 *          débil, nombre corto, auto-elevación de rol y rol inválido.
 *
 * Supabase se simula con el mock (sin base de datos real).
 */

const { test, before, after, describe } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const supabaseMock = require('./mocks/supabaseMock');
const { getApp, restore } = require('./helpers/loadApp');

let app;
let ipCounter = 0;
const nuevaIp = () => `198.51.100.${++ipCounter}`;

before(async () => {
  supabaseMock.reset();
  await supabaseMock.seedUsuarioConHash({
    id: 1,
    email: 'activo@test.com',
    password: 'Password123',
    rol: 'paciente',
    activo: true,
    nombre: 'Usuario Activo',
  });
  await supabaseMock.seedUsuarioConHash({
    id: 2,
    email: 'admin@test.com',
    password: 'AdminPass1',
    rol: 'admin',
    activo: true,
    nombre: 'Admin',
  });
  await supabaseMock.seedUsuarioConHash({
    id: 3,
    email: 'inactivo@test.com',
    password: 'Password123',
    rol: 'paciente',
    activo: false,
    nombre: 'Usuario Inactivo',
  });
  app = getApp();
});

after(() => restore());

// ============================================================================
// LOGIN
// ============================================================================
describe('POST /api/auth/login', () => {
  test('200 - login exitoso con usuario activo y credenciales correctas', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .set('x-forwarded-for', nuevaIp())
      .send({ email: 'activo@test.com', password: 'Password123' });

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.equal(typeof res.body.data.token, 'string');
    assert.ok(res.body.data.token.length > 10, 'debe devolver un token JWT');
    assert.equal(res.body.data.rol, 'paciente');
    assert.equal(res.body.data.email, 'activo@test.com');
    assert.ok(res.body.data.id, 'debe devolver el id');
  });

  test('200 - login normaliza email con mayúsculas y espacios', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .set('x-forwarded-for', nuevaIp())
      .send({ email: '  ACTIVO@TEST.COM  ', password: 'Password123' });

    assert.equal(res.status, 200, `se esperaba 200, se obtuvo ${res.status}: ${res.body.message}`);
  });

  test('422 - email con formato inválido', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .set('x-forwarded-for', nuevaIp())
      .send({ email: 'no-es-un-mail', password: 'Password123' });

    assert.equal(res.status, 422);
    assert.equal(res.body.success, false);
    assert.equal(res.body.message, 'Errores de validación');
    assert.ok(Array.isArray(res.body.errors));
  });

  test('422 - email vacío', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .set('x-forwarded-for', nuevaIp())
      .send({ email: '', password: 'Password123' });

    assert.equal(res.status, 422);
  });

  test('422 - contraseña vacía', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .set('x-forwarded-for', nuevaIp())
      .send({ email: 'activo@test.com', password: '' });

    assert.equal(res.status, 422);
  });

  test('422 - campos ausentes (sin body)', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .set('x-forwarded-for', nuevaIp())
      .send({});

    assert.equal(res.status, 422);
  });

  test('401 - email no registrado', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .set('x-forwarded-for', nuevaIp())
      .send({ email: 'noexiste@test.com', password: 'Password123' });

    assert.equal(res.status, 401);
    assert.equal(res.body.success, false);
    assert.equal(res.body.message, 'Credenciales inválidas');
  });

  test('401 - contraseña incorrecta (no revela si el usuario existe)', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .set('x-forwarded-for', nuevaIp())
      .send({ email: 'activo@test.com', password: 'ContrasenaIncorrecta1' });

    assert.equal(res.status, 401);
    assert.equal(res.body.message, 'Credenciales inválidas');
  });

  test('403 - usuario desactivado', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .set('x-forwarded-for', nuevaIp())
      .send({ email: 'inactivo@test.com', password: 'Password123' });

    assert.equal(res.status, 403);
    assert.equal(res.body.success, false);
    assert.ok(/desactivada/i.test(res.body.message));
  });

  test('429 - rate limit tras exceder intentos (fuerza bruta)', async () => {
    const ip = nuevaIp();
    let conteo429 = 0;
    let ultimoStatus = 0;
    // El límite es 10; mandamos 15 para confirmar el bloqueo
    for (let i = 0; i < 15; i++) {
      const res = await request(app)
        .post('/api/auth/login')
        .set('x-forwarded-for', ip)
        .send({ email: 'noexiste@test.com', password: 'Password123' });
      ultimoStatus = res.status;
      if (res.status === 429) conteo429++;
      if (res.status === 429) break;
    }
    assert.equal(ultimoStatus, 429, 'debe bloquear con 429');
    assert.ok(conteo429 >= 1, 'debe responder al menos una vez con 429');
  });
});

// ============================================================================
// REGISTER
// ============================================================================
describe('POST /api/auth/register', () => {
  test('201 - registro exitoso de paciente', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .set('x-forwarded-for', nuevaIp())
      .send({ nombre: 'Nuevo Paciente', email: 'nuevo@test.com', password: 'Password123', rol: 'paciente' });

    assert.equal(res.status, 201, `se obtuvo ${res.status}: ${JSON.stringify(res.body)}`);
    assert.equal(res.body.success, true);
    assert.equal(res.body.data.rol, 'paciente');
    assert.ok(res.body.data.token, 'debe devolver token');
    // El email debe quedar normalizado en la respuesta
    assert.equal(res.body.data.email, 'nuevo@test.com'.toLowerCase());
  });

  test('400 - email ya registrado (duplicado)', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .set('x-forwarded-for', nuevaIp())
      .send({ nombre: 'Dup', email: 'activo@test.com', password: 'Password123', rol: 'paciente' });

    assert.equal(res.status, 400);
    assert.equal(res.body.message, 'El email ya está registrado');
  });

  test('422 - email con formato inválido', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .set('x-forwarded-for', nuevaIp())
      .send({ nombre: 'Paciente', email: 'malo', password: 'Password123', rol: 'paciente' });

    assert.equal(res.status, 422);
  });

  test('422 - contraseña corta (menos de 8)', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .set('x-forwarded-for', nuevaIp())
      .send({ nombre: 'Paciente', email: 'corta@test.com', password: 'Abc12', rol: 'paciente' });

    assert.equal(res.status, 422);
  });

  test('422 - contraseña sin números', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .set('x-forwarded-for', nuevaIp())
      .send({ nombre: 'Paciente', email: 'simnum@test.com', password: 'SoloLetras', rol: 'paciente' });

    assert.equal(res.status, 422);
  });

  test('422 - contraseña sin letras', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .set('x-forwarded-for', nuevaIp())
      .send({ nombre: 'Paciente', email: 'sinletras@test.com', password: '12345678', rol: 'paciente' });

    assert.equal(res.status, 422);
  });

  test('422 - nombre demasiado corto', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .set('x-forwarded-for', nuevaIp())
      .send({ nombre: 'A', email: 'nombrecorto@test.com', password: 'Password123', rol: 'paciente' });

    assert.equal(res.status, 422);
  });

  test('422 - rol inválido', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .set('x-forwarded-for', nuevaIp())
      .send({ nombre: 'Paciente', email: 'rolinv@test.com', password: 'Password123', rol: 'superheroe' });

    assert.equal(res.status, 422);
  });

  test('403 - auto-elevación: crear admin sin token de administrador', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .set('x-forwarded-for', nuevaIp())
      .send({ nombre: 'Mal Intencionado', email: 'malo@test.com', password: 'Password123', rol: 'admin' });

    assert.equal(res.status, 403);
    assert.ok(/administrador/i.test(res.body.message));
  });

  test('403 - auto-elevación: crear medico sin token de administrador', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .set('x-forwarded-for', nuevaIp())
      .send({ nombre: 'Mal Intencionado', email: 'malo2@test.com', password: 'Password123', rol: 'medico' });

    assert.equal(res.status, 403);
  });
});

// ============================================================================
// Health / rutas protegidas sin token
// ============================================================================
describe('Endpoints de autenticación', () => {
  test('200 - health check disponible', async () => {
    const res = await request(app).get('/api/health');
    assert.equal(res.status, 200);
    assert.equal(res.body.status, 'OK');
  });

  test('401 - /api/auth/profile sin token', async () => {
    const res = await request(app).get('/api/auth/profile');
    assert.equal(res.status, 401);
    assert.equal(res.body.message, 'Token no proporcionado');
  });

  test('401 - /api/auth/logout sin token', async () => {
    const res = await request(app).post('/api/auth/logout');
    assert.equal(res.status, 401);
  });
});
