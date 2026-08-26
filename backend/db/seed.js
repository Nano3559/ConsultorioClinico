/**
 * Siembra los usuarios iniciales por rol en Supabase.
 *
 *   npm run db:seed            -> solo siembra si la tabla está vacía
 *   npm run db:seed -- --reset -> además restablece la contraseña de los
 *                                 usuarios semilla ya existentes y completa
 *                                 sus perfiles si faltan
 *
 * Requiere SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY (o SUPABASE_ANON_KEY) en
 * .env y haber ejecutado antes db/migrations/001_initial_schema.sql en el
 * SQL Editor de Supabase.
 */
const bcrypt = require('bcryptjs');
const { getSupabase } = require('../src/config/supabase');

const RESET = process.argv.includes('--reset');

const SEED_USERS = [
  { nombre: 'Administrador', email: 'admin@consultorio.com', password: 'admin123', rol: 'admin' },
  { nombre: 'Carlos Ramírez', email: 'carlos@consultorio.com', password: 'medico123', rol: 'medico',
    perfil: { apellido: 'Gómez', cedula: '1712345671', especialidad: 'Medicina General', tarifa: 30 } },
  { nombre: 'Laura Sánchez', email: 'laura@consultorio.com', password: 'medico123', rol: 'medico',
    perfil: { apellido: 'Torres', cedula: '1712345672', especialidad: 'Pediatría', tarifa: 35 } },
  { nombre: 'María Pérez', email: 'maria@consultorio.com', password: 'recepcion123', rol: 'recepcion' },
  { nombre: 'Pedro Paciente', email: 'pedro@gmail.com', password: 'paciente123', rol: 'paciente',
    perfil: { apellido: 'González', cedula: '1712345673' } },
];

async function crearPerfil(supabase, u, usuarioId) {
  if (u.rol === 'medico') {
    const { data: existe } = await supabase.from('medicos').select('id').eq('usuario_id', usuarioId).limit(1);
    let medicoId;
    if (existe && existe.length > 0) {
      medicoId = existe[0].id;
    } else {
      const { data, error } = await supabase
        .from('medicos')
        .insert({
          usuario_id: usuarioId,
          nombre: u.nombre,
          apellido: u.perfil.apellido,
          cedula: u.perfil.cedula,
          especialidad: u.perfil.especialidad,
          email: u.email,
          tarifa_consulta: u.perfil.tarifa,
        })
        .select('id')
        .single();
      if (error) throw error;
      medicoId = data.id;
    }
    // Horarios de ejemplo para que la reserva tenga franjas disponibles.
    await supabase.from('horarios').delete().eq('medico_id', medicoId);
    const horarios = [
      { medico_id: medicoId, dia_semana: 'Lunes', hora_inicio: '08:00', hora_fin: '12:00', activo: true },
      { medico_id: medicoId, dia_semana: 'Martes', hora_inicio: '14:00', hora_fin: '18:00', activo: true },
      { medico_id: medicoId, dia_semana: 'Miércoles', hora_inicio: '08:00', hora_fin: '12:00', activo: true },
      { medico_id: medicoId, dia_semana: 'Jueves', hora_inicio: '14:00', hora_fin: '18:00', activo: true },
      { medico_id: medicoId, dia_semana: 'Viernes', hora_inicio: '08:00', hora_fin: '12:00', activo: true },
    ];
    const { error: hErr } = await supabase.from('horarios').insert(horarios);
    if (hErr) console.log('⚠️ No se sembraron horarios:', hErr.message);
  }
  if (u.rol === 'paciente') {
    const { data: existe } = await supabase.from('pacientes').select('id').eq('usuario_id', usuarioId).limit(1);
    if (existe && existe.length > 0) return;
    const { error } = await supabase.from('pacientes').insert({
      usuario_id: usuarioId,
      nombre: u.nombre,
      apellido: u.perfil.apellido,
      cedula: u.perfil.cedula,
      email: u.email,
    });
    if (error) throw error;
  }
}

async function main() {
  const supabase = getSupabase();

  const { count, error: countError } = await supabase
    .from('usuarios')
    .select('id', { count: 'exact', head: true });
  if (countError) throw countError;

  if (count === 0 || RESET) {
    for (const u of SEED_USERS) {
      const hashed = await bcrypt.hash(u.password, 10);

      // ¿Ya existe el usuario por email?
      const { data: existentes } = await supabase
        .from('usuarios')
        .select('id')
        .eq('email', u.email)
        .limit(1);

      let usuarioId;
      if (existentes && existentes.length > 0) {
        usuarioId = existentes[0].id;
        if (!RESET) {
          console.log(`ℹ️  ${u.email} ya existe; se omite`);
          continue;
        }
        const { error: updErr } = await supabase
          .from('usuarios')
          .update({ nombre: u.nombre, password: hashed, rol: u.rol, activo: true })
          .eq('id', usuarioId);
        if (updErr) throw updErr;
        console.log(`🔑 Contraseña restablecida: ${u.email}`);
      } else {
        const { data, error } = await supabase
          .from('usuarios')
          .insert({ nombre: u.nombre, email: u.email, password: hashed, rol: u.rol })
          .select('id')
          .single();
        if (error) throw error;
        usuarioId = data.id;
        console.log(`👤 ${u.rol.padEnd(10)} ${u.email}  (contraseña: ${u.password})`);
      }

      await crearPerfil(supabase, u, usuarioId);
    }
    console.log(RESET ? '✅ Usuarios semilla verificados/restablecidos' : '✅ Usuarios sembrados correctamente');
    return;
  }

  console.log(`ℹ️  Ya existen ${count} usuarios; use "npm run db:seed -- --reset" para restablecer contraseñas`);
}

main().catch((err) => {
  console.error('❌ Error en db:seed:', err.message);
  process.exit(1);
});
