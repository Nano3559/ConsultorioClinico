const fs = require('fs');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');

const sa = JSON.parse(
  fs.readFileSync('F:/Proyecto PSI/ConsultorioClinico/firebase-migrator-key.json', 'utf8').replace(/^﻿/, '')
);
initializeApp({ credential: cert(sa) });
const db = getFirestore();
const auth = getAuth();

const patientEmail = (ci) => `pac_${ci.replace(/[^a-zA-Z0-9]/g, '')}@clinica.app`;
const patientPassword = (ci, ymd) => `Pac.${ci}.${ymd}`;

function ymdFrom(str) {
  if (!str) return null;
  const d = new Date(str.length === 10 ? str : str);
  if (isNaN(d.getTime())) return null;
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, '0');
  const day = String(d.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

(async () => {
  const snap = await db.collection('pacientes').get();
  let ok = 0;
  let skip = 0;
  for (const doc of snap.docs) {
    const p = doc.data();
    const oldId = doc.id;
    const ci = (p.cedula || p.ci || '').toString().trim();
    const ymd = ymdFrom(p.fecha_nacimiento || p.fechaNacimiento);
    if (!ci || !ymd) {
      console.log('SKIP (sin CI/fecha):', oldId);
      skip++;
      continue;
    }
    const email = patientEmail(ci);
    const password = patientPassword(ci, ymd);

    // Asegurar cuenta Auth (reusar si ya existe).
    let uid;
    try {
      const u = await auth.createUser({ email, password });
      uid = u.uid;
    } catch (e) {
      if (e.code === 'auth/email-already-exists') {
        const list = await auth.getUsers([{ email }]);
        const rec = list.users.find((x) => x.email === email);
        if (!rec) { console.log('ERROR usuario:', email); skip++; continue; }
        uid = rec.uid;
        await auth.updateUser(uid, { password });
      } else {
        console.log('ERROR createUser', email, e.message);
        skip++;
        continue;
      }
    }

    // Documento paciente con id = uid.
    const pacienteData = { ...p, id: uid, uid, cedula: ci, fecha_nacimiento: ymd };
    await db.collection('pacientes').doc(uid).set(pacienteData);

    // Documento usuarios (rol paciente).
    await db.collection('usuarios').doc(uid).set({
      uid,
      nombre: `${(p.nombre || '')} ${(p.apellido || '')}`.trim(),
      email,
      rol: 'paciente',
      perfilTipo: 'paciente',
      perfilId: uid,
      activo: true,
      creadoEn: FieldValue.serverTimestamp(),
    });

    // Reenlazar referencias.
    const batch = db.batch();
    for (const col of ['citas', 'consultas', 'pagos']) {
      const refs = await db.collection(col).where('paciente_id', '==', oldId).get();
      for (const r of refs.docs) {
        batch.update(r.ref, { paciente_id: uid });
      }
    }
    await batch.commit();

    // Eliminar documentos antiguos.
    if (oldId !== uid) {
      await db.collection('pacientes').doc(oldId).delete();
      const oldUser = await db.collection('usuarios').doc(oldId).get();
      if (oldUser.exists) await db.collection('usuarios').doc(oldId).delete();
    }
    ok++;
    console.log(`Paciente ${ok}: ${email} -> ${uid}`);
  }
  console.log(`\nListo. Remapeados: ${ok}, omitidos: ${skip}`);
})();
