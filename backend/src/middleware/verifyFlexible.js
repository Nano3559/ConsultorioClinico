const { sendError } = require('../utils/helpers');
const { validarTokenJwt } = require('./auth');
const firebaseAdmin = require('../config/firebaseAdmin');

/**
 * Autenticación FLEXIBLE (Fase 1 del puente de auth): acepta el JWT propio
 * (comportamiento histórico intacto, con revocación por sesiones) O un
 * Firebase ID token (login de la app Flutter).
 *
 * Camino Firebase: verifica la firma con Admin SDK, busca el usuario por
 * email en Supabase (fuente de roles) y adjunta req.user con la MISMA forma
 * que el JWT ({ id, email, rol, ... }) para que checkRole no cambie.
 * Si el email no tiene usuario en el backend: 401 (debe crearlo un admin).
 * Si está desactivado: 403.
 */
const verifyFlexible = async (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return sendError(res, 'Token no proporcionado', 401);
  }
  const token = authHeader.split(' ')[1];

  // 1. JWT propio (no se toca su comportamiento).
  try {
    req.user = await validarTokenJwt(token);
    req.user.authTipo = req.user.authTipo || 'jwt';
    return next();
  } catch (_jwtError) {
    // No era JWT válido: se intenta como Firebase ID token.
  }

  // 2. Firebase ID token.
  try {
    const decoded = await firebaseAdmin.verifyIdToken(token);
    const email = String(decoded.email || '').trim().toLowerCase();
    if (!email) {
      return sendError(res, 'Token sin email verificado', 401);
    }
    const { getSupabase } = require('../config/supabase');
    const supabase = getSupabase();
    const { data, error } = await supabase
      .from('usuarios')
      .select('id, email, rol, activo')
      .eq('email', email)
      .limit(1);
    if (error) throw error;
    if (!data || data.length === 0) {
      return sendError(res, 'Usuario no registrado en el sistema', 401);
    }
    const usuario = data[0];
    if (usuario.activo === false) {
      return sendError(res, 'Usuario desactivado', 403);
    }
    req.user = {
      id: usuario.id,
      email: usuario.email,
      rol: usuario.rol,
      firebaseUid: decoded.uid,
      authTipo: 'firebase',
    };
    return next();
  } catch (error) {
    if (error && error.status) {
      return sendError(res, error.message, error.status);
    }
    console.error('[auth] verifyFlexible/firebase:', error.message);
    return sendError(res, 'Token inválido', 401);
  }
};

module.exports = { verifyFlexible };
