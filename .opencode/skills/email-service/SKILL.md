---
name: email-service
description: Guía del envío de correos de ConsultorioClinico: mail-service propio en Vercel (Gmail SMTP + plantillas HTML) y Firebase Cloud Functions alternativas; endpoints send-confirm y send-reset. Use when editing mail-service/, frontend/functions/, email templates, Gmail SMTP config or password-reset/confirmation flows.
---

# Skill: Servicio de correo (ConsultorioClínico)

Aplica cuando la tarea toque correos: `mail-service/` o `frontend/functions/`.

## Dos implementaciones equivalentes
1. **mail-service (preferida)** — Vercel + Gmail SMTP:
   - `mail-service/api/send-confirm.js` → `POST /api/send-confirm` con `{ email, nombre }` — invitación/alta de médico.
   - `mail-service/api/send-reset.js` → `POST /api/send-reset` con `{ email }` — restablecimiento de contraseña.
   - `api/_lib/mail.js` — plantillas HTML (mantener estilos inline y responsivo).
   - `api/_lib/firebase.js` — Firebase Admin SDK.
2. **Firebase Cloud Functions** — `frontend/functions/index.js` con nodemailer (`smtp.gmail.com:587`).

## Reglas al modificar
- Variables de entorno del mail-service: `GMAIL_USER`, `GMAIL_APP_PASSWORD` (App Password de 16 letras, no la contraseña normal), `FIREBASE_SERVICE_ACCOUNT` (contenido JSON del service account), `FROM_EMAIL` (opcional).
- Nunca loguear contraseñas, tokens ni el service account. Nunca subir `firebase-migrator-key.json` (está en .gitignore).
- Respuestas JSON consistentes: `{ ok: true }` / `{ error: "..." }` con códigos HTTP correctos.
- Conexión con la app Flutter: `flutter build web --release --dart-define=MAIL_API_URL=https://...`.
- Si cambias una plantilla, prueba con un correo real en preview antes de desplegar.
- Documentación detallada: `mail-service/README.md`.
