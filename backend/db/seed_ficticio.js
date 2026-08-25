/**
 * Siembra datos ficticios (demostración) CONSUMIENDO LA API REST.
 *
 *   node db/seed_ficticio.js
 *
 * Equivale a que un ADMINISTRADOR cargue la información desde la interfaz:
 *  - Se autentica con la cuenta admin (ADMIN_EMAIL / ADMIN_PASSWORD).
 *  - Crea médicos (POST /api/medicos) y sus horarios (POST /api/medicos/:id/horarios).
 *  - Crea pacientes (POST /api/pacientes).
 *  - Crea citas (POST /api/citas) y ajusta su estado (PATCH /api/citas/:id/estado).
 *  - Registra consultas (POST /api/consultas) y pagos (POST /api/pagos).
 *
 * Requisitos:
 *  - Backend corriendo (API_BASE_URL, por defecto http://localhost:3000/api).
 *  - Tablas creadas (migraciones db/migrations/001..004*.sql) y db:seed ejecutado.
 *  - Node >= 18 (usa fetch global).
 *
 * Es idempotente: si ya detecta médicos ficticios, no duplica.
 */
const BASE = process.env.API_BASE_URL || 'http://localhost:3000/api';
const ADMIN_EMAIL = process.env.ADMIN_EMAIL || 'admin@consultorio.com';
const ADMIN_PASS = process.env.ADMIN_PASSWORD || 'admin123';

const MARCADOR_CEDULA = '5678901';

const MEDICOS = [
  {
    nombre: 'Ana', apellido: 'Ruiz', cedula: '5678901', especialidad: 'Pediatría',
    email: 'ana.ruiz@clinica.com', telefono: '0981 200 101', tarifa_consulta: 35,
    horarios: [
      { dia_semana: 'Lunes', hora_inicio: '08:00', hora_fin: '12:00' },
      { dia_semana: 'Martes', hora_inicio: '08:00', hora_fin: '12:00' },
      { dia_semana: 'Miércoles', hora_inicio: '08:00', hora_fin: '12:00' },
      { dia_semana: 'Jueves', hora_inicio: '08:00', hora_fin: '12:00' },
      { dia_semana: 'Viernes', hora_inicio: '08:00', hora_fin: '12:00' },
    ],
  },
  {
    nombre: 'Luis', apellido: 'Gómez', cedula: '5678902', especialidad: 'Cardiología',
    email: 'luis.gomez@clinica.com', telefono: '0981 200 102', tarifa_consulta: 50,
    horarios: [
      { dia_semana: 'Martes', hora_inicio: '14:00', hora_fin: '18:00' },
      { dia_semana: 'Jueves', hora_inicio: '14:00', hora_fin: '18:00' },
      { dia_semana: 'Viernes', hora_inicio: '14:00', hora_fin: '18:00' },
    ],
  },
  {
    nombre: 'Sofía', apellido: 'Núñez', cedula: '5678903', especialidad: 'Ginecología',
    email: 'sofia.nunez@clinica.com', telefono: '0981 200 103', tarifa_consulta: 45,
    horarios: [
      { dia_semana: 'Lunes', hora_inicio: '09:00', hora_fin: '13:00' },
      { dia_semana: 'Miércoles', hora_inicio: '09:00', hora_fin: '13:00' },
      { dia_semana: 'Viernes', hora_inicio: '09:00', hora_fin: '13:00' },
    ],
  },
  {
    nombre: 'Carlos', apellido: 'Benítez', cedula: '5678904', especialidad: 'Traumatología',
    email: 'carlos.benitez@clinica.com', telefono: '0981 200 104', tarifa_consulta: 40,
    horarios: [
      { dia_semana: 'Lunes', hora_inicio: '13:00', hora_fin: '17:00' },
      { dia_semana: 'Martes', hora_inicio: '13:00', hora_fin: '17:00' },
      { dia_semana: 'Miércoles', hora_inicio: '13:00', hora_fin: '17:00' },
      { dia_semana: 'Jueves', hora_inicio: '13:00', hora_fin: '17:00' },
      { dia_semana: 'Viernes', hora_inicio: '13:00', hora_fin: '17:00' },
    ],
  },
  {
    nombre: 'Miguel', apellido: 'Aguilar', cedula: '5678905', especialidad: 'Dermatología',
    email: 'miguel.aguilar@clinica.com', telefono: '0981 200 105', tarifa_consulta: 38,
    horarios: [
      { dia_semana: 'Martes', hora_inicio: '08:00', hora_fin: '12:00' },
      { dia_semana: 'Jueves', hora_inicio: '08:00', hora_fin: '12:00' },
    ],
  },
  {
    nombre: 'Patricia', apellido: 'Cáceres', cedula: '5678906', especialidad: 'Medicina General',
    email: 'patricia.caceres@clinica.com', telefono: '0981 200 106', tarifa_consulta: 30,
    horarios: [
      { dia_semana: 'Lunes', hora_inicio: '07:00', hora_fin: '13:00' },
      { dia_semana: 'Martes', hora_inicio: '07:00', hora_fin: '13:00' },
      { dia_semana: 'Miércoles', hora_inicio: '07:00', hora_fin: '13:00' },
      { dia_semana: 'Jueves', hora_inicio: '07:00', hora_fin: '13:00' },
      { dia_semana: 'Viernes', hora_inicio: '07:00', hora_fin: '13:00' },
    ],
  },
];

