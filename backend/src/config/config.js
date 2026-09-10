require('dotenv').config();
const crypto = require('crypto');

const nodeEnv = process.env.NODE_ENV || 'development';

if (nodeEnv === 'production' && !process.env.JWT_SECRET) {
  throw new Error('JWT_SECRET es obligatorio en producción');
}

// En desarrollo, si no hay JWT_SECRET se genera uno aleatorio por proceso.
// Esto evita el fallback hardcodeado ('fallback_secret_key') que era predecible.
const jwtSecret =
  process.env.JWT_SECRET ||
  (nodeEnv === 'production'
    ? (() => {
        throw new Error('JWT_SECRET es obligatorio en producción');
      })()
    : (() => {
        const generado = crypto.randomBytes(48).toString('hex');
        console.warn(
          '[config] ⚠ JWT_SECRET no definido. Se usa un secreto aleatorio solo para desarrollo. Define JWT_SECRET en .env.'
        );
        return generado;
      })());

// Lista de orígenes permitidos para CORS (separados por coma en CORS_ORIGINS).
// Si está vacía, se responde sin cabecera Access-Control-Allow-Origin a
// solicitudes con Origin (navegador) y se permiten requests server-to-server.
const corsOrigins = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);

module.exports = {
  port: process.env.PORT || 3000,
  nodeEnv,
  jwtSecret,
  jwtExpire: process.env.JWT_EXPIRE || '24h',
  corsOrigins,

  // Configuración de MySQL (legacy, no usada actualmente)
  db: {
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '3306', 10),
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    name: process.env.DB_NAME || 'consultorio_clinico',
  },

  // Configuración de Supabase (PostgreSQL)
  supabase: {
    url: process.env.SUPABASE_URL || '',
    anonKey: process.env.SUPABASE_ANON_KEY || '',
    serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY || '',
  },
};