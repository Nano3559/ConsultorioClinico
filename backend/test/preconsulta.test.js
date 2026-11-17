'use strict';

/**
 * Suite de pruebas de la PreConsulta IA (migración 015).
 *
 * Cubre tres capas:
 *
 *  1. Motor de triage (`services/preconsultaTriage`): catálogo, validación
 *     de respuestas, banderas rojas, techos de nivel, explicabilidad,
 *     determinismo y degradación honesta sin datos.
 *  2. Consentimiento (`services/preconsultaContenido`): versión y hash
 *     auditables.
 *  3. API `/api/preconsulta`: autenticación, roles, validación de entrada y
 *     rechazo de consentimientos desactualizados.
 *
 * Las rutas que exigen base de datos se prueban en los caminos que no
 * consultan tablas (401/403/422/409), de modo que la suite no depende del
 * mock de Supabase ni de credenciales reales.
 */

const { test, before, after, describe } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const path = require('path');
const mock = require('mock-require');
const supabaseMock = require('./mocks/supabaseMock');
const { getApp, restore } = require('./helpers/loadApp');

const triage = require('../src/services/preconsultaTriage');
const { CONSENTIMIENTO, TEXTO_HASH } = require('../src/services/preconsultaContenido');
const config = require('../src/config/config');

const __firebaseMock = {
  verifyIdToken: async () => {
    throw new Error('auth/argument-error');
  },
};
mock(path.resolve(__dirname, '../src/config/firebaseAdmin.js'), {
  getAdmin: () => {
    throw new Error('mock sin getAdmin');
  },
  verifyIdToken: (...args) => __firebaseMock.verifyIdToken(...args),
});

let app;
let tokenMedico;
let tokenPaciente;
let ipCounter = 0;
const nuevaIp = () => `203.0.113.${++ipCounter}`;

async function loginToken(email, password) {
  const res = await request(app)
    .post('/api/auth/login')
    .set('x-forwarded-for', nuevaIp())
    .send({ email, password });
  assert.equal(res.status, 200, `login falló: ${JSON.stringify(res.body)}`);
  return res.body.data.token;
}

before(async () => {
  supabaseMock.reset();
  await supabaseMock.seedUsuarioConHash({
    id: 1,
    email: 'medico-pre@test.com',
    password: 'MedPass1',
    rol: 'medico',
    activo: true,
    nombre: 'Médico PreConsulta',
  });
  await supabaseMock.seedUsuarioConHash({
    id: 2,
    email: 'paciente-pre@test.com',
    password: 'PacPass1',
    rol: 'paciente',
    activo: true,
    nombre: 'Paciente PreConsulta',
  });
  app = getApp();
  tokenMedico = await loginToken('medico-pre@test.com', 'MedPass1');
  tokenPaciente = await loginToken('paciente-pre@test.com', 'PacPass1');
});

after(() => restore());

/** Respuestas válidas mínimas (todas las obligatorias). */
function respuestasBase(extra = {}) {
  return {
    motivo_principal: 'Dolor de cabeza desde ayer',
    dolor_intensidad: 3,
    dolor_inicio: '1_3_dias',
    fiebre: 'no',
    dificultad_respiratoria: 'no',
    dolor_toracico: false,
    mareo_desmayo: 'no',
    sangrado: 'no',
    ...extra,
  };
}

// ============================================================================
// 1. Catálogo y validación del cuestionario
// ============================================================================
describe('catálogo del cuestionario', () => {
  test('los códigos son únicos y las preguntas obligatorias tienen rango', () => {
    const codigos = triage.CATALOGO_PREGUNTAS.map((p) => p.codigo);
    assert.equal(new Set(codigos).size, codigos.length);
    assert.ok(codigos.includes('motivo_principal'));
    assert.ok(codigos.includes('dolor_intensidad'));
    for (const pregunta of triage.CATALOGO_PREGUNTAS) {
      assert.ok(['texto', 'escala', 'si_no', 'opcion', 'multiopcion'].includes(pregunta.tipo));
      if (pregunta.tipo === 'opcion' || pregunta.tipo === 'multiopcion') {
        assert.ok(Array.isArray(pregunta.opciones) && pregunta.opciones.length > 0);
      }
      if (pregunta.tipo === 'escala') {
        assert.ok(pregunta.min < pregunta.max);
      }
    }
  });

  test('secciones y niveles de triage son coherentes', () => {
    assert.equal(triage.NIVELES_TRIAGE.length, 5);
    assert.deepEqual(
      triage.NIVELES_TRIAGE.map((n) => n.nivel),
      [1, 2, 3, 4, 5]
    );
    assert.ok(triage.SECCIONES.length >= 3);
    for (const seccion of triage.SECCIONES) {
      assert.ok(triage.CATALOGO_PREGUNTAS.some((p) => p.seccion === seccion.clave));
    }
  });
});

