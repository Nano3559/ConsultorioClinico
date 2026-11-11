const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const { getSupabase } = require('../config/supabase');
const { sendSuccess, sendError, formatDate, normalizarTexto, horaAMinutos } = require('../utils/helpers');
const { ESTADOS_CITA } = require('../utils/constants');

const normalizarEmail = (email) => String(email || '').trim().toLowerCase();

/**
 * Resuelve especialidad_id a partir del nombre (normalizado), buscando en la
 * tabla catálogo especialidades. Devuelve { id, nombre } o { id: null, nombre }.
 * Es la única fuente de verdad para evitar desnormalización (texto vs. FK).
 */
const resolverEspecialidad = async (supabase, nombreEspecialidad) => {
  const nombre = (nombreEspecialidad || '').trim();
  if (!nombre) return { id: null, nombre };

  const { data: rows, error } = await supabase
    .from('especialidades')
    .select('id, nombre')
    .eq('activo', true);
  if (error) {
    if (error.code === '42P01' || error.code === 'PGRST205') return { id: null, nombre }; // tabla aún no existe
    throw error;
  }
  const match = (rows || []).find(
    (e) => normalizarTexto(e.nombre) === normalizarTexto(nombre)
  );
  return match ? { id: match.id, nombre: match.nombre } : { id: null, nombre };
};

/**
 * Columnas seguras para lecturas públicas (sin email/cédula/telefono).
 */
const SELECT_MEDICO_PUBLICO =
  'id, nombre, apellido, especialidad, especialidad_id, consulorio, tarifa_consulta, activo';

/**
 * GET /api/medicos
 * Listar todos los médicos activos.
 * - Autenticado (staff): devuelve el registro completo.
 * - Público / paciente: solo columnas esenciales de catálogo.
 */
const getAll = async (req, res) => {
  try {
    const supabase = getSupabase();
    const esStaff = req.user && req.user.rol !== 'paciente';
    const columnas = esStaff ? '*' : SELECT_MEDICO_PUBLICO;

    const { data, error } = await supabase
      .from('medicos')
      .select(columnas)
      .eq('activo', true)
      .order('id');

    if (error) {
      console.error('medicos.getAll SUPABASE ERROR:', JSON.stringify(error, null, 2));
      throw error;
    }
    console.log('medicos.getAll OK, registros:', data ? data.length : 0);
    return sendSuccess(res, data);
  } catch (error) {
    console.error('medicos.getAll ERROR:', JSON.stringify(error, null, 2));
    return sendError(res, `Error al listar médicos: ${error.message || 'desconocido'}`, 500);
  }
};

/**
 * GET /api/medicos/:id
 * Obtener médico por ID (misma lógica de campos según autenticación)
 */
const getById = async (req, res) => {
  try {
    const supabase = getSupabase();
    const esStaff = req.user && req.user.rol !== 'paciente';
    const columnas = esStaff ? '*' : SELECT_MEDICO_PUBLICO;

    const { data, error } = await supabase
      .from('medicos')
      .select(columnas)
      .eq('id', req.params.id)
      .limit(1);

    if (error) throw error;
    if (!data || data.length === 0) {
      return sendError(res, 'Médico no encontrado', 404);
    }
    return sendSuccess(res, data[0]);
  } catch (error) {
    console.error('medicos.getById ERROR:', JSON.stringify(error, null, 2));
    return sendError(res, `Error al obtener médico: ${error.message || 'desconocido'}`, 500);
  }
};

