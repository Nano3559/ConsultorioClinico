const express = require('express');
const router = express.Router();
const { body } = require('express-validator');
const { getAll, getByPaciente, getById, create, update } = require('../controllers/consultaController');
const { verifyToken } = require('../middleware/auth');
const { checkRole } = require('../middleware/roles');
const { validate } = require('../middleware/validation');

// Validaciones
const consultaValidation = [
  body('paciente_id').isInt().withMessage('El ID del paciente es obligatorio'),
  body('medico_id').isInt().withMessage('El ID del médico es obligatorio'),
  body('diagnostico').notEmpty().withMessage('El diagnóstico es obligatorio'),
  body('tratamiento').notEmpty().withMessage('El tratamiento es obligatorio'),
];

// Todas las rutas requieren autenticación
router.use(verifyToken);

router.get('/', checkRole('admin', 'medico', 'recepcion'), getAll);
router.get('/paciente/:id', getByPaciente);
router.get('/:id', getById);
router.post('/', checkRole('admin', 'medico'), consultaValidation, validate, create);
router.put('/:id', checkRole('admin', 'medico'), update);

module.exports = router;
