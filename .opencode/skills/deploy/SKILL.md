---
name: deploy
description: Guía de despliegue de ConsultorioClinico: backend Express a Vercel (serverless), frontend web a Firebase Hosting, Cloud Functions, mail-service a Vercel y build/distribución del APK con Firebase App Distribution. Use when deploying, building for production, configuring Vercel/Firebase releases or distributing the APK.
---

# Skill: Despliegue (ConsultorioClínico)

Aplica cuando se despliegue o construya para producción.

## Backend → Vercel
**Siempre desde la RAÍZ del repo.** El proyecto `consultorio-clinico` tiene
Root Directory = `backend`, y el link de Vercel que manda es el de la raíz
(`.vercel/project.json` → `consultorio-clinico`). Correr `vercel` desde
`backend/` despliega al proyecto equivocado.
```bash
vercel login
git pull origin main            # main debe estar actualizado (solo main es desplegable)
vercel deploy --dry             # revisar framework + archivos antes de subir
vercel --prod                   # producción
```
- Routing (verificado en los configs, no tocar):
  - Con Root Directory = `backend` manda `backend/vercel.json`: build
    `@vercel/node` de `backend/api/index.js` y todas las rutas hacia él.
  - El `vercel.json` de la raíz solo aplica si Root Directory quedara vacío, y
    ahí su rewrite apunta a `/api/index.js` (que existe en la raíz y delega a
    `backend/src/app`). Con Root Directory vacío el build usa el
    `package.json` de la raíz, no el de `backend/`.
- Si aparece `med-core2/backend` en `vercel env ls` o `vercel ls`, estás en el
  directorio equivocado: sal de `backend/` y relanza desde la raíz.
- Variables en Vercel (solo Production): `NODE_ENV=production`, `JWT_SECRET`,
  `JWT_EXPIRE`, `CORS_ORIGINS`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
  `SUPABASE_SERVICE_ROLE_KEY`, `VISION_ENABLED`,
  `KIOSCO_VERIFICATION_WINDOW_MIN` / `KIOSCO_VERIFY_RATE_MAX` /
  `KIOSCO_CONFIRM_RATE_MAX`. Plantilla: `backend/.env.example`.
  - **No** setear `PORT` (lo maneja Vercel).
  - `CORS_ORIGINS` vacío = navegadores bloqueados (solo server-to-server).
  - `VISION_ENABLED=false` mientras el microservicio Python no exista: el
    kiosco deriva a recepción con 503 controlado en vez de 502.
- Verificación post-deploy (esperados: 200 / 422 / 401 / 401 / 401):
  ```bash
  B=https://consultorio-clinico.vercel.app
  curl -s -o /dev/null -w "%{http_code}\n" $B/api/health
  curl -s -o /dev/null -w "%{http_code}\n" -X POST -H "Content-Type: application/json" -d '{}' $B/api/kiosco/verificar-rostro
  curl -s -o /dev/null -w "%{http_code}\n" $B/api/kiosco/intentos
  curl -s -o /dev/null -w "%{http_code}\n" -X POST -H "Content-Type: application/json" -d '{}' $B/api/vision/registrar-rostro/1
  curl -s -o /dev/null -w "%{http_code}\n" $B/api/vision/rostro/1
  ```
  Un 500 en vez de 401/422 apunta a migraciones `011_kiosco_facial.sql` /
  `012_kiosco_seguridad.sql` sin aplicar en producción.


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
