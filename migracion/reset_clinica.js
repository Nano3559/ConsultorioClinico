const fs = require('fs');
const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');
const sa = JSON.parse(fs.readFileSync('F:/Proyecto PSI/ConsultorioClinico/firebase-migrator-key.json', 'utf8').replace(/^﻿/, ''));
initializeApp({ credential: cert(sa) });
const db = getFirestore();
const auth = getAuth();

const KEEP_EMAIL = 'qbrayanm05@gmail.com'; // unico medico a conservar

async function clearColl(name) {
  const snap = await db.collection(name).get();
  console.log(`Borrando ${snap.size} docs de '${name}'...`);
  for (const d of snap.docs) await d.ref.delete();
}

function patientEmail(ci) {
  return 'pac_' + ci.replace(/[^a-zA-Z0-9]/g, '') + '@clinica.app';
}
function patientPassword(ci, ymd) {
  return `Pac.${ci}.${ymd}`;
}

(async () => {
  // 1) Borrar todas las colecciones
  for (const c of ['citas', 'consultas', 'pagos', 'horarios', 'disponibilidad', 'pacientes', 'medicos', 'usuarios', 'especialidades']) {
    await clearColl(c);
  }

  // 2) Borrar todas las cuentas Auth excepto brayan
  const list = await auth.listUsers();
  for (const u of list.users) {
    if (u.email !== KEEP_EMAIL) {
      try { await auth.deleteUser(u.uid); } catch (e) { /* ya no existe */ }
    }
  }
  console.log('Auth: se conservo solo', KEEP_EMAIL);

  // 3) Especialidades (brayan apuntara a Medicina General)
  const especialidades = ['Medicina General', 'Cardiología', 'Pediatría', 'Ginecología', 'Dermatología', 'Odontología'];
  const espIds = {};
  for (const nombre of especialidades) {
    const ref = await db.collection('especialidades').add({ nombre });
    espIds[nombre] = ref.id;
  }
  console.log('Especialidades creadas. Medicina General id =', espIds['Medicina General']);

  // 4) Recrear brayan (medico + usuarios), conservando su Auth uid
  const brayanAuth = await auth.getUserByEmail(KEEP_EMAIL);
  const bUid = brayanAuth.uid;
  await db.collection('medicos').doc(bUid).set({
    id: bUid,
    uid: bUid,
    nombre: 'brayan',
    apellido: 'terceros coca',
    cedula: '13192657',
    email: KEEP_EMAIL,
    especialidad_id: espIds['Medicina General'],
    telefono: '',
    activo: true,
  });
  await db.collection('usuarios').doc(bUid).set({
    uid: bUid,
    nombre: 'brayan terceros coca',
    email: KEEP_EMAIL,
    rol: 'medico',
    perfilTipo: 'medico',
    perfilId: bUid,
    activo: true,
    creadoEn: new Date(),
  });
  console.log('Medico brayan recreado:', bUid, '-> Medicina General');

  // 5) Horarios de brayan (Lun-Vie 08-12 / 14-18)
  const dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes'];
  const rangos = [{ ini: '08:00', fin: '12:00' }, { ini: '14:00', fin: '18:00' }];
  for (const d of dias) for (const r of rangos) {
    await db.collection('horarios').add({ medico_id: bUid, dia_semana: d, hora_inicio: r.ini, hora_fin: r.fin });
  }

  // 6) 3 pacientes ficticios (Auth + usuarios + pacientes)
  const pacientes = [
    { ci: '5412789', ymd: '1992-03-15', nombre: 'Laura', apellido: 'Torres', tel: '0981 111 222' },
    { ci: '8123456', ymd: '1988-07-22', nombre: 'Diego', apellido: 'Ramírez', tel: '0982 333 444' },
    { ci: '6234598', ymd: '2001-11-05', nombre: 'Sofía', apellido: 'Castro', tel: '0983 555 666' },
  ];
  for (const p of pacientes) {
    const email = patientEmail(p.ci);
    const password = patientPassword(p.ci, p.ymd);
    let uid;
    try {
      const cu = await auth.createUser({ email, password, emailVerified: false });
      uid = cu.uid;
    } catch (e) {
      const eu = await auth.getUserByEmail(email);
      uid = eu.uid;
    }
    await db.collection('pacientes').doc(uid).set({
      id: uid,
      uid: uid,
      nombre: p.nombre,
      apellido: p.apellido,
      cedula: p.ci,
      fecha_nacimiento: p.ymd,
      email: email,
      telefono: p.tel,
    });
    await db.collection('usuarios').doc(uid).set({
      uid: uid,
      nombre: `${p.nombre} ${p.apellido}`,
      email: email,
      rol: 'paciente',
      perfilTipo: 'paciente',
      perfilId: uid,
      activo: true,
      creadoEn: new Date(),
    });
    console.log(`Paciente ${p.nombre} ${p.apellido} | CI ${p.ci} | nac ${p.ymd} | login: CI + ${p.ymd} | email ${email}`);
  }

  console.log('\nRESET COMPLETO. Solo queda brayan (Medico General) + 3 pacientes.');
})().catch((e) => { console.error('ERROR:', e); process.exit(1); });
