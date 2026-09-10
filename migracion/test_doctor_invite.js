const fs = require('fs');
const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');
const { initializeApp: fbInit } = require('firebase/app');
const { getAuth: fbGetAuth, sendPasswordResetEmail } = require('firebase/auth');

const sa = JSON.parse(fs.readFileSync('F:/Proyecto PSI/ConsultorioClinico/firebase-migrator-key.json', 'utf8').replace(/^﻿/, ''));
initializeApp({ credential: cert(sa) });
const adminAuth = getAuth();
const db = getFirestore();

const webConfig = {
  apiKey: 'AIzaSyC4LkmBEK4RozuqL374WsvB6dqyWZbtmgg',
  authDomain: 'consultorioclinico-2026.firebaseapp.com',
  projectId: 'consultorioclinico-2026',
  appId: '1:279633708085:web:3ee31312b71562134f9d7c',
};
fbInit(webConfig);
const clientAuth = fbGetAuth();

(async () => {
  const email = 'qbrayanm05@gmail.com';
  const nombre = 'brayan';
  const apellido = 'terceros coca';
  const ci = '13192657';
  const especialidad = 'medicina general';
  const temp = 'Temp' + Date.now();

  let uid;
  try {
    const u = await adminAuth.createUser({ email, password: temp, emailVerified: false });
    uid = u.uid;
    console.log('Usuario Auth creado:', uid);
  } catch (e) {
    if (e.code === 'auth/email-already-exists') {
      const u = await adminAuth.getUserByEmail(email);
      uid = u.uid;
      console.log('Usuario Auth ya existe:', uid);
    } else {
      throw e;
    }
  }

  await db.collection('medicos').doc(uid).set({
    id: uid, uid, nombre, apellido, cedula: ci, email,
    especialidad: especialidad, telefono: '', activo: true,
  }, { merge: true });
  await db.collection('usuarios').doc(uid).set({
    uid, nombre: (nombre + ' ' + apellido).trim(), email, rol: 'medico',
    perfilTipo: 'medico', perfilId: uid, activo: true, creadoEn: new Date(),
  }, { merge: true });
  console.log('Docs medicos/usuarios creados (activo=true)');

  await sendPasswordResetEmail(clientAuth, email, {
    url: 'https://consultorioclinico-2026.web.app/reset',
    handleCodeInApp: true,
    iOSBundleId: 'com.example.consultorioClinico',
    androidPackageName: 'com.example.consultorioClinico',
    androidInstallApp: false,
  });
  console.log('Correo de invitacion enviado a', email);
  console.log('El medico debe abrir el link y fijar su contrasena en /reset');
  console.log('Luego entra en login (pestana Personal) con', email, 'y su nueva clave.');
})().catch((e) => { console.error('ERROR:', e); process.exit(1); });
