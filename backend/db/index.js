/**
 * Inicialización unificada de la base de datos.
 *
 * Este archivo se puede ejecutar para:
 *   1. Verificar la conexión a Supabase
 *   2. Ejecutar las migraciones SQL pendientes (si SUPABASE_DB_URL está configurada)
 *   3. Sembrar los usuarios iniciales (si la tabla está vacía)
 *
 * Uso:
 *   node db/index.js              -> inicialización completa
 *   node db/index.js --check      -> solo verificar conexión
 *   node db/index.js --seed       -> solo sembrar usuarios
 *   node db/index.js --migrate    -> solo ejecutar migraciones
 */
const { testConnection } = require('../src/config/supabase');

const args = process.argv.slice(2);
const CHECK_ONLY = args.includes('--check');
const SEED_ONLY = args.includes('--seed');
const MIGRATE_ONLY = args.includes('--migrate');
const FULL_INIT = !CHECK_ONLY && !SEED_ONLY && !MIGRATE_ONLY;

async function checkConnection() {
  console.log('[DB] Verificando conexión a Supabase...');
  try {
    await testConnection();
    console.log('[DB] Conexión exitosa');
    return true;
  } catch (error) {
    console.error('[DB] Error de conexión:', error.message);
    return false;
  }
}

async function runSeed() {
  console.log('[DB] Ejecutando seed de usuarios...');
  try {
    require('./seed.js');
  } catch (error) {
    console.error('[DB] Error en seed:', error.message);
    return false;
  }
  return true;
}

async function runMigrate() {
  const cs = (process.env.SUPABASE_DB_URL || process.env.DATABASE_URL || '').trim();
  if (!cs) {
    console.log('[DB] SUPABASE_DB_URL no configurada; omitiendo migraciones.');
    console.log('[DB] Para ejecutar migraciones, configura SUPABASE_DB_URL en .env');
    console.log('[DB] o ejecuta las migraciones manualmente desde el SQL Editor de Supabase.');
    return true;
  }
  console.log('[DB] Ejecutando migraciones...');
  try {
    require('./migrate.js');
  } catch (error) {
    console.error('[DB] Error en migraciones:', error.message);
    return false;
  }
  return true;
}

async function main() {
  console.log('========================================');
  console.log('  ConsultorioClinico - Inicialización DB');
  console.log('========================================\n');

  const connected = await checkConnection();
  if (!connected) {
    console.error('\n[DB] No se pudo conectar. Verifica SUPABASE_URL y las credenciales en .env');
    process.exit(1);
  }

  if (CHECK_ONLY) {
    console.log('\n[DB] Verificación completada exitosamente.');
    return;
  }

  if (FULL_INIT || MIGRATE_ONLY) {
    await runMigrate();
  }

  if (FULL_INIT || SEED_ONLY) {
    await runSeed();
  }

  console.log('\n[DB] Inicialización completada.');
}

main().catch((err) => {
  console.error('[DB] Error fatal:', err.message);
  process.exit(1);
});
