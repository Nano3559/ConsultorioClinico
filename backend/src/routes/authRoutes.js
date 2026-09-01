const express = require('express');
const router = express.Router();
const { body } = require('express-validator');
const { register, login, getProfile, logout } = require('../controllers/authController');
const { verifyToken, optionalAuth } = require('../middleware/auth');
const { validate, passwordStrongValidation, sanitizarTexto } = require('../middleware/validation');
const { rateLimit } = require('../middleware/rateLimiter');
const { ROLES } = require('../utils/constants');

// Rate limiting: protege login/registro contra fuerza bruta (por IP).
const loginLimiter = rateLimit({
  max: 10,
  windowMs: 15 * 60 * 1000,
  mensaje: 'Demasiados intentos de inicio de sesión. Intente en 15 minutos',
});

const registerLimiter = rateLimit({
  max: 5,
  windowMs: 60 * 60 * 1000,
  mensaje: 'Demasiados registros desde esta IP. Intente más tarde',
});

// Validaciones
const registerValidation = [
  body('nombre')
    .isLength({ min: 2, max: 120 }).withMessage('El nombre debe tener entre 2 y 120 caracteres')
    .customSanitizer(sanitizarTexto),
  body('email').trim().toLowerCase().isEmail().withMessage('Email inválido'),
  ...passwordStrongValidation,
  body('rol').optional().isIn(Object.values(ROLES)).withMessage(`Rol inválido. Valores permitidos: ${Object.values(ROLES).join(', ')}`),
];

const loginValidation = [
  body('email').trim().toLowerCase().isEmail().withMessage('Email inválido'),
  body('password').notEmpty().withMessage('La contraseña es obligatoria'),
];

// Rutas públicas (optionalAuth permite que un admin autenticado cree usuarios privilegiados)
router.post('/register', registerLimiter, optionalAuth, registerValidation, validate, register);
router.post('/login', loginLimiter, loginValidation, validate, login);

// Rutas protegidas
router.get('/profile', verifyToken, getProfile);
router.post('/logout', verifyToken, logout);

module.exports = router;