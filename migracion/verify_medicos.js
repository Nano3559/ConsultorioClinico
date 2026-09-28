const fs = require('fs');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
initializeApp({ credential: cert(JSON.parse(fs.readFileSync('F:/Proyecto PSI/ConsultorioClinico/firebase-migrator-key.json', 'utf8').replace(/^﻿/, ''))) });
const db = getFirestore();
(async () => {
  const snap = await db.collection('medicos').get();
  console.log('Total medicos:', snap.size);
  for (const d of snap.docs) {
    const x = d.data();
    console.log(' -', d.id, '|', x.nombre, x.apellido || '', '| esp:', x.especialidad_id || x.especialidad || '',
      '| activo:', x.activo, '| email:', x.email || '', '| anios:', x.anios_experiencia || 0,
      '| desc:', (x.descripcion || '').slice(0, 60));
  }
  const es = await db.collection('especialidades').get();
  const esp = {};
  es.forEach(d => { esp[d.id] = d.data().nombre; });
  console.log('Especialidades:', esp);
  process.exit(0);
})();
