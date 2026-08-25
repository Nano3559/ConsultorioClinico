/**
 * Ejecuta las migraciones SQL de db/migrations contra la base de datos
 * PostgreSQL de Supabase, en orden y sin repetir las ya aplicadas.
 *
 *   npm run db:migrate            -> aplica migraciones pendientes
 *   npm run db:migrate -- --status-> solo muestra el estado
 *
 * Requiere en .env la cadena de conexión directa a Postgres:
 *   SUPABASE_DB_URL=postgresql://postgres:TU_PASSWORD@db.xxxx.supabase.co:5432/postgres
 *   (Dashboard -> Project Settings -> Database -> Connection string -> URI)
 *
 * Cada archivo se aplica dentro de una transacción y queda registrado en la
 * tabla _migraciones; si uno falla, se revierte y se detiene.
 */
const fs = require('fs');
const path = require('path');
const { Client } = require('pg');

const STATUS_ONLY = process.argv.includes('--status');
const MIGRATIONS_DIR = path.join(__dirname, 'migrations');

function connectionString() {
  return (
    process.env.SUPABASE_DB_URL ||
    process.env.DATABASE_URL ||
    ''
  ).trim();
}

async function main() {
  const cs = connectionString();
  if (!cs) {
    console.error(
      '❌ Falta SUPABASE_DB_URL en backend/.env\n' +
        '   Cópiala desde Supabase Dashboard -> Project Settings -> Database\n' +
        '   -> Connection string -> URI (usa tu password de base de datos).'
    );
    process.exit(1);
  }

  const archivos = fs
    .readdirSync(MIGRATIONS_DIR)
    .filter((f) => f.endsWith('.sql'))
    .sort();
  if (archivos.length === 0) {
    console.log('ℹ️  No hay migraciones en db/migrations');
    return;
  }

  const client = new Client({
    connectionString: cs,
    ssl: /localhost|127\.0\.0\.1/.test(cs)
      ? false
      : { rejectUnauthorized: false },
  });
  await client.connect();

  // Registro de migraciones aplicadas (esquema public, nombre descriptivo)
  await client.query(`
    CREATE TABLE IF NOT EXISTS _migraciones (
      nombre      VARCHAR(255) PRIMARY KEY,
      aplicada_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  const { rows } = await client.query('SELECT nombre FROM _migraciones');
  const aplicadas = new Set(rows.map((r) => r.nombre));

  console.log(`📦 ${archivos.length} migraciones encontradas, ${aplicadas.size} ya aplicadas`);

  let pendientes = 0;
  for (const archivo of archivos) {
    if (aplicadas.has(archivo)) {
      console.log(`✅ ${archivo} (ya aplicada)`);
      continue;
    }
    if (STATUS_ONLY) {
      console.log(`⏳ ${archivo} (pendiente)`);
      pendientes++;
      continue;
    }

    const sql = fs.readFileSync(path.join(MIGRATIONS_DIR, archivo), 'utf8');
    console.log(`▶️  Aplicando ${archivo}...`);
    try {
      await client.query('BEGIN');
      await client.query(sql);
      await client.query('INSERT INTO _migraciones (nombre) VALUES ($1)', [
        archivo,
      ]);
      await client.query('COMMIT');
      console.log(`✅ ${archivo} aplicada`);
      pendientes++;
    } catch (err) {
      await client.query('ROLLBACK');
      console.error(`❌ Error aplicando ${archivo}: ${err.message}`);
      await client.end();
      process.exit(1);
    }
  }

  if (STATUS_ONLY && pendientes === 0) {
    console.log('✅ Base de datos al día');
  } else if (!STATUS_ONLY) {
    console.log('🎉 Migraciones completas. Base de datos lista.');
  }

  await client.end();
}

main().catch((err) => {
  console.error('❌ Error en db:migrate:', err.message);
  process.exit(1);
});
