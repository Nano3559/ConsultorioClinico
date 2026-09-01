const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { getSupabase, dbErrorMessage } = require('../config/supabase');
const config = require('../config/config');
const { sendSuccess, sendError } = require('../utils/helpers');
const { ROLES } = require('../utils/constants');
const ROLES_VALUES = Object.values(ROLES);

/** Roles que solo un admin puede crear/modificar */
const ROLES_PRIVILEGIADOS = [ROLES.ADMIN, ROLES.MEDICO, ROLES.RECEPCION];

/**
 * Normaliza el email (trim + minúsculas) para evitar duplicados por formato.
 * La BD también lo garantiza con el trigger normalizar_email_usuario.
 */
const normalizarEmail = (email) => String(email || '').trim().toLowerCase();

/**
 * Busca la fila de perfil asociada al usuario según su rol
 * (pacientes o medicos). Devuelve { tipo, id } o null.
 */
const obtenerPerfil = async (supabase, usuarioId, rol) => {
  try {
    if (rol === ROLES.MEDICO) {
      const { data } = await supabase
        .from('medicos')
        .select('id')
        .eq('usuario_id', usuarioId)
        .limit(1);
      if (data && data[0]) return { tipo: 'medico', id: data[0].id };
    }
    if (rol === ROLES.PACIENTE) {
      const { data } = await supabase
        .from('pacientes')
        .select('id')
        .eq('usuario_id', usuarioId)
        .limit(1);
      if (data && data[0]) return { tipo: 'paciente', id: data[0].id };
    }
  } catch (_error) {
    // Perfil ausente no debe romper el login
  }
  return null;
};

/**
 * Crea la fila de perfil asociada según el rol (mejor esfuerzo).
 */
const crearPerfilSegunRol = async (supabase, nuevoId, nombre, email, rolFinal) => {
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
};

/**
 * Registra la sesión en la tabla sesiones (mejor esfuerzo; si la migración
 * 003 aún no se ejecutó, el login sigue funcionando sin auditoría).
 */
const registrarSesion = async (supabase, usuarioId, tokenId, req, expiraEn) => {
  try {
    await supabase.from('sesiones').insert({
      usuario_id: usuarioId,
      token_id: tokenId,
      ip_address: (req.ip || '').slice(0, 60),
      user_agent: (req.headers['user-agent'] || '').slice(0, 250),
      expira_en: expiraEn.toISOString(),
    });
  } catch (sesionErr) {
    console.error('No se pudo registrar la sesión:', sesionErr.message);
  }
};

/**
 * POST /api/auth/register
 * Registrar nuevo usuario.
 * - Público solo permite crear PACIENTES.
 * - Crear admin/medico/recepcion requiere estar autenticado como admin
 *   (Bearer token), evitando auto-elevación de privilegios.
 */
