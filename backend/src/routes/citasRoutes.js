const express = require('express');
const router = express.Router();
const { body } = require('express-validator');
const {
  getAll,
  getById,
  create,
  update,
  remove,
} = require('../controllers/citaController');
const { verifyToken } = require('../middleware/auth');
const { checkRole } = require('../middleware/roles');
const { validate } = require('../middleware/validation');

const citaValidation = [
  body('paciente_id').isInt().withMessage('El ID del paciente es obligatorio'),
  body('medico_id').isInt().withMessage('El ID del médico es obligatorio'),
  body('fecha').notEmpty().withMessage('La fecha es obligatoria'),
  body('hora').notEmpty().withMessage('La hora es obligatoria'),
];

router.use(verifyToken);

// GET / - Listar todas las citas
router.get('/', checkRole('admin', 'recepcion'), getAll);

// GET /:id - Obtener cita por ID
router.get('/:id', getById);

// POST / - Crear cita
router.post('/', checkRole('admin', 'recepcion', 'paciente'), citaValidation, validate, create);

// PUT /:id - Actualizar cita
router.put('/:id', checkRole('admin', 'recepcion', 'paciente'), update);

// DELETE /:id - Eliminar cita
router.delete('/:id', checkRole('admin', 'recepcion'), remove);

module.exports = router;
