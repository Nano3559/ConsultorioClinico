const express = require('express');
const router = express.Router();
const { body } = require('express-validator');
const {
  getEspecialidades,
  getEspecialidadById,
  createEspecialidad,
  updateEspecialidad,
  deleteEspecialidad,
  getEspecialidadesByMedico,
} = require('../controllers/especialidadController');
const { verifyToken } = require('../middleware/auth');
const { checkRole } = require('../middleware/roles');
const { validate } = require('../middleware/validation');

// Validaciones
const especialidadValidation = [
  body('nombre').notEmpty().withMessage('El nombre es obligatorio'),
];

// Rutas públicas (lectura)
router.get('/', getEspecialidades);
router.get('/medico/:medicoId', getEspecialidadesByMedico);
router.get('/:id', getEspecialidadById);

// Rutas protegidas (escritura)
router.post('/', verifyToken, checkRole('admin'), especialidadValidation, validate, createEspecialidad);
router.put('/:id', verifyToken, checkRole('admin'), updateEspecialidad);
router.delete('/:id', verifyToken, checkRole('admin'), deleteEspecialidad);

module.exports = router;
