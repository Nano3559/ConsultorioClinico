require('dotenv').config();
const crypto = require('crypto');

const nodeEnv = process.env.NODE_ENV || 'development';

if (nodeEnv === 'production' && !process.env.JWT_SECRET) {
  throw new Error('JWT_SECRET es obligatorio en producción');
}

// En desarrollo, si no hay JWT_SECRET se genera uno aleatorio por proceso.
// Esto evita el fallback hardcodeado ('fallback_secret_key') que era predecible.
const jwtSecret =
  process.env.JWT_SECRET ||
  (nodeEnv === 'production'
    ? (() => {
        throw new Error('JWT_SECRET es obligatorio en producción');
      })()
    : (() => {
        const generado = crypto.randomBytes(48).toString('hex');
        console.warn(
          '[config] ⚠ JWT_SECRET no definido. Se usa un secreto aleatorio solo para desarrollo. Define JWT_SECRET en .env.'
        );
        return generado;
      })());

// Lista de orígenes permitidos para CORS (separados por coma en CORS_ORIGINS).
// Si está vacía, se responde sin cabecera Access-Control-Allow-Origin a
// solicitudes con Origin (navegador) y se permiten requests server-to-server.
const corsOrigins = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);

module.exports = {
  port: process.env.PORT || 3000,
  nodeEnv,
  jwtSecret,
  jwtExpire: process.env.JWT_EXPIRE || '24h',
  corsOrigins,

  // Configuración de MySQL (legacy, no usada actualmente)
  db: {
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '3306', 10),
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    name: process.env.DB_NAME || 'consultorio_clinico',
  },

  // Configuración de Supabase (PostgreSQL)
  supabase: {
    url: process.env.SUPABASE_URL || '',
    anonKey: process.env.SUPABASE_ANON_KEY || '',
    serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY || '',
  },

  // Configuración del microservicio de visión (Python + FastAPI). Variables
  // VISION_* (KIO-16 del kiosco de auto-check-in). Centralizadas aquí para
  // que el proxy Node (visionService/kiosco) y el módulo de visión compartan
  // los mismos valores configurables por .env.
  vision: {
    // VISION_ENABLED: si es 'false' se desactiva el reconocimiento (fallback
    // a recepción). Por defecto habilitado.
    enabled: process.env.VISION_ENABLED !== 'false',

    // URL base del microservicio de visión (alias VISION_SERVICE_URL /
    // VISION_PYTHON_SERVICE_URL). Mantiene la variable original del README.
    serviceUrl:
      process.env.VISION_PYTHON_SERVICE_URL ||
      process.env.VISION_SERVICE_URL ||
      'http://localhost:8000',

    // Ruta del modelo de rostros entrenado (LBPH) usado por el módulo.
    faceModel: process.env.VISION_FACE_MODEL || '',

    // Pack de modelos InsightFace usado por el microservicio de visión
    // (detección SCRFD + embedding ArcFace 512-d). El kiosco descarga este
    // mismo pack al sincronizar (ver manifest del kiosco).
    modelPack: process.env.VISION_MODEL_PACK || 'buffalo_s',

    // Versión lógica del pack de modelos. Si cambia, el kiosco detecta la
    // diferencia en el manifest y actualiza sus modelos locales.
    modelVersion: process.env.VISION_MODEL_VERSION || 'buffalo_s_v1',

    // Umbral de similitud coseno [0-1] para considerar un rostro reconocido.
    // Punto de partida 0.5 (calibrar con datos reales: subir = más estricto).
    similarityThreshold: Number(process.env.VISION_SIMILARITY_THRESHOLD) || 0.5,

    // Umbral de confianza LBPH: por debajo se considera "rostro reconocido".
    confidenceThreshold: Number(process.env.VISION_CONFIDENCE_THRESHOLD) || 80,

    // Cantidad de muestras a capturar por paciente al registrar el rostro.
    captureCount: Number(process.env.VISION_CAPTURE_COUNT) || 20,

    // Ruta del clasificador Haar Cascade para detección de rostros.
    cascadePath: process.env.VISION_CASCADE_PATH || '',

    // Tiempo máximo de espera por llamada HTTP (ms). Default 30s: la
    // primera inferencia en frío del microservicio es lenta (carga de
    // modelos); con warmup al arranque las siguientes responden en ms.
    timeoutMs: Number(process.env.VISION_TIMEOUT_MS) || 30000,

    // Reintentos ante fallos de red/timeout.
    retries: Number(process.env.VISION_RETRIES) || 3,
  },

  // Alias retrocompatible: el proxy Node (visionService.js / kioscoController)
  // usa `config.visionServiceUrl`. Apunta al mismo valor configurable.
  visionServiceUrl:
    process.env.VISION_PYTHON_SERVICE_URL ||
    process.env.VISION_SERVICE_URL ||
    'http://localhost:8000',

  // Configuración de seguridad del kiosco de auto-check-in (KIO-15/19/20).
  // Controla la auditoría de intentos, la ventana de verificación válida para
  // confirmar la cita y los límites de tasa por IP de los endpoints públicos.
  kiosco: {
    // Minutos durante los que una verificación facial exitosa (misma IP)
    // habilita confirmar la cita sin volver a verificar.
    verificationWindowMs:
      (Number(process.env.KIOSCO_VERIFICATION_WINDOW_MIN) || 15) * 60 * 1000,

    // Máximo de verificaciones faciales por IP en la ventana de 15 minutos.
    verifyRateMax: Number(process.env.KIOSCO_VERIFY_RATE_MAX) || 30,

    // Máximo de confirmaciones de cita por IP en la ventana de 15 minutos.
    confirmRateMax: Number(process.env.KIOSCO_CONFIRM_RATE_MAX) || 10,

    // Clave compartida del kiosco Windows (reconocimiento local, offline).
    // Si el request trae el header x-kiosk-key con este valor, confirmar-cita
    // acepta el check-in sin exigir la verificación facial en nube (el kiosco
    // ya verificó el rostro localmente con OpenCV). Vacía = desactivado.
    apiKey: process.env.KIOSK_API_KEY || '',

    // Cada cuántos minutos el kiosco comprueba el manifest de sincronización
    // (plantillas + versión del modelo) contra la nube.
    syncMinutos: Number(process.env.KIOSCO_SYNC_MINUTOS) || 15,

    // Días de vigencia del registro facial. Si el rostro de un paciente se
    // registró hace más días, la reserva online vuelve a pedirle foto y el
    // kiosco sugiere re-registro. Los rasgos no cambian en 30 días salvo
    // barba/lentes/peso (esos casos los cubre el re-registro por baja
    // similitud); 90 días es el equilibrio recomendado.
    reenrollDias: Number(process.env.KIOSCO_REENROLL_DIAS) || 90,

    // Bucket privado de Supabase Storage donde viven los packs de fotos por
    // persona: rostros/{cedula}_{nombre-slug}/pose_*.jpg (ver migración 013).
    rostroBucket: process.env.KIOSCO_ROSTRO_BUCKET || 'rostros',
  },
};