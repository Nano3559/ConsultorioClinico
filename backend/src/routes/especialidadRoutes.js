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

// Todas las rutas requieren autenticación
router.use(verifyToken);

router.get('/', getEspecialidades);
router.get('/medico/:medicoId', getEspecialidadesByMedico);
router.get('/:id', getEspecialidadById);
router.post('/', checkRole('admin'), especialidadValidation, validate, createEspecialidad);
router.put('/:id', checkRole('admin'), updateEspecialidad);
router.delete('/:id', checkRole('admin'), deleteEspecialidad);

module.exports = router;
