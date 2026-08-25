const jwt = require('jsonwebtoken');
const config = require('../config/config');
const { sendError } = require('../utils/helpers');

/**
 * Middleware para verificar token JWT
 */
const verifyToken = (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return sendError(res, 'Token no proporcionado', 401);
    }

    const token = authHeader.split(' ')[1];
    const decoded = jwt.verify(token, config.jwtSecret);

    req.user = decoded;
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return sendError(res, 'Token expirado', 401);
    }
    return sendError(res, 'Token inválido', 401);
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

module.exports = { verifyToken, optionalAuth };
