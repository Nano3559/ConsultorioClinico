'use strict';

const crypto = require('crypto');
const config = require('../config/config');
const { llamarVision } = require('./visionService');

/**
 * Lógica compartida del registro facial multi-pose (YuNet+SFace).
 *
 * La usan dos caminos:
 *   - visionController.registrarRostro (recepción/admin, paciente ya existe).
 *   - kioscoController.ingestarPaquete (reserva online pública: crea el
 *     paciente del backend por cédula si no existe y registra su pack).
 *
 * Convenciones:
 *   - Poses válidas: frontal, izquierda, derecha, arriba, abajo.
 *   - El frontend envía muestras como [{ imagen, pose }] (una por pose como
 *     mínimo) o, por compatibilidad, [base64, ...] (se asumen frontales).
 *   - Las fotos se guardan LIVIANAS: el microservicio Python recorta el
 *     rostro y devuelve JPEG (máx 640px, q80); eso es lo que se sube a
 *     Storage, nunca el original de la cámara.
 *   - Carpeta por persona en el bucket: rostros/{cedula}_{nombre-slug}/
 */

const POSES = ['frontal', 'izquierda', 'derecha', 'arriba', 'abajo'];

/**
 * Convierte "María José Pérez" en "maria-jose-perez" para carpetas.
 */