const PACIENTES = [
  { nombre: 'Jorge', apellido: 'Martínez', cedula: '9801001', telefono: '0981 300 201', email: 'jorge.martinez@mail.com', fecha_nacimiento: '1990-04-12', sexo: 'M', direccion: 'Av. España 123', tipo_sangre: 'O+', alergias: 'Ninguna', contacto_emergencia: '0981 999 001' },
  { nombre: 'Claudia', apellido: 'López', cedula: '9801002', telefono: '0981 300 202', email: 'claudia.lopez@mail.com', fecha_nacimiento: '1985-09-30', sexo: 'F', direccion: 'Calle Palma 456', tipo_sangre: 'A+', alergias: 'Penicilina', contacto_emergencia: '0981 999 002' },
  { nombre: 'Rubén', apellido: 'Cáceres', cedula: '9801003', telefono: '0981 300 203', email: 'ruben.caceres@mail.com', fecha_nacimiento: '1978-01-22', sexo: 'M', direccion: 'Barrio Trinidad', tipo_sangre: 'B+', alergias: 'Ninguna', contacto_emergencia: '0981 999 003' },
  { nombre: 'Valeria', apellido: 'Giménez', cedula: '9801004', telefono: '0981 300 204', email: 'valeria.gimenez@mail.com', fecha_nacimiento: '1996-07-08', sexo: 'F', direccion: 'Los Laureles', tipo_sangre: 'AB+', alergias: 'Frío', contacto_emergencia: '0981 999 004' },
  { nombre: 'Héctor', apellido: 'Riveros', cedula: '9801005', telefono: '0981 300 205', email: 'hector.riveros@mail.com', fecha_nacimiento: '1969-11-15', sexo: 'M', direccion: 'Mbocayá 88', tipo_sangre: 'O-', alergias: 'Ninguna', contacto_emergencia: '0981 999 005' },
  { nombre: 'Gabriela', apellido: 'Acuña', cedula: '9801006', telefono: '0981 300 206', email: 'gabriela.acuna@mail.com', fecha_nacimiento: '2001-03-03', sexo: 'F', direccion: 'San Lorenzo', tipo_sangre: 'A-', alergias: 'Ninguna', contacto_emergencia: '0981 999 006' },
  { nombre: 'Diego', apellido: 'Ojeda', cedula: '9801007', telefono: '0981 300 207', email: 'diego.ojeda@mail.com', fecha_nacimiento: '1988-12-19', sexo: 'M', direccion: 'Villa Elisa', tipo_sangre: 'B-', alergias: 'Polen', contacto_emergencia: '0981 999 007' },
  { nombre: 'Mónica', apellido: 'Paredes', cedula: '9801008', telefono: '0981 300 208', email: 'monica.paredes@mail.com', fecha_nacimiento: '1993-06-25', sexo: 'F', direccion: 'Fernando de la Mora', tipo_sangre: 'O+', alergias: 'Ninguna', contacto_emergencia: '0981 999 008' },
  { nombre: 'Oscar', apellido: 'León', cedula: '9801009', telefono: '0981 300 209', email: 'oscar.leon@mail.com', fecha_nacimiento: '1975-02-10', sexo: 'M', direccion: 'Luque', tipo_sangre: 'A+', alergias: 'Ninguna', contacto_emergencia: '0981 999 009' },
  { nombre: 'Camila', apellido: 'Sosa', cedula: '9801010', telefono: '0981 300 210', email: 'camila.sosa@mail.com', fecha_nacimiento: '2004-08-17', sexo: 'F', direccion: 'Capiatá', tipo_sangre: 'O+', alergias: 'Ninguna', contacto_emergencia: '0981 999 010' },
  { nombre: 'Néstor', apellido: 'Brítez', cedula: '9801011', telefono: '0981 300 211', email: 'nestor.britez@mail.com', fecha_nacimiento: '1982-05-05', sexo: 'M', direccion: 'Lambaré', tipo_sangre: 'B+', alergias: 'Sulfas', contacto_emergencia: '0981 999 011' },
  { nombre: 'Rocío', apellido: 'Vera', cedula: '9801012', telefono: '0981 300 212', email: 'rocio.vera@mail.com', fecha_nacimiento: '1999-10-28', sexo: 'F', direccion: 'Ñemby', tipo_sangre: 'AB-', alergias: 'Ninguna', contacto_emergencia: '0981 999 012' },
];

