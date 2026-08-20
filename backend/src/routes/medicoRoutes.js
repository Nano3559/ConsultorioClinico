const express = require('express');
const router = express.Router();
const { body } = require('express-validator');
const { getAll, getById, create, update, toggleEstado, getHorarios } = require('../controllers/medicoController');
const { verifyToken } = require('../middleware/auth');
const { checkRole } = require('../middleware/roles');
const { validate } = require('../middleware/validation');

// Validaciones
const medicoValidation = [
  body('nombre').notEmpty().withMessage('El nombre es obligatorio'),
  body('apellido').notEmpty().withMessage('El apellido es obligatorio'),
  body('cedula').notEmpty().withMessage('La cédula es obligatoria'),
  body('especialidad').notEmpty().withMessage('La especialidad es obligatoria'),
  body('email').isEmail().withMessage('Email inválido'),
];

// Todas las rutas requieren autenticación
router.use(verifyToken);

router.get('/', getAll);
router.get('/:id', getById);
router.post('/', checkRole('admin'), medicoValidation, validate, create);
router.put('/:id', checkRole('admin'), update);
router.patch('/:id/estado', checkRole('admin'), toggleEstado);
router.get('/:id/horarios', getHorarios);

module.exports = router;
