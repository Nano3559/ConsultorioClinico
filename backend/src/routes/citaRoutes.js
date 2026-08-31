const express = require('express');
const router = express.Router();
const {
  getAll,
  getById,
  create,
  update,
  updateEstado,
  remove,
  getHoy,
  getByMedico,
  getByPaciente,
  getMisCitas,
  confirmar,
} = require('../controllers/citaController');
const { verifyToken } = require('../middleware/auth');
const { checkRole } = require('../middleware/roles');
const {
  validate,
  idParamValidation,
  medicoIdParamValidation,
  pacienteIdParamValidation,
  citaValidation,
  citaReprogramarValidation,
  citaEstadoValidation,
} = require('../middleware/validation');

// Todas las rutas requieren autenticación
router.use(verifyToken);

// Rutas especiales (deben ir antes de /:id)
router.get('/mis-citas', checkRole('paciente'), getMisCitas);
router.get('/mis/citas', checkRole('paciente'), getMisCitas);
router.get('/agenda/hoy', checkRole('admin', 'medico', 'recepcion'), getHoy);
router.get('/medico/:medicoId', medicoIdParamValidation, validate, getByMedico);
router.get('/medico/:id', idParamValidation, validate, getByMedico);
router.get('/paciente/:pacienteId', pacienteIdParamValidation, validate, getByPaciente);
router.get('/paciente/:id', idParamValidation, validate, getByPaciente);
router.post('/:id/confirmar', checkRole('admin', 'recepcion', 'medico'), idParamValidation, validate, confirmar);

// CRUD
router.get('/', checkRole('admin', 'recepcion'), getAll);
router.get('/:id', idParamValidation, validate, getById);
router.post('/', checkRole('admin', 'recepcion', 'paciente'), citaValidation, validate, create);
router.put('/:id', checkRole('admin', 'recepcion', 'paciente'), citaReprogramarValidation, validate, update);
router.patch('/:id/estado', checkRole('admin', 'recepcion', 'medico'), citaEstadoValidation, validate, updateEstado);
router.delete('/:id', checkRole('admin', 'recepcion'), remove);

module.exports = router;