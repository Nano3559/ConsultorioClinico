#!/usr/bin/env node
// ============================================================================
// SEED DE CUENTAS DEMO PARA FIREBASE
// ----------------------------------------------------------------------------
// Crea los usuarios de demostración (AUTH + perfil en FIRESTORE) para que el
// login del frontend (Flutter) funcione de verdad al pulsar los chips de
// "Acceso rápido" de la pantalla de login.
//
// Las cuentas coinciden con `_demoAccounts` en
//   lib/features/public/login_page.dart
//
// USO:
//   1) Genera una clave de cuenta de servicio (service account) en Firebase:
//        Project settings (consultorioclinico-2026) > Service accounts >
//        "Generate new private key"  -> te descarga un JSON.
//   2) Guarda ese JSON como  scripts/service-account.json  (NO lo subas al repo)
//   3) Instala la dependencia y ejecuta:
//        cd frontend/scripts
//        npm install firebase-admin
//        set GOOGLE_APPLICATION_CREDENTIALS=.\\service-account.json   (PowerShell)
//        node seed_firebase.mjs
//
// El script es IDEMPOTENTE: si una cuenta ya existe, la actualiza (rol/perfil)
// sin fallar.
// ============================================================================

import { readFileSync, existsSync } from 'node:fs';
import { initializeApp, cert, deleteApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

const PROJECT_ID = 'consultorioclinico-2026';

// Cuentas demo (deben coincidir con login_page.dart). Rol interno del sistema.
const CUENTAS = [
  { email: 'admin@consultorio.com',   password: 'admin123',     rol: 'admin',     perfilTipo: null },
  { email: 'carlos@consultorio.com',  password: 'medico123',    rol: 'medico',    perfilTipo: 'medico' },
  { email: 'maria@consultorio.com',   password: 'recepcion123', rol: 'recepcion', perfilTipo: null },
  { email: 'pedro@gmail.com',         password: 'paciente123',  rol: 'paciente',  perfilTipo: 'paciente' },
];

const localServiceFile = new URL('./service-account.json', import.meta.url).pathname;

function cargarCredencial() {
  const envPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const ruta = envPath || (existsSync(localServiceFile) ? localServiceFile : null);

  if (!ruta) {
    console.error(
      'FALTA la clave de servicio.\n' +
        'Descarga el JSON de "Service accounts" en Firebase y guárdalo como ' +
        'scripts/service-account.json, o define GOOGLE_APPLICATION_CREDENTIALS.'
    );
    process.exit(1);
  }

  try {
    return cert(JSON.parse(readFileSync(ruta, 'utf8')));
  } catch (e) {
    console.error(`No se pudo leer la clave de servicio en ${ruta}:`, e.message);
    process.exit(1);
  }
}

const nombreCorto = (email) =>
  email.split('@')[0].replace(/[^a-zA-ZÀ-ÿ ]/g, ' ').trim();

async function main() {
  const app = initializeApp({ credential: cargarCredencial(), projectId: PROJECT_ID });
  const auth = getAuth(app);
  const db = getFirestore(app);

  console.log(`Sembrando cuentas demo en ${PROJECT_ID}...\n`);

  for (const cuenta of CUENTAS) {
    let userRecord = null;

    // 1) Auth: obtener o crear el usuario
    try {
      userRecord = await auth.getUserByEmail(cuenta.email);
      console.log(`• ${cuenta.email} ya existía en Auth.`);
    } catch (e) {
      if (e.code !== 'auth/user-not-found') throw e;
      userRecord = await auth.createUser({
        email: cuenta.email,
        password: cuenta.password,
        emailVerified: false,
      });
      console.log(`• ${cuenta.email} creado en Auth (uid ${userRecord.uid}).`);
    }

    const uid = userRecord.uid;

    // 2) Firestore: asegurar perfil en 'usuarios/[uid]'
    const usuarioDoc = {
      uid,
      nombre: nombreCorto(cuenta.email),
      email: cuenta.email,
      rol: cuenta.rol,
      perfilTipo: cuenta.perfilTipo,
      perfilId: null,
      activo: true,
      creadoEn: new Date(),
    };

    // Perfil asociado según el rol
    if (cuenta.perfilTipo === 'medico') {
      const medicoRef = db.collection('medicos').doc(uid);
      const medicoExistente = await medicoRef.get();
      if (!medicoExistente.exists) {
        await medicoRef.set({
          nombre: (nombreCorto(cuenta.email).split(' ')[0] || 'Carlos').replace(/[^a-zA-ZÀ-ÿ]/g, ''),
          apellido: 'Medico',
          cedula: `M_DEMO_${uid.slice(0, 6)}`,
          especialidad: 'Medicina General',
          email: cuenta.email,
          activo: true,
          uid,
        });
      }
      usuarioDoc.perfilId = uid;
    } else if (cuenta.perfilTipo === 'paciente') {
      const pacienteRef = db.collection('pacientes').doc(uid);
      const pacienteExistente = await pacienteRef.get();
      if (!pacienteExistente.exists) {
        await pacienteRef.set({
          nombre: (nombreCorto(cuenta.email).split(' ')[0] || 'Pedro').replace(/[^a-zA-ZÀ-ÿ]/g, ''),
          apellido: 'Paciente',
          cedula: '',
          telefono: '',
          email: cuenta.email,
          uid,
          activo: true,
          creadoEn: new Date(),
        });
      }
      usuarioDoc.perfilId = uid;
    }

    await db.collection('usuarios').doc(uid).set(usuarioDoc, { merge: true });
    console.log(`  ✓ Perfil en Firestore (rol=${cuenta.rol}).`);
  }

  console.log('\n¡Listo! Las cuentas demo ya pueden iniciar sesión en /login.');
  await deleteApp(app);
}

main().catch((e) => {
  console.error('Error de seed:', e);
  process.exit(1);
});
