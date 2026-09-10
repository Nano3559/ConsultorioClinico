const fs = require('fs');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const sa = JSON.parse(fs.readFileSync('F:/Proyecto PSI/ConsultorioClinico/firebase-migrator-key.json', 'utf8').replace(/^﻿/, ''));
initializeApp({ credential: cert(sa) });
const db = getFirestore();

const fmt = (d) => {
  if (d && d.toDate) d = d.toDate();
  const dt = new Date(d);
  return `${dt.getFullYear()}-${String(dt.getMonth() + 1).padStart(2, '0')}-${String(dt.getDate()).padStart(2, '0')}`;
};

(async () => {
  const snap = await db.collection('citas').get();
  let creados = 0;
  for (const doc of snap.docs) {
    const c = doc.data();
    const estado = (c.estado || '').toString().toLowerCase();
    if (estado === 'cancelada' || estado === 'no_asistio') continue;
    const medico = (c.medico_id || '').toString();
    const fecha = fmt(c.fecha);
    const hora = (c.hora || '').toString();
    if (!medico || !hora) continue;
    const id = `${medico}__${fecha}__${hora}`;
    await db.collection('disponibilidad').doc(id).set({
      medico_id: medico,
      fecha,
      hora,
      cita_id: doc.id,
    }, { merge: true });
    creados++;
  }
  console.log('Turnos ocupados creados:', creados);
})().catch((e) => { console.error('ERROR:', e); process.exit(1); });
