'use strict';

/**
 * Smoke test E2E de PreConsulta IA contra la API local (http://127.0.0.1:3000).
 *
 * Requiere:
 *   - backend/.env con SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY + FIREBASE_SERVICE_ACCOUNT
 *   - backend escuchando en el puerto 3000
 *   - usuario admin@consultorio.com en Firebase Auth
 *
 * Crea una preconsulta marcada como prueba, recorre el flujo completo
 * (crear → validaciones → respuestas → finalizar → detalle → cola → métricas
 * → eventos → tendencias → revisión clínica → bloqueo tras cierre) y al final
 * elimina SOLO los registros que creó. No deja datos en la base.
 *
 * Uso:  cd backend && node scripts/preconsulta_smoke.js
 */

const fs = require('fs');
const path = require('path');
const dotenv = require('dotenv');
dotenv.config({ path: path.join(__dirname, '..', '.env') });

const { initializeApp, cert, getApps } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { createClient } = require('@supabase/supabase-js');

const BASE = 'http://127.0.0.1:3000/api';
const sb = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const ok = (cond, etiqueta, detalle = '') =>
  console.log(`${cond ? 'OK  ' : 'FALLO'} | ${etiqueta}${detalle ? ' | ' + detalle : ''}`);

function apiKeyWeb() {
  const ruta = path.join(__dirname, '..', '..', 'frontend', 'lib', 'firebase_options.dart');
  const s = fs.readFileSync(ruta, 'utf8');
  const i = s.indexOf('FirebaseOptions web');
  return (s.slice(i).match(/apiKey:\s*'([^']+)'/) || [])[1];
}

async function idToken(email) {
  const app = getApps()[0] || initializeApp({ credential: cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)) });
  const user = await getAuth(app).getUserByEmail(email);
  const customToken = await getAuth(app).createCustomToken(user.uid);
  const r = await fetch(
    'https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=' + apiKeyWeb(),
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: customToken, returnSecureToken: true }),
    }
  );
  const j = await r.json();
  if (!r.ok) throw new Error('Firebase REST: ' + ((j.error && j.error.message) || r.status));
  return j.idToken;
}

