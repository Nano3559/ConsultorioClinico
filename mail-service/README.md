# Servicio de correo (Gmail SMTP + Firebase Admin) — funciones de Vercel

Envía los correos de confirmación / restablecimiento de contraseña con tu
propia plantilla HTML usando tu **cuenta personal de Gmail** (SMTP), generando
el enlace real de reset (`oobCode`) con el Admin SDK.

## 1. Prepara tu Gmail (Contraseña de aplicación)
Tu contraseña normal NO sirve. Necesitas una "Contraseña de aplicación":

1. Entra a https://myaccount.google.com/security
2. Activa **Verificación en dos pasos** (obligatorio).
3. En Seguridad busca **"Contraseñas de aplicación"** → crea una nueva.
4. Copia las **16 letras** que te da (formato `abcd abcd abcd abcd`).

> Gmail tiene un límite de envío (~500 correos/día). Para un consultorio que
> registra pocos médicos al día es más que suficiente. Si más adelante envías
> masivamente (recordatorios SMS/email), pasa a Resend con dominio verificado.

## 2. Desplegar en Vercel
```
cd mail-service
npm install
npm i -g vercel        # si no lo tienes
vercel login
vercel                # sigue las indicaciones (primer deploy)
```

Agrega variables de entorno en Vercel (Settings → Environment Variables),
las mismas que en `.env.example`:
- `GMAIL_USER` = tu correo Gmail
- `GMAIL_APP_PASSWORD` = las 16 letras
- `FIREBASE_SERVICE_ACCOUNT` = contenido completo de `firebase-migrator-key.json`
  (la key ya está en .gitignore, nunca se sube)
- `FROM_EMAIL` (opcional) = `ConsultorioClínico <tu.correo@gmail.com>`

Obtén la URL: `https://tu-proyecto.vercel.app`.

## 3. Conectar la app Flutter
Compila el frontend pasando la URL del servicio y despliega:

```
cd frontend
flutter build web --release --dart-define=MAIL_API_URL=https://tu-proyecto.vercel.app
firebase deploy --only hosting --project consultorioclinico-2026
```

Si `MAIL_API_URL` no está definida, la app usa el correo de Firebase como
respaldo para que el flujo nunca se rompa.

## 4. Endpoints
- `POST /api/send-confirm`  body `{ email, nombre }` → alta de médico / confirmación.
- `POST /api/send-reset`     body `{ email }` → "olvidé mi contraseña" (listo
  para cuando se agregue la pantalla).

## Nota sobre spam
- Gmail a veces marca los envíos automáticos desde Gmail personal hacia otras
  bandejas. Arreglo simple: el **destinatario marka "No es spam"** la primera
  vez (en la app ya avisamos dónde buscar el correo).
- Si el envío va a funcionar de forma seria (muchos usuarios), lo correcto es
  Resend/SendGrid + dominio verificado (SPF/DKIM) — ahora envío el mismo
  servicio solo cambiando `mail.js` a `import { Resend }`, es decir, el
  proveedor es intercambiable.
