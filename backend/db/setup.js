/**
 * Crea las tablas (db/schema.sql) y siembra los usuarios iniciales por rol.
 *
 *   npm run db:setup
 *
 * Requiere que la base de datos exista y que DB_* estén configurados en .env
 * (ver .env.example). Los usuarios semilla solo se insertan si la tabla está vacía.
 */
const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');
const mysql = require('mysql2/promise');
const config = require('../src/config/config');

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
  const schemaPath = path.join(__dirname, 'schema.sql');
  const schema = fs.readFileSync(schemaPath, 'utf8');

  const conn = await mysql.createConnection({
    host: config.db.host,
    port: config.db.port,
    user: config.db.user,
    password: config.db.password,
    database: config.db.name,
    multipleStatements: true,
  });

  try {
    await conn.query(schema);
    console.log('✅ Tablas verificadas/creadas');

    const [rows] = await conn.query('SELECT COUNT(*) AS total FROM usuarios');
    if (rows[0].total > 0) {
      console.log(`ℹ️  Ya existen ${rows[0].total} usuarios; no se siembran duplicados`);
      return;
    }

    for (const u of SEED_USERS) {
      const hashed = await bcrypt.hash(u.password, 10);
      const [result] = await conn.query(
        'INSERT INTO usuarios (nombre, email, password, rol) VALUES (?, ?, ?, ?)',
        [u.nombre, u.email, hashed, u.rol]
      );

      if (u.rol === 'medico') {
        await conn.query(
          `INSERT INTO medicos (usuario_id, nombre, apellido, cedula, especialidad, email, tarifa_consulta)
           VALUES (?, ?, ?, ?, ?, ?, ?)`,
          [result.insertId, u.nombre, u.perfil.apellido, u.perfil.cedula, u.perfil.especialidad, u.email, u.perfil.tarifa]
        );
      }
      if (u.rol === 'paciente') {
        await conn.query(
          `INSERT INTO pacientes (usuario_id, nombre, apellido, cedula, email)
           VALUES (?, ?, ?, ?, ?)`,
          [result.insertId, u.nombre, u.perfil.apellido, u.perfil.cedula, u.email]
        );
      }
      console.log(`   👤 ${u.rol.padEnd(10)} ${u.email}  (contraseña: ${u.password})`);
    }
    console.log('✅ Usuarios sembrados correctamente');
  } finally {
    await conn.end();
  }
}

main().catch((err) => {
  console.error('❌ Error en db:setup:', err.message);
  process.exit(1);
});
