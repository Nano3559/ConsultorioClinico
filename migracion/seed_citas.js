const fs = require('fs');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const sa = JSON.parse(fs.readFileSync('F:/Proyecto PSI/ConsultorioClinico/firebase-migrator-key.json', 'utf8').replace(/^﻿/, ''));
initializeApp({ credential: cert(sa) });
const db = getFirestore();

function ymd(d) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

(async () => {
  // medico brayan
  const mSnap = await db.collection('medicos').where('email', '==', 'qbrayanm05@gmail.com').limit(1).get();
  if (mSnap.empty) { console.error('No se encontro el medico brayan'); return; }
  const medicoId = mSnap.docs[0].id;

  // pacientes por CI
  const cis = ['5412789', '8123456'];
  const pacSnap = await db.collection('pacientes').where('cedula', 'in', cis).get();
  const porCi = {};
  pacSnap.forEach(d => { porCi[String(d.data().cedula)] = d.id; });
  console.log('Pacientes encontrados:', porCi);

  const manana = new Date();
  manana.setDate(manana.getDate() + 1);
  const fecha = ymd(manana);

  const citas = [
    { ci: '5412789', hora: '09:00', motivo: 'Control general' },
    { ci: '8123456', hora: '10:30', motivo: 'Dolor de cabeza' },
  ];

  for (const c of citas) {
    const pid = porCi[c.ci];
    if (!pid) { console.log('Paciente', c.ci, 'no encontrado; se omite'); continue; }
    await db.collection('citas').add({
      paciente_id: pid,
      medico_id: medicoId,
      fecha,
      hora: c.hora,
      motivo: c.motivo,
      estado: 'pendiente',
    });
    console.log(`Cita creada: paciente ${c.ci} -> ${fecha} ${c.hora}`);
  }
  console.log('Listo.');
})();
