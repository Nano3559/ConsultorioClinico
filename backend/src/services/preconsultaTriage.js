'use strict';

/**
 * Motor de triage de la PreConsulta IA.
 *
 * Diseño:
 *  - DETERMINISTA y EXPLICABLE: mismas entradas => mismo nivel y mismos
 *    motivos. Cada punto del puntaje queda registrado con su origen
 *    (cuestionario, signos estimados o expresión facial).
 *  - El nivel 1 es el más urgente y el 5 el menos urgente.
 *  - Las BANDERAS ROJAS no solo suman: imponen un techo de nivel (p. ej.
 *    dolor torácico + disnea => nunca mejor que nivel 1).
 *  - La IA NUNCA diagnostica ni decide sola: el resultado siempre requiere
 *    revisión humana y el backend lo guarda con `requiere_revision = true`.
 *
 * No hace I/O: recibe métricas ya calculadas por el microservicio de visión
 * y respuestas ya normalizadas. Así se puede probar con node:test sin BD,
 * sin cámara y sin modelos.
 */

const TRIAGE_VERSION = 'preconsulta-triage-1.0.0';

/** Niveles de prioridad (1 = atención inmediata). */
const NIVELES_TRIAGE = [
  { nivel: 1, clave: 'inmediato', etiqueta: 'Atención inmediata', color: '#DC2626', maxMinutos: 0 },
  { nivel: 2, clave: 'urgente', etiqueta: 'Urgente', color: '#EA580C', maxMinutos: 30 },
  { nivel: 3, clave: 'prioritario', etiqueta: 'Prioritario', color: '#D97706', maxMinutos: 120 },
  { nivel: 4, clave: 'programado', etiqueta: 'Programado', color: '#2563EB', maxMinutos: 240 },
  { nivel: 5, clave: 'no_urgente', etiqueta: 'No urgente', color: '#16A34A', maxMinutos: null },
];

const SECCIONES = [
  { clave: 'motivo', titulo: 'Motivo de consulta', descripcion: '¿Qué te trae hoy al consultorio?' },
  { clave: 'sintomas', titulo: 'Síntomas actuales', descripcion: 'Marca lo que sientas ahora o en las últimas horas.' },
  { clave: 'contexto', titulo: 'Contexto clínico', descripcion: 'Ayuda a interpretar tus síntomas con más seguridad.' },
];

/**
 * Catálogo único de preguntas. El frontend lo recibe desde
 * `GET /api/preconsulta/consentimiento` para no duplicar etiquetas.
 */
