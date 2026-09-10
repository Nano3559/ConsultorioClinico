import { initializeApp, cert, getApps, getApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

/// Inicializa Firebase Admin con la cuenta de servicio (variable de entorno).
export function adminAuth() {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!raw) {
    throw new Error(
      'Falta la variable de entorno FIREBASE_SERVICE_ACCOUNT (JSON de la cuenta de servicio).'
    );
  }
  const app = getApps().length
    ? getApp()
    : initializeApp({ credential: cert(JSON.parse(raw)) });
  return getAuth(app);
}
