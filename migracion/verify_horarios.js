const fs = require('fs');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
initializeApp({ credential: cert(JSON.parse(fs.readFileSync('F:/Proyecto PSI/ConsultorioClinico/firebase-migrator-key.json', 'utf8').replace(/^﻿/, ''))) });
const db = getFirestore();
(async () => {
  const snap = await db.collection('horarios').get();
  const por = {};
  snap.forEach(d => {
    const med = d.data().medico_id || '?';
    const dia = d.data().dia_semana || '?';
    por[med] = por[med] || [];
    por[med].push(`${dia} ${d.data().hora_inicio}-${d.data().hora_fin}`);
  });
  console.log('Total horarios:', snap.size);
  for (const [med, arr] of Object.entries(por)) {
    console.log('MEDICO', med, '->', arr.join(', '));
  }
  process.exit(0);
})();
