const express = require('express');
const router = express.Router();
const {
  getAll,
  getByMedico,
  getDisponibles,
  create,
  update,
  remove,
} = require('../controllers/horarioController');
const { verifyToken } = require('../middleware/auth');
const { checkRole } = require('../middleware/roles');
const {
  validate,
  idParamValidation,
  medicoIdParamValidation,
  horarioValidation,
  horarioUpdateValidation,
} = require('../middleware/validation');

// Rutas públicas (antes de las protegidas para evitar conflictos)
router.get('/', getAll);
router.get('/disponibles', getDisponibles);
router.get('/medico/:medicoId', medicoIdParamValidation, validate, getByMedico);

// Rutas protegidas (solo admin)
router.post('/', verifyToken, checkRole('admin'), horarioValidation, validate, create);
router.put('/:id', verifyToken, checkRole('admin'), idParamValidation, horarioUpdateValidation, validate, update);
router.delete('/:id', verifyToken, checkRole('admin'), idParamValidation, validate, remove);

module.exports = router;
