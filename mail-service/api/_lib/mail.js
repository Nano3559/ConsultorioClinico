import nodemailer from 'nodemailer';

/// Envía un correo con nodemailer vía SMTP. Enviador por defecto: tu propia
/// cuenta de Gmail (con Contraseña de aplicación). Se puede sobreescribir el
/// remitente con FROM_EMAIL.
export async function sendMail({ to, subject, html }) {
  const user = process.env.GMAIL_USER;
  const pass = process.env.GMAIL_APP_PASSWORD;
  if (!user || !pass) {
    throw new Error(
      'Faltan GMAIL_USER o GMAIL_APP_PASSWORD (usa una "Contraseña de aplicación" de Google).'
    );
  }
  const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: { user, pass },
  });
  const from = process.env.FROM_EMAIL || `ConsultorioClínico <${user}>`;
  return transporter.sendMail({ from, to, subject, html });
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

/// Correo de confirmación de cuenta/alta de médico.
export function confirmHtml({ nombre, email, link }) {
  const body = `
    <h2 style="margin:0 0 12px;color:#0f172a">¡Hola, ${nombre}!</h2>
    <p style="color:#475569;line-height:1.6;margin:0">
      Bienvenido/a a <b>ConsultorioClínico</b>. Tu cuenta ha sido creada y solo
      falta un paso: <b>crear tu propia contraseña</b> para poder ingresar al sistema.
    </p>`;
  return shell({ body, link, buttonText: 'Crear mi contraseña', footerEmail: email });
}

/// Correo para restablecer la contraseña cuando ya se tiene cuenta.
export function resetHtml({ email, link }) {
  const body = `
    <h2 style="margin:0 0 12px;color:#0f172a">Restablece tu contraseña</h2>
    <p style="color:#475569;line-height:1.6;margin:0">
      Recibimos una solicitud para restablecer la contraseña de tu cuenta.
      Si no la hiciste tú, ignora este correo. De lo contrario, pulsa el botón
      para crear una nueva contraseña.
    </p>`;
  return shell({ body, link, buttonText: 'Restablecer contraseña', footerEmail: email });
}
