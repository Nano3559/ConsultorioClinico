const express = require('express');
const router = express.Router();
const { body } = require('express-validator');
const { getAll, getById, create, update, toggleEstado, remove, getHorarios } = require('../controllers/medicoController');
const { getEspecialidadesByMedico } = require('../controllers/especialidadController');
const { verifyToken } = require('../middleware/auth');
const { checkRole } = require('../middleware/roles');
const {
  validate,
  idParamValidation,
  medicoIdParamValidation,
} = require('../middleware/validation');

// Validaciones
const medicoValidation = [
  body('nombre').notEmpty().withMessage('El nombre es obligatorio'),
  body('apellido').notEmpty().withMessage('El apellido es obligatorio'),
  body('cedula').optional().notEmpty().withMessage('La cédula no puede estar vacía'),
  body('especialidad').notEmpty().withMessage('La especialidad es obligatoria'),
  body('email').optional().isEmail().withMessage('Email inválido'),
];

// Rutas públicas
router.get('/', getAll);
router.get('/:id', idParamValidation, validate, getById);
router.get('/:id/horarios', verifyToken, idParamValidation, validate, getHorarios);
router.get('/:medicoId/especialidades', medicoIdParamValidation, validate, getEspecialidadesByMedico);

// Rutas protegidas (solo admin)
router.post('/', verifyToken, checkRole('admin'), medicoValidation, validate, create);
router.put('/:id', verifyToken, checkRole('admin'), idParamValidation, validate, update);
router.patch('/:id/estado', verifyToken, checkRole('admin'), idParamValidation, validate, toggleEstado);
router.delete('/:id', verifyToken, checkRole('admin'), idParamValidation, validate, remove);

module.exports = router;
