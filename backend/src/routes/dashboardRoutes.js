const express = require('express');
const router = express.Router();
const { getResumen } = require('../controllers/dashboardController');
const { verifyToken } = require('../middleware/auth');

// Todas las rutas requieren autenticación
router.use(verifyToken);

router.get('/', getResumen);

module.exports = router;
