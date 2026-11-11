const jwt = require('jsonwebtoken');
const config = require('../config/config');
const { sendError } = require('../utils/helpers');

/**
 * Verifica contra la tabla sesiones que el token (jti) de la sesión siga
 * activa y no haya expirado. Mejor esfuerzo: si la tabla no existe o hay un
 * error de red, se permite el acceso y se loguea la incidencia.
 */
const sesionActiva = async (tokenId) => {
  try {
    const { getSupabase } = require('../config/supabase');
    const supabase = getSupabase();

    const { data, error } = await supabase
      .from('sesiones')
      .select('id')
      .eq('token_id', tokenId)
      .eq('activa', true)
      .limit(1);

    if (error) {
      console.error('[auth] No se pudo validar la sesión:', error.message);
      return null;
    }

    return data && data.length > 0;
  } catch (err) {
    console.error('[auth] Error validando sesión:', err.message);
    return null;
  }
};

/**
 * Núcleo compartido de validación del JWT propio.
 * Lo usan verifyToken (comportamiento histórico intacto) y verifyFlexible
 * (que además acepta ID tokens de Firebase).
 *
 * @param {string} token JWT en crudo (sin 'Bearer ').
 * @returns {object} payload decodificado (req.user).
 * @throws {{status:number, message:string}} en fallos duros (401).
 */
const validarTokenJwt = async (token) => {
  let decoded;
  try {
    decoded = jwt.verify(token, config.jwtSecret);
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      throw { status: 401, message: 'Token expirado' };
    }
    throw { status: 401, message: 'Token inválido' };
  }

  // Tokens de tipo prueba o legacy sin jti no se validan contra sesiones
  if (decoded.jti) {
    const activa = await sesionActiva(decoded.jti);
    if (activa === false) {
      throw { status: 401, message: 'Sesión cerrada. Inicie sesión nuevamente' };
    }
    // activa === null (indeterminado): se continúa para no romper el servicio
  }

  return decoded;
};

/**
 * Middleware para verificar token JWT.
 * Si el token incluye jti (emitido por /login), comprueba además que la
 * sesión siga activa en la BD, de modo que un logout la revoque de inmediato.
 */
const verifyToken = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return sendError(res, 'Token no proporcionado', 401);
    }

    const token = authHeader.split(' ')[1];
    req.user = await validarTokenJwt(token);
    return next();
  } catch (error) {
    if (error && error.status) {
      return sendError(res, error.message, error.status);
    }
    console.error('[auth] verifyToken:', error.message);
    return sendError(res, 'Error interno de autenticación', 500);
  }
};

/**
 * Middleware opcional: decodifica el token si viene, pero nunca falla.
 * Se usa en rutas públicas que mejoran su comportamiento cuando hay sesión
 * (ej: registro, donde solo un admin puede crear usuarios privilegiados).
 */
const optionalAuth = (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (authHeader && authHeader.startsWith('Bearer ')) {
    try {
      req.user = jwt.verify(authHeader.split(' ')[1], config.jwtSecret);
    } catch (_error) {
      // Token inválido/expirado: se continúa como anónimo
      req.user = undefined;
    }
  }

  next();
};

module.exports = { verifyToken, optionalAuth, validarTokenJwt, sesionActiva };
