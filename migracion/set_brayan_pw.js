const fs = require('fs');
const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');

const sa = JSON.parse(fs.readFileSync('F:/Proyecto PSI/ConsultorioClinico/firebase-migrator-key.json', 'utf8').replace(/^﻿/, ''));
initializeApp({ credential: cert(sa) });
const adminAuth = getAuth();

const EMAIL = 'qbrayanm05@gmail.com';
const NEW_PASSWORD = 'Medico1234';

(async () => {
  try {
    const u = await adminAuth.getUserByEmail(EMAIL);
    await adminAuth.updateUser(u.uid, { password: NEW_PASSWORD, emailVerified: true });
    console.log('Password de', EMAIL, 'actualizado a', NEW_PASSWORD);
  } catch (e) {
    console.error('Error:', e.message);
  }
})();
