'use strict';

/**
 * Inicialización perezosa de Firebase Admin SDK (solo Auth: verifyIdToken).
 *
 * Lee la service account de FIREBASE_SERVICE_ACCOUNT (JSON completo, igual
 * que mail-service). Si no está configurada, verifyIdToken lanza un error
 * claro y el llamador decide (verifyFlexible responde 401).
 *
 * El require() va dentro de la función para no romper el arranque cuando la
 * dependencia o la credencial no existen (tests, entornos sin Firebase).
 */

let admin = null;
let intentado = false;

function getAdmin() {
  if (admin) return admin;
  const credencial = process.env.FIREBASE_SERVICE_ACCOUNT || '';
  if (!credencial) {
    throw new Error('FIREBASE_SERVICE_ACCOUNT no configurada');
  }
  const sdk = require('firebase-admin');
  let parsed;
  try {
    parsed = JSON.parse(credencial);
  } catch (_err) {
    throw new Error('FIREBASE_SERVICE_ACCOUNT no es un JSON válido');
  }
  if (sdk.apps.length === 0) {
    sdk.initializeApp({ credential: sdk.credential.cert(parsed) });
  }
  admin = sdk;
  return admin;
}

/**
 * Verifica un Firebase ID token (login de la app Flutter) y devuelve su
 * payload decodificado ({ uid, email, ... }).
 */
async function verifyIdToken(token) {
  const sdk = getAdmin();
  return sdk.auth().verifyIdToken(token);
}

module.exports = { getAdmin, verifyIdToken };