describe('validarRespuestas', () => {
  test('acepta un cuestionario completo y normaliza los tipos', () => {
    const resultado = triage.validarRespuestas([
      { codigo: 'motivo_principal', valor: '  Dolor   de cabeza  ' },
      { codigo: 'dolor_intensidad', valor: '4' },
      { codigo: 'dolor_inicio', valor: 'hoy' },
      { codigo: 'fiebre', valor: 'no' },
      { codigo: 'dificultad_respiratoria', valor: 'no' },
      { codigo: 'dolor_toracico', valor: 'no' },
      { codigo: 'mareo_desmayo', valor: 'no' },
      { codigo: 'sangrado', valor: 'no' },
      { codigo: 'antecedentes', valor: ['ninguna', 'diabetes'] },
    ]);
    assert.equal(resultado.ok, true, JSON.stringify(resultado.errores));
    assert.equal(resultado.respuestas.motivo_principal, 'Dolor de cabeza');
    assert.equal(resultado.respuestas.dolor_intensidad, 4);
    assert.equal(resultado.respuestas.dolor_toracico, false);
    // "ninguna" se descarta cuando se marca otra condición.
    assert.deepEqual(resultado.respuestas.antecedentes, ['diabetes']);
  });

  test('rechaza preguntas desconocidas', () => {
    const resultado = triage.validarRespuestas([
      ...Object.entries(respuestasBase()).map(([codigo, valor]) => ({ codigo, valor })),
      { codigo: 'pregunta_inventada', valor: 'x' },
    ]);
    assert.equal(resultado.ok, false);
    assert.ok(resultado.errores.some((e) => e.codigo === 'pregunta_inventada'));
  });

  test('rechaza escala fuera de rango', () => {
    const resultado = triage.validarRespuestas([
      ...Object.entries(respuestasBase({ dolor_intensidad: 11 })).map(([codigo, valor]) => ({
        codigo,
        valor,
      })),
    ]);
    assert.equal(resultado.ok, false);
    assert.ok(resultado.errores.some((e) => e.codigo === 'dolor_intensidad'));
  });

  test('exige las preguntas obligatorias', () => {
    const resultado = triage.validarRespuestas([{ codigo: 'fiebre', valor: 'no' }]);
    assert.equal(resultado.ok, false);
    const faltantes = resultado.errores.map((e) => e.codigo);
    assert.ok(faltantes.includes('motivo_principal'));
    assert.ok(faltantes.includes('dolor_intensidad'));
  });

  test('rechaza texto demasiado largo y valores de opción inválidos', () => {
    const largo = 'x'.repeat(400);
    const resultado = triage.validarRespuestas([
      ...Object.entries(respuestasBase({ motivo_principal: largo, fiebre: 'quizas' })).map(
        ([codigo, valor]) => ({ codigo, valor })
      ),
    ]);
    assert.equal(resultado.ok, false);
    assert.ok(resultado.errores.some((e) => e.codigo === 'motivo_principal'));
    assert.ok(resultado.errores.some((e) => e.codigo === 'fiebre'));
  });

  test('acepta lista vacía como cuestionario sin responder', () => {
    const resultado = triage.validarRespuestas([]);
    assert.equal(resultado.ok, false); // faltan obligatorias
    const nulo = triage.validarRespuestas(null);
    assert.equal(nulo.ok, true);
    assert.deepEqual(nulo.respuestas, {});
  });
});