const register = async (req, res) => {
  try {
    let { nombre, email, password, rol } = req.body;
    email = normalizarEmail(email);
    const rolSolicitado = ROLES_VALUES.includes(rol) ? rol : ROLES.PACIENTE;

    if (
      ROLES_PRIVILEGIADOS.includes(rolSolicitado) &&
      (!req.user || req.user.rol !== ROLES.ADMIN)
    ) {
      return sendError(
        res,
        'Solo un administrador puede crear usuarios con roles privilegiados',
        403
      );
    }

    const supabase = getSupabase();

    const { data: existentes, error: existeError } = await supabase
      .from('usuarios')
      .select('id')
      .eq('email', email)
      .limit(1);
    if (existeError) throw existeError;
    if (existentes && existentes.length > 0) {
      return sendError(res, 'El email ya está registrado', 400);
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    const { data: nuevoUsuario, error: insertError } = await supabase
      .from('usuarios')
      .insert({ nombre, email, password: hashedPassword, rol: rolSolicitado })
      .select('id')
      .single();

    if (insertError) {
      console.error('register:', insertError);
      return sendError(res, dbErrorMessage(insertError) || 'Error al registrar usuario', 500);
    }
    const nuevoId = nuevoUsuario.id;

    // Perfil asociado según el rol (no bloquea el registro)
    await crearPerfilSegunRol(supabase, nuevoId, nombre, email, rolSolicitado);

    const perfil = await obtenerPerfil(supabase, nuevoId, rolSolicitado);

    const token = jwt.sign(
      {
        id: nuevoId,
        email,
        rol: rolSolicitado,
        perfilTipo: perfil ? perfil.tipo : null,
        perfilId: perfil ? perfil.id : null,
      },
      config.jwtSecret,
      { expiresIn: config.jwtExpire }
    );

    return sendSuccess(
      res,
      { id: nuevoId, nombre, email, rol: rolSolicitado, perfil, token },
      'Usuario registrado exitosamente',
      201
    );
  } catch (error) {
    console.error('register:', error);
    return sendError(res, dbErrorMessage(error) || 'Error al registrar usuario', dbErrorMessage(error) ? 503 : 500);
  }
};

/**
 * POST /api/auth/login
 * Iniciar sesión con email + contraseña. Devuelve el token JWT, el rol y el
 * perfil asociado para que cada rol entre a su vista correspondiente.
 */
const login = async (req, res) => {
  try {
    let { email, password } = req.body;
    email = normalizarEmail(email);
    const supabase = getSupabase();

    const { data: rows, error: queryError } = await supabase
      .from('usuarios')
      .select('id, nombre, email, password, rol, activo')
      .eq('email', email)
      .limit(1);
    if (queryError) throw queryError;
    const usuario = rows && rows[0];

    if (!usuario) {
      return sendError(res, 'Credenciales inválidas', 401);
    }

    const isMatch = await bcrypt.compare(password, usuario.password);
    if (!isMatch) {
      return sendError(res, 'Credenciales inválidas', 401);
    }

    if (!usuario.activo) {
      return sendError(res, 'Cuenta desactivada. Contacte al administrador', 403);
    }

    const perfil = await obtenerPerfil(supabase, usuario.id, usuario.rol);

    // Sesión con ID único para poder cerrarla realmente desde /logout
    const tokenId = crypto.randomUUID();
    const expiraMs = parseExpira(config.jwtExpire);
    const fechaExpiracion = new Date(Date.now() + expiraMs);

    const token = jwt.sign(
      {
        id: usuario.id,
        email: usuario.email,
        rol: usuario.rol,
        perfilTipo: perfil ? perfil.tipo : null,
        perfilId: perfil ? perfil.id : null,
        jti: tokenId,
      },
      config.jwtSecret,
      { expiresIn: config.jwtExpire }
    );

    // Auditoría: último acceso + fila de sesión (no bloquean el login)
    try {
      await supabase
        .from('usuarios')
        .update({ ultimo_acceso: new Date().toISOString() })
        .eq('id', usuario.id);
    } catch (_e) {
      /* columna opcional hasta ejecutar migración 003 */
    }
    await registrarSesion(supabase, usuario.id, tokenId, req, fechaExpiracion);

    return sendSuccess(res, {
      id: usuario.id,
      nombre: usuario.nombre,
      email: usuario.email,
      rol: usuario.rol,
      perfil,
      token,
    }, 'Inicio de sesión exitoso');
  } catch (error) {
    console.error('login:', error);
    return sendError(res, dbErrorMessage(error) || 'Error al iniciar sesión', dbErrorMessage(error) ? 503 : 500);
  }
};

/**
 * Convierte valores tipo '24h' | '7d' | '30m' a milisegundos (fallback 24h)
 */
function parseExpira(expira) {
  const match = /^(\d+)([smhd])$/.exec(String(expira || ''));
  if (!match) return 24 * 60 * 60 * 1000;
  const mult = { s: 1000, m: 60000, h: 3600000, d: 86400000 }[match[2]];
  return parseInt(match[1], 10) * mult;
}

/**
 * GET /api/auth/profile
 * Perfil del usuario autenticado (requiere Bearer token).
 */
const getProfile = async (req, res) => {
  try {
    const supabase = getSupabase();
    let select = 'id, nombre, email, rol, activo, creado_en, ultimo_acceso';
    let { data: rows, error: queryError } = await supabase
      .from('usuarios')
      .select(select)
      .eq('id', req.user.id)
      .limit(1);

    // Si la columna ultimo_acceso no existe (migración 003 no aplicada),
    // reintentar sin ella para no romper el perfil.
    if (queryError && (queryError.code === '42703' || /ultimo_acceso/.test(queryError.message || ''))) {
      select = 'id, nombre, email, rol, activo, creado_en';
      ({ data: rows, error: queryError } = await supabase
        .from('usuarios')
        .select(select)
        .eq('id', req.user.id)
        .limit(1));
    }
    if (queryError) throw queryError;
    const usuario = rows && rows[0];

    if (!usuario) {
      return sendError(res, 'Usuario no encontrado', 404);
    }

    const perfil = await obtenerPerfil(supabase, usuario.id, usuario.rol);

    return sendSuccess(res, { ...usuario, perfil });
  } catch (error) {
    console.error('getProfile:', error);
    return sendError(res, dbErrorMessage(error) || 'Error al obtener perfil', dbErrorMessage(error) ? 503 : 500);
  }
};

/**
 * POST /api/auth/logout
 * Cierra la sesión actual (revoca el token registrado). Requiere Bearer token.
 * Si la tabla sesiones no existe, responde igualmente OK (logout stateless).
 */
const logout = async (req, res) => {
  try {
    const supabase = getSupabase();
    const tokenId = req.user.jti;

    if (tokenId) {
      await supabase
        .from('sesiones')
        .update({ activa: false, cerrada_en: new Date().toISOString() })
        .eq('token_id', tokenId)
        .eq('activa', true);
    }

    return sendSuccess(res, null, 'Sesión cerrada exitosamente');
  } catch (error) {
    // Logout siempre exitoso desde la perspectiva del cliente
    console.error('logout:', error.message);
    return sendSuccess(res, null, 'Sesión cerrada exitosamente');
  }
};

module.exports = { register, login, getProfile, logout };