async function api(path, { method = 'GET', body, token } = {}) {
  const res = await fetch(BASE + path, {
    method,
    headers: {
      Authorization: 'Bearer ' + token,
      'Content-Type': 'application/json',
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  let json = null;
  try {
    json = await res.json();
  } catch (_e) {
    json = null;
  }
  return { status: res.status, json };
}

(async () => {
  const creadas = [];
  try {
    // Limpieza de restos de corridas anteriores (consentimientos huérfanos).
    const refs = await sb.from('preconsultas').select('consentimiento_id');
    const usados = new Set((refs.data || []).map((r) => r.consentimiento_id).filter(Boolean));
    const todos = await sb.from('consentimientos_preconsulta').select('id');
    const huerfanos = (todos.data || []).map((r) => r.id).filter((x) => !usados.has(x));
    if (huerfanos.length) {
      const del = await sb.from('consentimientos_preconsulta').delete().in('id', huerfanos);
      console.log(`Limpieza previa: ${huerfanos.length} consentimiento(s) huérfano(s)${del.error ? ' — ERROR ' + del.error.message : ''}`);
    }

    // --- Preparación ------------------------------------------------------
    const pac = await sb
      .from('pacientes')
      .select('id, nombre, apellido, activo')
      .eq('activo', true)
      .order('id')
      .limit(5);
    if (pac.error || !pac.data || !pac.data.length) {
      console.log('FALLO | no hay pacientes activos:', pac.error ? pac.error.message : 'lista vacía');
      process.exit(1);
    }
    const paciente = pac.data[0];
    console.log(`Paciente de prueba: #${paciente.id} ${paciente.nombre} ${paciente.apellido}`);

    const token = await idToken('admin@consultorio.com');
    ok(!!token, 'Firebase ID token (admin)');

    const cons = await api('/preconsulta/consentimiento', { token });
    ok(cons.status === 200 && cons.json?.success, 'GET /preconsulta/consentimiento', 'HTTP ' + cons.status);
    const version = cons.json?.data?.version;
    ok(!!version, 'versión del consentimiento', version);

    // --- 1) Crear ---------------------------------------------------------
    const crear = await api('/preconsulta', {
      method: 'POST',
      token,
      body: {
        paciente_id: paciente.id,
        consentimiento_aceptado: true,
        consentimiento_version: version,
        canal: 'recepcion',
        motivo: 'PRUEBA E2E TEMPORAL — eliminar',
      },
    });
    ok(crear.status === 201, 'POST /preconsulta', 'HTTP ' + crear.status);
    if (crear.status !== 201) {
      console.log(JSON.stringify(crear.json, null, 2));
      process.exit(1);
    }
    const id = crear.json.data.id;
    creadas.push(id);
    ok(!!id, 'id de preconsulta', String(id));
    ok(crear.json.data.estado === 'pendiente', 'estado inicial', crear.json.data.estado);

    // --- 2) Validaciones negativas ---------------------------------------
    const mala = await api(`/preconsulta/${id}/respuestas`, {
      method: 'PUT',
      token,
      body: { respuestas: [{ codigo: 'no_existe', valor: 1 }] },
    });
    ok(mala.status === 422, 'PUT respuestas con código inválido → 422', 'HTTP ' + mala.status);

    const vacio = await api(`/preconsulta/${id}/finalizar`, { method: 'POST', token, body: {} });
    ok(vacio.status === 422, 'POST finalizar sin respuestas → 422', 'HTTP ' + vacio.status);

    // --- 3) Respuestas (caso de urgencia) --------------------------------
    const respuestas = [
      { codigo: 'motivo_principal', valor: 'Dolor en el pecho y falta de aire (PRUEBA E2E)' },
      { codigo: 'dolor_intensidad', valor: 8 },
      { codigo: 'dolor_inicio', valor: 'hoy' },
      { codigo: 'fiebre', valor: 'no' },
      { codigo: 'dificultad_respiratoria', valor: 'reposo' },
      { codigo: 'dolor_toracico', valor: 'si' },
      { codigo: 'mareo_desmayo', valor: 'no' },
      { codigo: 'sangrado', valor: 'no' },
      { codigo: 'vomito', valor: false },
      { codigo: 'cefalea_intensa', valor: false },
    ];
    const guardar = await api(`/preconsulta/${id}/respuestas`, {
      method: 'PUT',
      token,
      body: { respuestas },
    });
    ok(guardar.status === 200, 'PUT /preconsulta/:id/respuestas', 'HTTP ' + guardar.status);
    if (guardar.status !== 200) console.log(JSON.stringify(guardar.json, null, 2));

    // --- 4) Finalizar -----------------------------------------------------
    const fin = await api(`/preconsulta/${id}/finalizar`, { method: 'POST', token, body: {} });
    ok(fin.status === 200, 'POST /preconsulta/:id/finalizar', 'HTTP ' + fin.status);
    if (fin.status !== 200) console.log(JSON.stringify(fin.json, null, 2));
    const triage = fin.json?.data?.triage || {};
    ok(!!triage.nivel, 'triage nivel', String(triage.nivel) + ' — ' + (triage.nivel_etiqueta || ''));
    ok(Array.isArray(triage.banderas) && triage.banderas.length > 0, 'triage banderas', JSON.stringify(triage.banderas));
    ok(!!triage.resumen, 'triage resumen', String(triage.resumen).slice(0, 110));
    ok(fin.json?.data?.triage?.requiere_revision === true, 'requiere_revision (triage)', String(fin.json?.data?.triage?.requiere_revision));
    ok(fin.json?.data?.requiere_revision_humana === true, 'requiere_revision_humana', String(fin.json?.data?.requiere_revision_humana));
    ok(fin.json?.data?.estado === 'completada', 'estado final', String(fin.json?.data?.estado));

    // --- 5) Detalle -------------------------------------------------------
    const det = await api(`/preconsulta/${id}`, { token });
    ok(det.status === 200, 'GET /preconsulta/:id', 'HTTP ' + det.status);
    const resp = det.json?.data?.respuestas || [];
    ok(resp.length === respuestas.length, 'respuestas guardadas', `${resp.length}/${respuestas.length}`);
    ok(det.json?.data?.no_es_diagnostico === true, 'marca no_es_diagnostico');

    // --- 6) Cola ----------------------------------------------------------
    const cola = await api('/preconsulta/cola?limit=50', { token });
    ok(cola.status === 200, 'GET /preconsulta/cola', 'HTTP ' + cola.status);
    const enCola = (cola.json?.data?.preconsultas || []).some((x) => Number(x.id) === Number(id));
    ok(!!enCola, 'la preconsulta aparece en la cola');

    // --- 7) Métricas ------------------------------------------------------
    const met = await api('/preconsulta/metricas?dias=7', { token });
    ok(met.status === 200, 'GET /preconsulta/metricas', 'HTTP ' + met.status);
    const total = met.json?.data?.total ?? met.json?.data?.total_preconsultas;
    ok(total != null, 'métricas total', String(total));

    // --- 8) Eventos -------------------------------------------------------
    const ev = await api(`/preconsulta/${id}/eventos`, { token });
    ok(ev.status === 200, 'GET /preconsulta/:id/eventos', 'HTTP ' + ev.status);
    const eventos = ev.json?.data?.eventos || [];
    ok(eventos.length >= 3, 'eventos registrados', String(eventos.length) + ': ' + eventos.map((e) => e.tipo).join(', '));

    // --- 9) Tendencia del paciente ---------------------------------------
    const ten = await api(`/preconsulta/paciente/${paciente.id}/tendencias`, { token });
    ok(ten.status === 200, 'GET /preconsulta/paciente/:id/tendencias', 'HTTP ' + ten.status);

    // --- 10) Revisión clínica --------------------------------------------
    const rev = await api(`/preconsulta/${id}/revision`, {
      method: 'PATCH',
      token,
      body: { nivel_revisado: triage.nivel, nota: 'Revisión de prueba E2E. Se elimina al terminar.' },
    });
    ok(rev.status === 200, 'PATCH /preconsulta/:id/revision', 'HTTP ' + rev.status);
    ok(rev.json?.data?.estado === 'revisada', 'estado tras revisión', String(rev.json?.data?.estado));

    // --- 11) Bloqueo tras cierre -----------------------------------------
    const bloqueo = await api(`/preconsulta/${id}/respuestas`, {
      method: 'PUT',
      token,
      body: { respuestas: [{ codigo: 'dolor_intensidad', valor: 3 }] },
    });
    ok(bloqueo.status === 409, 'PUT respuestas tras cierre → 409', 'HTTP ' + bloqueo.status);

    // --- 12) Finalizar enviando el cuestionario en el cuerpo --------------
    // Es lo que hace el asistente web al cerrar sin cámara: un solo POST.
    const crear2 = await api('/preconsulta', {
      method: 'POST',
      token,
      body: {
        paciente_id: paciente.id,
        consentimiento_aceptado: true,
        consentimiento_version: version,
        canal: 'web',
        motivo: 'PRUEBA E2E TEMPORAL sin cámara — eliminar',
      },
    });
    ok(crear2.status === 201, 'POST /preconsulta (2)', 'HTTP ' + crear2.status);
    if (crear2.status === 201) {
      const id2 = crear2.json.data.id;
      creadas.push(id2);
      const finInline = await api(`/preconsulta/${id2}/finalizar`, {
        method: 'POST',
        token,
        body: {
          respuestas: [
            { codigo: 'motivo_principal', valor: 'Control de presión arterial (PRUEBA E2E)' },
            { codigo: 'dolor_intensidad', valor: 2 },
            { codigo: 'dolor_inicio', valor: 'mas_7_dias' },
            { codigo: 'fiebre', valor: 'no' },
            { codigo: 'dificultad_respiratoria', valor: 'no' },
            { codigo: 'dolor_toracico', valor: false },
            { codigo: 'mareo_desmayo', valor: 'no' },
            { codigo: 'sangrado', valor: 'no' },
          ],
        },
      });
      ok(finInline.status === 200, 'POST finalizar con respuestas en el cuerpo', 'HTTP ' + finInline.status);
      if (finInline.status !== 200) console.log(JSON.stringify(finInline.json, null, 2));
      ok(finInline.json?.data?.triage?.nivel != null, 'triage sin captura (cuerpo)', String(finInline.json?.data?.triage?.nivel) + ' — ' + (finInline.json?.data?.triage?.nivel_etiqueta || ''));
      ok(
        (finInline.json?.data?.respuestas || []).length === 8,
        'respuestas persistidas por finalizar',
        (finInline.json?.data?.respuestas || []).length + '/8'
      );
      const ev2 = await api(`/preconsulta/${id2}/eventos`, { token });
      const tipos2 = (ev2.json?.data?.eventos || []).map((e) => e.tipo);
      ok(tipos2.includes('respuestas'), 'evento de respuestas en auditoría', tipos2.join(', '));
    }
  } catch (e) {
    console.log('FALLO | excepción:', e.message);
  } finally {
    // --- Limpieza ---------------------------------------------------------
    const consentimientos = new Set();
    for (const id of creadas) {
      const fila = await sb.from('preconsultas').select('consentimiento_id').eq('id', id).maybeSingle();
      if (fila.data?.consentimiento_id) consentimientos.add(fila.data.consentimiento_id);
      const del = await sb.from('preconsultas').delete().eq('id', id);
      ok(!del.error, 'limpieza preconsulta', '#' + id + (del.error ? ' — ' + del.error.message : ''));
    }
    for (const cid of consentimientos) {
      const delC = await sb.from('consentimientos_preconsulta').delete().eq('id', cid);
      ok(!delC.error, 'limpieza consentimiento', '#' + cid + (delC.error ? ' — ' + delC.error.message : ''));
    }
    for (const t of ['preconsultas', 'consentimientos_preconsulta', 'preconsulta_respuestas', 'preconsulta_revisiones', 'preconsulta_eventos']) {
      const c = await sb.from(t).select('*', { count: 'exact', head: true });
      console.log(`CONTEO | ${t}: ${c.error ? 'ERROR ' + c.error.code : c.count}`);
    }
  }
})();
