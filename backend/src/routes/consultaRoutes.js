const express = require('express');
const router = express.Router();
const { body } = require('express-validator');
const { getAll, getByPaciente, getById, create, update } = require('../controllers/consultaController');
const { verifyFlexible } = require('../middleware/verifyFlexible');
const { checkRole } = require('../middleware/roles');
const { validate } = require('../middleware/validation');

// Validaciones
// medico_id es opcional en la validación porque un médico autenticado
// archiva siempre bajo su propio perfil (lo impone el controlador).
const consultaValidation = [
  body('paciente_id').isInt().withMessage('El ID del paciente es obligatorio'),
  body('medico_id').optional().isInt().withMessage('El ID del médico debe ser entero'),
  body('cita_id').optional().isInt().withMessage('El ID de la cita debe ser entero'),
  body('diagnostico').notEmpty().withMessage('El diagnóstico es obligatorio'),
  body('tratamiento').notEmpty().withMessage('El tratamiento es obligatorio'),
];

// Todas las rutas requieren autenticación (JWT propio o Firebase ID token)
router.use(verifyFlexible);

router.get('/', checkRole('admin', 'medico', 'recepcion'), getAll);
router.get('/paciente/:id', checkRole('admin', 'medico', 'recepcion'), getByPaciente);
router.get('/:id', checkRole('admin', 'medico', 'recepcion'), getById);
router.post('/', checkRole('admin', 'medico'), consultaValidation, validate, create);
router.put('/:id', checkRole('admin', 'medico'), update);

module.exports = router;