const slug = (texto) =>
  String(texto || '')
    .normalize('NFD')
    .replace(/[^\x00-\x7F]/g, '')
    .replace(/[^a-zA-Z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .toLowerCase()
    .slice(0, 60) || 'sin-nombre';

const carpetaPersona = (cedula, nombre, apellido) =>
  `${String(cedula).trim()}_${slug(`${nombre || ''} ${apellido || ''}`)}`;

/**
 * Normaliza el payload de muestras a [{ imagen, pose }].
 * Acepta el formato legacy [base64, ...] (pose frontal).
 */
const normalizarMuestras = (imagenes) => {
  if (!Array.isArray(imagenes)) return [];
  return imagenes
    .map((m) => {
      if (typeof m === 'string') return { imagen: m, pose: 'frontal' };
      if (m && typeof m.imagen === 'string') {
        const pose = POSES.includes(m.pose) ? m.pose : 'frontal';
        return { imagen: m.imagen, pose };
      }
      return null;
    })
    .filter(Boolean);
};

/**
 * Normaliza un embedding pgvector a array de números.
 * Supabase lo devuelve como string "[0.1,0.2,...]" o como array según el
 * cliente/versión: se aceptan ambas formas (y null si no es válido).
 */
const parseEmbedding = (valor) => {
  if (Array.isArray(valor)) {
    const nums = valor.map(Number);
    return nums.every((n) => Number.isFinite(n)) ? nums : null;
  }
  if (typeof valor === 'string') {
    const texto = valor.trim();
    if (!texto.startsWith('[') || !texto.endsWith(']')) return null;
    const nums = texto
      .slice(1, -1)
      .split(',')
      .map((x) => Number(x.trim()));
    if (nums.length === 0 || !nums.every((n) => Number.isFinite(n))) return null;
    return nums;
  }
  return null;
};

/**
 * md5 del embedding para el manifest de sincronización del kiosco
 * (comparar hashes evita descargar plantillas que no cambiaron).
 */
const hashPlantilla = (embedding) => {
  const nums = parseEmbedding(embedding);
  if (!nums || nums.length === 0) return null;
  return crypto.createHash('md5').update(nums.join(',')).digest('hex');
};

/**
 * ¿El registro facial sigue vigente? (política KIOSCO_REENROLL_DIAS).
 */
const rostroVigente = (paciente, dias = config.kiosco.reenrollDias) => {
  if (!paciente || !parseEmbedding(paciente.rostro_embedding) || !paciente.rostro_actualizado_en) {
    return false;
  }
  const limite = Date.now() - dias * 24 * 60 * 60 * 1000;
  return new Date(paciente.rostro_actualizado_en).getTime() >= limite;
};

/**
 * Procesa un pack de fotos: llama al microservicio Python (detección
 * YuNet+SFace + calidad + embedding 128-d por pose + foto liviana),
 * sube las fotos al bucket privado y persiste plantillas + vigencia.
 *
 * @param {object} supabase Cliente Supabase (service_role).
 * @param {object} paciente  { id, cedula, nombre, apellido }.
 * @param {Array}  muestras  [{ imagen, pose }] en base64.
 * @param {boolean} espejado Fotos espejadas (web): el Python invierte el yaw.
 * @returns {object} { guardadas, porPose, rostro_registrado, calidades, carpeta }
 */
const procesarPaquete = async (supabase, paciente, muestras, espejado = false) => {
  const normalizadas = normalizarMuestras(muestras);
  if (normalizadas.length === 0) {
    const error = new Error('Debe enviar al menos una imagen válida');
    error.statusCode = 400;
    throw error;
  }

  const respuesta = await llamarVision(
    `/api/vision/registrar-rostro/${paciente.id}`,
    { imagenes: normalizadas, espejado: espejado === true }
  );
  let dato;
  try {
    dato = await respuesta.json();
  } catch (err) {
    dato = {};
  }
  if (!respuesta.ok) {
    const error = new Error(dato.message || 'Error del microservicio de visión');
    error.statusCode = respuesta.status;
    throw error;
  }
  const dataVision = dato.data || {};
  const resultados = Array.isArray(dataVision.muestras) ? dataVision.muestras : [];

  const bucket = config.kiosco.rostroBucket;
  const carpeta = carpetaPersona(paciente.cedula, paciente.nombre, paciente.apellido);
  let guardadas = 0;
  const porPose = {};

  for (const r of resultados) {
    if (!r || !r.guardada || !r.foto || !POSES.includes(r.pose)) continue;
    const ruta = `${carpeta}/${r.pose}.jpg`;
    const buffer = Buffer.from(r.foto, 'base64');
    const { error: errorSubida } = await supabase.storage
      .from(bucket)
      .upload(ruta, buffer, { contentType: 'image/jpeg', upsert: true });
    if (errorSubida) throw errorSubida;

    const { error: errorMuestra } = await supabase.from('rostro_muestras').upsert(
      {
        paciente_id: paciente.id,
        pose: r.pose,
        storage_path: `${bucket}/${ruta}`,
        embedding: `[${(r.embedding || []).join(',')}]`,
        calidad: r.calidad ?? 0,
      },
      { onConflict: 'paciente_id,pose' }
    );
    if (errorMuestra) throw errorMuestra;
    guardadas += 1;
    porPose[r.pose] = r.calidad ?? 0;
  }

  // Plantilla principal = promedio de embeddings por pose (ya normalizado
  // por el microservicio) + marca de vigencia para la política de 1 mes+.
  let rostroRegistrado = false;
  const embedding = dataVision.rostro_embedding;
  if (Array.isArray(embedding) && embedding.length === 128 && guardadas > 0) {
    const { error: errorUpdate } = await supabase
      .from('pacientes')
      .update({
        rostro_embedding: `[${embedding.join(',')}]`,
        rostro_actualizado_en: new Date().toISOString(),
      })
      .eq('id', paciente.id);
    if (errorUpdate) throw errorUpdate;
    rostroRegistrado = true;
  }

  // Log de rechazadas (diagnóstico vía logs; sin imágenes, solo poses/motivos).
  const rechazadas = Object.fromEntries(
    resultados.filter((r) => r && !r.guardada).map((r) => [r.pose || '?', r.motivo || 'rechazada'])
  );
  if (Object.keys(rechazadas).length > 0) {
    console.log(`[rostro] paciente=${paciente.id} rechazadas=${JSON.stringify(rechazadas)}`);
  }

  return {
    guardadas,
    porPose,
    rechazadas,
    rostro_registrado: rostroRegistrado,
    carpeta: `${bucket}/${carpeta}/`,
  };
};

module.exports = {
  POSES,
  slug,
  carpetaPersona,
  normalizarMuestras,
  parseEmbedding,
  hashPlantilla,
  rostroVigente,
  procesarPaquete,
};