/**
 * POST /api/medicos
 * Crear nuevo médico
 */
  const create = async (req, res) => {
  try {
    const { nombre, apellido, cedula, especialidad, telefono, email, consulorio, tarifa_consulta, titulo, descripcion, anios_experiencia } = req.body;
    const supabase = getSupabase();

    // La cédula es única; si el formulario no la envía, generamos un marcador
    // con sufijo aleatorio para evitar colisiones con el UNIQUE de la BD.
    // Formato corto (13 chars): la columna es varchar(20) y el formato
    // anterior (M + timestamp + 8 hex = 22 chars) siempre fallaba.
    const cedulaFinal = cedula && String(cedula).trim()
      ? String(cedula).trim()
      : `M${Date.now().toString().slice(-8)}${crypto.randomBytes(2).toString('hex')}`;

    const { data: existentes } = await supabase
      .from('medicos')
      .select('id')
      .eq('cedula', cedulaFinal)
      .limit(1);
    if (existentes && existentes.length > 0) {
      return sendError(res, 'Ya existe un médico con esa cédula', 400);
    }

    // Normalizar: resolver especialidad_id desde el catálogo por nombre.
    const esp = await resolverEspecialidad(supabase, especialidad);

    const nuevoMedico = {
      nombre,
      apellido,
      cedula: cedulaFinal,
      especialidad: esp.nombre,
      telefono,
      email: email && String(email).trim() ? email : null,
      consulorio,
      tarifa_consulta: parseFloat(tarifa_consulta) || 0,
      titulo: (titulo && String(titulo).trim()) ? String(titulo).trim() : 'Dr./Dra.',
      descripcion: descripcion || '',
      anios_experiencia: parseInt(anios_experiencia, 10) || 0,
    };
    // especialidad_id es una FK agregada por la migración 004. Si la columna
    // aún no existe en la BD (migración pendiente), la insertamos sin ella.
    if (esp.id) nuevoMedico.especialidad_id = esp.id;

    const { data, error } = await supabase
      .from('medicos')
      .insert(nuevoMedico)
      .select('*')
      .single();

    if (error) {
      if (error.code === '23505') {
        return sendError(res, 'Ya existe un médico con esa cédula', 400);
      }
      // Columna especialidad_id inexistente (migración 004 no aplicada):
      // reintentar sin ese campo para conservar la funcionalidad.
      if (
        error.code === 'PGRST204' ||
        (error.code === 'PGRST205' && /especialidad_id|specialidades/i.test(error.message || '')) ||
        /especialidad_id/.test(error.message || '')
      ) {
        delete nuevoMedico.especialidad_id;
        const retry = await supabase
          .from('medicos')
          .insert(nuevoMedico)
          .select('*')
          .single();
        if (retry.error) {
          if (retry.error.code === '23505') {
            return sendError(res, 'Ya existe un médico con esa cédula', 400);
          }
          throw retry.error;
        }
        return sendSuccess(res, retry.data, 'Médico creado exitosamente', 201);
      }
      throw error;
    }
    return sendSuccess(res, data, 'Médico creado exitosamente', 201);
  } catch (error) {
    console.error('medicos.create ERROR:', JSON.stringify(error, null, 2));
    return sendError(res, `Error al crear médico: ${error.message || 'desconocido'}`, 500);
  }
};

/**
 * POST /api/medicos/invitar (solo admin)
 * Alta completa de médico para el flujo de invitación: crea la fila en
 * `usuarios` (rol médico, contraseña temporal hasheada), la fila en
 * `medicos` vinculada y la cuenta en Firebase Auth. Es idempotente por
 * email: si el médico ya existe (o quedó a medias), completa lo que falte
 * y devuelve sus ids en vez de fallar. Si algo falla, revierte lo creado
 * en ESTE request para permitir reintentar limpio.
 */
