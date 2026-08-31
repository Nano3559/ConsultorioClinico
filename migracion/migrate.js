const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const API = 'https://consultorio-clinico.vercel.app/api';
const ADMIN_EMAIL = 'admin@consultorio.com';
const ADMIN_PASSWORD = 'admin123';
const PROJECT_ID = 'consultorioclinico-2026';
const SA_PATH = path.resolve(__dirname, '..', 'firebase-migrator-key.json');

const sa = JSON.parse(fs.readFileSync(SA_PATH, 'utf8').replace(/^﻿/, ''));
admin.initializeApp({ credential: admin.credential.cert(sa), projectId: PROJECT_ID });
const db = admin.firestore();
const auth = admin.auth();

const ymd = (v) => (v == null ? '' : String(v).slice(0, 10));
const hhmm = (v) => (v == null ? '' : String(v).slice(0, 5));

const COLLECTIONS = ['especialidades', 'medicos', 'pacientes', 'horarios', 'citas', 'consultas', 'pagos', 'usuarios'];

async function wipeAll() {
  for (const name of COLLECTIONS) {
    const snap = await db.collection(name).get();
    let count = 0;
    while (snap.docs.length > 0) {
      const batch = db.batch();
      for (const d of snap.docs.slice(0, 450)) { batch.delete(d.ref); count++; }
      await batch.commit();
      break;
    }
    console.log(`wiped ${name}: ${count}`);
  }
}

async function apiGet(token, path) {
  const res = await fetch(`${API}${path}`, { headers: { Authorization: `Bearer ${token}` } });
  if (!res.ok) throw new Error(`GET ${path} -> ${res.status}`);
  const json = await res.json();
  return json.data || [];
}

async function safeApiGet(token, path) {
  try { return await apiGet(token, path); } catch (e) { console.warn(`WARN ${path}: ${e.message}`); return []; }
}

const DEFAULT_ESP = ['Medicina General', 'Pediatría', 'Ginecología', 'Cardiología', 'Dermatología', 'Odontología'];

async function ensureUser(email, password, displayName) {
  const mail = String(email).toLowerCase();
  try {
    const u = await auth.createUser({ email: mail, password, displayName });
    return u.uid;
  } catch (e) {
    if (e.code === 'auth/email-already-exists') {
      const u = await auth.getUserByEmail(mail);
      return u.uid;
    }
    if (e.code === 'auth/invalid-email') return null;
    throw e;
  }
}

