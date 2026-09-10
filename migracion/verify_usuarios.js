const fs = require('fs');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
initializeApp({ credential: cert(JSON.parse(fs.readFileSync('F:/Proyecto PSI/ConsultorioClinico/firebase-migrator-key.json', 'utf8').replace(/^﻿/, ''))) });
const db = getFirestore();
(async () => {
  const snap = await db.collection('usuarios').get();
  console.log('Total usuarios:', snap.size);
  snap.forEach(d => console.log(' -', d.id, '| rol:', d.data().rol, '| email:', d.data().email));
  process.exit(0);
})();