const invitar = async (req, res) => {
  const supabase = getSupabase();
  let usuarioCreado = null;
  let medicoCreado = null;
  try {
    const { nombre, apellido, cedula, especialidad, telefono, email, consulorio, tarifa_consulta, titulo, descripcion, anios_experiencia, password } = req.body;
    const emailNorm = normalizarEmail(email);

    // 1) Idempotencia: usuario + médico ya vinculados → completar Firebase.
    const { data: usuExist } = await supabase
      .from('usuarios')
      .select('id, rol')
      .eq('email', emailNorm)
      .limit(1);
    let usuarioId = null;
    let medico = null;
    let existed = false;
    if (usuExist && usuExist.length > 0) {
      if (usuExist[0].rol !== 'medico') {
        return sendError(res, 'Ese correo ya pertenece a una cuenta de otro rol', 409);
      }
      usuarioId = usuExist[0].id;
      const { data: medExist } = await supabase
        .from('medicos')
        .select('*')
        .eq('usuario_id', usuarioId)
        .limit(1);
      if (medExist && medExist.length > 0) {
        medico = medExist[0];
        existed = true;
      }
    }

    if (!existed) {
      // Cédula duplicada (misma regla que create).
      const cedulaFinal = cedula && String(cedula).trim()
        ? String(cedula).trim()
        : `M${Date.now().toString().slice(-8)}${crypto.randomBytes(2).toString('hex')}`;
      const { data: cedExist } = await supabase
        .from('medicos')
        .select('id')
        .eq('cedula', cedulaFinal)
        .limit(1);
      if (cedExist && cedExist.length > 0) {
        return sendError(res, 'Ya existe un médico con esa cédula', 400);
      }

      // Fila en usuarios (rol médico).
      if (!usuarioId) {
        const hash = await bcrypt.hash(password, 10);
        const { data: nuevoUsuario, error: errUsu } = await supabase
          .from('usuarios')
          .insert({
            nombre: `${nombre || ''} ${apellido || ''}`.trim(),
            email: emailNorm,
            password: hash,
            rol: 'medico',
            activo: true,
          })
          .select('id')
          .single();
        if (errUsu) {
          if (errUsu.code === '23505') {
            return sendError(res, 'Ya existe un usuario con ese correo', 409);
          }
          throw errUsu;
        }
        usuarioId = nuevoUsuario.id;
        usuarioCreado = usuarioId;
      }

      // Fila en medicos vinculada (misma construcción que create).
      const esp = await resolverEspecialidad(supabase, especialidad);
      const filaMedico = {
        usuario_id: usuarioId,
        nombre,
        apellido,
        cedula: cedulaFinal,
        especialidad: esp.nombre,
        telefono,
        email: emailNorm,
        consulorio,
        tarifa_consulta: parseFloat(tarifa_consulta) || 0,
        titulo: (titulo && String(titulo).trim()) ? String(titulo).trim() : 'Dr./Dra.',
        descripcion: descripcion || '',
        anios_experiencia: parseInt(anios_experiencia, 10) || 0,
      };
      if (esp.id) filaMedico.especialidad_id = esp.id;
      let ins = await supabase.from('medicos').insert(filaMedico).select('*').single();
      if (ins.error && /especialidad_id/.test(ins.error.message || '')) {
        delete filaMedico.especialidad_id;
        ins = await supabase.from('medicos').insert(filaMedico).select('*').single();
      }
      if (ins.error) {
        if (ins.error.code === '23505') {
          await revertirInvitacion(supabase, null, usuarioCreado);
          return sendError(res, 'Ya existe un médico con esa cédula', 400);
        }
        throw ins.error;
      }
      medico = ins.data;
      medicoCreado = medico.id;
    }

    // 2) Cuenta en Firebase Auth (crear o reutilizar).
    let firebaseUid = null;
    try {
      const { getAuth } = require('firebase-admin/auth');
      const { getAdmin } = require('../config/firebaseAdmin');
      const auth = getAuth(getAdmin());
      let fbUser = null;
      try {
        fbUser = await auth.getUserByEmail(emailNorm);
      } catch (e) {
        if (!e || e.code !== 'auth/user-not-found') throw e;
      }
      if (!fbUser) {
        fbUser = await auth.createUser({
          email: emailNorm,
          password,
          displayName: `${nombre || ''} ${apellido || ''}`.trim() || undefined,
        });
      }
      firebaseUid = fbUser.uid;
    } catch (e) {
      await revertirInvitacion(supabase, medicoCreado, usuarioCreado);
      console.error('medicos.invitar FIREBASE ERROR:', e && e.message);
      return sendError(res, 'No se pudo crear la cuenta de acceso del médico, intenta de nuevo', 503);
    }

    return sendSuccess(
      res,
      { usuario_id: usuarioId, medico_id: medico.id, medico, firebase_uid: firebaseUid, existed },
      existed ? 'El médico ya estaba registrado' : 'Médico invitado exitosamente',
      existed ? 200 : 201
    );
  } catch (error) {
    await revertirInvitacion(supabase, medicoCreado, usuarioCreado);
    console.error('medicos.invitar ERROR:', JSON.stringify(error, null, 2));
    return sendError(res, `Error al invitar médico: ${error.message || 'desconocido'}`, 500);
  }
};

