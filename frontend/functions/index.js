/**
 * Servicio de correo de ConsultorioClínico.
 *
 * Cloud Functions (necesita plan Blaze para salida a internet):
 *  - POST /sendConfirm { email, nombre }  -> correo de alta/confirmación
 *  - POST /sendReset   { email }          -> correo de restablecer contraseña
 *
 * Genera el enlace de reset REAL (oobCode) con el Admin SDK y lo envía con
 * nodemailer vía SMTP Gmail usando una "Contraseña de aplicación" (NO tu
 * contraseña normal). El correo usa la plantilla HTML de la app.
 *
 * Configuración (se puede ejecutar con firebase CLI):
 *   firebase functions:config:set \
 *     gmail.user="brayanterceros@gmail.com" \
 *     gmail.apppassword="xxxxxxxxxxxxxxxx" \
 *     gmail.from="ConsultorioClínico <brayanterceros@gmail.com>" \
 *     reset.url="https://consultorioclinico-2026.web.app/reset"
 */
const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

const RESET_URL =
  (functions.config().reset && functions.config().reset.url) ||
  'https://consultorioclinico-2026.web.app/reset';
const GMAIL_USER = functions.config().gmail && functions.config().gmail.user;
const GMAIL_APP_PASSWORD =
  functions.config().gmail && functions.config().gmail.apppassword;
const FROM_EMAIL =
  (functions.config().gmail && functions.config().gmail.from) ||
  `ConsultorioClínico <${GMAIL_USER || ''}>`;

function transporter() {
  return nodemailer.createTransport({
    host: 'smtp.gmail.com',
    port: 587,
    secure: false,
    requireTLS: true,
    tls: { minVersion: 'TLSv1.2' },
    auth: { user: GMAIL_USER, pass: GMAIL_APP_PASSWORD },
    connectionTimeout: 20000,
    greetingTimeout: 20000,
    socketTimeout: 30000,
  });
}

function mailFn(handler) {
  return functions.runWith({ timeoutSeconds: 240, memory: '256MB' }).https.onRequest(handler);
}

function shell({ title, body, link, buttonText, footerEmail }) {
  return `
  <div style="background:#f0fdfa;padding:32px 16px;font-family:Arial,Helvetica,sans-serif">
    <div style="max-width:560px;margin:auto;background:#ffffff;border-radius:18px;overflow:hidden;border:1px solid #e2e8f0">
      <div style="background:linear-gradient(135deg,#14b8a6,#0f766e);padding:26px;color:#ffffff;text-align:center">
        <div style="font-size:34px">🏥</div>
        <h1 style="margin:6px 0 0;font-size:22px">ConsultorioClínico</h1>
        <p style="margin:6px 0 0;opacity:.9;font-size:14px">Sistema de gestión médica</p>
      </div>
      <div style="padding:28px">
        ${body}
        <a href="${link}" style="display:block;margin:24px 0 0;padding:14px;background:linear-gradient(135deg,#14b8a6,#0f766e);color:#ffffff;text-decoration:none;border-radius:12px;text-align:center;font-weight:bold;font-size:15px">${buttonText}</a>
        <p style="margin-top:18px;font-size:12px;color:#94a3b8;line-height:1.6">Si el botón no funciona, copia y pega este enlace en tu navegador:<br>
        <a href="${link}" style="color:#0d9488;word-break:break-all">${link}</a></p>
      </div>
      <div style="background:#f8fafc;padding:14px;text-align:center;font-size:12px;color:#64748b">
        ConsultorioClínico · ${footerEmail}
      </div>
    </div>
  </div>`;
}

function confirmHtml({ nombre, email, link }) {
  const body = `
    <h2 style="margin:0 0 12px;color:#0f172a">¡Hola, ${nombre}!</h2>
    <p style="color:#475569;line-height:1.6;margin:0">
      Bienvenido/a a <b>ConsultorioClínico</b>. Tu cuenta ha sido creada y solo
      falta un paso: <b>crear tu propia contraseña</b> para poder ingresar al
      sistema.
    </p>`;
  return shell({ body, link, buttonText: 'Crear mi contraseña', footerEmail: email });
}

function resetHtml({ email, link }) {
  const body = `
    <h2 style="margin:0 0 12px;color:#0f172a">Restablece tu contraseña</h2>
    <p style="color:#475569;line-height:1.6;margin:0">
      Recibimos una solicitud para restablecer la contraseña de tu cuenta.
      Si no la hiciste tú, ignora este correo. De lo contrario, pulsa el botón
      para crear una nueva contraseña.
    </p>`;
  return shell({ body, link, buttonText: 'Restablecer contraseña', footerEmail: email });
}

function cors(res) {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
}

/** Envía un correo de confirmación (alta de médico / cuenta). */
exports.sendConfirm = mailFn(async (req, res) => {
  cors(res);
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Usa POST' });
  if (!GMAIL_USER || !GMAIL_APP_PASSWORD) {
    return res
      .status(500)
      .json({ error: 'Configura gmail.user y gmail.apppassword (función)' });
  }
  try {
    const body = req.body || {};
    if (body.ping) return res.json({ pong: true });
    const email = String(body.email || '').trim();
    const nombre = String(body.nombre || 'Colega').trim();
    if (!email) return res.status(400).json({ error: 'email requerido' });
    console.log('[sendConfirm] generando enlace para', email);
    const link = await admin.auth().generatePasswordResetLink(email, {
      url: RESET_URL,
      handleCodeInApp: false,
    });
    console.log('[sendConfirm] enlace generado, enviando correo...');
    await transporter().sendMail({
      from: FROM_EMAIL,
      to: email,
      subject: `Confirma tu cuenta en ConsultorioClínico · ${nombre}`,
      html: confirmHtml({ nombre, email, link }),
    });
    console.log('[sendConfirm] correo enviado OK');
    return res.json({ ok: true });
  } catch (e) {
    console.error('sendConfirm error:', (e && e.message) || e);
    return res.status(500).json({ error: String((e && e.message) || e) });
  }
});

/** Envía un correo de "restablecer contraseña". */
exports.sendReset = mailFn(async (req, res) => {
  cors(res);
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Usa POST' });
  if (!GMAIL_USER || !GMAIL_APP_PASSWORD) {
    return res
      .status(500)
      .json({ error: 'Configura gmail.user y gmail.apppassword (función)' });
  }
  try {
    const body = req.body || {};
    const email = String(body.email || '').trim();
    if (!email) return res.status(400).json({ error: 'email requerido' });
    console.log('[sendReset] generando enlace para', email);
    const link = await admin.auth().generatePasswordResetLink(email, {
      url: RESET_URL,
      handleCodeInApp: false,
    });
    console.log('[sendReset] enlace generado, enviando correo...');
    await transporter().sendMail({
      from: FROM_EMAIL,
      to: email,
      subject: 'Restablece tu contraseña · ConsultorioClínico',
      html: resetHtml({ email, link }),
    });
    console.log('[sendReset] correo enviado OK');
    return res.json({ ok: true });
  } catch (e) {
    console.error('sendReset error:', (e && e.message) || e);
    return res.status(500).json({ error: String((e && e.message) || e) });
  }
});