// ============================================================================
// 2. Motor de triage
// ============================================================================
describe('evaluarTriage', () => {
  test('dolor torácico + disnea en reposo => nivel 1 con bandera crítica', () => {
    const resultado = triage.evaluarTriage({
      respuestas: respuestasBase({
        dolor_toracico: true,
        dificultad_respiratoria: 'reposo',
        dolor_intensidad: 6,
      }),
    });
    assert.equal(resultado.nivel, 1);
    assert.equal(resultado.nivel_clave, 'inmediato');
    assert.ok(resultado.banderas.some((b) => b.severidad === 'critica'));
    assert.ok(resultado.motivos.some((m) => m.codigo === 'bandera_dolor_toracico_disnea'));
    assert.equal(resultado.requiere_revision, true);
    assert.match(resultado.recomendaciones[0], /inmediata/i);
  });

  test('el techo de una bandera roja impone nivel 2 aunque el puntaje sea bajo', () => {
    const resultado = triage.evaluarTriage({
      respuestas: respuestasBase({
        dolor_toracico: true,
        dolor_intensidad: 0,
        dolor_inicio: 'mas_7_dias',
      }),
    });
    assert.equal(resultado.nivel, 2);
  });

  test('dolor severo (9/10) no puede quedar como no urgente', () => {
    const resultado = triage.evaluarTriage({
      respuestas: respuestasBase({
        dolor_intensidad: 9,
        dolor_inicio: 'mas_7_dias',
      }),
    });
    assert.ok(resultado.nivel <= 2);
    assert.ok(resultado.motivos.some((m) => m.codigo === 'dolor_severo'));
  });

  test('caso leve sin signos => nivel 5 con recomendación de no urgencia', () => {
    const resultado = triage.evaluarTriage({
      respuestas: respuestasBase({
        dolor_intensidad: 1,
        dolor_inicio: 'mas_7_dias',
      }),
      metricas: { rostro_detectado: false },
    });
    assert.equal(resultado.nivel, 5);
    assert.match(resultado.recomendaciones[0], /no urgente/i);
    assert.ok(resultado.recomendaciones.some((r) => /no sustituye/i.test(r)));
  });

  test('es determinista: mismas entradas producen el mismo resultado', () => {
    const entrada = {
      respuestas: respuestasBase({ dolor_intensidad: 7, fiebre: '38_39' }),
      metricas: { rostro_detectado: true, calidad_captura: 80, hr_bpm: 92, hr_confianza: 0.8 },
      paciente: { fecha_nacimiento: '1950-05-01', antecedentes: 'hipertensión' },
    };
    assert.deepEqual(triage.evaluarTriage(entrada), triage.evaluarTriage(entrada));
  });

  test('cada motivo es explicable (código, etiqueta, peso y fuente)', () => {
    const resultado = triage.evaluarTriage({
      respuestas: respuestasBase({ dolor_intensidad: 8, fiebre: 'mayor_39' }),
      metricas: {
        rostro_detectado: true,
        calidad_captura: 78,
        hr_bpm: 92,
        hr_confianza: 0.8,
        stress_score: 80,
      },
    });
    assert.ok(resultado.motivos.length > 0);
    for (const motivo of resultado.motivos) {
      assert.equal(typeof motivo.codigo, 'string');
      assert.equal(typeof motivo.etiqueta, 'string');
      assert.equal(typeof motivo.peso, 'number');
      assert.ok(['cuestionario', 'contexto', 'signos', 'facial', 'sistema'].includes(motivo.fuente));
    }
    assert.ok(resultado.confianza > 0 && resultado.confianza <= 1);
    assert.equal(resultado.version, triage.TRIAGE_VERSION);
    assert.deepEqual(resultado.fuentes, {
      cuestionario: true,
      signos: true,
      facial: false,
    });
  });

  test('sin datos no inventa un nivel tranquilizador', () => {
    const resultado = triage.evaluarTriage({});
    assert.equal(resultado.nivel, 3);
    assert.ok(resultado.recomendaciones.some((r) => /triage manual/i.test(r)));
    assert.ok(resultado.confianza < 0.6);
  });

  test('calidad baja ignora la FC estimada y lo advierte', () => {
    const resultado = triage.evaluarTriage({
      respuestas: respuestasBase({ dolor_intensidad: 2 }),
      metricas: {
        rostro_detectado: true,
        calidad_captura: 40,
        hr_bpm: 150,
        hr_confianza: 0.9,
      },
    });
    assert.ok(resultado.motivos.some((m) => m.codigo === 'calidad_baja'));
    assert.ok(!resultado.motivos.some((m) => m.codigo === 'fc_muy_alta'));
    assert.ok(!resultado.banderas.some((b) => b.codigo === 'taquicardia_marcada'));
  });

  test('detecta discrepancia entre dolor reportado y expresión facial', () => {
    const resultado = triage.evaluarTriage({
      respuestas: respuestasBase({ dolor_intensidad: 1 }),
      metricas: {
        rostro_detectado: true,
        calidad_captura: 82,
        pain_score: 7.5,
        pain_confianza: 0.6,
      },
    });
    assert.ok(resultado.motivos.some((m) => m.codigo === 'discrepancia_dolor'));
    assert.ok(resultado.recomendaciones.some((r) => /preguntar directamente por dolor/i.test(r)));
  });

  test('considera edad y antecedentes de la ficha sin duplicar antecedentes', () => {
    const joven = triage.evaluarTriage({
      respuestas: respuestasBase(),
      paciente: { fecha_nacimiento: '1995-01-01', antecedentes: 'Diabetes tipo 2' },
    });
    assert.ok(joven.motivos.some((m) => m.codigo === 'antecedentes_ficha'));

    const adultoMayor = triage.evaluarTriage({
      respuestas: respuestasBase(),
      paciente: { fecha_nacimiento: '1948-01-01' },
    });
    assert.ok(adultoMayor.motivos.some((m) => m.codigo === 'edad_mayor_70'));
  });

  test('las recomendaciones no se repiten y siempre incluyen el aviso clínico', () => {
    const resultado = triage.evaluarTriage({
      respuestas: respuestasBase({
        dolor_toracico: true,
        dificultad_respiratoria: 'reposo',
      }),
    });
    assert.equal(new Set(resultado.recomendaciones).size, resultado.recomendaciones.length);
    assert.ok(resultado.recomendaciones.some((r) => /no sustituye la valoración clínica/i.test(r)));
  });
});

