const express = require('express');
const router = express.Router();
const {
  getPorMedicoYFecha,
  getMedicosPorEspecialidad,
} = require('../controllers/disponibilidadController');
const {
  validate,
  medicoIdParamValidation,
  especialidadIdParamValidation,
  fechaParamValidation,
} = require('../middleware/validation');

// Rutas públicas
router.get(
  '/medico/:medicoId/fecha/:fecha',
  [...medicoIdParamValidation, ...fechaParamValidation],
  validate,
  getPorMedicoYFecha
);
router.get(
  '/especialidad/:especialidadId',
  especialidadIdParamValidation,
  validate,
  getMedicosPorEspecialidad
);

module.exports = router;
