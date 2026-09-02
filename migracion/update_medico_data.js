const fs = require('fs');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const sa = JSON.parse(fs.readFileSync('F:/Proyecto PSI/ConsultorioClinico/firebase-migrator-key.json', 'utf8').replace(/^﻿/, ''));
initializeApp({ credential: cert(sa) });
const db = getFirestore();

(async () => {
  const mSnap = await db.collection('medicos').where('email', '==', 'qbrayanm05@gmail.com').get();
  for (const d of mSnap.docs) {
    await d.ref.set(
      {
        titulo: 'Dr.',
        descripcion:
          'Médico general con más de 8 años de experiencia en atención integral y preventiva para toda la familia. Especialista en diagnóstico oportuno, seguimiento de enfermedades crónicas y salud ocupacional. Atención cercana y personalizada.',
        anios_experiencia: 8,
        telefono: '70012345',
        email: 'qbrayanm05@gmail.com',
        cedula: '13192657',
      },
      { merge: true }
    );
    console.log('Datos del médico completados:', d.id);
  }
  console.log('Listo.');
  process.exit(0);
})();
