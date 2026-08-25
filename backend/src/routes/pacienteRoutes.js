const express = require('express');
const router = express.Router();
const { body } = require('express-validator');
const { getAll, getById, create, update, remove } = require('../controllers/pacienteController');
const { verifyToken } = require('../middleware/auth');
const { checkRole } = require('../middleware/roles');
const { validate } = require('../middleware/validation');

// Validaciones
const pacienteValidation = [
  body('nombre').notEmpty().withMessage('El nombre es obligatorio'),
  body('apellido').notEmpty().withMessage('El apellido es obligatorio'),
  body('cedula').notEmpty().withMessage('La cédula es obligatoria'),
  body('email').isEmail().withMessage('Email inválido'),
  body('telefono').notEmpty().withMessage('El teléfono es obligatorio'),
];

// Rutas públicas (lectura)
router.get('/', getAll);
router.get('/:id', getById);

// Rutas protegidas (escritura)
router.post('/', verifyToken, checkRole('admin', 'recepcion'), pacienteValidation, validate, create);
router.put('/:id', verifyToken, checkRole('admin', 'recepcion'), update);
router.delete('/:id', verifyToken, checkRole('admin'), remove);

module.exports = router;
