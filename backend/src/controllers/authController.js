const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { getSupabase, dbErrorMessage } = require('../config/supabase');
const config = require('../config/config');
const { sendSuccess, sendError } = require('../utils/helpers');
const { ROLES } = require('../utils/constants');
const ROLES_VALUES = Object.values(ROLES);

/**
 * POST /api/auth/register
 * Registrar nuevo usuario (rol opcional: admin|medico|recepcion|paciente).
 * Si el rol es medico o paciente también crea su fila de perfil.
 */
const register = async (req, res) => {
  try {
    const { nombre, email, password, rol } = req.body;
    const rolFinal = ROLES_VALUES.includes(rol) ? rol : ROLES.PACIENTE;
    const supabase = getSupabase();

    const { data: existentes } = await supabase
      .from('usuarios')
      .select('id')
      .eq('email', email)
      .limit(1);
    if (existentes && existentes.length > 0) {
      return sendError(res, 'El email ya está registrado', 400);
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    const { data: nuevoUsuario, error: insertError } = await supabase
      .from('usuarios')
      .insert({ nombre, email, password: hashedPassword, rol: rolFinal })
      .select('id')
      .single();

    if (insertError) {
      console.error('register:', insertError);
      return sendError(res, dbErrorMessage(insertError) || 'Error al registrar usuario', 500);
    }
    const nuevoId = nuevoUsuario.id;

    // Perfil asociado según el rol (mejor esfuerzo; no bloquea el registro)
    try {
      if (rolFinal === ROLES.MEDICO) {
        await supabase.from('medicos').insert({
          usuario_id: nuevoId,
          nombre,
          apellido: 'Por completar',
          cedula: `M${nuevoId}${Date.now() % 100000}`,
          especialidad: 'Medicina General',
          email,
        });
      }
      if (rolFinal === ROLES.PACIENTE) {
        await supabase.from('pacientes').insert({
          usuario_id: nuevoId,
          nombre,
          apellido: 'Por completar',
          cedula: `P${nuevoId}${Date.now() % 100000}`,
          email,
        });
      }
    } catch (perfilErr) {
      console.error('No se pudo crear el perfil del usuario:', perfilErr.message);
    }

    const token = jwt.sign(
      { id: nuevoId, email, rol: rolFinal },
      config.jwtSecret,
      { expiresIn: config.jwtExpire }
    );

    return sendSuccess(res, {
      id: nuevoId,
      nombre,
      email,
      rol: rolFinal,
      token,
    }, 'Usuario registrado exitosamente', 201);
  } catch (error) {
    console.error('register:', error);
    return sendError(res, dbErrorMessage(error) || 'Error al registrar usuario', dbErrorMessage(error) ? 503 : 500);
  }
};

/**
 * POST /api/auth/login
 * Iniciar sesión con email + contraseña. Devuelve el token JWT y el rol.
 */
const login = async (req, res) => {
  try {
    const { email, password } = req.body;
    const supabase = getSupabase();

    const { data: rows } = await supabase
      .from('usuarios')
      .select('id, nombre, email, password, rol, activo')
      .eq('email', email)
      .limit(1);
    const usuario = rows && rows[0];

    if (!usuario) {
      return sendError(res, 'Credenciales inválidas', 401);
    }

    const isMatch = await bcrypt.compare(password, usuario.password);
    if (!isMatch) {
      return sendError(res, 'Credenciales inválidas', 401);
    }

    if (!usuario.activo) {
      return sendError(res, 'Cuenta desactivada', 403);
    }

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
    console.error('login:', error);
    return sendError(res, dbErrorMessage(error) || 'Error al iniciar sesión', dbErrorMessage(error) ? 503 : 500);
  }
};

/**
 * GET /api/auth/profile
 * Perfil del usuario autenticado (requiere Bearer token).
 */
const getProfile = async (req, res) => {
  try {
    const supabase = getSupabase();
    const { data: rows } = await supabase
      .from('usuarios')
      .select('id, nombre, email, rol, activo, creado_en')
      .eq('id', req.user.id)
      .limit(1);
    const usuario = rows && rows[0];

    if (!usuario) {
      return sendError(res, 'Usuario no encontrado', 404);
    }

    return sendSuccess(res, usuario);
  } catch (error) {
    console.error('getProfile:', error);
    return sendError(res, dbErrorMessage(error) || 'Error al obtener perfil', dbErrorMessage(error) ? 503 : 500);
  }
};

module.exports = { register, login, getProfile };
