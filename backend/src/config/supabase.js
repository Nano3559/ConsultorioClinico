const { createClient } = require('@supabase/supabase-js');
const config = require('./config');

/**
 * Cliente oficial de Supabase (PostgreSQL).
 *
 * Variables requeridas en .env (ver .env.example):
 *   SUPABASE_URL          URL del proyecto (https://xxxx.supabase.co)
 *   SUPABASE_ANON_KEY     Clave pública anon
 *   SUPABASE_SERVICE_ROLE_KEY  (recomendado en el backend) clave service_role
 *
 * El servidor usa service_role cuando está disponible porque es un contexto
 * confiable que ya valida identidad/roles con JWT propio; con eso las políticas
 * RLS no bloquean operaciones legítimas del API.
 */
let _client = null;

function getSupabase() {
  if (_client) return _client;

  const url = config.supabase.url;
  const key = config.supabase.serviceRoleKey || config.supabase.anonKey;

  if (!url || !key) {
    throw new Error(
      'Supabase no configurado. Define SUPABASE_URL y SUPABASE_ANON_KEY (o SUPABASE_SERVICE_ROLE_KEY) en .env'
    );
  }

  _client = createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return _client;
}

/**
 * Health-check de la conexión con Supabase.
 */
async function testConnection() {
  const supabase = getSupabase();
  const { error } = await supabase.from('usuarios').select('id').limit(1);
  if (error && error.code !== 'PGRST116') {
    throw error;
  }
  return true;
}

/**
 * Traduce errores del PostgREST/Supabase a mensajes claros para el cliente.
 */
function dbErrorMessage(error) {
  if (!error) return null;
  if (error.code === 'ECONNREFUSED' || /fetch failed|network/i.test(error.message || '')) {
    return 'No hay conexión con la base de datos';
  }
  if (error.code === '23505' || /duplicate key/i.test(error.message || '')) {
    return 'Ya existe un registro con esos datos únicos';
  }
  if (error.code === '23503' || /violates foreign key/i.test(error.message || '')) {
    return 'El registro referencia a otro inexistente';
  }
  if (error.code === '42P01' || /does not exist/i.test(error.message || '')) {
    return 'La tabla no existe. Ejecuta la migración en Supabase (db/migrations)';
  }
  return null;
}

module.exports = { getSupabase, testConnection, dbErrorMessage };
