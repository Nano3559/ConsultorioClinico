const fs = require('fs');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const sa = JSON.parse(fs.readFileSync('F:/Proyecto PSI/ConsultorioClinico/firebase-migrator-key.json', 'utf8').replace(/^﻿/, ''));
initializeApp({ credential: cert(sa) });
const db = getFirestore();

const unsplash = (id, w, h) => `https://images.unsplash.com/${id}?w=${w}&h=${h}&fit=crop&q=80`;

// Fotografías médicas de prueba (fotógrafos/plantillas Unsplash, estable y libre).
const MEDICO_FOTO = unsplash('photo-1612349317150-e413f6a5b16d', 400, 400); // médico con bata
const ESPECIALIDADES_FOTO = {
  'dermatologia': unsplash('photo-1570172619644-dfd03ed5d881', 600, 360),
  'cardiologia': unsplash('photo-1537368910025-700350fe46c7', 600, 360),
  'odontologia': unsplash('photo-1606811841689-23dfddce3e95', 600, 360),
  'ginecologia': unsplash('photo-1559839734-2b71ea197ec2', 600, 360),
  'pediatria': unsplash('photo-1584515933487-779824d29309', 600, 360),
  'medicina general': unsplash('photo-1576091160399-112ba8d25d1d', 600, 360),
};

(async () => {
  const mSnap = await db.collection('medicos').where('email', '==', 'qbrayanm05@gmail.com').get();
  for (const d of mSnap.docs) {
    await d.ref.set({ foto_url: MEDICO_FOTO }, { merge: true });
    console.log('foto médico actualizada:', d.id);
  }

  const esSnap = await db.collection('especialidades').get();
  for (const d of esSnap.docs) {
    const key = (d.data().nombre || '')
      .toLowerCase()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '');
    const url = ESPECIALIDADES_FOTO[key];
    if (url) {
      await d.ref.set({ foto_url: url }, { merge: true });
      console.log('foto especialidad:', d.data().nombre);
    } else {
      console.log('sin foto mapeada para:', d.data().nombre);
    }
  }
  console.log('Listo.');
  process.exit(0);
})();
