const { body, param, query, validationResult } = require('express-validator');
const { sendError } = require('../utils/helpers');
const { ESTADOS_CITA, DIAS_SEMANA } = require('../utils/constants');

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

// --- Sanitizadores reutilizables (mitigan XSS e inyección) ---
// Se aplican como sanitizers de express-validator: limpian el valor sin fallar
// la validación, y después el .notEmpty()/.isLength() verifica el resultado.

const sanitizarTexto = (valor) => {
  if (typeof valor !== 'string') return valor;
  return valor.trim().replace(/<[^>]*>?/gm, ''); // elimina etiquetas HTML/scripts
};

const passwordStrongValidation = [
  body('password')
    .isLength({ min: 8 }).withMessage('La contraseña debe tener al menos 8 caracteres')
    .matches(/[A-Za-z]/).withMessage('La contraseña debe incluir letras')
    .matches(/[0-9]/).withMessage('La contraseña debe incluir al menos un número'),
];

// --- Validaciones reutilizables ---

const idParamValidation = [
  param('id').isInt({ min: 1 }).withMessage('El ID debe ser un número entero válido'),
];

const medicoIdParamValidation = [
  param('medicoId').isInt({ min: 1 }).withMessage('El ID del médico debe ser un número entero válido'),
];

const pacienteIdParamValidation = [
  param('pacienteId').isInt({ min: 1 }).withMessage('El ID del paciente debe ser un número entero válido'),
];

const especialidadIdParamValidation = [
  param('especialidadId').isInt({ min: 1 }).withMessage('El ID de la especialidad debe ser un número entero válido'),
];

const fechaParamValidation = [
  param('fecha')
    .matches(/^\d{4}-\d{2}-\d{2}$/)
    .withMessage('La fecha debe tener formato YYYY-MM-DD')
    .isDate()
    .withMessage('La fecha no es válida'),
];

const citaValidation = [
  body('paciente_id').isInt().withMessage('El ID del paciente es obligatorio'),
  body('medico_id').isInt().withMessage('El ID del médico es obligatorio'),
  body('fecha').isDate().withMessage('La fecha es obligatoria'),
  body('hora').matches(/^\d{2}:\d{2}$/).withMessage('La hora debe tener formato HH:MM'),
  body('motivo')
    .optional({ values: 'falsy' })
    .isLength({ min: 2, max: 500 }).withMessage('El motivo debe tener entre 2 y 500 caracteres')
    .customSanitizer(sanitizarTexto),
];

const citaReprogramarValidation = [
  body('fecha').optional().isDate().withMessage('La fecha no es válida'),
  body('hora').optional().matches(/^\d{2}:\d{2}$/).withMessage('La hora debe tener formato HH:MM'),
  body('motivo')
    .optional({ values: 'falsy' })
    .isLength({ min: 2, max: 500 }).withMessage('El motivo debe tener entre 2 y 500 caracteres')
    .customSanitizer(sanitizarTexto),
];

const citaEstadoValidation = [
  body('estado')
    .isIn(Object.values(ESTADOS_CITA))
    .withMessage(`Estado inválido. Valores permitidos: ${Object.values(ESTADOS_CITA).join(', ')}`),
];

const horarioValidation = [
  body('medico_id').isInt({ min: 1 }).withMessage('El ID del médico es obligatorio'),
  body('dia_semana').isIn(DIAS_SEMANA).withMessage(`Día inválido. Valores permitidos: ${DIAS_SEMANA.join(', ')}`),
  body('hora_inicio').matches(/^\d{2}:\d{2}$/).withMessage('La hora de inicio debe tener formato HH:MM'),
  body('hora_fin').matches(/^\d{2}:\d{2}$/).withMessage('La hora de fin debe tener formato HH:MM'),
];

const horarioUpdateValidation = [
  body('medico_id').optional().isInt({ min: 1 }).withMessage('El ID del médico debe ser un número entero válido'),
  body('dia_semana').optional().isIn(DIAS_SEMANA).withMessage(`Día inválido. Valores permitidos: ${DIAS_SEMANA.join(', ')}`),
  body('hora_inicio').optional().matches(/^\d{2}:\d{2}$/).withMessage('La hora de inicio debe tener formato HH:MM'),
  body('hora_fin').optional().matches(/^\d{2}:\d{2}$/).withMessage('La hora de fin debe tener formato HH:MM'),
];

module.exports = {
  validate,
  passwordStrongValidation,
  sanitizarTexto,
  idParamValidation,
  medicoIdParamValidation,
  pacienteIdParamValidation,
  especialidadIdParamValidation,
  fechaParamValidation,
  citaValidation,
  citaReprogramarValidation,
  citaEstadoValidation,
  horarioValidation,
  horarioUpdateValidation,
};