const DIA_A_JS = { 'Domingo': 0, 'Lunes': 1, 'Martes': 2, 'Miércoles': 3, 'Jueves': 4, 'Viernes': 5, 'Sábado': 6 };

function nextDateForWeekday(dia, weeksAhead = 0) {
  const target = DIA_A_JS[dia];
  const hoy = new Date();
  hoy.setHours(0, 0, 0, 0);
  const diff = (target - hoy.getDay() + 7) % 7;
  const d = new Date(hoy);
  d.setDate(d.getDate() + diff + weeksAhead * 7);
  if (d < hoy) d.setDate(d.getDate() + 7);
  return d.toISOString().split('T')[0];
}

async function api(path, method, body, token) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = 'Bearer ' + token;
  const r = await fetch(BASE + path, { method, headers, body: body ? JSON.stringify(body) : undefined });
  const j = await r.json().catch(() => ({}));
  if (!r.ok) {
    throw new Error(`${method} ${path} -> ${r.status} ${j.message || JSON.stringify(j)}`);
  }
  return j.data !== undefined ? j.data : j;
}

async function login() {
  const r = await fetch(`${BASE}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: ADMIN_EMAIL, password: ADMIN_PASS }),
  });
  const j = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(`Login admin fallo: ${r.status} ${j.message || JSON.stringify(j)}`);
  const token = j.data && j.data.token ? j.data.token : j.token;
  if (!token) throw new Error('No se obtuvo token del login');
  return token;
}

async function main() {
  // Idempotencia: ¿ya existen los médicos ficticios?
  const lista = await api('/medicos', 'GET');
  const medicosExistentes = (lista.data || lista || []).filter
    ? (lista.data || lista)
    : [];
  if (Array.isArray(medicosExistentes) && medicosExistentes.some((m) => m.cedula === MARCADOR_CEDULA)) {
    console.log('ℹ️  Los datos ficticios ya fueron cargados vía API. No se duplican.');
    return;
  }

  const token = await login();
  console.log('🔑 Sesión admin iniciada.');

  const medicoId = {};
  for (const m of MEDICOS) {
    const creado = await api('/medicos', 'POST', {
      nombre: m.nombre, apellido: m.apellido, cedula: m.cedula,
      especialidad: m.especialidad, email: m.email, telefono: m.telefono,
      tarifa_consulta: m.tarifa_consulta,
    }, token);
    const id = creado.id;
    medicoId[m.cedula] = id;
    for (const h of m.horarios) {
      await api(`/medicos/${id}/horarios`, 'POST', {
        dia_semana: h.dia_semana, hora_inicio: h.hora_inicio, hora_fin: h.hora_fin,
      }, token);
    }
    console.log(`👨‍⚕️ Médico: ${m.nombre} ${m.apellido} (${m.especialidad}) + horarios`);
  }

  const pacienteId = {};
  for (const p of PACIENTES) {
    const creado = await api('/pacientes', 'POST', {
      nombre: p.nombre, apellido: p.apellido, cedula: p.cedula,
      telefono: p.telefono, email: p.email, fecha_nacimiento: p.fecha_nacimiento,
      sexo: p.sexo, direccion: p.direccion, tipo_sangre: p.tipo_sangre,
      alergias: p.alergias, contacto_emergencia: p.contacto_emergencia,
    }, token);
    pacienteId[p.cedula] = creado.id;
    console.log(`🧑 Paciente: ${p.nombre} ${p.apellido}`);
  }

  // Generar planes de citas: hasta 2 horarios por médico, semanas 0 y 1.
  const planes = [];
  let pi = 0;
  MEDICOS.forEach((m, mi) => {
    m.horarios.slice(0, 2).forEach((h) => {
      [0, 1].forEach((wk) => {
        const pc = PACIENTES[pi % PACIENTES.length].cedula;
        pi++;
        let estado = wk === 0 ? 'completada' : 'programada';
        if (mi === 0 && wk === 0) estado = 'cancelada';
        if (mi === 1 && wk === 0) estado = 'no_show';
        planes.push({ mc: m.cedula, pc, dia: h.dia_semana, hora: h.hora_inicio, wk, estado, motivo: 'Consulta de demostración' });
      });
    });
  });

  const metodos = ['efectivo', 'tarjeta', 'transferencia'];
  let ci = 0;
  for (const plan of planes) {
    const fecha = nextDateForWeekday(plan.dia, plan.wk);
    const cita = await api('/citas', 'POST', {
      paciente_id: pacienteId[plan.pc],
      medico_id: medicoId[plan.mc],
      fecha,
      hora: plan.hora,
      motivo: plan.motivo,
    }, token);
    const citaId = cita.id;

    if (plan.estado !== 'programada') {
      await api(`/citas/${citaId}/estado`, 'PATCH', { estado: plan.estado }, token);
    }
    console.log(`📅 Cita ${fecha} ${plan.hora} -> ${plan.estado}`);

    if (plan.estado === 'completada') {
      const diag = 'Control clínico sin complicaciones.';
      const trat = 'Indicaciones generales y seguimiento.';
      await api('/consultas', 'POST', {
        cita_id: citaId, paciente_id: pacienteId[plan.pc], medico_id: medicoId[plan.mc],
        diagnostico: diag, tratamiento: trat, notas_clinicas: 'Registro de demostración.',
      }, token);
      const monto = 30 + (ci % 5) * 5;
      await api('/pagos', 'POST', {
        paciente_id: pacienteId[plan.pc], cita_id: citaId, monto,
        metodo_pago: metodos[ci % metodos.length], descripcion: 'Consulta ' + plan.motivo,
      }, token);
      console.log(`📋 Consulta + 💳 Pago ${monto} (${metodos[ci % metodos.length]})`);
    }
    ci++;
  }

  console.log('✅ Datos ficticios cargados en la base de datos a través de la API.');
}

main().catch((err) => {
  console.error('❌ Error al cargar datos ficticios vía API:', err.message);
  process.exit(1);
});
