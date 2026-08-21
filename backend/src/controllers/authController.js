const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
<<<<<<< HEAD
const { pool } = require('../config/db');
const config = require('../config/config');
const { sendSuccess, sendError } = require('../utils/helpers');
const { ROLES } = require('../utils/constants');
const ROLES_VALUES = Object.values(ROLES);

/**
 * Traduce errores de MySQL a mensajes claros para el cliente.
 */
const dbErrorMessage = (error) => {
  if (['ECONNREFUSED', 'ETIMEDOUT', 'ENOTFOUND'].includes(error.code)) {
    return 'No hay conexión con la base de datos';
  }
  if (error.code === 'ER_ACCESS_DENIED_ERROR') {
    return 'Credenciales de base de datos inválidas';
  }
  if (error.code === 'ER_BAD_DB_ERROR') {
    return 'La base de datos no existe. Ejecuta npm run db:setup';
  }
  return null;
};

/**
 * POST /api/auth/register
 * Registrar nuevo usuario (rol opcional: admin|medico|recepcion|paciente).
 * Si el rol es medico o paciente también crea su fila de perfil.
=======
const { usuarios } = require('../data/mockData');
const config = require('../config/config');
const { sendSuccess, sendError, nextId } = require('../utils/helpers');

/**
 * POST /api/auth/register
 * Registrar nuevo usuario
>>>>>>> origin/main
 */
const register = async (req, res) => {
  try {
    const { nombre, email, password, rol } = req.body;
<<<<<<< HEAD
    const rolFinal = ROLES_VALUES.includes(rol) ? rol : ROLES.PACIENTE;

    const [existentes] = await pool.query(
      'SELECT id FROM usuarios WHERE email = ? LIMIT 1',
      [email]
    );
    if (existentes.length > 0) {
      return sendError(res, 'El email ya está registrado', 400);
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    const [result] = await pool.query(
      'INSERT INTO usuarios (nombre, email, password, rol) VALUES (?, ?, ?, ?)',
      [nombre, email, hashedPassword, rolFinal]
    );
    const nuevoId = result.insertId;

    // Perfil asociado según el rol (mejor esfuerzo; no bloquea el registro)
    try {
      if (rolFinal === ROLES.MEDICO) {
        await pool.query(
          `INSERT INTO medicos (usuario_id, nombre, apellido, cedula, especialidad, email)
           VALUES (?, ?, ?, ?, ?, ?)`,
          [nuevoId, nombre, 'Por completar', `M${nuevoId}${Date.now() % 100000}`, 'Medicina General', email]
        );
      }
      if (rolFinal === ROLES.PACIENTE) {
        await pool.query(
          `INSERT INTO pacientes (usuario_id, nombre, apellido, cedula, email)
           VALUES (?, ?, ?, ?, ?)`,
          [nuevoId, nombre, 'Por completar', `P${nuevoId}${Date.now() % 100000}`, email]
        );
      }
    } catch (perfilErr) {
      console.error('No se pudo crear el perfil del usuario:', perfilErr.message);
    }

    const token = jwt.sign(
      { id: nuevoId, email, rol: rolFinal },
=======

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
>>>>>>> origin/main
      config.jwtSecret,
      { expiresIn: config.jwtExpire }
    );

    return sendSuccess(res, {
<<<<<<< HEAD
      id: nuevoId,
      nombre,
      email,
      rol: rolFinal,
      token,
    }, 'Usuario registrado exitosamente', 201);
  } catch (error) {
    console.error('register:', error);
    return sendError(res, dbErrorMessage(error) || 'Error al registrar usuario', dbErrorMessage(error) ? 503 : 500);
=======
      id: nuevoUsuario.id,
      nombre: nuevoUsuario.nombre,
      email: nuevoUsuario.email,
      rol: nuevoUsuario.rol,
      token,
    }, 'Usuario registrado exitosamente', 201);
  } catch (error) {
    return sendError(res, 'Error al registrar usuario', 500);
>>>>>>> origin/main
  }
};

/**
 * POST /api/auth/login
<<<<<<< HEAD
 * Iniciar sesión con email + contraseña. Devuelve el token JWT y el rol.
=======
 * Iniciar sesión
>>>>>>> origin/main
 */
const login = async (req, res) => {
  try {
    const { email, password } = req.body;

<<<<<<< HEAD
    const [rows] = await pool.query(
      'SELECT id, nombre, email, password, rol, activo FROM usuarios WHERE email = ? LIMIT 1',
      [email]
    );
    const usuario = rows[0];

=======
    // Buscar usuario
    const usuario = usuarios.find((u) => u.email === email);
>>>>>>> origin/main
    if (!usuario) {
      return sendError(res, 'Credenciales inválidas', 401);
    }

<<<<<<< HEAD
=======
    // Verificar contraseña
>>>>>>> origin/main
    const isMatch = await bcrypt.compare(password, usuario.password);
    if (!isMatch) {
      return sendError(res, 'Credenciales inválidas', 401);
    }

<<<<<<< HEAD
=======
    // Verificar si está activo
>>>>>>> origin/main
    if (!usuario.activo) {
      return sendError(res, 'Cuenta desactivada', 403);
    }

<<<<<<< HEAD
=======
    // Generar token
>>>>>>> origin/main
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
<<<<<<< HEAD
    console.error('login:', error);
    return sendError(res, dbErrorMessage(error) || 'Error al iniciar sesión', dbErrorMessage(error) ? 503 : 500);
=======
    return sendError(res, 'Error al iniciar sesión', 500);
>>>>>>> origin/main
  }
};

/**
 * GET /api/auth/profile
<<<<<<< HEAD
 * Perfil del usuario autenticado (requiere Bearer token).
 */
const getProfile = async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT id, nombre, email, rol, activo, creado_en FROM usuarios WHERE id = ? LIMIT 1',
      [req.user.id]
    );
    const usuario = rows[0];

=======
 * Obtener perfil del usuario autenticado
 */
const getProfile = async (req, res) => {
  try {
    const usuario = usuarios.find((u) => u.id === req.user.id);
>>>>>>> origin/main
    if (!usuario) {
      return sendError(res, 'Usuario no encontrado', 404);
    }

<<<<<<< HEAD
    return sendSuccess(res, usuario);
  } catch (error) {
    console.error('getProfile:', error);
    return sendError(res, dbErrorMessage(error) || 'Error al obtener perfil', dbErrorMessage(error) ? 503 : 500);
  }
};

module.exports = { register, login, getProfile };
=======
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
>>>>>>> origin/main
