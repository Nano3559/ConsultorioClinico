const fs = require('fs');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const sa = JSON.parse(fs.readFileSync('F:/Proyecto PSI/ConsultorioClinico/firebase-migrator-key.json', 'utf8').replace(/^﻿/, ''));
initializeApp({ credential: cert(sa) });
const db = getFirestore();

const dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes'];
const rangos = [
  { ini: '08:00', fin: '12:00' },
  { ini: '14:00', fin: '18:00' },
];

(async () => {
  const med = await db.collection('medicos').get();
  let creados = 0;
  for (const doc of med.docs) {
    const m = doc.data();
    if ((m.activo === false)) continue;
    const exist = await db.collection('horarios').where('medico_id', '==', doc.id).limit(1).get();
    if (!exist.empty) {
      console.log('Ya tiene horarios:', (m.nombre || '') + ' ' + (m.apellido || ''));
      continue;
    }
    for (const d of dias) {
      for (const r of rangos) {
        await db.collection('horarios').add({
          medico_id: doc.id,
          dia_semana: d,
          hora_inicio: r.ini,
          hora_fin: r.fin,
        });
        creados++;
      }
    }
    console.log('Horarios creados para:', (m.nombre || '') + ' ' + (m.apellido || ''));
  }
  console.log('Total horarios creados:', creados);
})().catch((e) => { console.error(e); process.exit(1); });
