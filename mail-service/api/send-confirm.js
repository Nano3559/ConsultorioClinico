import { adminAuth } from './_lib/firebase.js';
import { sendMail, confirmHtml } from './_lib/mail.js';

/// POST /api/send-confirm  body: { email, nombre }
/// Crea un enlace real de reset (oobCode) con el Admin SDK y envía un correo
/// HTML personalizado con Resend. La app (Flutter) llama a este endpoint al
/// registrar un médico (en lugar del correo genérico de Firebase).
export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Usa POST' });
  }
  const { email, nombre } = req.body ?? {};
  if (!email || typeof email !== 'string') {
    return res.status(400).json({ error: 'email requerido' });
  }
  if (!process.env.GMAIL_USER || !process.env.GMAIL_APP_PASSWORD) {
    return res.status(500).json({ error: 'GMAIL_USER / GMAIL_APP_PASSWORD no configuradas' });
  }
  try {
    const link = await adminAuth().generatePasswordResetLink(email.trim(), {
      url: 'https://consultorioclinico-2026.web.app/reset',
      handleCodeInApp: false,
    });
    await sendMail({
      to: email.trim(),
      subject: `Confirma tu cuenta en ConsultorioClínico${nombre ? ` · ${nombre}` : ''}`,
      html: confirmHtml({ nombre: nombre?.trim() || 'Colega', email: email.trim(), link }),
    });
    res.json({ ok: true });
  } catch (e) {
    console.error('send-confirm error:', e?.message ?? e);
    res.status(500).json({ error: String(e?.message ?? e) });
  }
}
