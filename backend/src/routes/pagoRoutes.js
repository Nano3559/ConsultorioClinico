const express = require('express');
const router = express.Router();
const { body } = require('express-validator');
const { getAll, create, getByPaciente, updateEstado } = require('../controllers/pagoController');
const { verifyToken } = require('../middleware/auth');
const { checkRole } = require('../middleware/roles');
const { validate } = require('../middleware/validation');
const { METODOS_PAGO, ESTADOS_PAGO } = require('../utils/constants');

// Validaciones
const pagoValidation = [
  body('paciente_id').isInt().withMessage('El ID del paciente es obligatorio'),
  body('cita_id').optional().isInt().withMessage('El ID de la cita debe ser entero'),
  body('monto').isFloat({ min: 0.01 }).withMessage('El monto debe ser mayor a 0'),
  body('metodo_pago')
    .isIn(Object.values(METODOS_PAGO))
    .withMessage(`Método inválido. Valores permitidos: ${Object.values(METODOS_PAGO).join(', ')}`),
];

const pagoEstadoValidation = [
  body('estado')
    .isIn(Object.values(ESTADOS_PAGO))
    .withMessage(`Estado inválido. Valores permitidos: ${Object.values(ESTADOS_PAGO).join(', ')}`),
];

// Todas las rutas requieren autenticación
router.use(verifyToken);

router.get('/', checkRole('admin', 'recepcion'), getAll);
router.post('/', checkRole('admin', 'recepcion'), pagoValidation, validate, create);
router.get('/paciente/:id', getByPaciente);
router.patch('/:id/estado', checkRole('admin', 'recepcion'), pagoEstadoValidation, validate, updateEstado);

module.exports = router;
