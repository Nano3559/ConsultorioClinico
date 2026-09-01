# Servicio de correo (Resend + Firebase Admin) — functiones de Vercel

Envía los correos de confirmación / restablecimiento de contraseña con tu
propia plantilla HTML (sin usar el correo genérico de Firebase), generando el
enlace real de reset (`oobCode`) con el Admin SDK.

## 1. Crear cuenta en Resend (gratis, 100/día)
- https://resend.com → crea la cuenta.
- `API Keys` → `Create API Key` → copia la key (`re_...`).
- Para probar el envío usa `noreply@resend.dev` como remitente **solo** si el
  destinatario es tu correo (la cuenta sin dominio solo puede escribir a la
  propia). Para mandar a cualquier correo sin spam: verifica un dominio
  (`Domains`) y usa `no-reply@tudominio.com`.

## 2. Desplegar en Vercel
```
cd mail-service
npm install
npm i -g vercel        # si no lo tienes
vercel login
vercel                # sigue las indicaciones (primer deploy)
```

Una vez desplegado, agrega las variables de entorno en Vercel
(Settings → Environment Variables), las mismas que en `.env.example`:
- `RESEND_API_KEY=re_...`
- `FIREBASE_SERVICE_ACCOUNT` = contenido completo del archivo
  `firebase-migrator-key.json` (mantén la key fuera de git; ya está en .gitignore)
- `FROM_EMAIL=ConsultorioClínico <noreply@resend.dev>` (cámbialo al verificar dominio)

Obtén la URL: `https://tu-proyecto.vercel.app` (puedes fijarla en
Settings → Domains o usar la asignada; puedes cambiar el nombre en re-deploy).

## 3. Conectar la app Flutter
Compila el frontend pasando la URL del servicio y despliega:

```
cd frontend
flutter build web --release --dart-define=MAIL_API_URL=https://tu-proyecto.vercel.app
firebase deploy --only hosting --project consultorioclinico-2026
```

Si `MAIL_API_URL` no está definida, la app **usa el correo de Firebase como
respaldo** para que nunca se rompa el flujo.

## 4. Endpoints
- `POST /api/send-confirm`  body `{ email, nombre }` → alta de médico / confirmación.
- `POST /api/send-reset`     body `{ email }` → "olvidé mi contraseña" (listo
  para cuando se agregue la pantalla).

## Nota sobre spam
El correo que envía un dominio no verificado (resend.dev) puede caer en
Promociones/Spam. Con dominio verificado en Resend + SPF/DKIM configurados
(Resend lo hace automático al verificar), el entregado es excelente.
