const express = require('express');
const router = express.Router();
const { body } = require('express-validator');
const { getAll, getById, buscarPorCedula, create, update, remove } = require('../controllers/pacienteController');
const { verifyFlexible } = require('../middleware/verifyFlexible');
const { checkRole } = require('../middleware/roles');
const { rateLimit } = require('../middleware/rateLimiter');
const { validate, sanitizarTexto, buscarCedulaValidation } = require('../middleware/validation');

// Validaciones
const pacienteValidation = [
  body('nombre').isLength({ min: 2, max: 120 }).withMessage('El nombre debe tener entre 2 y 120 caracteres').customSanitizer(sanitizarTexto),
  body('apellido').isLength({ min: 2, max: 120 }).withMessage('El apellido debe tener entre 2 y 120 caracteres').customSanitizer(sanitizarTexto),
  body('cedula').isLength({ min: 5, max: 20 }).withMessage('La cédula debe tener entre 5 y 20 caracteres').customSanitizer(sanitizarTexto),
  body('email').optional().trim().toLowerCase().isEmail().withMessage('Email inválido'),
  body('telefono').optional().isLength({ max: 30 }).withMessage('El teléfono es demasiado largo'),
  body('direccion').optional().isLength({ max: 255 }).withMessage('La dirección es demasiado larga').customSanitizer(sanitizarTexto),
];

const pacienteUpdateValidation = [
  body('nombre').optional().isLength({ min: 2, max: 120 }).withMessage('El nombre debe tener entre 2 y 120 caracteres').customSanitizer(sanitizarTexto),
  body('apellido').optional().isLength({ min: 2, max: 120 }).withMessage('El apellido debe tener entre 2 y 120 caracteres').customSanitizer(sanitizarTexto),
  body('cedula').optional().isLength({ min: 5, max: 20 }).withMessage('La cédula debe tener entre 5 y 20 caracteres').customSanitizer(sanitizarTexto),
  body('email').optional().isEmail().withMessage('Email inválido'),
  body('sexo').optional().isIn(['M', 'F', 'O']).withMessage('Sexo inválido'),
  body('direccion').optional().isLength({ max: 255 }).withMessage('La dirección es demasiado larga').customSanitizer(sanitizarTexto),
];

// Rutas protegidas: los datos de pacientes son datos clínicos sensibles.
// - Listar: admin, recepcion, medico
// - Ver uno: además el propio paciente puede ver su ficha
router.get('/', verifyFlexible, checkRole('admin', 'recepcion', 'medico'), getAll);
// Búsqueda pública por cédula (ANTES de /:id para que no la capture):
// autocompletado de la reserva online. Rate limit 20/15min + respuesta
// mínima (sin historial clínico) para mitigar enumeración.
router.get(
  '/buscar',
  rateLimit({
    max: 20,
    windowMs: 15 * 60 * 1000,
    mensaje: 'Demasiadas búsquedas. Espere unos minutos e intente de nuevo',
  }),
  buscarCedulaValidation,
  validate,
  buscarPorCedula
);
router.get('/:id', verifyFlexible, checkRole('admin', 'recepcion', 'medico', 'paciente'), getById);

// Escritura
router.post('/', verifyFlexible, checkRole('admin', 'recepcion'), pacienteValidation, validate, create);
router.put('/:id', verifyFlexible, checkRole('admin', 'recepcion'), pacienteUpdateValidation, validate, update);
router.delete('/:id', verifyFlexible, checkRole('admin'), remove);

module.exports = router;