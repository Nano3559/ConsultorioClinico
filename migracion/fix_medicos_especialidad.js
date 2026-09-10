const fs = require('fs');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const sa = JSON.parse(fs.readFileSync('F:/Proyecto PSI/ConsultorioClinico/firebase-migrator-key.json', 'utf8').replace(/^﻿/, ''));
initializeApp({ credential: cert(sa) });
const db = getFirestore();

(async () => {
  const espSnap = await db.collection('especialidades').get();
  const byName = {};
  espSnap.forEach((d) => { byName[(d.data().nombre || '').toString().toLowerCase()] = d.id; });
  const medSnap = await db.collection('medicos').get();
  let fix = 0;
  for (const doc of medSnap.docs) {
    const m = doc.data();
    if (m.especialidad_id) continue;
    const nombreEsp = (m.especialidad || '').toString().toLowerCase();
    const id = byName[nombreEsp];
    if (id) {
      await db.collection('medicos').doc(doc.id).update({ especialidad_id: id });
      fix++;
      console.log('Set especialidad_id para', doc.id, '->', id);
    } else {
      console.log('SIN MAPA:', doc.id, m.especialidad);
    }
  }
  console.log('Medicos corregidos:', fix);
})().catch((e) => { console.error('ERROR:', e); process.exit(1); });