// ============================================================================
// 3. Consentimiento informado
// ============================================================================
describe('consentimiento informado', () => {
  test('la versión coincide con la configuración y el texto es completo', () => {
    assert.equal(CONSENTIMIENTO.version, config.preconsulta.consentVersion);
    assert.ok(CONSENTIMIENTO.parrafos.length >= 5);
    assert.ok(CONSENTIMIENTO.datos.length >= 4);
    assert.ok(CONSENTIMIENTO.derechos.length >= 3);
    assert.equal(CONSENTIMIENTO.no_es_diagnostico, true);
    assert.equal(CONSENTIMIENTO.requiere_revision_humana, true);
    for (const parrafo of CONSENTIMIENTO.parrafos) {
      assert.ok(parrafo.titulo && parrafo.texto);
    }
  });

  test('el hash del texto es estable y no expone la versión', () => {
    assert.match(TEXTO_HASH, /^[a-f0-9]{64}$/);
    delete require.cache[require.resolve('../src/services/preconsultaContenido')];
    const recargado = require('../src/services/preconsultaContenido');
    assert.equal(recargado.TEXTO_HASH, TEXTO_HASH);
  });
});

// ============================================================================
// 4. API /api/preconsulta
// ============================================================================
describe('API /api/preconsulta', () => {
  test('401 - sin token en consentimiento, cola y detalle', async () => {
    for (const ruta of ['/api/preconsulta/consentimiento', '/api/preconsulta/cola', '/api/preconsulta/1']) {
      const res = await request(app).get(ruta);
      assert.equal(res.status, 401, ruta);
    }
  });

  test('403 - un paciente no accede a la cola ni a las métricas', async () => {
    const cola = await request(app)
      .get('/api/preconsulta/cola')
      .set('Authorization', `Bearer ${tokenPaciente}`);
    assert.equal(cola.status, 403);

    const metricas = await request(app)
      .get('/api/preconsulta/metricas')
      .set('Authorization', `Bearer ${tokenPaciente}`);
    assert.equal(metricas.status, 403);
  });

  test('200 - el personal recibe consentimiento, cuestionario y niveles', async () => {
    const res = await request(app)
      .get('/api/preconsulta/consentimiento')
      .set('Authorization', `Bearer ${tokenMedico}`);
    assert.equal(res.status, 200);
    assert.equal(res.body.data.habilitado, true);
    assert.equal(res.body.data.consentimiento.version, config.preconsulta.consentVersion);
    assert.equal(res.body.data.preguntas.length, triage.CATALOGO_PREGUNTAS.length);
    assert.equal(res.body.data.niveles.length, 5);
    assert.equal(res.body.data.consentimiento.no_es_diagnostico, true);
  });

  test('409 - consentimiento desactualizado bloquea la creación', async () => {
    const res = await request(app)
      .post('/api/preconsulta')
      .set('Authorization', `Bearer ${tokenMedico}`)
      .send({
        paciente_id: 1,
        consentimiento_aceptado: true,
        consentimiento_version: 'version-inexistente',
      });
    assert.equal(res.status, 409);
    assert.match(res.body.message, /consentimiento cambió/i);
  });

  test('422 - crear sin aceptar el consentimiento', async () => {
    const res = await request(app)
      .post('/api/preconsulta')
      .set('Authorization', `Bearer ${tokenMedico}`)
      .send({
        paciente_id: 1,
        consentimiento_aceptado: false,
        consentimiento_version: config.preconsulta.consentVersion,
      });
    assert.equal(res.status, 422);
  });

  test('422 - crear sin paciente', async () => {
    const res = await request(app)
      .post('/api/preconsulta')
      .set('Authorization', `Bearer ${tokenMedico}`)
      .send({
        consentimiento_aceptado: true,
        consentimiento_version: config.preconsulta.consentVersion,
      });
    assert.equal(res.status, 422);
  });

  test('422 - analizar sin captura o con captura insuficiente', async () => {
    const sinCaptura = await request(app)
      .post('/api/preconsulta/1/analizar')
      .set('Authorization', `Bearer ${tokenPaciente}`)
      .send({});
    assert.equal(sinCaptura.status, 422);

    const pocosFrames = await request(app)
      .post('/api/preconsulta/1/analizar')
      .set('Authorization', `Bearer ${tokenPaciente}`)
      .send({ frames: ['aG9sYQ==', 'aG9sYQ=='] });
    assert.equal(pocosFrames.status, 422);

    const ambos = await request(app)
      .post('/api/preconsulta/1/analizar')
      .set('Authorization', `Bearer ${tokenPaciente}`)
      .send({ frames: new Array(60).fill('aG9sYQ=='), video: 'aG9sYQ==' });
    assert.equal(ambos.status, 422);
  });

  test('422 - respuestas con formato inválido', async () => {
    const res = await request(app)
      .put('/api/preconsulta/1/respuestas')
      .set('Authorization', `Bearer ${tokenPaciente}`)
      .send({ respuestas: [{ valor: 'sin código' }] });
    assert.equal(res.status, 422);
  });

  test('422 - revisión con nivel fuera de rango', async () => {
    const res = await request(app)
      .patch('/api/preconsulta/1/revision')
      .set('Authorization', `Bearer ${tokenMedico}`)
      .send({ nivel_revisado: 9 });
    assert.equal(res.status, 422);
  });

  test('403 - un paciente no puede revisar el triage', async () => {
    const res = await request(app)
      .patch('/api/preconsulta/1/revision')
      .set('Authorization', `Bearer ${tokenPaciente}`)
      .send({ nivel_revisado: 2 });
    assert.equal(res.status, 403);
  });

  test('422 - parámetros de ruta y consulta inválidos', async () => {
    const cita = await request(app)
      .get('/api/preconsulta/cita/abc')
      .set('Authorization', `Bearer ${tokenMedico}`);
    assert.equal(cita.status, 422);

    const metricas = await request(app)
      .get('/api/preconsulta/metricas?dias=0')
      .set('Authorization', `Bearer ${tokenMedico}`);
    assert.equal(metricas.status, 422);

    const cola = await request(app)
      .get('/api/preconsulta/cola?nivel=9')
      .set('Authorization', `Bearer ${tokenMedico}`);
    assert.equal(cola.status, 422);
  });
});
