const { sendError } = require('../utils/helpers');

/**
 * Middleware para verificar roles permitidos
 * @param  {...string} roles - Roles permitidos (ej: 'admin', 'medico', 'recepcion')
 */
const checkRole = (...roles) => {
  return (req, res, next) => {
    if (!req.user) {
      return sendError(res, 'No autenticado', 401);
    }

    if (!roles.includes(req.user.rol)) {
      return sendError(
        res,
        `Acceso denegado. Se requiere uno de estos roles: ${roles.join(', ')}`,
        403
      );
    }

    next();
  };
};

/**
 * Resuelve el id de perfil de médico del usuario autenticado.
 * verifyFlexible (camino Firebase) ya lo adjunta en req.user.perfilId;
 * el camino JWT legacy lo busca por usuarios.id -> medicos.usuario_id.
 */
async function perfilMedicoDe(req) {
  if (req.user.perfilId != null) return req.user.perfilId;
  const { getSupabase } = require('../config/supabase');
  const { data } = await getSupabase()
    .from('medicos')
    .select('id')
    .eq('usuario_id', req.user.id)
    .limit(1);
  return data && data[0] ? data[0].id : null;
}

/**
 * Admin, o el propio médico sobre su propio :id (parámetro de la ruta).
 */
const checkAdminOrSelfMedico = (param = 'id') => {
  return async (req, res, next) => {
    try {
      if (!req.user) return sendError(res, 'No autenticado', 401);
      if (req.user.rol === 'admin') return next();
      if (req.user.rol !== 'medico') {
        return sendError(res, 'Acceso denegado. Se requiere rol: admin o medico', 403);
      }
      const perfilId = await perfilMedicoDe(req);
      if (perfilId != null && String(perfilId) === String(req.params[param])) {
        return next();
      }
      return sendError(res, 'Acceso denegado: solo puedes editar tus propios horarios', 403);
    } catch (error) {
      console.error('roles.checkAdminOrSelfMedico:', error);
      return sendError(res, 'Error de autorización', 500);
    }
  };
};

/**
 * Admin, o el dueño del horario :id (se busca su medico_id en la BD).
 */
const checkAdminOrOwnHorario = async (req, res, next) => {
  try {
    if (!req.user) return sendError(res, 'No autenticado', 401);
    if (req.user.rol === 'admin') return next();
    if (req.user.rol !== 'medico') {
      return sendError(res, 'Acceso denegado. Se requiere rol: admin o medico', 403);
    }
    const { getSupabase } = require('../config/supabase');
    const { data } = await getSupabase()
      .from('horarios')
      .select('medico_id')
      .eq('id', req.params.id)
      .limit(1);
    if (!data || data.length === 0) {
      return sendError(res, 'Horario no encontrado', 404);
    }
    const perfilId = await perfilMedicoDe(req);
    if (perfilId != null && String(data[0].medico_id) === String(perfilId)) {
      return next();
    }
    return sendError(res, 'Acceso denegado: solo puedes editar tus propios horarios', 403);
  } catch (error) {
    console.error('roles.checkAdminOrOwnHorario:', error);
    return sendError(res, 'Error de autorización', 500);
  }
};

module.exports = { checkRole, checkAdminOrSelfMedico, checkAdminOrOwnHorario };
