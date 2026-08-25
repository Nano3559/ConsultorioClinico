const express = require('express');
const router = express.Router();
const { reporteCitas, reporteIngresos } = require('../controllers/reporteController');
const { verifyToken } = require('../middleware/auth');
const { checkRole } = require('../middleware/roles');

// Todas las rutas requieren autenticación y rol admin o recepcion
router.use(verifyToken);
router.use(checkRole('admin', 'recepcion'));

router.get('/citas', reporteCitas);
router.get('/ingresos', reporteIngresos);

module.exports = router;
