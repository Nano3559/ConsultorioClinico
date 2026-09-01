const fs = require('fs');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const sa = JSON.parse(
  fs.readFileSync('F:/Proyecto PSI/ConsultorioClinico/firebase-migrator-key.json', 'utf8').replace(/^﻿/, '')
);
initializeApp({ credential: cert(sa) });
const db = getFirestore();

(async () => {
  const s = await db.collection('usuarios').get();
  const by = {};
  s.forEach((d) => {
    const r = d.data().rol || '?';
    (by[r] = by[r] || []).push(d.data().email || d.id);
  });
  console.log('TOTAL usuarios:', s.size);
  for (const [r, e] of Object.entries(by)) {
    console.log('\n[' + r + '] (' + e.length + ')');
    e.forEach((x) => console.log('  - ' + x));
  }
})();
