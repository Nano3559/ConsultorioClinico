/**
 * Siembra datos ficticios (demostración) en Supabase usando el backend.
 *
 *   node db/seed_ficticio.js
 *
 * Requiere las variables de entorno del backend (SUPABASE_URL y
 * SUPABASE_SERVICE_ROLE_KEY o SUPABASE_ANON_KEY) en el archivo .env, y que las
 * migraciones db/migrations/001..004*.sql ya se hayan ejecutado en Supabase.
 *
 * Equivale a que un administrador cargue la información inicial: crea médicos
 * (con su horario), pacientes, citas, consultas (historia clínica) y pagos.
 * Es idempotente: si ya detecta datos ficticios previos, no duplica.
 */
require('dotenv').config();
const { getSupabase } = require('../src/config/supabase');

const MARCADOR_CEDULA = '5678901'; // cédula del primer médico ficticio

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

function diasDesde(hoy, delta) {
  const d = new Date(hoy);
  d.setDate(d.getDate() + delta);
  return d.toISOString().split('T')[0];
}

async function main() {
  const supabase = getSupabase();

  // Idempotencia: si ya existe el médico ficticio marcador, no duplicar.
  const { data: existente } = await supabase
    .from('medicos')
    .select('id')
    .eq('cedula', MARCADOR_CEDULA)
    .limit(1);
  if (existente && existente.length > 0) {
    console.log('ℹ️  Los datos ficticios ya fueron cargados. No se duplican.');
    return;
  }

  const medicoId = {};
  for (const m of MEDICOS) {
    const { data, error } = await supabase
      .from('medicos')
      .insert({
        nombre: m.nombre, apellido: m.apellido, cedula: m.cedula,
        especialidad: m.especialidad, email: m.email, telefono: m.telefono,
        tarifa_consulta: m.tarifa_consulta,
      })
      .select('id')
      .single();
    if (error) throw error;
    medicoId[m.cedula] = data.id;
    for (const h of m.horarios) {
      const { error: hErr } = await supabase.from('horarios').insert({
        medico_id: data.id, dia_semana: h.dia_semana,
        hora_inicio: h.hora_inicio, hora_fin: h.hora_fin, activo: true,
      });
      if (hErr) console.log('⚠️  horario no insertado:', hErr.message);
    }
    console.log(`👨‍⚕️ Médico: ${m.nombre} ${m.apellido} (${m.especialidad})`);
  }

  const pacienteId = {};
  for (const p of PACIENTES) {
    const { data, error } = await supabase
      .from('pacientes')
      .insert({
        nombre: p.nombre, apellido: p.apellido, cedula: p.cedula,
        telefono: p.telefono, email: p.email, fecha_nacimiento: p.fecha_nacimiento,
        sexo: p.sexo, direccion: p.direccion, tipo_sangre: p.tipo_sangre,
        alergias: p.alergias, contacto_emergencia: p.contacto_emergencia,
      })
      .select('id')
      .single();
    if (error) throw error;
    pacienteId[p.cedula] = data.id;
    console.log(`🧑 Paciente: ${p.nombre} ${p.apellido}`);
  }

  const hoy = new Date();
  const citasDef = [
    { mc: '5678901', pc: '9801001', delta: 0, hora: '08:00', motivo: 'Control pediátrico', estado: 'completada' },
    { mc: '5678901', pc: '9801004', delta: 0, hora: '09:00', motivo: 'Vacunación', estado: 'completada' },
    { mc: '5678902', pc: '9801003', delta: 0, hora: '14:00', motivo: 'Dolor torácico', estado: 'completada' },
    { mc: '5678903', pc: '9801008', delta: 0, hora: '09:00', motivo: 'Control prenatal', estado: 'completada' },
    { mc: '5678904', pc: '9801005', delta: 0, hora: '13:00', motivo: 'Lesión deportiva', estado: 'completada' },
    { mc: '5678906', pc: '9801002', delta: 0, hora: '10:00', motivo: 'Consulta general', estado: 'programada' },
    { mc: '5678906', pc: '9801006', delta: 1, hora: '11:00', motivo: 'Chequeo', estado: 'programada' },
    { mc: '5678905', pc: '9801010', delta: 1, hora: '08:00', motivo: 'Acné', estado: 'programada' },
    { mc: '5678902', pc: '9801007', delta: 2, hora: '15:00', motivo: 'Hipertensión', estado: 'programada' },
    { mc: '5678903', pc: '9801012', delta: 2, hora: '09:00', motivo: 'Planificación', estado: 'programada' },
    { mc: '5678901', pc: '9801009', delta: -3, hora: '08:00', motivo: 'Fiebre', estado: 'cancelada' },
    { mc: '5678904', pc: '9801011', delta: -1, hora: '14:00', motivo: 'Dolor lumbar', estado: 'no_show' },
    { mc: '5678906', pc: '9801001', delta: 3, hora: '12:00', motivo: 'Control general', estado: 'programada' },
    { mc: '5678905', pc: '9801004', delta: 4, hora: '08:00', motivo: 'Revisión cutaneous', estado: 'programada' },
  ];

  const citaId = [];
  for (const c of citasDef) {
    const { data, error } = await supabase
      .from('citas')
      .insert({
        paciente_id: pacienteId[c.pc], medico_id: medicoId[c.mc],
        fecha: diasDesde(hoy, c.delta), hora: c.hora, motivo: c.motivo, estado: c.estado,
      })
      .select('id')
      .single();
    if (error) {
      console.log('⚠️  cita no insertada:', error.message);
      continue;
    }
    citaId.push({ id: data.id, def: c });
    console.log(`📅 Cita: ${diasDesde(hoy, c.delta)} ${c.hora} (${c.estado})`);
  }

  const consultasDef = {
    completada: [
      { diag: 'Cuadro respiratorio leve', trat: 'Reposo y hidratación, sintomáticos.' },
      { diag: 'Arritmia detectada', trat: 'EKG y derivación a cardiología.' },
      { diag: 'Embarazo de 12 semanas', trat: 'Control mensual, ácido fólico.' },
      { diag: 'Esguince de tobillo', trat: 'Reposo, frío y vendaje.' },
      { diag: 'Vacunación al día', trat: 'Refuerzo según calendario.' },
    ],
  };
  let ci = 0;
  for (const c of citaId) {
    if (c.def.estado !== 'completada') continue;
    const def = consultasDef.completada[ci % consultasDef.completada.length];
    ci++;
    const { error } = await supabase.from('consultas').insert({
      cita_id: c.id, paciente_id: pacienteId[c.def.pc], medico_id: medicoId[c.def.mc],
      fecha: diasDesde(hoy, c.def.delta), diagnostico: def.diag, tratamiento: def.trat,
      notas_clinicas: 'Sin complicaciones.',
    });
    if (error) console.log('⚠️  consulta no insertada:', error.message);
    else console.log('📋 Consulta registrada');
  }

  const metodos = ['efectivo', 'tarjeta', 'transferencia'];
  let pi = 0;
  for (const c of citaId) {
    if (c.def.estado === 'cancelada' || c.def.estado === 'no_show') continue;
    const monto = 30 + (pi % 5) * 5;
    const { error } = await supabase.from('pagos').insert({
      paciente_id: pacienteId[c.def.pc], cita_id: c.id, monto,
      metodo_pago: metodos[pi % metodos.length],
      estado: c.def.estado === 'completada' ? 'pagado' : 'pendiente',
      descripcion: 'Consulta ' + c.def.motivo,
    });
    if (error) console.log('⚠️  pago no insertado:', error.message);
    else console.log(`💳 Pago ${monto} (${metodos[pi % metodos.length]})`);
    pi++;
  }

  console.log('✅ Datos ficticios cargados correctamente.');
}

main().catch((err) => {
  console.error('❌ Error al cargar datos ficticios:', err.message);
  process.exit(1);
});
