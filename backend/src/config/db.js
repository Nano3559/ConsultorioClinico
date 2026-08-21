const mysql = require('mysql2/promise');
const config = require('./config');

/**
 * Pool de conexiones a MySQL.
 * Variables leídas desde .env (ver .env.example):
 *   DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME
 */
const pool = mysql.createPool({
  host: config.db.host,
  port: config.db.port,
  user: config.db.user,
  password: config.db.password,
  database: config.db.name,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  timezone: 'Z',
  dateStrings: true,
});

/**
 * Verifica la conexión a la base de datos.
 * Útil como health-check al arrancar el servidor.
 */
async function testConnection() {
  const conn = await pool.getConnection();
  try {
    await conn.ping();
    return true;
  } finally {
    conn.release();
  }
}

module.exports = { pool, testConnection };
