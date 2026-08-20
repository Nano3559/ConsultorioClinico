const express = require('express');
const router = express.Router();
const mainController = require('../controllers/mainController');

router.get('/', mainController.index);
router.get('/nosotros', mainController.nosotros);
router.get('/especialidades', mainController.especialidades);
router.get('/medicos', mainController.medicos);
router.get('/servicios', mainController.servicios);
router.get('/horarios', mainController.horarios);
router.get('/cita', mainController.cita);
router.post('/cita', mainController.citaPost);
router.get('/contacto', mainController.contactoPage);
router.post('/contacto', mainController.contactoPost);
router.get('/login', mainController.login);
router.post('/login', mainController.loginPost);

module.exports = router;