/**
 * Borra las filas creadas por un intento de invitación (mejor esfuerzo).
 */
const revertirInvitacion = async (supabase, medicoId, usuarioId) => {
  try {
    if (medicoId) await supabase.from('medicos').delete().eq('id', medicoId);
    if (usuarioId) await supabase.from('usuarios').delete().eq('id', usuarioId);
  } catch (_) {
    // Mejor esfuerzo: no bloquear la respuesta de error original.
  }
};

/**
 * PUT /api/medicos/:id
 * Actualizar médico
 */
const update = async (req, res) => {
  try {
    const supabase = getSupabase();
    const permitidos = ['nombre', 'apellido', 'cedula', 'especialidad', 'telefono', 'email', 'consulorio', 'titulo', 'descripcion'];
    const cambios = {};
    for (const campo of permitidos) {
      if (req.body[campo] !== undefined) cambios[campo] = req.body[campo];
    }
    if (req.body.tarifa_consulta !== undefined) {
      cambios.tarifa_consulta = parseFloat(req.body.tarifa_consulta);
    }
    if (req.body.anios_experiencia !== undefined) {
      cambios.anios_experiencia = parseInt(req.body.anios_experiencia, 10) || 0;
    }

    // Mantener especialidad_id en sincronía con el texto de especialidad.
    // especialidad_id es FK de la migración 004; se omite si la columna no existe.
    if (cambios.especialidad !== undefined) {
      const esp = await resolverEspecialidad(supabase, cambios.especialidad);
      cambios.especialidad = esp.nombre;
      if (esp.id) cambios.especialidad_id = esp.id;
    }

    if (Object.keys(cambios).length === 0) {
      return sendError(res, 'No hay campos para actualizar', 400);
    }

    let { data, error } = await supabase
      .from('medicos')
      .update(cambios)
      .eq('id', req.params.id)
      .select('*');

    if (
      (error && error.code === 'PGRST204') ||
      (error && /especialidad_id/.test(error.message || ''))
    ) {
      delete cambios.especialidad_id;
      const retry = await supabase
        .from('medicos')
        .update(cambios)
        .eq('id', req.params.id)
        .select('*');
      if (retry.error) throw retry.error;
      data = retry.data;
      error = null;
    }

    if (error) {
      if (error.code === '23505') {
        return sendError(res, 'Ya existe un médico con esa cédula', 400);
      }
      throw error;
    }
    if (!data || data.length === 0) {
      return sendError(res, 'Médico no encontrado', 404);
    }
    return sendSuccess(res, data[0], 'Médico actualizado exitosamente');
  } catch (error) {
    console.error('medicos.update ERROR:', JSON.stringify(error, null, 2));
    return sendError(res, `Error al actualizar médico: ${error.message || 'desconocido'}`, 500);
  }
};

/**
 * PATCH /api/medicos/:id/estado
 * Activar/desactivar médico
 */
const toggleEstado = async (req, res) => {
  try {
    const supabase = getSupabase();

    const { data: actuales } = await supabase
      .from('medicos')
      .select('activo')
      .eq('id', req.params.id)
      .limit(1);
    if (!actuales || actuales.length === 0) {
      return sendError(res, 'Médico no encontrado', 404);
    }

    const nuevoEstado = !actuales[0].activo;
    const { data, error } = await supabase
      .from('medicos')
      .update({ activo: nuevoEstado })
      .eq('id', req.params.id)
      .select('*')
      .single();

    if (error) throw error;
    const estado = nuevoEstado ? 'activado' : 'desactivado';
    return sendSuccess(res, data, `Médico ${estado} exitosamente`);
  } catch (error) {
    console.error('medicos.toggleEstado ERROR:', JSON.stringify(error, null, 2));
    return sendError(res, `Error al cambiar estado del médico: ${error.message || 'desconocido'}`, 500);
  }
};

