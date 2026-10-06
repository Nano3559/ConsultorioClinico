const express = require('express');
const router = express.Router();
const { verifyFlexible } = require('../middleware/verifyFlexible');
const { checkRole } = require('../middleware/roles');
const { rateLimit } = require('../middleware/rateLimiter');
const { registrarRostro, consultarRostro, evaluarGesto } = require('../controllers/visionController');
const {
  validate,
  pacienteIdParamValidation,
  registrarRostroValidation,
  evaluarGestoValidation,
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

// Guía en vivo de captura (público, rate limit generoso: solo lectura sin
// writes; YuNet ~50ms en tibio). El cliente la usa como veredicto y cae a
// heurística local si tarda o falla.
router.post(
  '/evaluar-gesto',
  rateLimit({
    max: 600,
    windowMs: 60 * 60 * 1000,
    mensaje: 'Demasiadas evaluaciones desde este dispositivo. Intente más tarde',
  }),
  evaluarGestoValidation,
  validate,
  evaluarGesto
);

module.exports = router;