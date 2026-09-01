const express = require('express');
const router = express.Router();
const disponibilidadController = require('../controllers/disponibilidadController');
const {
  validate,
  medicoIdParamValidation,
  especialidadIdParamValidation,
  fechaParamValidation,
} = require('../middleware/validation');

// Rutas públicas (no requieren autenticación)
router.get(
  '/medico/:medicoId/fecha/:fecha',
  medicoIdParamValidation,
  fechaParamValidation,
  validate,
  disponibilidadController.getDisponibilidadByMedico
);
router.get(
  '/especialidad/:especialidadId',
  especialidadIdParamValidation,
  validate,
  disponibilidadController.getMedicosByEspecialidad
);

module.exports = router;
