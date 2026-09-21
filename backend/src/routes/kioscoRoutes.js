const express = require('express');
const router = express.Router();
const { verificarRostro } = require('../controllers/kioscoController');
const { validate, kioscoVerificarRostroValidation } = require('../middleware/validation');

// Verificar rostro (kiosco de auto-check-in, acceso público desde el kiosco)
router.post('/verificar-rostro', kioscoVerificarRostroValidation, validate, verificarRostro);

module.exports = router;