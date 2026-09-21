const express = require('express');
const router = express.Router();
const { verificarRostro, confirmarCita } = require('../controllers/kioscoController');
const {
  validate,
  kioscoVerificarRostroValidation,
  kioscoConfirmarCitaValidation,
} = require('../middleware/validation');

// Verificar rostro (kiosco de auto-check-in, acceso público desde el kiosco)
router.post('/verificar-rostro', kioscoVerificarRostroValidation, validate, verificarRostro);
router.post('/confirmar-cita', kioscoConfirmarCitaValidation, validate, confirmarCita);

module.exports = router;