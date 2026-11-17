'use strict';

/**
 * Texto y metadatos del consentimiento informado de la PreConsulta IA.
 *
 * Se versiona (PRECONSULTA_CONSENT_VERSION). Si cambia el texto debe subir la
 * versión: el backend guarda la versión aceptada y el hash del texto para que
 * sea auditable qué documento firmó cada paciente.
 *
 * Redacción deliberadamente clara y en español neutro. No promete beneficios
 * clínicos ni oculta limitaciones: es un apoyo al triage, no un diagnóstico.
 */

const crypto = require('crypto');
const config = require('../config/config');

const VERSION = config.preconsulta.consentVersion;

const CONSENTIMIENTO = {
  version: VERSION,
  titulo: 'Consentimiento para la PreConsulta con apoyo de IA',
  subtitulo: 'Lectura de signos y priorización antes de tu cita',
  resumen:
    'La PreConsulta IA estima algunos signos a partir de una captura breve de tu rostro y de un cuestionario. ' +
    'Su único fin es ayudar al personal a ordenar la atención. No es un diagnóstico ni reemplaza al médico.',
  parrafos: [
    {
      titulo: '¿Qué se hace?',
      texto:
        'Durante 20-30 segundos la cámara observa tu rostro para estimar la frecuencia cardíaca, la variabilidad ' +
        'del pulso y la respiración (técnica llamada rPPG). También se analiza la tensión de tu expresión facial ' +
        'y tus respuestas a un cuestionario de síntomas. Con todo eso se sugiere un nivel de prioridad de 1 a 5.',
    },
    {
      titulo: '¿Qué datos se guardan?',
      texto:
        'No se guardan fotos, video ni recortes de tu rostro. El video se procesa en memoria y se descarta al ' +
        'terminar. Solo se almacenan números derivados (por ejemplo, pulso estimado y calidad de la captura), ' +
        'tus respuestas, el nivel de prioridad sugerido y la explicación de por qué se sugirió.',
    },
    {
      titulo: 'Límites importantes',
      texto:
        'Las estimaciones pueden fallar por mala luz, movimiento, maquillaje o problemas de circulación. ' +
        'No miden oxígeno en sangre ni presión arterial y no detectan todas las enfermedades. El personal de ' +
        'salud revisa y puede corregir la prioridad sugerida. Ante una urgencia, avisa de inmediato a recepción.',
    },
    {
      titulo: 'Tu decisión es voluntaria',
      texto:
        'Puedes rechazar la captura con cámara y continuar solo con el cuestionario, o pedir que te valoren ' +
        'directamente. Rechazar la PreConsulta IA no afecta tu derecho a la atención ni la calidad del servicio.',
    },
    {
      titulo: 'Identidad (opcional)',
      texto:
        'Si ya registraste tu rostro en el consultorio, se puede comparar una sola imagen para confirmar tu ' +
        'identidad. Si no coincide, el personal verificará tu identidad de otra forma; la pre-consulta no se ' +
        'bloquea por eso.',
    },
  ],
  datos: [
    'Pulso y variabilidad cardíaca estimados (no son un electrocardiograma).',
    'Frecuencia respiratoria aproximada.',
    'Índices de tensión facial, estrés y fatiga (apoyo, no diagnóstico).',
    'Respuestas del cuestionario de síntomas y antecedentes.',
    'Nivel de prioridad sugerido y sus motivos.',
    'Quién revisó el resultado y cuándo.',
  ],
  derechos: [
    'Acceder a tus resultados y pedir su explicación.',
    'Solicitar la corrección de datos erróneos.',
    'Solicitar la eliminación de tus datos de pre-consulta (sujeto a obligaciones clínicas y legales).',
    'Retirar el consentimiento para futuras pre-consultas.',
  ],
  retencion:
    'Los resultados se conservan junto a tu historia clínica para que el médico pueda compararlos. ' +
    'No se almacena el material audiovisual original.',
  contacto:
    'Para ejercer tus derechos o resolver dudas, acude a recepción del consultorio o escribe al correo de contacto institucional.',
  no_es_diagnostico: true,
  requiere_revision_humana: true,
};

/** Hash estable del texto para auditoría (no incluye la versión). */
const TEXTO_HASH = crypto
  .createHash('sha256')
  .update(JSON.stringify({ ...CONSENTIMIENTO, version: undefined }))
  .digest('hex');

module.exports = { CONSENTIMIENTO, TEXTO_HASH };
