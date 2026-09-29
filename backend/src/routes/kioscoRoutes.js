const express = require('express');
const router = express.Router();
const config = require('../config/config');
const { verifyToken } = require('../middleware/auth');
const { checkRole } = require('../middleware/roles');
const { kioskAuth } = require('../middleware/kioscoAuth');
const { rateLimit } = require('../middleware/rateLimiter');
const {
  verificarRostro,
  confirmarCita,
  listarIntentos,
  obtenerManifest,
  obtenerPaquete,
  obtenerModelo,
  ingestarPaquete,
} = require('../controllers/kioscoController');
const {
  validate,
  pacienteIdParamValidation,
  kioscoVerificarRostroValidation,
  kioscoConfirmarCitaValidation,
  paqueteRostroValidation,
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

// Sincronización del kiosco: manifest de plantillas + paquetes + modelo.
// Protegidos con kioskAuth (x-kiosk-key del equipo o JWT de personal):
// la descarga masiva de plantillas biométricas jamás es pública.
router.get('/manifest', kioskAuth, obtenerManifest);
router.get(
  '/paquete/:pacienteId',
  kioskAuth,
  pacienteIdParamValidation,
  validate,
  obtenerPaquete
);
router.get('/modelo', kioskAuth, obtenerModelo);

// Puente de la reserva online (público, rate limit 5/h por IP): crea el
// paciente del backend por cédula si no existe y registra su pack facial
// multi-pose con el mismo pipeline de recepción.
router.post(
  '/paquete-rostro',
  rateLimit({
    max: 5,
    windowMs: 60 * 60 * 1000,
    mensaje: 'Demasiados registros faciales desde esta IP. Intente más tarde',
  }),
  paqueteRostroValidation,
  validate,
  ingestarPaquete
);

module.exports = router;