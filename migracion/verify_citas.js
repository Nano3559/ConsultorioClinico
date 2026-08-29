const fs = require('fs');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
initializeApp({ credential: cert(JSON.parse(fs.readFileSync('F:/Proyecto PSI/ConsultorioClinico/firebase-migrator-key.json', 'utf8').replace(/^﻿/, ''))) });
const db = getFirestore();
db.collection('citas').get().then(s => {
  console.log('Total citas:', s.size);
  s.forEach(d => console.log(' -', d.data().paciente_id, '|', d.data().fecha, d.data().hora, '|', d.data().estado));
  process.exit(0);
});
