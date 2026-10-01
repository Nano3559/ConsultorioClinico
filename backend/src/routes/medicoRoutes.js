const express = require('express');
const router = express.Router();
const { body } = require('express-validator');
const { getAll, getById, create, update, toggleEstado, remove, getHorarios, createHorario } = require('../controllers/medicoController');
const { getEspecialidadesByMedico } = require('../controllers/especialidadController');
const { verifyFlexible } = require('../middleware/verifyFlexible');
const { optionalAuth } = require('../middleware/auth');
const { checkRole, checkAdminOrSelfMedico } = require('../middleware/roles');
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

// Rutas públicas (lectura); optionalAuth permite exponer más campos al staff
router.get('/', optionalAuth, getAll);
router.get('/:id', optionalAuth, idParamValidation, validate, getById);
router.get('/:id/horarios', verifyFlexible, idParamValidation, validate, getHorarios);
// Horarios: el admin gestiona los de cualquier médico; el médico los suyos.
router.post('/:id/horarios', verifyFlexible, checkAdminOrSelfMedico('id'), idParamValidation, validate, createHorario);
router.get('/:medicoId/especialidades', medicoIdParamValidation, validate, getEspecialidadesByMedico);

// Rutas protegidas (solo admin)
router.post('/', verifyFlexible, checkRole('admin'), medicoValidation, validate, create);
router.put('/:id', verifyFlexible, checkRole('admin'), idParamValidation, validate, update);
router.patch('/:id/estado', verifyFlexible, checkRole('admin'), idParamValidation, validate, toggleEstado);
router.delete('/:id', verifyFlexible, checkRole('admin'), idParamValidation, validate, remove);

module.exports = router;