const CATALOGO_PREGUNTAS = [
  {
    codigo: 'motivo_principal',
    seccion: 'motivo',
    pregunta: 'Motivo principal de la consulta',
    ayuda: 'En tus palabras: qué te molesta y desde cuándo.',
    tipo: 'texto',
    min: 3,
    max: 300,
    requerida: true,
    orden: 10,
  },
  {
    codigo: 'dolor_intensidad',
    seccion: 'sintomas',
    pregunta: '¿Cuánto dolor sientes en este momento?',
    ayuda: '0 = sin dolor · 10 = el peor dolor imaginable.',
    tipo: 'escala',
    min: 0,
    max: 10,
    requerida: true,
    orden: 20,
  },
  {
    codigo: 'dolor_inicio',
    seccion: 'sintomas',
    pregunta: '¿Desde cuándo empezó el síntoma principal?',
    tipo: 'opcion',
    opciones: [
      { valor: 'hoy', etiqueta: 'Hoy (menos de 24 h)' },
      { valor: '1_3_dias', etiqueta: 'Hace 1 a 3 días' },
      { valor: '4_7_dias', etiqueta: 'Hace 4 a 7 días' },
      { valor: 'mas_7_dias', etiqueta: 'Hace más de una semana' },
    ],
    requerida: true,
    orden: 30,
  },
  {
    codigo: 'fiebre',
    seccion: 'sintomas',
    pregunta: '¿Has tenido fiebre medida?',
    tipo: 'opcion',
    opciones: [
      { valor: 'no', etiqueta: 'No / no la he medido' },
      { valor: '37_38', etiqueta: '37.5 – 38 °C' },
      { valor: '38_39', etiqueta: '38.1 – 39 °C' },
      { valor: 'mayor_39', etiqueta: 'Más de 39 °C' },
    ],
    requerida: true,
    orden: 40,
  },
  {
    codigo: 'dificultad_respiratoria',
    seccion: 'sintomas',
    pregunta: '¿Tienes dificultad para respirar?',
    tipo: 'opcion',
    opciones: [
      { valor: 'no', etiqueta: 'No' },
      { valor: 'esfuerzo', etiqueta: 'Sí, al hacer esfuerzo' },
      { valor: 'reposo', etiqueta: 'Sí, incluso en reposo' },
    ],
    requerida: true,
    orden: 50,
  },
  {
    codigo: 'dolor_toracico',
    seccion: 'sintomas',
    pregunta: '¿Sientes opresión, peso o dolor en el pecho?',
    tipo: 'si_no',
    requerida: true,
    orden: 60,
  },
  {
    codigo: 'mareo_desmayo',
    seccion: 'sintomas',
    pregunta: '¿Has tenido mareo o desmayo?',
    tipo: 'opcion',
    opciones: [
      { valor: 'no', etiqueta: 'No' },
      { valor: 'leve', etiqueta: 'Mareo leve' },
      { valor: 'intenso', etiqueta: 'Mareo intenso / casi me desmayo' },
      { valor: 'desmayo', etiqueta: 'Me desmayé' },
    ],
    requerida: true,
    orden: 70,
  },
  {
    codigo: 'sangrado',
    seccion: 'sintomas',
    pregunta: '¿Tienes algún sangrado?',
    tipo: 'opcion',
    opciones: [
      { valor: 'no', etiqueta: 'No' },
      { valor: 'leve', etiqueta: 'Leve (manchas o pequeñas heridas)' },
      { valor: 'abundante', etiqueta: 'Abundante o que no se detiene' },
    ],
    requerida: true,
    orden: 80,
  },
  {
    codigo: 'vomito',
    seccion: 'sintomas',
    pregunta: '¿Has vomitado en las últimas horas?',
    tipo: 'si_no',
    requerida: false,
    orden: 90,
  },
  {
    codigo: 'cefalea_intensa',
    seccion: 'sintomas',
    pregunta: '¿Tienes un dolor de cabeza súbito o muy intenso?',
    ayuda: 'Por ejemplo, el peor dolor de cabeza de tu vida o de inicio brusco.',
    tipo: 'si_no',
    requerida: false,
    orden: 100,
  },
  {
    codigo: 'rigidez_cuello',
    seccion: 'sintomas',
    pregunta: '¿Tienes rigidez de cuello o molestia con la luz?',
    tipo: 'si_no',
    requerida: false,
    orden: 110,
  },
  {
    codigo: 'embarazo',
    seccion: 'contexto',
    pregunta: '¿Estás embarazada o podría ser posible?',
    tipo: 'opcion',
    opciones: [
      { valor: 'no_aplica', etiqueta: 'No aplica' },
      { valor: 'no', etiqueta: 'No' },
      { valor: 'si', etiqueta: 'Sí / posible' },
    ],
    requerida: false,
    orden: 120,
  },
  {
    codigo: 'antecedentes',
    seccion: 'contexto',
    pregunta: '¿Tienes alguna de estas condiciones?',
    ayuda: 'Selecciona todas las que apliquen.',
    tipo: 'multiopcion',
    opciones: [
      { valor: 'ninguna', etiqueta: 'Ninguna' },
      { valor: 'hipertension', etiqueta: 'Hipertensión' },
      { valor: 'diabetes', etiqueta: 'Diabetes' },
      { valor: 'cardiopatia', etiqueta: 'Cardiopatía' },
      { valor: 'asma', etiqueta: 'Asma / EPOC' },
      { valor: 'inmunosupresion', etiqueta: 'Defensas bajas / inmunosupresión' },
      { valor: 'otra', etiqueta: 'Otra' },
    ],
    requerida: false,
    orden: 130,
  },
  {
    codigo: 'medicacion',
    seccion: 'contexto',
    pregunta: '¿Tomas medicación de forma habitual?',
    tipo: 'si_no',
    requerida: false,
    orden: 140,
  },
  {
    codigo: 'alergias',
    seccion: 'contexto',
    pregunta: '¿Tienes alergias conocidas?',
    ayuda: 'Medicamentos, alimentos u otras. Déjalo vacío si no tienes.',
    tipo: 'texto',
    min: 0,
    max: 200,
    requerida: false,
    orden: 150,
  },
  {
    codigo: 'sintomas_extra',
    seccion: 'contexto',
    pregunta: '¿Algo más que debamos saber?',
    ayuda: 'Opcional. Síntomas, dudas o cambios recientes.',
    tipo: 'texto',
    min: 0,
    max: 500,
    requerida: false,
    orden: 160,
  },
];

