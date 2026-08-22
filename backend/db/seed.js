/**
 * Siembra los usuarios iniciales por rol en Supabase.
 *
 *   npm run db:seed
 *
 * Requiere SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY (o SUPABASE_ANON_KEY) en
 * .env y haber ejecutado antes db/migrations/001_initial_schema.sql en el
 * SQL Editor de Supabase. Los usuarios semilla solo se insertan si la tabla
 * está vacía.
 */
const bcrypt = require('bcryptjs');
const { getSupabase } = require('../src/config/supabase');

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

async function main() {
  const supabase = getSupabase();

  const { count, error: countError } = await supabase
    .from('usuarios')
    .select('id', { count: 'exact', head: true });
  if (countError) throw countError;

  if (count > 0) {
    console.log(`ℹ️  Ya existen ${count} usuarios; no se siembran duplicados`);
    return;
  }

  for (const u of SEED_USERS) {
    const hashed = await bcrypt.hash(u.password, 10);
    const { data, error } = await supabase
      .from('usuarios')
      .insert({ nombre: u.nombre, email: u.email, password: hashed, rol: u.rol })
      .select('id')
      .single();
    if (error) throw error;

    if (u.rol === 'medico') {
      const { error: medError } = await supabase.from('medicos').insert({
        usuario_id: data.id,
        nombre: u.nombre,
        apellido: u.perfil.apellido,
        cedula: u.perfil.cedula,
        especialidad: u.perfil.especialidad,
        email: u.email,
        tarifa_consulta: u.perfil.tarifa,
      });
      if (medError) throw medError;
    }
    if (u.rol === 'paciente') {
      const { error: pacError } = await supabase.from('pacientes').insert({
        usuario_id: data.id,
        nombre: u.nombre,
        apellido: u.perfil.apellido,
        cedula: u.perfil.cedula,
        email: u.email,
      });
      if (pacError) throw pacError;
    }
    console.log(`   👤 ${u.rol.padEnd(10)} ${u.email}  (contraseña: ${u.password})`);
  }
  console.log('✅ Usuarios sembrados correctamente');
}

main().catch((err) => {
  console.error('❌ Error en db:seed:', err.message);
  process.exit(1);
});
