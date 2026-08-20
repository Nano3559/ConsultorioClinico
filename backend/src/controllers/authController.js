const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { usuarios } = require('../data/mockData');
const config = require('../config/config');
const { sendSuccess, sendError, nextId } = require('../utils/helpers');

/**
 * POST /api/auth/register
 * Registrar nuevo usuario
 */
const register = async (req, res) => {
  try {
    const { nombre, email, password, rol } = req.body;

    // Verificar si el email ya existe
    const existeUsuario = usuarios.find((u) => u.email === email);
    if (existeUsuario) {
      return sendError(res, 'El email ya está registrado', 400);
    }

    // Hash de la contraseña
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    // Crear usuario
    const nuevoUsuario = {
      id: nextId(usuarios),
      nombre,
      email,
      password: hashedPassword,
      rol: rol || 'paciente',
      activo: true,
      creado_en: new Date().toISOString(),
    };

    usuarios.push(nuevoUsuario);

    // Generar token
    const token = jwt.sign(
      { id: nuevoUsuario.id, email: nuevoUsuario.email, rol: nuevoUsuario.rol },
      config.jwtSecret,
      { expiresIn: config.jwtExpire }
    );

    return sendSuccess(res, {
      id: nuevoUsuario.id,
      nombre: nuevoUsuario.nombre,
      email: nuevoUsuario.email,
      rol: nuevoUsuario.rol,
      token,
    }, 'Usuario registrado exitosamente', 201);
  } catch (error) {
    return sendError(res, 'Error al registrar usuario', 500);
  }
};

/**
 * POST /api/auth/login
 * Iniciar sesión
 */
const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    // Buscar usuario
    const usuario = usuarios.find((u) => u.email === email);
    if (!usuario) {
      return sendError(res, 'Credenciales inválidas', 401);
    }

    // Verificar contraseña
    const isMatch = await bcrypt.compare(password, usuario.password);
    if (!isMatch) {
      return sendError(res, 'Credenciales inválidas', 401);
    }

    // Verificar si está activo
    if (!usuario.activo) {
      return sendError(res, 'Cuenta desactivada', 403);
    }

    // Generar token
    const token = jwt.sign(
      { id: usuario.id, email: usuario.email, rol: usuario.rol },
      config.jwtSecret,
      { expiresIn: config.jwtExpire }
    );

    return sendSuccess(res, {
      id: usuario.id,
      nombre: usuario.nombre,
      email: usuario.email,
      rol: usuario.rol,
      token,
    }, 'Inicio de sesión exitoso');
  } catch (error) {
    return sendError(res, 'Error al iniciar sesión', 500);
  }
};

/**
 * GET /api/auth/profile
 * Obtener perfil del usuario autenticado
 */
const getProfile = async (req, res) => {
  try {
    const usuario = usuarios.find((u) => u.id === req.user.id);
    if (!usuario) {
      return sendError(res, 'Usuario no encontrado', 404);
    }

    const { password, ...perfil } = usuario;
    return sendSuccess(res, perfil);
  } catch (error) {
    return sendError(res, 'Error al obtener perfil', 500);
  }
};

module.exports = {
  register,
  login,
  getProfile,
};
