const fs = require('fs');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
initializeApp({ credential: cert(JSON.parse(fs.readFileSync('F:/Proyecto PSI/ConsultorioClinico/firebase-migrator-key.json', 'utf8').replace(/^﻿/, ''))) });
const db = getFirestore();

function shortDay(dia) {
  const map = {
    lunes: 'Lun', martes: 'Mar', miércoles: 'Mié', miercoles: 'Mié',
    jueves: 'Jue', viernes: 'Vie', sábado: 'Sáb', sabado: 'Sáb', domingo: 'Dom',
  };
  return map[String(dia).toLowerCase()] || 'Lun';
}
function expandSlots(ini, fin) {
  const toMin = (t) => { const p = String(t).split(':'); if (p.length < 2) return null; const h = +p[0], mi = +p[1]; if (isNaN(h) || isNaN(mi)) return null; return h * 60 + mi; };
  const a = toMin(ini), b = toMin(fin);
  if (a == null || b == null || b <= a) return [];
  const out = [];
  for (let m = a; m + 30 <= b; m += 30) {
    out.push(String(Math.floor(m / 60)).padStart(2, '0') + ':' + String(m % 60).padStart(2, '0'));
  }
  return out;
}
(async () => {
  const snap = await db.collection('horarios').get();
  const byDoctor = {};
  snap.forEach((d) => {
    const med = d.data().medico_id || '?';
    const dia = shortDay(d.data().dia_semana || '');
    const slots = expandSlots(d.data().hora_inicio || '', d.data().hora_fin || '');
    byDoctor[med] = byDoctor[med] || {};
    byDoctor[med][dia] = [...(byDoctor[med][dia] || []), ...slots];
  });
  const med = await db.collection('medicos').where('email', '==', 'qbrayanm05@gmail.com').get();
  const idBrayan = med.docs[0].id;
  for (const [m, sched] of Object.entries(byDoctor)) {
    const entradas = Object.entries(sched).map(([d, s]) => `${d} ${s[0]}-${s[s.length - 1]}`);
    console.log(m === idBrayan ? 'BRAYAN (medicina general):' : 'OTRO:', entradas.join(' | ') || '(VACIO)');
  }
  process.exit(0);
})();
