const express = require('express');
const router = express.Router();
const { body } = require('express-validator');
const {
  getAll,
  getById,
  create,
  update,
  updateEstado,
  remove,
  getHoy,
  getByMedico,
  getByPaciente,
} = require('../controllers/citaController');
const { verifyToken } = require('../middleware/auth');
const { checkRole } = require('../middleware/roles');
const { validate } = require('../middleware/validation');

// Validaciones
const citaValidation = [
  body('paciente_id').isInt().withMessage('El ID del paciente es obligatorio'),
  body('medico_id').isInt().withMessage('El ID del médico es obligatorio'),
  body('fecha').isDate().withMessage('La fecha es obligatoria'),
  body('hora').matches(/^\d{2}:\d{2}$/).withMessage('La hora debe tener formato HH:MM'),
  body('motivo').notEmpty().withMessage('El motivo es obligatorio'),
];

// Todas las rutas requieren autenticación
router.use(verifyToken);

// Rutas especiales (deben ir antes de /:id)
router.get('/agenda/hoy', getHoy);
router.get('/medico/:id', getByMedico);
router.get('/paciente/:id', getByPaciente);

// CRUD
router.get('/', getAll);
router.get('/:id', getById);
router.post('/', checkRole('admin', 'recepcion', 'medico'), citaValidation, validate, create);
router.put('/:id', checkRole('admin', 'recepcion', 'medico'), update);
router.patch('/:id/estado', checkRole('admin', 'recepcion', 'medico'), updateEstado);
router.delete('/:id', checkRole('admin', 'recepcion'), remove);

module.exports = router;
