const { createClient } = require('@supabase/supabase-js');
const config = require('./config');

let _client = null;

function getSupabase() {
  if (_client) return _client;

  const url = config.supabase.url;
  const key = config.supabase.serviceRoleKey || config.supabase.anonKey;

  if (!url || !key) {
    console.error('[Supabase] FALLO: Variables no configuradas');
    console.error('[Supabase] URL:', url ? 'OK' : 'FALTA');
    console.error('[Supabase] KEY:', key ? 'OK' : 'FALTA');
    throw new Error(
      'Supabase no configurado. Define SUPABASE_URL y SUPABASE_ANON_KEY (o SUPABASE_SERVICE_ROLE_KEY) en .env'
    );
  }

  console.log('[Supabase] Creando cliente...');
  console.log('[Supabase] URL:', url);
  console.log('[Supabase] Key tipo:', config.supabase.serviceRoleKey ? 'service_role' : 'anon');

  _client = createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  console.log('[Supabase] Cliente creado OK');
  return _client;
}

async function testConnection() {
  const supabase = getSupabase();
  const { error } = await supabase.from('usuarios').select('id').limit(1);
  if (error && error.code !== 'PGRST116') {
    throw error;
  }
  return true;
}

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
