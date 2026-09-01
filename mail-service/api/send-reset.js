import { adminAuth } from './_lib/firebase.js';
import { sendMail, resetHtml } from './_lib/mail.js';

/// POST /api/send-reset  body: { email }
/// Correo de "restablecer contraseña" con plantilla propia. Útil para el
/// "¿Olvidaste tu contraseña?" que se quiera agregar más adelante.
export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Usa POST' });
  }
  const { email } = req.body ?? {};
  if (!email || typeof email !== 'string') {
    return res.status(400).json({ error: 'email requerido' });
  }
  if (!process.env.RESEND_API_KEY) {
    return res.status(500).json({ error: 'RESEND_API_KEY no configurada' });
  }
  try {
    const link = await adminAuth().generatePasswordResetLink(email.trim(), {
      url: 'https://consultorioclinico-2026.web.app/reset',
      handleCodeInApp: false,
    });
    await sendMail({
      to: email.trim(),
      subject: 'Restablece tu contraseña · ConsultorioClínico',
      html: resetHtml({ email: email.trim(), link }),
    });
    res.json({ ok: true });
  } catch (e) {
    console.error('send-reset error:', e?.message ?? e);
    res.status(500).json({ error: String(e?.message ?? e) });
  }
}
