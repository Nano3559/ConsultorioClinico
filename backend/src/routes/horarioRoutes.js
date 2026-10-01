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
const { verifyFlexible } = require('../middleware/verifyFlexible');
const { checkRole, checkAdminOrOwnHorario } = require('../middleware/roles');
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

// Escrituras: admin siempre; el médico solo sobre sus propios horarios.
router.post('/', verifyFlexible, checkRole('admin'), horarioValidation, validate, create);
router.put('/:id', verifyFlexible, checkRole('admin'), idParamValidation, horarioUpdateValidation, validate, update);
router.delete('/:id', verifyFlexible, checkAdminOrOwnHorario, idParamValidation, validate, remove);

module.exports = router;
