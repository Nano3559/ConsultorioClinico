const fs = require('fs');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');

const sa = JSON.parse(
  fs.readFileSync('F:/Proyecto PSI/ConsultorioClinico/firebase-migrator-key.json', 'utf8').replace(/^﻿/, '')
);
initializeApp({ credential: cert(sa) });
const db = getFirestore();
const auth = getAuth();

const REC_PASS = 'Recepcion123!';
const PAC_PASS = 'Paciente123!';

async function createAuthUser(email, password, displayName) {
  try {
    const u = await auth.createUser({ email, password, displayName });
    return u.uid;
  } catch (e) {
    if (e.code === 'auth/email-already-exists') {
      const list = await auth.getUsers([{ email }]);
      const rec = list.users.find((x) => x.email === email);
      if (rec) return rec.uid;
    }
    throw e;
  }
}

(async () => {
  // Recepcionista
  const recEmail = 'recepcion@clinica.com';
  const recUid = await createAuthUser(recEmail, REC_PASS, 'Recepcionista');
  await db.collection('usuarios').doc(recUid).set({
    uid: recUid,
    nombre: 'Recepcionista',
    email: recEmail,
    rol: 'recepcion',
    perfilTipo: 'recepcion',
    perfilId: null,
    activo: true,
    creadoEn: new Date().toISOString(),
  });
  console.log('Recepcionista ->', recEmail, '|', recUid);

  // Pacientes con citas (top 3)
  const pacs = await db.collection('pacientes').get();
  const citas = await db.collection('citas').get();
  const countByPac = {};
  citas.forEach((c) => {
    const pid = c.data().paciente_id;
    countByPac[pid] = (countByPac[pid] || 0) + 1;
  });

  const list = pacs.docs
    .map((d) => ({ id: d.id, data: d.data(), n: countByPac[d.id] || 0 }))
    .filter((x) => x.n > 0)
    .sort((a, b) => b.n - a.n)
    .slice(0, 3);

  if (list.length === 0) {
    console.log('No hay pacientes con citas para enlazar.');
  }

  for (const p of list) {
    const nombre = `${p.data.nombre || ''} ${p.data.apellido || ''}`.trim();
    const ced = p.data.cedula || p.id;
    const email =
      p.data.email && /@/.test(p.data.email)
        ? p.data.email
        : `paciente.${ced}@clinica.com`.toLowerCase();
    let uid;
    try {
      uid = await createAuthUser(email, PAC_PASS, nombre);
    } catch (e) {
      console.log('  SKIP', email, e.message);
      continue;
    }
    await db.collection('usuarios').doc(uid).set({
      uid,
      nombre,
      email,
      rol: 'paciente',
      perfilTipo: 'paciente',
      perfilId: p.id,
      activo: true,
      creadoEn: new Date().toISOString(),
    });
    console.log(`Paciente -> ${email} | paciente ${p.id} | citas ${p.n}`);
  }
  console.log('DONE');
})();
