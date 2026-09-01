'use strict';

/**
 * Mock del cliente Supabase para tests de integración del login.
 *
 * Simula la API encadenable que usa authController.js:
 *   supabase.from('usuarios').select(...).eq('email', X).limit(1)
 *   supabase.from('usuarios').insert({...}).select().single()
 *   supabase.from('usuarios').update({...}).eq(...)
 *
 * El estado (usuarios en memoria) es reseteable por test. Los hashes de
 * password se generan con bcrypt real para verificar las comparaciones.
 */

const bcrypt = require('bcryptjs');

let USUARIOS = [];
const inserciones = [];

function reset() {
  USUARIOS.length = 0;
  inserciones.length = 0;
}

function getUsuarios() {
  return USUARIOS;
}

function getInserciones() {
  return inserciones;
}

/** Inserta un usuario ya "hasheado" (se asume password ya cifrada). */
function seedUsuario({ id, nombre = 'Usuario', email, password, rol = 'paciente', activo = true }) {
  const u = { id, nombre, email: String(email).trim().toLowerCase(), password, rol, activo };
  USUARIOS.push(u);
  return u;
}

/** Inserta un usuario generando el hash de la contraseña con bcrypt. */
async function seedUsuarioConHash(opts) {
  const passwordHash = await bcrypt.hash(opts.password, 4);
  return seedUsuario({ ...opts, password: passwordHash });
}

/**
 * Construye una cadena fluida para 'usuarios'. El método `.limit()` (que es
 * sobre el que se hace `await`) resuelve la consulta filtrando por el email
 * capturado en `.eq('email', X)`.
 */
function makeUsuariosChain() {
  let emailFiltro = null;
  let limitN = null;
  let seleccionado = null;

  function resolver() {
    let result = USUARIOS;
    if (emailFiltro != null) {
      result = result.filter((u) => u.email === emailFiltro);
    }
    if (limitN != null && typeof limitN === 'number') {
      result = result.slice(0, limitN);
    }
    return { data: result, error: null };
  }

  const base = {
    select: (...cols) => {
      seleccionado = cols;
      return base;
    },
    eq: (campo, valor) => {
      if (campo === 'email') emailFiltro = String(valor).trim().toLowerCase();
      return base;
    },
    limit: (n) => {
      limitN = n;
      return Promise.resolve(resolver());
    },
    // .limit() sobre un mock que resuelve en Promise. También soportamos
    // que el código haga `await ... .limit(1)` (devuelve un then-able).
    then: (resolve, reject) => {
      try {
        return resolve(resolver());
      } catch (e) {
        if (reject) return reject(e);
        throw e;
      }
    },
    single: () => {
      const r = resolver();
      return Promise.resolve({ data: r.data[0] || null, error: r.error });
    },
    update: (valores) => {
      return Promise.resolve({ data: null, error: null });
    },
    order: () => base,
    range: () => Promise.resolve({ data: [], error: null }),
  };

  function resolverInsertUsuarios(valor) {
    const nuevo = { ...valor };
    nuevo.email = String(nuevo.email || '').trim().toLowerCase();
    const duplicado = USUARIOS.some((u) => u.email === nuevo.email);
    if (duplicado) {
      return Promise.resolve({
        data: null,
        error: { code: '23505', message: 'duplicate key value violates unique constraint "usuarios_email_key"' },
      });
    }
    if (!nuevo.id) nuevo.id = USUARIOS.reduce((m, u) => (u.id ? Math.max(m, u.id) : m), 0) + 1;
    USUARIOS.push(nuevo);
    inserciones.push({ tabla: 'usuarios', valor: nuevo });
    return Promise.resolve({ data: [nuevo], error: null });
  }

  // insert() debe permitir encadenamiento insert().select().single()
  base.insert = (valor) => {
    const promesa = resolverInsertUsuarios(valor);
    // Devuelve un objeto que permite .select().single()
    return {
      select: () => ({
        single: async () => {
          const res = await promesa;
          if (res.error) return res;
          return { data: res.data[0], error: null };
        },
        then: (resolve, reject) => promesa.then(resolve, reject),
      }),
      then: (resolve, reject) => promesa.then(resolve, reject),
      single: async () => {
        const res = await promesa;
        return res;
      },
    };
  };

  return base;
}

/** Cadena genérica para tablas no-usuarios (sesiones, intentos_acceso, medicos, pacientes). */
function makeOtherChain(tabla) {
  return {
    select: () => ({
      then: (resolve) => resolve({ data: [], error: null }),
    }),
    eq: () => Promise.resolve({ data: null, error: null }),
    limit: () => Promise.resolve({ data: [], error: null }),
    order: () => Promise.resolve({ data: [], error: null }),
    insert: (valor) => {
      inserciones.push({ tabla, valor });
      return Promise.resolve({ data: [valor], error: null });
    },
    update: () => Promise.resolve({ data: null, error: null }),
    upsert: () => Promise.resolve({ data: null, error: null }),
    single: () => Promise.resolve({ data: null, error: null }),
  };
}

const getSupabase = () => {
  const chain = {
    from(tabla) {
      if (tabla === 'usuarios') return makeUsuariosChain();
      return makeOtherChain(tabla);
    },
  };
  return chain;
};

module.exports = { getSupabase, reset, seedUsuario, seedUsuarioConHash, getUsuarios, getInserciones };