const PREGUNTAS_POR_CODIGO = new Map(CATALOGO_PREGUNTAS.map((p) => [p.codigo, p]));
const CODIGOS_VALIDOS = new Set(CATALOGO_PREGUNTAS.map((p) => p.codigo));

const limpiarTexto = (valor) =>
  String(valor == null ? '' : valor)
    .replace(/<[^>]*>?/gm, '')
    .replace(/\s+/g, ' ')
    .trim();

/**
 * Valida y normaliza las respuestas del cuestionario.
 * @param {unknown} entrada [{ codigo, valor }]
 * @returns {{ ok: boolean, errores: Array<{codigo:string,mensaje:string}>, respuestas: Object }}
 */
function validarRespuestas(entrada) {
  const errores = [];
  const respuestas = {};

  if (entrada == null) {
    return { ok: true, errores, respuestas };
  }
  if (!Array.isArray(entrada)) {
    return {
      ok: false,
      errores: [{ codigo: 'respuestas', mensaje: 'Las respuestas deben enviarse como lista' }],
      respuestas,
    };
  }

  for (const item of entrada) {
    if (!item || typeof item !== 'object') {
      errores.push({ codigo: 'respuestas', mensaje: 'Cada respuesta debe ser un objeto { codigo, valor }' });
      continue;
    }
    const codigo = limpiarTexto(item.codigo);
    if (!CODIGOS_VALIDOS.has(codigo)) {
      errores.push({ codigo, mensaje: `Pregunta desconocida: ${codigo || '(vacía)'}` });
      continue;
    }
    const pregunta = PREGUNTAS_POR_CODIGO.get(codigo);
    const valor = item.valor;

    if (pregunta.tipo === 'texto') {
      const texto = limpiarTexto(valor);
      if (pregunta.requerida && texto.length < pregunta.min) {
        errores.push({ codigo, mensaje: `"${pregunta.pregunta}" requiere al menos ${pregunta.min} caracteres` });
        continue;
      }
      if (texto.length > pregunta.max) {
        errores.push({ codigo, mensaje: `"${pregunta.pregunta}" no puede superar ${pregunta.max} caracteres` });
        continue;
      }
      respuestas[codigo] = texto;
      continue;
    }

    if (pregunta.tipo === 'escala') {
      const numero = Number(valor);
      if (!Number.isFinite(numero) || numero < pregunta.min || numero > pregunta.max) {
        errores.push({ codigo, mensaje: `"${pregunta.pregunta}" debe estar entre ${pregunta.min} y ${pregunta.max}` });
        continue;
      }
      respuestas[codigo] = Math.round(numero * 10) / 10;
      continue;
    }

    if (pregunta.tipo === 'si_no') {
      if (valor === true || valor === 'true' || valor === 'si' || valor === 'sí' || valor === 1 || valor === '1') {
        respuestas[codigo] = true;
      } else if (valor === false || valor === 'false' || valor === 'no' || valor === 0 || valor === '0' || valor == null) {
        respuestas[codigo] = false;
      } else {
        errores.push({ codigo, mensaje: `"${pregunta.pregunta}" debe responderse sí o no` });
      }
      continue;
    }

    if (pregunta.tipo === 'opcion') {
      if (valor == null || valor === '') continue; // opcional sin responder
      const permitidos = pregunta.opciones.map((o) => o.valor);
      const texto = limpiarTexto(valor);
      if (!permitidos.includes(texto)) {
        errores.push({ codigo, mensaje: `Valor inválido para "${pregunta.pregunta}"` });
        continue;
      }
      respuestas[codigo] = texto;
      continue;
    }

    if (pregunta.tipo === 'multiopcion') {
      const lista = Array.isArray(valor) ? valor : [];
      const permitidos = pregunta.opciones.map((o) => o.valor);
      const normalizada = [];
      for (const v of lista) {
        const texto = limpiarTexto(v);
        if (!permitidos.includes(texto)) {
          errores.push({ codigo, mensaje: `Valor inválido para "${pregunta.pregunta}"` });
          normalizada.length = 0;
          break;
        }
        if (!normalizada.includes(texto)) normalizada.push(texto);
      }
      if (normalizada.length === 0) {
        respuestas[codigo] = [];
      } else {
        respuestas[codigo] = normalizada.filter((v) => v !== 'ninguna' || normalizada.length === 1);
      }
    }
  }

  // Requeridas ausentes.
  for (const pregunta of CATALOGO_PREGUNTAS) {
    if (!pregunta.requerida) continue;
    const v = respuestas[pregunta.codigo];
    const vacia = v === undefined || v === null || v === '' || (Array.isArray(v) && v.length === 0);
    if (vacia) {
      errores.push({ codigo: pregunta.codigo, mensaje: `Falta responder "${pregunta.pregunta}"` });
    }
  }

  return { ok: errores.length === 0, errores, respuestas };
}

