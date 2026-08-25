const express = require('express');
const router = express.Router();
const { body } = require('express-validator');
const { getAll, create, getByPaciente, updateEstado } = require('../controllers/pagoController');
const { verifyToken } = require('../middleware/auth');
const { checkRole } = require('../middleware/roles');
const { validate } = require('../middleware/validation');

// Validaciones
const pagoValidation = [
  body('paciente_id').isInt().withMessage('El ID del paciente es obligatorio'),
  body('cita_id').optional().isInt().withMessage('El ID de la cita debe ser entero'),
  body('monto').isFloat({ min: 0.01 }).withMessage('El monto debe ser mayor a 0'),
  body('metodo_pago').notEmpty().withMessage('El método de pago es obligatorio'),
];

// Todas las rutas requieren autenticación
router.use(verifyToken);

router.get('/', checkRole('admin', 'recepcion'), getAll);
router.post('/', checkRole('admin', 'recepcion'), pagoValidation, validate, create);
router.get('/paciente/:id', getByPaciente);
router.patch('/:id/estado', checkRole('admin', 'recepcion'), updateEstado);

module.exports = router;