/**
 * GET /api/medicos/:id/horarios
 * Obtener horarios de un médico
 */
const getHorarios = async (req, res) => {
  try {
    const supabase = getSupabase();

    const { data: medicos } = await supabase
      .from('medicos')
      .select('id')
      .eq('id', req.params.id)
      .limit(1);
    if (!medicos || medicos.length === 0) {
      return sendError(res, 'Médico no encontrado', 404);
    }

    const { data, error } = await supabase
      .from('horarios')
      .select('*')
      .eq('medico_id', req.params.id)
      .eq('activo', true)
      .order('id');

    if (error) throw error;
    return sendSuccess(res, data || []);
  } catch (error) {
    console.error('medicos.getHorarios:', error);
    return sendError(res, 'Error al obtener horarios', 500);
  }
};

/**
 * POST /api/medicos/:id/horarios
 * Agregar un horario de atención al médico (solo admin)
 */
const createHorario = async (req, res) => {
  try {
    const { dia_semana, hora_inicio, hora_fin } = req.body;
    const supabase = getSupabase();

    // Validar que la hora de fin sea posterior a la de inicio.
    if (horaAMinutos(hora_fin) <= horaAMinutos(hora_inicio)) {
      return sendError(res, 'La hora de fin debe ser posterior a la de inicio', 400);
    }

    const { data: medicos } = await supabase
      .from('medicos')
      .select('id')
      .eq('id', req.params.id)
      .limit(1);
    if (!medicos || medicos.length === 0) {
      return sendError(res, 'Médico no encontrado', 404);
    }

    const { data, error } = await supabase
      .from('horarios')
      .insert({
        medico_id: req.params.id,
        dia_semana,
        hora_inicio,
        hora_fin,
        activo: true,
      })
      .select('*')
      .single();

    if (error) throw error;
    return sendSuccess(res, data, 'Horario agregado exitosamente', 201);
  } catch (error) {
    // Exclusion constraint excl_horarios_solapamiento: rango ya cubierto.
    if (error && error.code === '23P01') {
      return sendError(res, 'Ya existe un horario que se solapa en ese día', 409);
    }
    console.error('medicos.createHorario:', error);
    return sendError(res, 'Error al agregar horario', 500);
  }
};

/**
 * DELETE /api/medicos/:id
 * Eliminar médico
 */
const remove = async (req, res) => {
  try {
    const supabase = getSupabase();

    const { data: actuales } = await supabase
      .from('medicos')
      .select('id')
      .eq('id', req.params.id)
      .limit(1);
    if (!actuales || actuales.length === 0) {
      return sendError(res, 'Médico no encontrado', 404);
    }
    const medicoId = actuales[0].id;

    // No permitir eliminar si tiene citas activas (no canceladas) hoy o futuras
    const hoy = formatDate(new Date());
    const { data: citasActivas } = await supabase
      .from('citas')
      .select('id')
      .eq('medico_id', medicoId)
      .neq('estado', ESTADOS_CITA.CANCELADA)
      .gte('fecha', hoy)
      .limit(1);
    if (citasActivas && citasActivas.length > 0) {
      return sendError(res, 'No se puede eliminar: el médico tiene citas activas pendientes', 409);
    }

    // Los horarios y citas históricas se eliminan en cascada por FK
    const { error } = await supabase.from('medicos').delete().eq('id', medicoId);
    if (error) throw error;

    return sendSuccess(res, null, 'Médico eliminado exitosamente');
  } catch (error) {
    console.error('medicos.remove ERROR:', JSON.stringify(error, null, 2));
    return sendError(res, `Error al eliminar médico: ${error.message || 'desconocido'}`, 500);
  }
};

module.exports = {
  getAll,
  getById,
  create,
  invitar,
  update,
  toggleEstado,
  remove,
  getHorarios,
  createHorario,
};
