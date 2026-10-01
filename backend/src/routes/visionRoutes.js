const express = require('express');
const router = express.Router();
const { verifyFlexible } = require('../middleware/verifyFlexible');
const { checkRole } = require('../middleware/roles');
const { registrarRostro, consultarRostro } = require('../controllers/visionController');
const {
  validate,
  pacienteIdParamValidation,
  registrarRostroValidation,
} = require('../middleware/validation');

// Autenticación flexible (Fase 1): JWT propio o Firebase ID token.
// Repara el 401 de recepción: la app envía el token de Firebase Auth.
// Solo admin o recepción pueden operar sobre descriptores faciales.
router.post(
  '/registrar-rostro/:pacienteId',
  verifyFlexible,
  checkRole('admin', 'recepcion'),
  pacienteIdParamValidation,
  registrarRostroValidation,
  validate,
  registrarRostro
);

router.get(
  '/rostro/:pacienteId',
  verifyFlexible,
  checkRole('admin', 'recepcion', 'medico'),
  pacienteIdParamValidation,
  validate,
  consultarRostro
);

module.exports = router;