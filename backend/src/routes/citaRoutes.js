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
} = require('../controllers/citaController');
const { verifyToken } = require('../middleware/auth');
const { checkRole } = require('../middleware/roles');
const {
  validate,
  idParamValidation,
  citaValidation,
  citaReprogramarValidation,
  citaEstadoValidation,
} = require('../middleware/validation');

// Todas las rutas requieren autenticación
router.use(verifyToken);

// Rutas especiales (deben ir antes de /:id)
router.get('/agenda/hoy', checkRole('admin', 'medico'), getHoy);
router.get('/medico/:id', idParamValidation, validate, getByMedico);
router.get('/paciente/:id', idParamValidation, validate, getByPaciente);

// CRUD
router.get('/', checkRole('admin', 'recepcion'), getAll);
router.get('/:id', idParamValidation, validate, getById);
router.post('/', checkRole('admin', 'recepcion', 'paciente'), citaValidation, validate, create);
router.put('/:id', checkRole('admin', 'recepcion', 'paciente'), citaReprogramarValidation, validate, update);
router.patch('/:id/estado', checkRole('admin', 'recepcion', 'medico'), citaEstadoValidation, validate, updateEstado);
router.delete('/:id', checkRole('admin', 'recepcion'), remove);

module.exports = router;
