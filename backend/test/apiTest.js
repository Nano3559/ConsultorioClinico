const http = require('http');
const app = require('../src/app');

const PORT = 3998;
const BASE = `http://localhost:${PORT}`;

let server;
let tokens = {}; // rol -> token

function request(method, path, { body, token } = {}) {
  return new Promise((resolve, reject) => {
    const data = body ? JSON.stringify(body) : null;
    const headers = { 'Content-Type': 'application/json' };
    if (token) headers['Authorization'] = `Bearer ${token}`;
    if (data) headers['Content-Length'] = Buffer.byteLength(data);
    const req = http.request(
      { hostname: 'localhost', port: PORT, path, method, headers },
      (res) => {
        let raw = '';
        res.on('data', (c) => (raw += c));
        res.on('end', () => {
          let json = null;
          try { json = JSON.parse(raw); } catch (e) {}
          resolve({ status: res.statusCode, body: json, raw });
        });
      }
    );
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

const results = [];
let current = '';
function group(name) { current = name; }
function test(name, fn) {
  return { name, group: current, fn };
}
function check(label, cond, extra = '') {
  if (!cond) throw new Error(`${label}${extra ? ' | ' + extra : ''}`);
}

const allTests = [];

async function main() {
  server = app.listen(PORT);
  await new Promise((r) => server.on('listening', r));

  // ================= AUTH =================
  group('AUTH');
  allTests.push(
    test('registro sin token crea paciente', async () => {
      const r = await request('POST', '/api/auth/register', {
        body: { nombre: 'Test', email: `test_${Date.now()}@mail.com`, password: '123456' },
      });
      check('201', r.status === 201, JSON.stringify(r.raw));
      check('token', r.body && r.body.data && r.body.data.token);
      check('rol paciente', r.body.data.rol === 'paciente');
    }),
    test('registro con rol privilegiado sin admin -> 403', async () => {
      const r = await request('POST', '/api/auth/register', {
        body: { nombre: 'X', email: `x_${Date.now()}@mail.com`, password: '123456', rol: 'admin' },
      });
      check('403', r.status === 403, JSON.stringify(r.raw));
    }),
    test('registro email duplicado -> 400', async () => {
      const r = await request('POST', '/api/auth/register', {
        body: { nombre: 'X', email: 'pedro@gmail.com', password: '123456' },
      });
      check('400', r.status === 400, JSON.stringify(r.raw));
    }),
    test('login admin', async () => {
      const r = await request('POST', '/api/auth/login', {
        body: { email: 'admin@consultorio.com', password: 'admin123' },
      });
      check('200', r.status === 200, JSON.stringify(r.raw));
      check('admin token', r.body && r.body.data && r.body.data.token);
      check('rol admin', r.body.data.rol === 'admin');
      tokens.admin = r.body.data.token;
    }),
    test('login medico', async () => {
      const r = await request('POST', '/api/auth/login', {
        body: { email: 'carlos@consultorio.com', password: 'medico123' },
      });
      check('200', r.status === 200, JSON.stringify(r.raw));
      tokens.medico = r.body.data.token;
    }),
    test('login recepcion', async () => {
      const r = await request('POST', '/api/auth/login', {
        body: { email: 'maria@consultorio.com', password: 'recepcion123' },
      });
      check('200', r.status === 200, JSON.stringify(r.raw));
      tokens.recepcion = r.body.data.token;
    }),
    test('login paciente', async () => {
      const r = await request('POST', '/api/auth/login', {
        body: { email: 'pedro@gmail.com', password: 'paciente123' },
      });
      check('200', r.status === 200, JSON.stringify(r.raw));
      tokens.paciente = r.body.data.token;
    }),
    test('login password incorrecto -> 401', async () => {
      const r = await request('POST', '/api/auth/login', {
        body: { email: 'admin@consultorio.com', password: 'mala' },
      });
      check('401', r.status === 401, JSON.stringify(r.raw));
    }),
    test('profile sin token -> 401', async () => {
      const r = await request('GET', '/api/auth/profile');
      check('401', r.status === 401, JSON.stringify(r.raw));
    }),
    test('profile con token', async () => {
      const r = await request('GET', '/api/auth/profile', { token: tokens.admin });
      check('200', r.status === 200, JSON.stringify(r.raw));
      check('email', r.body.data.email === 'admin@consultorio.com');
    }),
    test('register validaciones (email invalido) -> 422', async () => {
      const r = await request('POST', '/api/auth/register', {
        body: { nombre: 'X', email: 'noesemail', password: '123456' },
      });
      check('422', r.status === 422, JSON.stringify(r.raw));
      check('errors', Array.isArray(r.body.errors) && r.body.errors.length > 0);
    }),
    test('register password corto -> 422', async () => {
      const r = await request('POST', '/api/auth/register', {
        body: { nombre: 'X', email: `c_${Date.now()}@mail.com`, password: '123' },
      });
      check('422', r.status === 422, JSON.stringify(r.raw));
    })
  );

  // ================= PUBLICOS =================
  group('PUBLICOS');
  allTests.push(
    test('GET /api/health', async () => {
      const r = await request('GET', '/api/health');
      check('200', r.status === 200, JSON.stringify(r.raw));
    }),
    test('GET /api/pacientes', async () => {
      const r = await request('GET', '/api/pacientes');
      check('200', r.status === 200, JSON.stringify(r.raw));
      check('data array', Array.isArray(r.body.data));
    }),
    test('GET /api/pacientes/1', async () => {
      const r = await request('GET', '/api/pacientes/1');
      check('200', r.status === 200, JSON.stringify(r.raw));
      check('id 1', r.body.data && r.body.data.id === 1);
    }),
    test('GET /api/pacientes/999999 -> 404', async () => {
      const r = await request('GET', '/api/pacientes/999999');
      check('404', r.status === 404, JSON.stringify(r.raw));
    }),
    test('GET /api/pacientes/abc -> 422 (idParamValidation)', async () => {
      const r = await request('GET', '/api/pacientes/abc');
      check('422', r.status === 422, JSON.stringify(r.raw));
      check('mensaje validacion', /validación/i.test(r.body.message || ''));
    }),
    test('GET /api/medicos', async () => {
      const r = await request('GET', '/api/medicos');
      check('200', r.status === 200, JSON.stringify(r.raw));
      check('data array', Array.isArray(r.body.data));
    }),
    test('GET /api/medicos/1', async () => {
      const r = await request('GET', '/api/medicos/1');
      check('200', r.status === 200, JSON.stringify(r.raw));
    }),
    test('GET /api/medicos/abc -> 422 (idParamValidation)', async () => {
      const r = await request('GET', '/api/medicos/abc');
      check('422', r.status === 422, JSON.stringify(r.raw));
    }),
    test('GET /api/especialidades', async () => {
      const r = await request('GET', '/api/especialidades');
      check('200', r.status === 200, JSON.stringify(r.raw));
      check('data array', Array.isArray(r.body.data));
    }),
    test('GET /api/horarios', async () => {
      const r = await request('GET', '/api/horarios');
      check('200', r.status === 200, JSON.stringify(r.raw));
    }),
    test('GET /api/horarios/disponibles', async () => {
      const r = await request('GET', '/api/horarios/disponibles');
      check('200', r.status === 200, JSON.stringify(r.raw));
    }),
    test('GET /api/horarios/medico/1', async () => {
      const r = await request('GET', '/api/horarios/medico/1');
      check('200', r.status === 200, JSON.stringify(r.raw));
    }),
    test('GET /api/horarios/medico/999999 -> 404', async () => {
      const r = await request('GET', '/api/horarios/medico/999999');
      check('404', r.status === 404, JSON.stringify(r.raw));
    }),
    // Disponibilidad (requiere valida params)
    test('GET disponibilidad fecha valida', async () => {
      const futuro = '2030-06-10';
      const r = await request('GET', `/api/disponibilidad/medico/3/fecha/${futuro}`);
      check('200', r.status === 200, JSON.stringify(r.raw));
      check('slots array', Array.isArray(r.body.data.slots_disponibles));
    }),
    test('GET disponibilidad medico invalido -> 422', async () => {
      const r = await request('GET', '/api/disponibilidad/medico/abc/fecha/2030-06-10');
      check('422', r.status === 422, JSON.stringify(r.raw));
    }),
    test('GET disponibilidad fecha invalida -> 422', async () => {
      const r = await request('GET', '/api/disponibilidad/medico/3/fecha/10-06-2030');
      check('422', r.status === 422, JSON.stringify(r.raw));
    }),
    test('GET disponibilidad fecha pasada -> 400', async () => {
      const r = await request('GET', '/api/disponibilidad/medico/3/fecha/2020-01-01');
      check('400', r.status === 400, JSON.stringify(r.raw));
    })
  );

  // ================= PROTEGIDOS (401 sin token) =================
  group('PROTEGIDOS sin token');
  allTests.push(
    test('GET /api/citas sin token -> 401', async () => {
      const r = await request('GET', '/api/citas');
      check('401', r.status === 401, JSON.stringify(r.raw));
    }),
    test('GET /api/consultas sin token -> 401', async () => {
      const r = await request('GET', '/api/consultas');
      check('401', r.status === 401);
    }),
    test('GET /api/pagos sin token -> 401', async () => {
      const r = await request('GET', '/api/pagos');
      check('401', r.status === 401);
    }),
    test('GET /api/reportes/citas sin token -> 401', async () => {
      const r = await request('GET', '/api/reportes/citas');
      check('401', r.status === 401);
    }),
    test('GET /api/dashboard sin token -> 401', async () => {
      const r = await request('GET', '/api/dashboard');
      check('401', r.status === 401);
    })
  );

  // ================= CITAS =================
  group('CITAS');
  allTests.push(
    test('GET /api/citas con admin', async () => {
      const r = await request('GET', '/api/citas', { token: tokens.admin });
      check('200', r.status === 200, JSON.stringify(r.raw));
      check('citas array', Array.isArray(r.body.data.citas));
    }),
    test('GET /api/citas con paciente -> 403', async () => {
      const r = await request('GET', '/api/citas', { token: tokens.paciente });
      check('403', r.status === 403, JSON.stringify(r.raw));
    }),
    test('GET /api/citas/1 con token', async () => {
      const r = await request('GET', '/api/citas/1', { token: tokens.admin });
      check('200', r.status === 200, JSON.stringify(r.raw));
      check('id 1', r.body.data && r.body.data.id === 1);
    }),
    test('GET /api/citas/agenda/hoy con admin', async () => {
      const r = await request('GET', '/api/citas/agenda/hoy', { token: tokens.admin });
      check('200', r.status === 200, JSON.stringify(r.raw));
    }),
    test('POST /api/citas con admin (crear en slot libre)', async () => {
      // Buscar el próximo lunes futuro y pedir un slot libre
      const d = new Date();
      d.setDate(d.getDate() + ((7 - d.getDay() + 1) % 7 || 7));
      d.setFullYear(d.getFullYear() + 1); // asegurar futuro
      const dd = String(d.getFullYear()).padStart(4, '0') + '-' +
        String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
      const disp = await request('GET', `/api/disponibilidad/medico/3/fecha/${dd}`);
      const slots = (disp.body && disp.body.data && disp.body.data.slots_disponibles) || [];
      if (slots.length === 0) throw new Error('sin slots disponibles para el médico en ese día');
      const hora = slots[0];
      const r = await request('POST', '/api/citas', {
        token: tokens.admin,
        body: { paciente_id: 3, medico_id: 3, fecha: dd, hora, motivo: 'test' },
      });
      check('201', r.status === 201, JSON.stringify(r.raw));
      check('estado programada', r.body.data.estado === 'programada');
    }),
    test('POST /api/citas validacion faltante -> 422', async () => {
      const r = await request('POST', '/api/citas', {
        token: tokens.admin,
        body: { paciente_id: 3 },
      });
      check('422', r.status === 422, JSON.stringify(r.raw));
    }),
    test('mi-citas con paciente', async () => {
      const r = await request('GET', '/api/citas/mis-citas', { token: tokens.paciente });
      check('200', r.status === 200, JSON.stringify(r.raw));
    })
  );

  // ================= ROLES / OTROS =================
  group('ROLES');
  allTests.push(
    test('POST /api/pacientes como paciente -> 403', async () => {
      const r = await request('POST', '/api/pacientes', {
        token: tokens.paciente,
        body: { nombre: 'X', apellido: 'Y', cedula: '12345678', email: 'x@y.com' },
      });
      check('403', r.status === 403, JSON.stringify(r.raw));
    }),
    test('POST /api/medicos como recepcion -> 403', async () => {
      const r = await request('POST', '/api/medicos', {
        token: tokens.recepcion,
        body: { nombre: 'X', apellido: 'Y', especialidad: 'Medicina General', cedula: '1111' },
      });
      check('403', r.status === 403, JSON.stringify(r.raw));
    }),
    test('POST /api/pacientes como admin', async () => {
      const cedula = `T${Date.now()}`;
      const r = await request('POST', '/api/pacientes', {
        token: tokens.admin,
        body: { nombre: 'TestPac', apellido: 'Ap', cedula, email: `${cedula}@mail.com`, sexo: 'M' },
      });
      check('201', r.status === 201, JSON.stringify(r.raw));
      check('sexo M', r.body.data.sexo === 'M');
    }),
    test('POST /api/pacientes validacion cedula vacio -> 422', async () => {
      const r = await request('POST', '/api/pacientes', {
        token: tokens.admin,
        body: { nombre: 'X', apellido: 'Y' },
      });
      check('422', r.status === 422, JSON.stringify(r.raw));
    }),
    test('POST /api/pacientes sexo invalido -> 422', async () => {
      const r = await request('POST', '/api/pacientes', {
        token: tokens.admin,
        body: { nombre: 'X', apellido: 'Y', cedula: `S${Date.now()}`, sexo: 'Z' },
      });
      check('422', r.status === 422, JSON.stringify(r.raw));
    }),
    test('POST /api/medicos como admin', async () => {
      const cedula = `M${Date.now()}`;
      const r = await request('POST', '/api/medicos', {
        token: tokens.admin,
        body: { nombre: 'TestMed', apellido: 'Doc', cedula, especialidad: 'Medicina General', email: `${cedula}@mail.com` },
      });
      check('201', r.status === 201, JSON.stringify(r.raw));
    }),
    test('POST /api/medicos validacion sin especialidad -> 422', async () => {
      const r = await request('POST', '/api/medicos', {
        token: tokens.admin,
        body: { nombre: 'X', apellido: 'Y', cedula: `X${Date.now()}` },
      });
      check('422', r.status === 422, JSON.stringify(r.raw));
    }),
    test('GET /api/reportes/citas con admin', async () => {
      const r = await request('GET', '/api/reportes/citas', { token: tokens.admin });
      check('200', r.status === 200, JSON.stringify(r.raw));
    }),
    test('GET /api/reportes/citas con medico -> 403', async () => {
      const r = await request('GET', '/api/reportes/citas', { token: tokens.medico });
      check('403', r.status === 403, JSON.stringify(r.raw));
    }),
    test('GET /api/dashboard con admin', async () => {
      const r = await request('GET', '/api/dashboard', { token: tokens.admin });
      check('200', r.status === 200, JSON.stringify(r.raw));
    }),
    test('GET /api/consultas con admin', async () => {
      const r = await request('GET', '/api/consultas', { token: tokens.admin });
      check('200', r.status === 200, JSON.stringify(r.raw));
    })
  );

  // ================= HORARIOS (admin) =================
  group('HORARIOS admin');
  allTests.push(
    test('POST horario valido en médico de prueba -> 201', async () => {
      // Médico de prueba nuevo (sin horarios) para no colisionar con datos existentes
      const cedula = `HM${Date.now()}`;
      const med = await request('POST', '/api/medicos', {
        token: tokens.admin,
        body: { nombre: 'HorMed', apellido: 'Prueba', cedula, especialidad: 'Medicina General' },
      });
      check('medico creado', med.status === 201, JSON.stringify(med.raw));
      const medId = med.body.data.id;
      const r = await request('POST', '/api/horarios', {
        token: tokens.admin,
        body: { medico_id: medId, dia_semana: 'Domingo', hora_inicio: '09:00', hora_fin: '10:00' },
      });
      check('201', r.status === 201, JSON.stringify(r.raw) || 'ok');
    }),
    test('POST horario solapado -> 409', async () => {
      const cedula = `HS${Date.now()}`;
      const med = await request('POST', '/api/medicos', {
        token: tokens.admin,
        body: { nombre: 'HorSol', apellido: 'Prueba', cedula, especialidad: 'Medicina General' },
      });
      check('medico creado', med.status === 201, JSON.stringify(med.raw));
      const medId = med.body.data.id;
      const base = await request('POST', '/api/horarios', {
        token: tokens.admin,
        body: { medico_id: medId, dia_semana: 'Domingo', hora_inicio: '09:00', hora_fin: '10:00' },
      });
      check('base creado', base.status === 201, JSON.stringify(base.raw));
      const r = await request('POST', '/api/horarios', {
        token: tokens.admin,
        body: { medico_id: medId, dia_semana: 'Domingo', hora_inicio: '09:30', hora_fin: '11:00' },
      });
      check('409', r.status === 409, JSON.stringify(r.raw));
    }),
    test('POST horario hora_fin <= hora_inicio -> 400', async () => {
      const r = await request('POST', '/api/horarios', {
        token: tokens.admin,
        body: { medico_id: 3, dia_semana: 'Domingo', hora_inicio: '11:00', hora_fin: '09:00' },
      });
      check('400', r.status === 400, JSON.stringify(r.raw));
    }),
    test('POST horario dia invalido -> 422', async () => {
      const r = await request('POST', '/api/horarios', {
        token: tokens.admin,
        body: { medico_id: 3, dia_semana: 'XYZ', hora_inicio: '09:00', hora_fin: '10:00' },
      });
      check('422', r.status === 422, JSON.stringify(r.raw));
    })
  );

  // ================= PAGOS =================
  group('PAGOS');
  allTests.push(
    test('POST /api/pagos valido (admin)', async () => {
      const r = await request('POST', '/api/pagos', {
        token: tokens.admin,
        body: { paciente_id: 3, cita_id: 1, monto: 30, metodo_pago: 'efectivo' },
      });
      check('201', r.status === 201, JSON.stringify(r.raw));
    }),
    test('POST /api/pagos monto invalido -> 422', async () => {
      const r = await request('POST', '/api/pagos', {
        token: tokens.admin,
        body: { paciente_id: 3, monto: 0, metodo_pago: 'efectivo' },
      });
      check('422', r.status === 422, JSON.stringify(r.raw));
    }),
    test('POST /api/pagos metodo invalido -> 422', async () => {
      const r = await request('POST', '/api/pagos', {
        token: tokens.admin,
        body: { paciente_id: 3, monto: 30, metodo_pago: 'bitcoin' },
      });
      check('422', r.status === 422, JSON.stringify(r.raw));
    })
  );

  // ================= CONSULTAS =================
  group('CONSULTAS');
  allTests.push(
    test('POST /api/consultas (medico)', async () => {
      const r = await request('POST', '/api/consultas', {
        token: tokens.medico,
        body: { paciente_id: 3, medico_id: 1, diagnostico: 'D', tratamiento: 'T' },
      });
      check('201', r.status === 201, JSON.stringify(r.raw));
    }),
    test('POST /api/consultas validacion -> 422', async () => {
      const r = await request('POST', '/api/consultas', {
        token: tokens.medico,
        body: { paciente_id: 3 },
      });
      check('422', r.status === 422, JSON.stringify(r.raw));
    })
  );

  // ================= ESPECIALIDADES admin =================
  group('ESPECIALIDADES');
  allTests.push(
    test('POST /api/especialidades como admin (tabla no existe -> 503)', async () => {
      const r = await request('POST', '/api/especialidades', {
        token: tokens.admin,
        body: { nombre: 'Cardiología' },
      });
      // Si tabla no existe devuelve 503; sino 201
      check('503 o 201', r.status === 503 || r.status === 201, JSON.stringify(r.raw));
    })
  );

  // ================= EJECUTAR =================
  let passed = 0;
  const failures = [];
  for (const { name, group: g, fn } of allTests) {
    try {
      await fn();
      passed++;
      console.log(`  PASS  [${g}] ${name}`);
    } catch (e) {
      failures.push({ g, name, msg: e.message });
      console.log(`  FAIL  [${g}] ${name} -> ${e.message}`);
    }
  }

  await new Promise((r) => server.close(r));
  console.log(`\n========== RESULTADO: ${passed}/${allTests.length} pasaron ==========`);
  if (failures.length) {
    console.log('\nFALLOS:');
    failures.forEach((f) => console.log(`  - [${f.g}] ${f.name}: ${f.msg}`));
    process.exitCode = 1;
  }
}

main().catch((e) => {
  console.error('Error fatal en test:', e);
  process.exit(1);
});
