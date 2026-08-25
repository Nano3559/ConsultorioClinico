const express = require('express');
const router = express.Router();
const { body } = require('express-validator');
const { register, login, getProfile, logout } = require('../controllers/authController');
const { verifyToken, optionalAuth } = require('../middleware/auth');
const { validate } = require('../middleware/validation');
const { ROLES } = require('../utils/constants');

// Validaciones
const registerValidation = [
  body('nombre').notEmpty().withMessage('El nombre es obligatorio'),
  body('email').trim().toLowerCase().isEmail().withMessage('Email inválido'),
  body('password').isLength({ min: 6 }).withMessage('La contraseña debe tener al menos 6 caracteres'),
  body('rol').optional().isIn(Object.values(ROLES)).withMessage(`Rol inválido. Valores permitidos: ${Object.values(ROLES).join(', ')}`),
];

const loginValidation = [
  body('email').trim().toLowerCase().isEmail().withMessage('Email inválido'),
  body('password').notEmpty().withMessage('La contraseña es obligatoria'),
];

// Rutas públicas (optionalAuth permite que un admin autenticado cree usuarios privilegiados)
router.post('/register', optionalAuth, registerValidation, validate, register);
router.post('/login', loginValidation, validate, login);

// Rutas protegidas
router.get('/profile', verifyToken, getProfile);
router.post('/logout', verifyToken, logout);

module.exports = router;
