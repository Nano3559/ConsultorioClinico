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

module.exports = { verifyToken };
