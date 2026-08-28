const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const sa = JSON.parse(fs.readFileSync(path.resolve(__dirname, '..', 'firebase-migrator-key.json'), 'utf8').replace(/^﻿/, ''));
admin.initializeApp({ credential: admin.credential.cert(sa), projectId: 'consultorioclinico-2026' });
const db = admin.firestore();
const COLS = ['especialidades', 'medicos', 'pacientes', 'horarios', 'citas', 'consultas', 'pagos', 'usuarios'];
(async () => {
  for (const c of COLS) {
    const n = (await db.collection(c).get()).size;
    console.log(`${c}: ${n}`);
  }
  const m = await db.collection('medicos').limit(2).get();
  m.forEach((d) => console.log('MEDICO sample:', JSON.stringify(d.data())));
  const ci = await db.collection('citas').limit(2).get();
  ci.forEach((d) => console.log('CITA sample:', JSON.stringify(d.data())));
  process.exit(0);
})().catch((e) => { console.error(e); process.exit(1); });
