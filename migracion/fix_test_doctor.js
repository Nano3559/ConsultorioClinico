const fs = require('fs');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const sa = JSON.parse(fs.readFileSync('F:/Proyecto PSI/ConsultorioClinico/firebase-migrator-key.json', 'utf8').replace(/^﻿/, ''));
initializeApp({ credential: cert(sa) });
const db = getFirestore();

(async () => {
  const esp = await db.collection('especialidades').where('nombre', '==', 'Medicina general').limit(1).get();
  if (esp.empty) {
    // probar insensible a mayusculas
    const all = await db.collection('especialidades').get();
    const found = all.docs.find((d) => (d.data().nombre || '').toString().toLowerCase().includes('medicina general'));
    if (!found) { console.error('No se encontro la especialidad Medicina general'); process.exit(1); }
    var espId = found.id; var espName = found.data().nombre;
  } else {
    var espId = esp.docs[0].id; var espName = esp.docs[0].data().nombre;
  }
  console.log('Especialidad:', espName, '=>', espId);

  const m = await db.collection('medicos').where('email', '==', 'qbrayanm05@gmail.com').limit(1).get();
  if (m.empty) { console.error('No se encontro el medico de prueba'); process.exit(1); }
  const doc = m.docs[0];
  await db.collection('medicos').doc(doc.id).update({
    especialidad_id: espId,
    especialidad: espName,
    activo: true,
  });
  console.log('Medico actualizado:', doc.id, '-> especialidad_id', espId);
})().catch((e) => { console.error('ERROR:', e); process.exit(1); });
