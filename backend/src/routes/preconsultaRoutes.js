'use strict';

/**
 * Rutas de PreConsulta IA (`/api/preconsulta`).
 *
 * Autenticación: verifyFlexible (JWT propio o Firebase ID token).
 * Roles:
 *   - paciente: crea/consulta SOLO sus pre-consultas y responde su cuestionario.
 *   - recepción/admin: crean en nombre del paciente, ven cola y métricas.
 *   - médico/admin: además revisan y ajustan el nivel de triage.
 *
 * Rate limiting por IP en las operaciones caras (análisis) y en la creación,
 * coherente con el resto de endpoints sensibles del backend.
 */

const express = require('express');
const router = express.Router();
const config = require('../config/config');
const { verifyFlexible } = require('../middleware/verifyFlexible');
const { checkRole } = require('../middleware/roles');
const { rateLimit } = require('../middleware/rateLimiter');
const {
  validate,
  idParamValidation,
  pacienteIdParamValidation,
  citaIdParamValidation,
  preconsultaCreateValidation,
  preconsultaAnalizarValidation,
  preconsultaRespuestasValidation,
  preconsultaRevisionValidation,
  preconsultaFinalizarValidation,
  preconsultaColaQueryValidation,
  preconsultaMetricasQueryValidation,
} = require('../middleware/validation');
const {
  getConsentimiento,
  crear,
  analizar,
  guardarRespuestas,
  finalizarSinCaptura,
  getById,
  getByCita,
  getCola,
  getMetricas,
  getTendenciasPaciente,
  revisar,
  getEventos,
} = require('../controllers/preconsultaController');

router.use(verifyFlexible);

// --- Rutas especiales (antes de /:id) --------------------------------------
router.get('/consentimiento', getConsentimiento);

router.get(
  '/cola',
  checkRole('admin', 'medico', 'recepcion'),
  preconsultaColaQueryValidation,
  validate,
  getCola
);

router.get(
  '/metricas',
  checkRole('admin', 'medico', 'recepcion'),
  preconsultaMetricasQueryValidation,
  validate,
  getMetricas
);

router.get(
  '/cita/:citaId',
  citaIdParamValidation,
  validate,
  getByCita
);

router.get(
  '/paciente/:pacienteId/tendencias',
  pacienteIdParamValidation,
  validate,
  getTendenciasPaciente
);

// --- Creación y ciclo de vida ---------------------------------------------
router.post(
  '/',
  checkRole('paciente', 'admin', 'recepcion', 'medico'),
  rateLimit({
    max: config.preconsulta.createRateMax,
    windowMs: 15 * 60 * 1000,
    mensaje: 'Demasiadas preconsultas desde este dispositivo. Espere unos minutos.',
  }),
  preconsultaCreateValidation,
  validate,
  crear
);

router.post(
  '/:id/analizar',
  checkRole('paciente', 'admin', 'recepcion', 'medico'),
  rateLimit({
    max: config.preconsulta.analysisRateMax,
    windowMs: 15 * 60 * 1000,
    mensaje: 'Demasiados análisis desde este dispositivo. Espere unos minutos e intente de nuevo.',
  }),
  idParamValidation,
  validate,
  preconsultaAnalizarValidation,
  validate,
  analizar
);

router.put(
  '/:id/respuestas',
  checkRole('paciente', 'admin', 'recepcion', 'medico'),
  rateLimit({
    max: config.preconsulta.answersRateMax,
    windowMs: 15 * 60 * 1000,
    mensaje: 'Demasiados envíos de cuestionario. Espere unos minutos.',
  }),
  idParamValidation,
  validate,
  preconsultaRespuestasValidation,
  validate,
  guardarRespuestas
);

router.post(
  '/:id/finalizar',
  checkRole('paciente', 'admin', 'recepcion', 'medico'),
  rateLimit({
    max: config.preconsulta.answersRateMax,
    windowMs: 15 * 60 * 1000,
    mensaje: 'Demasiados envíos. Espere unos minutos.',
  }),
  idParamValidation,
  validate,
  preconsultaFinalizarValidation,
  validate,
  finalizarSinCaptura
);

// --- Revisión clínica (solo médico/admin) ---------------------------------
router.patch(
  '/:id/revision',
  checkRole('admin', 'medico'),
  idParamValidation,
  validate,
  preconsultaRevisionValidation,
  validate,
  revisar
);

router.get(
  '/:id/eventos',
  checkRole('admin', 'medico', 'recepcion'),
  idParamValidation,
  validate,
  getEventos
);

// --- Detalle (último: no debe capturar /cola, /metricas, etc.) ------------
router.get('/:id', idParamValidation, validate, getById);

module.exports = router;
