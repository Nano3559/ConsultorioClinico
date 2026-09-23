const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middleware/auth');
const { checkRole } = require('../middleware/roles');
const { registrarRostro, consultarRostro } = require('../controllers/visionController');
const {
  validate,
  pacienteIdParamValidation,
  registrarRostroValidation,
} = require('../middleware/validation');

// Autenticados: endpoint de registro/consulta del rostro. Solo admin o
// recepción pueden operar sobre los descriptores faciales (KIO-20).
router.post(
  '/registrar-rostro/:pacienteId',
  verifyToken,
  checkRole('admin', 'recepcion'),
  pacienteIdParamValidation,
  registrarRostroValidation,
  validate,
  registrarRostro
);

router.get(
  '/rostro/:pacienteId',
  verifyToken,
  checkRole('admin', 'recepcion', 'medico'),
  pacienteIdParamValidation,
  validate,
  consultarRostro
);

module.exports = router;