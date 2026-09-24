const express = require('express');
const router = express.Router();
const config = require('../config/config');
const { verifyToken } = require('../middleware/auth');
const { checkRole } = require('../middleware/roles');
const { rateLimit } = require('../middleware/rateLimiter');
const {
  verificarRostro,
  confirmarCita,
  listarIntentos,
} = require('../controllers/kioscoController');
const {
  validate,
  kioscoVerificarRostroValidation,
  kioscoConfirmarCitaValidation,
} = require('../middleware/validation');

// KIO-20: los endpoints de la tablet del kiosco son públicos por diseño (el
// paciente no se autentica), pero quedan protegidos contra abuso con un rate
// limit por IP (ventana de 15 minutos). Confirmar-cita además exige una
// verificación facial exitosa previa del mismo paciente e IP (KIO-15).
router.post(
  '/verificar-rostro',
  rateLimit({
    max: config.kiosco.verifyRateMax,
    windowMs: 15 * 60 * 1000,
    mensaje: 'Demasiadas verificaciones faciales. Espere unos minutos e intente de nuevo',
  }),
  kioscoVerificarRostroValidation,
  validate,
  verificarRostro
);

router.post(
  '/confirmar-cita',
  rateLimit({
    max: config.kiosco.confirmRateMax,
    windowMs: 15 * 60 * 1000,
    mensaje: 'Demasiadas confirmaciones desde este dispositivo. Espere unos minutos',
  }),
  kioscoConfirmarCitaValidation,
  validate,
  confirmarCita
);

// KIO-19: auditoría de intentos del kiosco. Solo admin/recepción.
router.get(
  '/intentos',
  verifyToken,
  checkRole('admin', 'recepcion'),
  listarIntentos
);

module.exports = router;