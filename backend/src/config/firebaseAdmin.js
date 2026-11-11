'use strict';

/**
 * Inicialización perezosa de Firebase Admin SDK (solo Auth: verifyIdToken).
 *
 * Lee la service account de FIREBASE_SERVICE_ACCOUNT (JSON completo, igual
 * que mail-service). Si no está configurada, verifyIdToken lanza un error
 * claro y el llamador decide (verifyFlexible responde 401).
 *
 * Usa la API MODULAR de firebase-admin v14+ (initializeApp/getApps de
 * 'firebase-admin/app', getAuth de 'firebase-admin/auth'): la forma vieja
 * admin.apps / admin.auth() ya no existe. Los require() van dentro de las
 * funciones para no romper el arranque cuando la dependencia o la
 * credencial no existen (tests, entornos sin Firebase).
 */

function leerCredencial() {
  const credencial = process.env.FIREBASE_SERVICE_ACCOUNT || '';
  if (!credencial) {
    throw new Error('FIREBASE_SERVICE_ACCOUNT no configurada');
  }
  try {
    return JSON.parse(credencial);
  } catch (_err) {
    throw new Error('FIREBASE_SERVICE_ACCOUNT no es un JSON válido');
  }
}

function getAdmin() {
  const { initializeApp, getApps, cert } = require('firebase-admin/app');
  const existentes = getApps();
  if (existentes.length > 0) return existentes[0];
  return initializeApp({ credential: cert(leerCredencial()) });
}

/**
 * Verifica un Firebase ID token (login de la app Flutter) y devuelve su
 * payload decodificado ({ uid, email, ... }).
 */
async function verifyIdToken(token) {
  const { getAuth } = require('firebase-admin/auth');
  return getAuth(getAdmin()).verifyIdToken(token);
}

module.exports = { getAdmin, verifyIdToken };