/** Etiqueta legible de una respuesta (para historial y explicación). */
function etiquetaRespuesta(codigo, valor) {
  const pregunta = PREGUNTAS_POR_CODIGO.get(codigo);
  if (!pregunta) return String(valor ?? '');
  if (pregunta.tipo === 'si_no') return valor ? 'Sí' : 'No';
  if (pregunta.tipo === 'escala') return `${valor}/10`;
  if (pregunta.tipo === 'multiopcion') {
    if (!Array.isArray(valor) || valor.length === 0) return 'Ninguna';
    return valor
      .map((v) => (pregunta.opciones.find((o) => o.valor === v) || {}).etiqueta || v)
      .join(', ');
  }
  if (pregunta.tipo === 'opcion') {
    return (pregunta.opciones.find((o) => o.valor === valor) || {}).etiqueta || String(valor ?? '');
  }
  return limpiarTexto(valor);
}

/** Redondeo estable a n decimales. */
const r = (valor, decimales = 1) => {
  const n = Number(valor);
  if (!Number.isFinite(n)) return null;
  const factor = 10 ** decimales;
  return Math.round(n * factor) / factor;
};

const clamp = (valor, min, max) => Math.min(max, Math.max(min, valor));

/**
 * Evalúa el triage.
 *
 * @param {object} entrada
 * @param {object} [entrada.metricas]  Signos/rostro ya calculados (snake_case)
 * @param {object} [entrada.respuestas] Respuestas normalizadas por código
 * @param {object|null} [entrada.paciente] { fecha_nacimiento, antecedentes, alergias }
 * @returns {object} resultado completo listo para persistir y mostrar
 */
