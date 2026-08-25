const { sendError } = require('../utils/helpers');

/**
 * Middleware para verificar roles permitidos
 * @param  {...string} roles - Roles permitidos (ej: 'admin', 'medico', 'recepcion')
 */
const checkRole = (...roles) => {
  return (req, res, next) => {
    if (!req.user) {
      return sendError(res, 'No autenticado', 401);
    }

    if (!roles.includes(req.user.rol)) {
      return sendError(
        res,
        `Acceso denegado. Se requiere uno de estos roles: ${roles.join(', ')}`,
        403
      );
    }

    next();
  };
};

module.exports = { checkRole };
