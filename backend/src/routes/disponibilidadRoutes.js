const express = require('express');
const router = express.Router();
const disponibilidadController = require('../controllers/disponibilidadController');

// Rutas públicas (no requieren autenticación)
router.get('/medico/:medicoId/fecha/:fecha', disponibilidadController.getDisponibilidadByMedico);
router.get('/especialidad/:especialidadId', disponibilidadController.getMedicosByEspecialidad);

module.exports = router;
