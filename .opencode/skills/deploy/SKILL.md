---
name: deploy
description: Guía de despliegue de ConsultorioClinico: backend Express a Vercel (serverless), frontend web a Firebase Hosting, Cloud Functions, mail-service a Vercel y build/distribución del APK con Firebase App Distribution. Use when deploying, building for production, configuring Vercel/Firebase releases or distributing the APK.
---

# Skill: Despliegue (ConsultorioClínico)

Aplica cuando se despliegue o construya para producción.

## Backend → Vercel
```bash
cd backend
vercel login
vercel          # preview
vercel --prod   # producción
```
- Routing (verificado en los configs, no tocar):
  - Raíz `vercel.json`: rewrite de todo lo que **NO** empieza con `/api/` hacia `/api/index.js`.
  - `backend/vercel.json`: build `@vercel/node` de `api/index.js` con todas las rutas hacia él.
- Variables en Vercel: `JWT_SECRET`, `JWT_EXPIRE`, `CORS_ORIGINS`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, (`SUPABASE_DB_URL` solo para migrar). Plantilla: `backend/.env.example`.
- `CORS_ORIGINS` vacío = navegadores bloqueados (solo server-to-server).

## Frontend web → Firebase Hosting
```bash
cd frontend
flutter build web
firebase deploy --only hosting --project consultorioclinico-2026
```

## Reglas e índices de Firestore
```bash
firebase deploy --only firestore:rules --project consultorioclinico-2026
firebase deploy --only firestore:indexes --project consultorioclinico-2026
```

## Cloud Functions (correo)
```bash
cd frontend/functions && npm install && cd ..
firebase deploy --only functions --project consultorioclinico-2026
```
- Requiere **plan Blaze** (salida a internet).
- Config real (formato en `frontend/functions/index.js`):
```bash
firebase functions:config:set gmail.user="..." gmail.apppassword="..." \
  gmail.from="ConsultorioClínico <...>" reset.url="https://consultorioclinico-2026.web.app/reset"
```
- Endpoints: `POST /sendConfirm` `{ email, nombre }`, `POST /sendReset` `{ email }` (genera `oobCode` real con Admin SDK).

## mail-service → Vercel
```bash
cd mail-service && npm install && vercel
```
Variables: `GMAIL_USER`, `GMAIL_APP_PASSWORD` (16 letras), `FIREBASE_SERVICE_ACCOUNT`, `FROM_EMAIL` (plantilla: `mail-service/.env.example`).
Si `MAIL_API_URL` no se pasa al frontend, la app hace fallback al correo de Firebase.

## APK Android firmado
- Firma release en `frontend/android/app/build.gradle.kts` con `upload-keystore.jks` (alias `upload`) + `key.properties` — **ambos ignorados por git, nunca subir**.
- Build: `flutter build apk` (o `flutter build apk --release --dart-define=MAIL_API_URL=...`).
- Distribución privada: Firebase App Distribution.

## Checklist pre-deploy
1. `flutter analyze` sin warnings · `flutter test` OK.
2. `npm test` (backend) en verde.
3. Migraciones aplicadas si hubo cambio de esquema.
4. `CORS_ORIGINS` incluye el dominio de Firebase Hosting.
