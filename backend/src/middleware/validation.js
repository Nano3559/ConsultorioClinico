const { validationResult } = require('express-validator');
const { sendError } = require('../utils/helpers');

/**
 * Middleware para validar resultados de express-validator
 */
const validate = (req, res, next) => {
  const errors = validationResult(req);

  if (!errors.isEmpty()) {
    const extractedErrors = errors.array().map((err) => ({
      campo: err.path,
      mensaje: err.msg,
    }));

    return sendError(res, 'Errores de validación', 422, extractedErrors);
  }

  next();
};

module.exports = { validate };