function evaluarTriage({ metricas = {}, respuestas = {}, paciente = null } = {}) {
  const m = metricas || {};
  const resp = respuestas || {};

  const motivos = [];
  const banderas = [];
  const recomendaciones = [];
  let score = 0;
  let techo = 5;

  const addMotivo = (codigo, etiqueta, peso, detalle, fuente) => {
    if (!peso && peso !== 0) return;
    score += peso;
    motivos.push({
      codigo,
      etiqueta,
      peso: r(peso, 1),
      detalle: detalle || '',
      fuente,
    });
  };

  const addBandera = (codigo, severidad, texto, techoNivel) => {
    banderas.push({ codigo, severidad, texto });
    if (techoNivel != null) techo = Math.min(techo, techoNivel);
  };

  // ---------------------------------------------------------------------
  // 1) BANDERAS ROJAS (seguridad del paciente). Se evalúan primero.
  // ---------------------------------------------------------------------
  const disnea = resp.dificultad_respiratoria;
  const dolorToracico = resp.dolor_toracico === true;
  const mareo = resp.mareo_desmayo;
  const sangrado = resp.sangrado;
  const fiebre = resp.fiebre;
  const cefalea = resp.cefalea_intensa === true;
  const rigidez = resp.rigidez_cuello === true;
  const embarazo = resp.embarazo === 'si';

  if (dolorToracico && (disnea === 'reposo' || disnea === 'esfuerzo')) {
    addBandera(
      'dolor_toracico_disnea',
      'critica',
      'Dolor torácico con dificultad para respirar: posible emergencia cardiovascular o respiratoria.',
      1
    );
    addMotivo('bandera_dolor_toracico_disnea', 'Dolor en el pecho + disnea', 30, 'Combinación de alarma que exige valoración inmediata.', 'cuestionario');
  } else if (dolorToracico && (mareo === 'intenso' || mareo === 'desmayo')) {
    addBandera(
      'dolor_toracico_mareo',
      'critica',
      'Dolor torácico con mareo intenso o desmayo: posible emergencia cardiovascular.',
      1
    );
    addMotivo('bandera_dolor_toracico_mareo', 'Dolor en el pecho + mareo/desmayo', 30, 'Combinación de alarma que exige valoración inmediata.', 'cuestionario');
  } else if (dolorToracico) {
    addBandera(
      'dolor_toracico',
      'alta',
      'Dolor torácico: requiere valoración prioritaria y toma de signos.',
      2
    );
    addMotivo('bandera_dolor_toracico', 'Dolor en el pecho', 22, 'Síntoma que nunca debe esperar sin valoración.', 'cuestionario');
  }

  if (disnea === 'reposo') {
    addBandera('disnea_reposo', 'critica', 'Dificultad para respirar en reposo: valoración inmediata.', 1);
    addMotivo('bandera_disnea_reposo', 'Disnea en reposo', 28, 'La falta de aire en reposo es una señal de alarma.', 'cuestionario');
  } else if (disnea === 'esfuerzo') {
    addBandera('disnea_esfuerzo', 'media', 'Dificultad para respirar al esfuerzo: priorizar y valorar.', 3);
    addMotivo('bandera_disnea_esfuerzo', 'Disnea de esfuerzo', 10, 'Puede indicar compromiso respiratorio o cardiovascular.', 'cuestionario');
  }

  if (sangrado === 'abundante') {
    addBandera('sangrado_abundante', 'critica', 'Sangrado abundante o que no se detiene: atención inmediata.', 1);
    addMotivo('bandera_sangrado', 'Sangrado abundante', 28, 'Riesgo de pérdida significativa de sangre.', 'cuestionario');
  } else if (sangrado === 'leve') {
    addMotivo('sangrado_leve', 'Sangrado leve', 4, 'Vigilar evolución y detener el sangrado.', 'cuestionario');
  }

  if (mareo === 'desmayo') {
    addBandera('desmayo', 'alta', 'Pérdida de consciencia: valorar causa y riesgo de caída.', 2);
    addMotivo('bandera_desmayo', 'Desmayo', 20, 'Requiere valoración para descartar causas graves.', 'cuestionario');
  } else if (mareo === 'intenso') {
    addBandera('mareo_intenso', 'media', 'Mareo intenso: riesgo de caída, acompañar al paciente.', 3);
    addMotivo('mareo_intenso', 'Mareo intenso', 8, 'Vigilar presión arterial y seguridad.', 'cuestionario');
  }

  if (fiebre === 'mayor_39' && rigidez) {
    addBandera('fiebre_rigidez', 'critica', 'Fiebre alta con rigidez de cuello o molestia a la luz: atención inmediata.', 1);
    addMotivo('bandera_fiebre_rigidez', 'Fiebre + rigidez de cuello', 30, 'Combinación que requiere descartar infección grave.', 'cuestionario');
  } else if (rigidez) {
    addBandera('rigidez_cuello', 'media', 'Rigidez de cuello o molestia con la luz: valorar de forma prioritaria.', 3);
    addMotivo('rigidez_cuello', 'Rigidez de cuello / fotofobia', 12, 'Síntoma neurológico que debe evaluarse.', 'cuestionario');
  }

  if (cefalea) {
    addBandera('cefalea_súbita', 'alta', 'Cefalea súbita o muy intensa: valoración prioritaria.', 2);
    addMotivo('bandera_cefalea', 'Cefalea súbita/intensa', 18, 'El inicio brusco o la intensidad máxima son señales de alarma.', 'cuestionario');
  }

  if (embarazo && sangrado && sangrado !== 'no') {
    addBandera('embarazo_sangrado', 'alta', 'Embarazo con sangrado: valoración obstétrica prioritaria.', 2);
    addMotivo('bandera_embarazo_sangrado', 'Embarazo + sangrado', 20, 'Requiere evaluación obstétrica sin demora.', 'cuestionario');
  }

  // ---------------------------------------------------------------------
  // 2) CUESTIONARIO (peso clínico)
  // ---------------------------------------------------------------------
  const dolor = Number(resp.dolor_intensidad);
  if (Number.isFinite(dolor)) {
    if (dolor >= 9) {
      addMotivo('dolor_severo', 'Dolor severo', 20, `El paciente reporta ${dolor}/10.`, 'cuestionario');
      techo = Math.min(techo, 2);
    } else if (dolor >= 7) {
      addMotivo('dolor_alto', 'Dolor alto', 12, `El paciente reporta ${dolor}/10.`, 'cuestionario');
    } else if (dolor >= 4) {
      addMotivo('dolor_moderado', 'Dolor moderado', 6, `El paciente reporta ${dolor}/10.`, 'cuestionario');
    }
  }

  const inicio = resp.dolor_inicio;
  if (inicio === 'hoy') {
    addMotivo('inicio_agudo', 'Inicio agudo (menos de 24 h)', 6, 'Los síntomas de aparición reciente requieren vigilancia.', 'cuestionario');
  } else if (inicio === '1_3_dias') {
    addMotivo('inicio_reciente', 'Inicio reciente (1-3 días)', 3, '', 'cuestionario');
  } else if (inicio === '4_7_dias') {
    addMotivo('inicio_semana', 'Evolución de 4-7 días', 1, '', 'cuestionario');
  }

  if (fiebre === 'mayor_39') {
    addMotivo('fiebre_alta', 'Fiebre mayor a 39 °C', 16, 'La fiebre alta requiere valoración y control térmico.', 'cuestionario');
    techo = Math.min(techo, 3);
  } else if (fiebre === '38_39') {
    addMotivo('fiebre_moderada', 'Fiebre 38.1-39 °C', 8, '', 'cuestionario');
  } else if (fiebre === '37_38') {
    addMotivo('febricula', 'Febrícula 37.5-38 °C', 3, '', 'cuestionario');
  }

  if (resp.vomito === true) {
    addMotivo('vomito', 'Vómitos', 4, 'Vigilar hidratación.', 'cuestionario');
  }

  if (embarazo) {
    addMotivo('embarazo', 'Embarazo o posibilidad', 4, 'Ajustar decisiones clínicas y evitar riesgos.', 'contexto');
  }

  // Antecedentes del cuestionario + ficha del paciente.
  const antecedentes = Array.isArray(resp.antecedentes) ? resp.antecedentes : [];
  const pesosAntecedentes = {
    cardiopatia: 4,
    inmunosupresion: 3,
    hipertension: 2,
    diabetes: 2,
    asma: 2,
    otra: 1,
  };
  const antecedentesSumados = antecedentes.filter((a) => a !== 'ninguna');
  const pesoAntecedentes = antecedentesSumados.reduce((total, a) => total + (pesosAntecedentes[a] || 1), 0);
  if (pesoAntecedentes > 0) {
    addMotivo(
      'antecedentes',
      'Antecedentes de riesgo',
      Math.min(pesoAntecedentes, 8),
      antecedentesSumados.map((a) => ((PREGUNTAS_POR_CODIGO.get('antecedentes').opciones.find((o) => o.valor === a) || {}).etiqueta || a)).join(', '),
      'contexto'
    );
  }

  // Edad y antecedentes de la ficha (si están disponibles).
  let edad = null;
  if (paciente && paciente.fecha_nacimiento) {
    const nacimiento = new Date(paciente.fecha_nacimiento);
    if (!Number.isNaN(nacimiento.getTime())) {
      const hoy = new Date();
      edad = hoy.getFullYear() - nacimiento.getFullYear();
      const mes = hoy.getMonth() - nacimiento.getMonth();
      if (mes < 0 || (mes === 0 && hoy.getDate() < nacimiento.getDate())) edad -= 1;
    }
  }
  if (edad != null && edad >= 0) {
    if (edad >= 70) {
      addMotivo('edad_mayor_70', 'Edad mayor a 70 años', 4, `${edad} años.`, 'contexto');
    } else if (edad >= 60) {
      addMotivo('edad_mayor_60', 'Edad mayor a 60 años', 2, `${edad} años.`, 'contexto');
    } else if (edad <= 5) {
      addMotivo('edad_pediatrica', 'Edad pediátrica', 3, `${edad} años.`, 'contexto');
    }
  }

  const antecedentesFicha = limpiarTexto(paciente && paciente.antecedentes).toLowerCase();
  if (antecedentesFicha) {
    const cronicas = [];
    if (/hipertens/.test(antecedentesFicha)) cronicas.push('hipertensión');
    if (/diabet/.test(antecedentesFicha)) cronicas.push('diabetes');
    if (/(cardio|coronar|arritmia|infarto)/.test(antecedentesFicha)) cronicas.push('cardiopatía');
    if (/(asma|epoc|respirator)/.test(antecedentesFicha)) cronicas.push('asma/EPOC');
    if (cronicas.length > 0 && antecedentesSumados.length === 0) {
      addMotivo('antecedentes_ficha', 'Antecedentes en ficha clínica', Math.min(cronicas.length * 2, 5), cronicas.join(', '), 'contexto');
    }
  }

  // ---------------------------------------------------------------------
  // 3) SIGNOS ESTIMADOS POR rPPG (solo si hay confianza suficiente)
  // ---------------------------------------------------------------------
  const calidad = Number(m.calidad_captura);
  const calidadBaja = Number.isFinite(calidad) && calidad < 55;
  const senalConf = Number(m.senal_confianza);
  const rostroOk = m.rostro_detectado === true;

  if (!rostroOk) {
    addMotivo('sin_captura', 'Sin captura facial válida', 0, 'El triage usa solo el cuestionario.', 'signos');
  } else if (calidadBaja) {
    addMotivo('calidad_baja', 'Calidad de captura baja', 0, `Calidad ${r(calidad, 0)}/100: los signos estimados no son concluyentes.`, 'signos');
  }

  const hr = Number(m.hr_bpm);
  const hrConf = Number(m.hr_confianza);
  const hrUsable = rostroOk && !calidadBaja && Number.isFinite(hr) && (!Number.isFinite(hrConf) || hrConf >= 0.45);
  if (hrUsable) {
    if (hr > 140) {
      addMotivo('fc_muy_alta', 'Frecuencia cardíaca muy elevada', 22, `FC estimada ${r(hr, 0)} lpm (confianza ${r(hrConf ?? 0.7, 2)}).`, 'signos');
      banderas.push({ codigo: 'taquicardia_marcada', severidad: 'alta', texto: 'FC estimada > 140 lpm: confirmar con pulso manual.' });
      techo = Math.min(techo, 2);
    } else if (hr > 120) {
      addMotivo('fc_alta', 'Frecuencia cardíaca elevada', 14, `FC estimada ${r(hr, 0)} lpm.`, 'signos');
    } else if (hr > 100) {
      addMotivo('fc_levemente_alta', 'FC levemente elevada', 8, `FC estimada ${r(hr, 0)} lpm.`, 'signos');
    } else if (hr < 50) {
      addMotivo('fc_baja', 'Frecuencia cardíaca baja', 10, `FC estimada ${r(hr, 0)} lpm.`, 'signos');
    }
  } else if (rostroOk && !calidadBaja) {
    addMotivo('fc_no_concluyente', 'Frecuencia cardíaca no concluyente', 0, 'La señal no alcanzó confianza suficiente; se ignora en el puntaje.', 'signos');
  }

  const rmssd = Number(m.rmssd_ms);
  const hrvConf = Number(m.hrv_confianza);
  const hrvUsable = rostroOk && !calidadBaja && Number.isFinite(rmssd) && (!Number.isFinite(hrvConf) || hrvConf >= 0.4);
  if (hrvUsable) {
    if (rmssd < 15) {
      addMotivo('hrv_muy_baja', 'Variabilidad cardíaca muy baja', 6, `RMSSD estimado ${r(rmssd, 0)} ms: sugiere activación fisiológica.`, 'signos');
    } else if (rmssd < 25) {
      addMotivo('hrv_baja', 'Variabilidad cardíaca baja', 3, `RMSSD estimado ${r(rmssd, 0)} ms.`, 'signos');
    }
  }

  const stress = Number(m.stress_score);
  const stressUsable = rostroOk && Number.isFinite(stress);
  if (stressUsable) {
    if (stress >= 75) {
      addMotivo('estres_alto', 'Estrés facial alto', 8, `Índice ${r(stress, 0)}/100.`, 'facial');
    } else if (stress >= 55) {
      addMotivo('estres_moderado', 'Estrés facial moderado', 4, `Índice ${r(stress, 0)}/100.`, 'facial');
    }
  }

  const fatiga = Number(m.fatigue_score);
  if (rostroOk && Number.isFinite(fatiga) && fatiga >= 75) {
    addMotivo('fatiga_alta', 'Fatiga facial alta', 4, `Índice ${r(fatiga, 0)}/100.`, 'facial');
  }

  const painFacial = Number(m.pain_score);
  const painConf = Number(m.pain_confianza);
  const painUsable = rostroOk && Number.isFinite(painFacial) && (!Number.isFinite(painConf) || painConf >= 0.45);
  if (painUsable) {
    if (painFacial >= 6.5 && Number.isFinite(dolor) && dolor <= 3) {
      addMotivo(
        'discrepancia_dolor',
        'Posible dolor no reportado',
        8,
        `Expresión de dolor ${r(painFacial, 1)}/10 con dolor reportado ${dolor}/10.`,
        'facial'
      );
      recomendaciones.push('Preguntar directamente por dolor: la expresión facial sugiere más tensión de la reportada.');
    } else if (painFacial >= 6.5) {
      addMotivo('dolor_facial_alto', 'Expresión facial de dolor alta', 5, `Índice ${r(painFacial, 1)}/10.`, 'facial');
    } else if (painFacial >= 4) {
      addMotivo('dolor_facial_moderado', 'Expresión facial de tensión', 2, `Índice ${r(painFacial, 1)}/10.`, 'facial');
    }
  }

  // ---------------------------------------------------------------------
  // 4) NIVEL FINAL
  // ---------------------------------------------------------------------
  const scoreFinal = Math.max(0, Math.round(score));
  let nivel;
  if (scoreFinal >= 55) nivel = 1;
  else if (scoreFinal >= 38) nivel = 2;
  else if (scoreFinal >= 24) nivel = 3;
  else if (scoreFinal >= 12) nivel = 4;
  else nivel = 5;

  // Los techos (banderas rojas) solo pueden SUBIR la urgencia (bajar el nivel).
  nivel = clamp(Math.min(nivel, techo), 1, 5);

  // Si no hay ni cuestionario ni signos, no se inventa un nivel "tranquilo".
  const hayRespuestas = Object.keys(resp).length > 0;
  const haySignos = rostroOk && !calidadBaja && Number.isFinite(hr);
  if (!hayRespuestas && !haySignos) {
    nivel = 3;
    recomendaciones.push('Sin datos suficientes: el personal debe hacer el triage manual.');
  } else if (!haySignos) {
    recomendaciones.push('No hubo estimación de signos: confirmar frecuencia cardíaca y saturación con equipos de recepción.');
  } else if (calidadBaja) {
    recomendaciones.push('Repetir la captura con mejor iluminación y el rostro centrado para confirmar los signos.');
  }

  // Confianza del resultado (no del nivel clínico real).
  let confianza = 0.94;
  if (!haySignos) confianza -= 0.24;
  else if (calidadBaja) confianza -= 0.12;
  if (!hrvUsable) confianza -= 0.06;
  if (!hayRespuestas) confianza -= 0.18;
  if (banderas.some((b) => b.severidad === 'critica')) confianza += 0.04;
  if (!Number.isFinite(senalConf) || senalConf < 0.4) confianza -= 0.05;
  confianza = clamp(r(confianza, 3), 0.3, 0.96);

  // ---------------------------------------------------------------------
  // 5) RECOMENDACIONES BASE POR NIVEL
  // ---------------------------------------------------------------------
  const base = {
    1: 'Atención inmediata: avisar ahora a recepción/enfermería y no dejar solo al paciente.',
    2: 'Atender en los próximos 30 minutos. Reevaluar de inmediato si empeora.',
    3: 'Priorizar en la cola del día; reevaluar en 1-2 horas.',
    4: 'Atención programada: puede esperar su turno con control periódico.',
    5: 'No urgente: puede esperar su turno habitual.',
  };
  recomendaciones.unshift(base[nivel]);

  if (hrUsable && hr > 120) {
    recomendaciones.push('Confirmar la frecuencia cardíaca con pulso manual o tensiómetro antes de decidir.');
  }
  if (banderas.some((b) => b.severidad === 'critica')) {
    recomendaciones.push('Ante señales críticas, activar el protocolo de emergencia del consultorio.');
  }
  recomendaciones.push('Apoyo al triage: no sustituye la valoración clínica ni emite diagnósticos.');

  if (!motivos.some((x) => x.codigo === 'sin_hallazgos') && motivos.length === 0) {
    motivos.push({
      codigo: 'sin_hallazgos',
      etiqueta: 'Sin hallazgos de alarma',
      peso: 0,
      detalle: 'No se identificaron señales de alarma en el cuestionario ni en la captura.',
      fuente: 'sistema',
    });
  }

  const nivelMeta = NIVELES_TRIAGE.find((n) => n.nivel === nivel);
  const resumenPartes = [];
  resumenPartes.push(`Nivel ${nivel} · ${nivelMeta.etiqueta}`);
  if (Number.isFinite(dolor)) resumenPartes.push(`dolor ${dolor}/10`);
  if (hrUsable) resumenPartes.push(`FC ${r(hr, 0)} lpm`);
  if (banderas.length > 0) resumenPartes.push(`${banderas.length} bandera${banderas.length === 1 ? '' : 's'}`);

  return {
    nivel,
    nivel_etiqueta: nivelMeta.etiqueta,
    nivel_clave: nivelMeta.clave,
    confianza,
    score: scoreFinal,
    motivos: motivos.map((x) => ({ ...x, peso: x.peso == null ? 0 : x.peso })),
    banderas,
    recomendaciones: [...new Set(recomendaciones)],
    resumen: resumenPartes.join(' · '),
    version: TRIAGE_VERSION,
    requiere_revision: true,
    fuentes: {
      cuestionario: hayRespuestas,
      signos: haySignos,
      facial: rostroOk && Number.isFinite(painFacial),
    },
  };
}

module.exports = {
  TRIAGE_VERSION,
  NIVELES_TRIAGE,
  SECCIONES,
  CATALOGO_PREGUNTAS,
  PREGUNTAS_POR_CODIGO,
  validarRespuestas,
  etiquetaRespuesta,
  evaluarTriage,
};
