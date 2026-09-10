const fs = require('fs');
const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');
const sa = JSON.parse(fs.readFileSync('F:/Proyecto PSI/ConsultorioClinico/firebase-migrator-key.json', 'utf8').replace(/^﻿/, ''));
initializeApp({ credential: cert(sa) });
const db = getFirestore();
const auth = getAuth();

const staff = [
  { nombre: 'Ana Pérez', email: 'admin@consultorio.com', password: 'Admin1234', rol: 'admin' },
  { nombre: 'Lucía Gómez', email: 'recepcion@consultorio.com', password: 'Recepcion1234', rol: 'recepcion' },
];

(async () => {
  for (const s of staff) {
    let uid;
    try {
      const cu = await auth.createUser({ email: s.email, password: s.password, emailVerified: true });
      uid = cu.uid;
      console.log(`Auth creada: ${s.email}`);
    } catch (e) {
      if (e.errorInfo && e.errorInfo.code === 'auth/email-already-exists') {
        const eu = await auth.getUserByEmail(s.email);
        uid = eu.uid;
        // asegurar password (por si se recrea)
        try { await auth.updateUser(uid, { password: s.password }); } catch (_) {}
        console.log(`Auth ya existia: ${s.email}`);
      } else {
        console.error('Error Auth', s.email, e.errorInfo?.code || e);
        continue;
      }
    }
    await db.collection('usuarios').doc(uid).set({
      uid,
      nombre: s.nombre,
      email: s.email,
      rol: s.rol,
      perfilTipo: null,
      perfilId: null,
      activo: true,
      creadoEn: new Date(),
    });
    console.log(`Usuario '${s.rol}' creado/actualizado: ${s.nombre} (${s.email})`);
  }
  console.log('\nListo. Ambos pueden iniciar sesion con email + contrasena.');
})().catch((e) => { console.error('ERROR:', e); process.exit(1); });
