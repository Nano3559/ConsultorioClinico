const fs = require('fs');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const sa = JSON.parse(fs.readFileSync('F:/Proyecto PSI/ConsultorioClinico/firebase-migrator-key.json', 'utf8').replace(/^﻿/, ''));
initializeApp({ credential: cert(sa) });
const db = getFirestore();

const GABRIEL = '69aJ7jTcetVLIhb7BK1Xw3EhF9i2';

(async () => {
  await db.collection('medicos').doc(GABRIEL).set(
    {
      titulo: 'Dr.',
      descripcion:
        'Cardiólogo con amplia experiencia en diagnóstico y tratamiento de enfermedades cardiovasculares. Especializado en electrocardiografía, ecocardiografía y prevención de riesgos cardíacos. Atención integral con seguimiento cercano de cada paciente.',
      anios_experiencia: 12,
      telefono: '70023456',
      cedula: '13192658',
      foto_url: 'https://images.unsplash.com/photo-1607462109225-6b64ae2dd3cb?w=400&h=400&fit=crop&q=80',
    },
    { merge: true }
  );
  console.log('Perfil de Gabriel completado.');

  const dias = [
    ['lunes', '08:00', '12:00'],
    ['martes', '14:00', '18:00'],
    ['miercoles', '08:00', '12:00'],
    ['jueves', '14:00', '18:00'],
    ['viernes', '08:00', '12:00'],
  ];
  for (const [dia, ini, fin] of dias) {
    const id = `${GABRIEL}_${dia}`;
    const ref = db.collection('horarios').doc(id);
    await ref.set({ medico_id: GABRIEL, dia_semana: dia, hora_inicio: ini, hora_fin: fin });
  }
  console.log('Horarios de Gabriel creados (Lun-Vie 08-12 / 14-18).');
  process.exit(0);
})();
