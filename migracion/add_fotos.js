const fs = require('fs');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const sa = JSON.parse(fs.readFileSync('F:/Proyecto PSI/ConsultorioClinico/firebase-migrator-key.json', 'utf8').replace(/^﻿/, ''));
initializeApp({ credential: cert(sa) });
const db = getFirestore();

(async () => {
  const mSnap = await db.collection('medicos').where('email', '==', 'qbrayanm05@gmail.com').get();
  for (const d of mSnap.docs) {
    await d.ref.set({ foto_url: 'https://randomuser.me/api/portraits/men/32.jpg' }, { merge: true });
    console.log('foto médico actualizada:', d.id);
  }

  const esSnap = await db.collection('especialidades').get();
  let i = 0;
  for (const d of esSnap.docs) {
    await d.ref.set({ foto_url: `https://picsum.photos/seed/especialidad-${i}/600/360` }, { merge: true });
    console.log('foto especialidad:', d.data().nombre, '->', i);
    i++;
  }
  console.log('Listo.');
  process.exit(0);
})();
