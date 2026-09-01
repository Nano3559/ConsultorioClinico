const express = require('express');
const router = express.Router();
const { body } = require('express-validator');
const { getAll, getById, create, update, remove } = require('../controllers/pacienteController');
const { verifyToken } = require('../middleware/auth');
const { checkRole } = require('../middleware/roles');
const { validate, idParamValidation, pacienteIdParamValidation } = require('../middleware/validation');

// Validaciones
const pacienteValidation = [
  body('nombre').notEmpty().withMessage('El nombre es obligatorio'),
  body('apellido').notEmpty().withMessage('El apellido es obligatorio'),
  body('cedula').notEmpty().withMessage('La cédula es obligatoria'),
  body('email').optional().isEmail().withMessage('Email inválido'),
  body('telefono').optional(),
  body('sexo').optional().isIn(['M', 'F', 'O']).withMessage('Sexo inválido'),
  body('tipo_sangre').optional().isIn(['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-']).withMessage('Tipo de sangre inválido'),
];

const pacienteUpdateValidation = [
  body('nombre').optional().notEmpty().withMessage('El nombre no puede estar vacío'),
  body('apellido').optional().notEmpty().withMessage('El apellido no puede estar vacío'),
  body('cedula').optional().notEmpty().withMessage('La cédula no puede estar vacía'),
  body('email').optional().isEmail().withMessage('Email inválido'),
  body('sexo').optional().isIn(['M', 'F', 'O']).withMessage('Sexo inválido'),
];

// Rutas públicas (lectura)
router.get('/', getAll);
router.get('/:id', idParamValidation, validate, getById);

// Rutas protegidas (escritura)
router.post('/', verifyToken, checkRole('admin', 'recepcion'), pacienteValidation, validate, create);
router.put('/:id', verifyToken, checkRole('admin', 'recepcion'), pacienteUpdateValidation, validate, update);
router.delete('/:id', verifyToken, checkRole('admin'), remove);

module.exports = router;
