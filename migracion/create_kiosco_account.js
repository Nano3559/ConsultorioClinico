const fs = require('fs');
const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');

const sa = JSON.parse(fs.readFileSync('F:/Proyecto PSI/ConsultorioClinico/firebase-migrator-key.json', 'utf8').replace(/^﻿/, ''));
initializeApp({ credential: cert(sa) });

const EMAIL = 'kiosco@consultorio.com';
// La clave NO se commitea: pásala por variable de entorno.
// Ej: $env:KIOSK_PASSWORD='...'; node create_kiosco_account.js
const PASSWORD = process.env.KIOSK_PASSWORD || '';
if (!PASSWORD) {
  console.error('Falta KIOSK_PASSWORD en el entorno.');
  process.exit(1);
}

(async () => {
  const auth = getAuth();
  const db = getFirestore();
  let uid;
  try {
    const u = await auth.createUser({ email: EMAIL, password: PASSWORD, emailVerified: true, displayName: 'Kiosco Recepción' });
    uid = u.uid;
    console.log('Cuenta kiosco creada:', uid);
  } catch (e) {
    if (e.code === 'auth/email-already-exists') {
      const u = await auth.getUserByEmail(EMAIL);
      uid = u.uid;
      await auth.updateUser(uid, { password: PASSWORD });
      console.log('Cuenta kiosco ya existía, clave actualizada:', uid);
    } else {
      throw e;
    }
  }
  await db.collection('usuarios').doc(uid).set({
    uid,
    nombre: 'Kiosco Recepción',
    email: EMAIL,
    rol: 'recepcion',
    perfilTipo: 'recepcion',
    perfilId: uid,
    activo: true,
  });
  console.log('Rol recepcion asignado. Listo.');
  process.exit(0);
})();