(async () => {
  console.log('Limpiando colecciones previas...');
  await wipeAll();

  // Login admin
  const login = await fetch(`${API}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: ADMIN_EMAIL, password: ADMIN_PASSWORD }),
  });
  if (!login.ok) throw new Error(`login admin -> ${login.status}`);
  const tok = (await login.json()).data.token;
  console.log('Token admin obtenido');

  const [espec, meds, pacs, cit, con, pag] = await Promise.all([
    safeApiGet(tok, '/especialidades'),
    safeApiGet(tok, '/medicos'),
    safeApiGet(tok, '/pacientes'),
    safeApiGet(tok, '/citas'),
    safeApiGet(tok, '/consultas'),
    safeApiGet(tok, '/pagos'),
  ]);
  console.log(`especialidades=${espec.length} medicos=${meds.length} pacientes=${pacs.length} citas=${cit.length} consultas=${con.length} pagos=${pag.length}`);

  // Horarios (todas)
  let hor = [];
  try { hor = await apiGet(tok, '/horarios'); } catch (e) { console.warn(`WARN /horarios: ${e.message}`); }

  // Especialidades
  const fuenteEsp = espec.length > 0 ? espec : DEFAULT_ESP.map((n, i) => ({ id: `def_${i}`, nombre: n, descripcion: '' }));
  const mapEsp = {};
  for (const e of fuenteEsp) {
    const ref = await db.collection('especialidades').add({ nombre: e.nombre || '', descripcion: e.descripcion || '' });
    mapEsp[e.id] = ref.id;
  }
  const espByName = {};
  for (const e of fuenteEsp) espByName[String(e.nombre || '').toLowerCase()] = mapEsp[e.id];

  // Medicos + Auth + usuarios
  const mapMed = {};
  for (const m of meds) {
    const email = (m.email && String(m.email).includes('@')) ? m.email : `medico${m.id}@consultorio.com`;
    const uid = await ensureUser(email, 'Medico123!', `${m.nombre || ''} ${m.apellido || ''}`.trim());
    if (!uid) continue;
    const espId = espByName[String(m.especialidad || '').toLowerCase()] || '';
    await db.collection('medicos').doc(uid).set({
      uid,
      nombre: m.nombre || '',
      apellido: m.apellido || '',
      activo: m.activo !== false,
      especialidad_id: espId,
      email,
      telefono: m.telefono || '',
    });
    await db.collection('usuarios').doc(uid).set({
      uid,
      nombre: `${m.nombre || ''} ${m.apellido || ''}`.trim(),
      email,
      rol: 'medico',
      perfilTipo: 'medico',
      perfilId: uid,
      activo: true,
      creadoEn: admin.firestore.FieldValue.serverTimestamp(),
    });
    mapMed[m.id] = uid;
  }

  // Pacientes
  const mapPac = {};
  const mapPacUid = {};   // id origen -> Firebase uid del paciente vinculado
  const mapPacInfo = {};  // id origen -> datos para su documento `usuarios`
  for (const p of pacs) {
    const email = (p.email && String(p.email).includes('@')) ? String(p.email).toLowerCase() : null;
    let linkedUid = null;
    if (email) {
      try {
        const existing = await auth.getUserByEmail(email);
        linkedUid = existing.uid;
      } catch (e) {
        // Solo la cuenta demo recibe password conocido; el resto debe autoregistrarse.
        if (e.code === 'auth/user-not-found' && email === 'pedro@gmail.com') {
          linkedUid = await ensureUser(email, 'paciente123', `${p.nombre || ''} ${p.apellido || ''}`.trim());
          console.log(`demo paciente creado: ${email} -> ${linkedUid}`);
        }
      }
    }
    const doc = {
      nombre: p.nombre || '',
      apellido: p.apellido || '',
      cedula: p.cedula || p.ci || '',
      telefono: p.telefono || '',
      email: email || '',
      fecha_nacimiento: ymd(p.fecha_nacimiento),
      alergias: p.alergias || '',
      contacto_emergencia: p.contacto_emergencia || '',
    };
    if (linkedUid) doc.uid = linkedUid;
    const ref = await db.collection('pacientes').add(doc);
    mapPac[p.id] = ref.id;
    if (linkedUid) {
      mapPacUid[p.id] = linkedUid;
      mapPacInfo[p.id] = { email: email || '', nombre: `${p.nombre || ''} ${p.apellido || ''}`.trim() };
    }
  }

  // Usuarios de pacientes con cuenta Firebase (acceso a su ficha y citas).
  for (const [srcId, linkedUid] of Object.entries(mapPacUid)) {
    const info = mapPacInfo[srcId] || {};
    await db.collection('usuarios').doc(linkedUid).set({
      uid: linkedUid,
      nombre: info.nombre,
      email: info.email,
      rol: 'paciente',
      perfilTipo: 'paciente',
      perfilId: mapPac[srcId],
      activo: true,
      creadoEn: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  }

  // Horarios
  let nHor = 0;
  for (const h of hor) {
    const mid = mapMed[h.medico_id];
    if (!mid) continue;
    await db.collection('horarios').add({
      medico_id: mid,
      dia_semana: String(h.dia_semana || '').toLowerCase(),
      hora_inicio: hhmm(h.hora_inicio) || (h.hora_inicio || ''),
      hora_fin: hhmm(h.hora_fin) || (h.hora_fin || ''),
    });
    nHor++;
  }

  // Citas
  const mapCit = {};
  const mapCitMed = {};
  for (const c of cit) {
    const mid = mapMed[c.medico_id];
    const pid = mapPac[c.paciente_id];
    if (!mid || !pid) continue;
    const doc = {
      paciente_id: pid,
      medico_id: mid,
      fecha: ymd(c.fecha),
      hora: hhmm(c.hora),
      motivo: c.motivo || '',
      estado: c.estado || 'programada',
    };
    if (mapPacUid[c.paciente_id]) doc.paciente_uid = mapPacUid[c.paciente_id];
    const ref = await db.collection('citas').add(doc);
    mapCit[c.id] = ref.id;
    mapCitMed[c.id] = mid;
  }

  // Consultas
  for (const c of con) {
    const mid = mapMed[c.medico_id];
    const pid = mapPac[c.paciente_id];
    if (!mid || !pid) continue;
    const doc = {
      paciente_id: pid,
      medico_id: mid,
      fecha: ymd(c.fecha || c.creado_en),
      diagnostico: c.diagnostico || '',
      tratamiento: c.tratamiento || '',
      notas_clinicas: c.notas_clinicas || '',
    };
    if (mapPacUid[c.paciente_id]) doc.paciente_uid = mapPacUid[c.paciente_id];
    await db.collection('consultas').add(doc);
  }

  // Pagos
  for (const p of pag) {
    const pid = mapPac[p.paciente_id];
    if (!pid) continue;
    const cid = p.cita_id ? mapCit[p.cita_id] : null;
    const mid = p.cita_id ? mapCitMed[p.cita_id] : null;
    const monto = typeof p.monto === 'number' ? p.monto : parseFloat(p.monto) || 0;
    const doc = {
      paciente_id: pid,
      cita_id: cid || '',
      medico_id: mid || '',
      monto,
      metodo_pago: p.metodo_pago || 'efectivo',
      estado: p.estado || 'pendiente',
      fecha_pago: ymd(p.fecha_pago || p.creado_en),
    };
    if (mapPacUid[p.paciente_id]) doc.paciente_uid = mapPacUid[p.paciente_id];
    await db.collection('pagos').add(doc);
  }

  // Admin
  const adminUid = await ensureUser('admin@consultorio.com', 'admin123', 'Administrador');
  if (adminUid) {
    await db.collection('usuarios').doc(adminUid).set({
      uid: adminUid,
      nombre: 'Administrador',
      email: 'admin@consultorio.com',
      rol: 'admin',
      perfilTipo: null,
      perfilId: null,
      activo: true,
      creadoEn: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  }

  console.log(`Migración completa. horarios=${nHor} adminUid=${adminUid}`);
  process.exit(0);
})().catch((e) => {
  console.error('ERROR:', e);
  process.exit(1);
});
