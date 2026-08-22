const express = require('express');
const router = express.Router();
const { body } = require('express-validator');
const { register, login, getProfile } = require('../controllers/authController');
const { verifyToken } = require('../middleware/auth');
const { validate } = require('../middleware/validation');
<<<<<<< HEAD
const { ROLES } = require('../utils/constants');
=======
>>>>>>> origin/main

// Validaciones
const registerValidation = [
  body('nombre').notEmpty().withMessage('El nombre es obligatorio'),
  body('email').isEmail().withMessage('Email inválido'),
  body('password').isLength({ min: 6 }).withMessage('La contraseña debe tener al menos 6 caracteres'),
<<<<<<< HEAD
  body('rol').optional().isIn(Object.values(ROLES)).withMessage(`Rol inválido. Valores permitidos: ${Object.values(ROLES).join(', ')}`),
=======
>>>>>>> origin/main
];

const loginValidation = [
  body('email').isEmail().withMessage('Email inválido'),
  body('password').notEmpty().withMessage('La contraseña es obligatoria'),
];

// Rutas públicas
router.post('/register', registerValidation, validate, register);
router.post('/login', loginValidation, validate, login);

// Rutas protegidas
router.get('/profile', verifyToken, getProfile);

module.exports = router;
