-- ============================================================================
-- MIGRACIÓN 015 - PreConsulta IA (triage asistido multimodal)
-- Proyecto: Consultorio Clínico
--
-- Ejecutar con: npm run db:migrate   (o Supabase Dashboard -> SQL Editor)
-- Depende de:   001 (pacientes/usuarios/citas), 003 (sesiones), 009 (estados).
-- Idempotente:  CREATE TABLE IF NOT EXISTS + bloque DO $$ para políticas.
--
-- QUÉ RESUELVE
--   Registra una pre-consulta de 60-90 s antes de la cita: consentimiento,
--   cuestionario estructurado, estimación de signos a partir de video/video-
--   secuencia facial (rPPG: frecuencia cardíaca, HRV, respiración; expresión
--   facial: dolor/tensión/estrés/fatiga) y un nivel de prioridad EXPLICABLE
--   (1 = atención inmediata ... 5 = no urgente). El personal revisa y ajusta
--   el nivel: la IA NUNCA decide sola ni emite diagnósticos.
--
-- PRIVACIDAD (por diseño)
--   * No se guardan fotogramas, video ni recortes del rostro.
--   * Solo se persisten métricas derivadas, la calidad de la captura y la
--     explicación del triage.
--   * El consentimiento queda versionado y auditado (quién, cuándo, IP hash).
--   * RLS habilitado sin políticas: el backend accede con service_role.
--
-- Rollback (solo si aún no hay datos productivos):
--   DROP TABLE IF EXISTS preconsulta_eventos, preconsulta_revisiones,
--     preconsulta_respuestas, preconsultas, consentimientos_preconsulta,
--     modelos_ia;
-- ============================================================================

-- ---------------------------------------------------------------------------
-- modelos_ia: registro de versiones de los modelos usados (trazabilidad y
-- reproducibilidad del triage). Una fila por tarea/modelo.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS modelos_ia (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre      TEXT NOT NULL,
  version     TEXT NOT NULL,
  tarea       TEXT NOT NULL CHECK (tarea IN ('preconsulta_vision', 'preconsulta_triage')),
  descripcion TEXT NOT NULL DEFAULT '',
  metricas    JSONB NOT NULL DEFAULT '{}'::jsonb,
  activo      BOOLEAN NOT NULL DEFAULT TRUE,
  creado_en   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (nombre, version)
);

ALTER TABLE modelos_ia ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE modelos_ia IS
  'Versiones de modelos de IA con su tarea y métricas. Permite auditar qué modelo generó cada resultado.';

-- ---------------------------------------------------------------------------
-- consentimientos_preconsulta: consentimiento informado versionado.
-- Se guarda un hash de IP (no la IP en claro) y el texto aceptado.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS consentimientos_preconsulta (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  paciente_id    BIGINT NOT NULL REFERENCES pacientes (id) ON DELETE CASCADE,
  usuario_id     BIGINT NULL REFERENCES usuarios (id) ON DELETE SET NULL,
  version        TEXT NOT NULL,
  aceptado       BOOLEAN NOT NULL DEFAULT FALSE,
  texto_hash     TEXT NOT NULL DEFAULT '',
  ip_hash        TEXT NOT NULL DEFAULT '',
  user_agent     TEXT NOT NULL DEFAULT '',
  aceptado_en    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE consentimientos_preconsulta ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_consentimientos_paciente
  ON consentimientos_preconsulta (paciente_id, aceptado_en DESC);

COMMENT ON TABLE consentimientos_preconsulta IS
  'Consentimiento informado de la PreConsulta IA (versionado). ip_hash evita almacenar la IP en claro.';

-- ---------------------------------------------------------------------------
-- preconsultas: entidad central. Un registro por intento de pre-consulta.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS preconsultas (
  id                          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  paciente_id                 BIGINT NOT NULL REFERENCES pacientes (id) ON DELETE CASCADE,
  medico_id                   BIGINT NULL REFERENCES medicos (id) ON DELETE SET NULL,
  cita_id                     BIGINT NULL REFERENCES citas (id) ON DELETE SET NULL,
  consentimiento_id           BIGINT NULL REFERENCES consentimientos_preconsulta (id) ON DELETE SET NULL,
  creada_por_usuario_id       BIGINT NULL REFERENCES usuarios (id) ON DELETE SET NULL,

  estado                      TEXT NOT NULL DEFAULT 'pendiente'
                              CHECK (estado IN ('pendiente', 'analizando', 'completada', 'fallida', 'revisada', 'cancelada')),
  canal                       TEXT NOT NULL DEFAULT 'web'
                              CHECK (canal IN ('web', 'android', 'recepcion', 'tablet')),
  motivo                      TEXT NOT NULL DEFAULT '',

  -- Captura (sin conservar imágenes)
  duracion_captura_seg        NUMERIC(6, 1),
  frames_enviados             INTEGER,
  calidad_captura             NUMERIC(5, 1) CHECK (calidad_captura IS NULL OR (calidad_captura >= 0 AND calidad_captura <= 100)),
  rostro_detectado            BOOLEAN NOT NULL DEFAULT FALSE,
  captura_detalle             JSONB NOT NULL DEFAULT '{}'::jsonb,

  -- Vitales estimados por rPPG (no son dispositivos médicos)
  hr_bpm                      NUMERIC(5, 1) CHECK (hr_bpm IS NULL OR (hr_bpm > 0 AND hr_bpm < 260)),
  hr_confianza                NUMERIC(4, 3) CHECK (hr_confianza IS NULL OR (hr_confianza >= 0 AND hr_confianza <= 1)),
  rmssd_ms                    NUMERIC(7, 1) CHECK (rmssd_ms IS NULL OR (rmssd_ms >= 0 AND rmssd_ms < 5000)),
  sdnn_ms                     NUMERIC(7, 1) CHECK (sdnn_ms IS NULL OR (sdnn_ms >= 0 AND sdnn_ms < 5000)),
  pnn50                       NUMERIC(5, 2) CHECK (pnn50 IS NULL OR (pnn50 >= 0 AND pnn50 <= 100)),
  hrv_confianza               NUMERIC(4, 3) CHECK (hrv_confianza IS NULL OR (hrv_confianza >= 0 AND hrv_confianza <= 1)),
  respiraciones_rpm           NUMERIC(5, 1) CHECK (respiraciones_rpm IS NULL OR (respiraciones_rpm >= 0 AND respiraciones_rpm < 120)),
  senal_snr_db                NUMERIC(6, 2),
  senal_confianza             NUMERIC(4, 3) CHECK (senal_confianza IS NULL OR (senal_confianza >= 0 AND senal_confianza <= 1)),

  -- Rostro / expresión (índices, no diagnóstico)
  pain_score                  NUMERIC(4, 1) CHECK (pain_score IS NULL OR (pain_score >= 0 AND pain_score <= 10)),
  pain_confianza              NUMERIC(4, 3) CHECK (pain_confianza IS NULL OR (pain_confianza >= 0 AND pain_confianza <= 1)),
  stress_score                NUMERIC(5, 1) CHECK (stress_score IS NULL OR (stress_score >= 0 AND stress_score <= 100)),
  fatigue_score               NUMERIC(5, 1) CHECK (fatigue_score IS NULL OR (fatigue_score >= 0 AND fatigue_score <= 100)),
  blink_rate                  NUMERIC(5, 1),
  expresion_dominante         TEXT,
  microexpresiones            JSONB NOT NULL DEFAULT '[]'::jsonb,
  pose_estabilidad            NUMERIC(4, 3) CHECK (pose_estabilidad IS NULL OR (pose_estabilidad >= 0 AND pose_estabilidad <= 1)),

  -- Identidad (opcional, no bloqueante)
  identidad_similitud         NUMERIC(5, 4),
  identidad_coincide          BOOLEAN,

  -- Triage explicable
  triage_nivel                SMALLINT CHECK (triage_nivel IS NULL OR (triage_nivel BETWEEN 1 AND 5)),
  triage_confianza            NUMERIC(4, 3) CHECK (triage_confianza IS NULL OR (triage_confianza >= 0 AND triage_confianza <= 1)),
  triage_motivos              JSONB NOT NULL DEFAULT '[]'::jsonb,
  triage_recomendaciones      JSONB NOT NULL DEFAULT '[]'::jsonb,
  banderas                    JSONB NOT NULL DEFAULT '[]'::jsonb,
  triage_resumen              TEXT NOT NULL DEFAULT '',
  triage_version              TEXT NOT NULL DEFAULT '',
  modelo_version              TEXT NOT NULL DEFAULT '',

  requiere_revision           BOOLEAN NOT NULL DEFAULT TRUE,
  revisado_por_usuario_id     BIGINT NULL REFERENCES usuarios (id) ON DELETE SET NULL,
  revisado_en                 TIMESTAMPTZ,
  nivel_revisado              SMALLINT CHECK (nivel_revisado IS NULL OR (nivel_revisado BETWEEN 1 AND 5)),
  nota_revision               TEXT NOT NULL DEFAULT '',

  creado_en                   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  actualizado_en              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  analizado_en                TIMESTAMPTZ
);

ALTER TABLE preconsultas ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_preconsultas_paciente
  ON preconsultas (paciente_id, creado_en DESC);
CREATE INDEX IF NOT EXISTS idx_preconsultas_cita
  ON preconsultas (cita_id);
CREATE INDEX IF NOT EXISTS idx_preconsultas_estado
  ON preconsultas (estado, creado_en DESC);
CREATE INDEX IF NOT EXISTS idx_preconsultas_triage
  ON preconsultas (triage_nivel, creado_en DESC);
CREATE INDEX IF NOT EXISTS idx_preconsultas_medico
  ON preconsultas (medico_id, creado_en DESC);

DROP TRIGGER IF EXISTS trg_preconsultas_updated_at ON preconsultas;
CREATE TRIGGER trg_preconsultas_updated_at
  BEFORE UPDATE ON preconsultas
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMENT ON TABLE preconsultas IS
  'Pre-consulta asistida por IA: métricas derivadas (sin imágenes), cuestionario y triage explicable. Requiere revisión humana.';
COMMENT ON COLUMN preconsultas.triage_nivel IS
  'Prioridad sugerida: 1 atención inmediata, 2 urgente, 3 prioritario, 4 programado, 5 no urgente. Revisable por el médico.';
COMMENT ON COLUMN preconsultas.triage_motivos IS
  'Explicación del nivel: [{codigo, etiqueta, peso, detalle, fuente}].';
COMMENT ON COLUMN preconsultas.banderas IS
  'Señales de alarma detectadas: [{codigo, severidad, texto}].';
COMMENT ON COLUMN preconsultas.modelo_version IS
  'Versión del pipeline de visión que generó las métricas (p. ej. preconsulta-vision-1.0.0).';

-- ---------------------------------------------------------------------------
-- preconsulta_respuestas: cuestionario estructurado (una fila por pregunta).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS preconsulta_respuestas (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  preconsulta_id BIGINT NOT NULL REFERENCES preconsultas (id) ON DELETE CASCADE,
  codigo         TEXT NOT NULL,
  pregunta       TEXT NOT NULL DEFAULT '',
  respuesta      TEXT NOT NULL DEFAULT '',
  valor_num      NUMERIC(8, 2),
  creado_en      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  actualizado_en TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (preconsulta_id, codigo)
);

ALTER TABLE preconsulta_respuestas ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_preconsulta_respuestas_preconsulta
  ON preconsulta_respuestas (preconsulta_id, codigo);

DROP TRIGGER IF EXISTS trg_preconsulta_respuestas_updated_at ON preconsulta_respuestas;
CREATE TRIGGER trg_preconsulta_respuestas_updated_at
  BEFORE UPDATE ON preconsulta_respuestas
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- preconsulta_revisiones: historial de revisiones humanas (nunca se pisa).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS preconsulta_revisiones (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  preconsulta_id  BIGINT NOT NULL REFERENCES preconsultas (id) ON DELETE CASCADE,
  usuario_id      BIGINT NULL REFERENCES usuarios (id) ON DELETE SET NULL,
  nivel_anterior  SMALLINT,
  nivel_nuevo     SMALLINT NOT NULL CHECK (nivel_nuevo BETWEEN 1 AND 5),
  nota            TEXT NOT NULL DEFAULT '',
  creado_en       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE preconsulta_revisiones ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_preconsulta_revisiones_preconsulta
  ON preconsulta_revisiones (preconsulta_id, creado_en DESC);

COMMENT ON TABLE preconsulta_revisiones IS
  'Historial inmutable de revisión clínica del triage (quién ajustó el nivel y por qué).';

-- ---------------------------------------------------------------------------
-- preconsulta_eventos: auditoría del ciclo de vida (creada, analizada,
-- respuestas, revisada, error). No guarda datos clínicos sensibles.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS preconsulta_eventos (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  preconsulta_id BIGINT NOT NULL REFERENCES preconsultas (id) ON DELETE CASCADE,
  tipo           TEXT NOT NULL,
  detalle        JSONB NOT NULL DEFAULT '{}'::jsonb,
  usuario_id     BIGINT NULL REFERENCES usuarios (id) ON DELETE SET NULL,
  creado_en      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE preconsulta_eventos ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_preconsulta_eventos_preconsulta
  ON preconsulta_eventos (preconsulta_id, creado_en DESC);

COMMENT ON TABLE preconsulta_eventos IS
  'Auditoría de la PreConsulta IA: creación, análisis, respuestas, revisión y errores.';

-- ---------------------------------------------------------------------------
-- Catálogo inicial de modelos (idempotente).
-- ---------------------------------------------------------------------------
INSERT INTO modelos_ia (nombre, version, tarea, descripcion, metricas)
VALUES
  (
    'preconsulta-vision',
    '1.0.0',
    'preconsulta_vision',
    'rPPG POS/CHROM sobre ROI facial (MediaPipe FaceMesh) + índices faciales de dolor/estrés/fatiga. No es un dispositivo médico.',
    '{"modalidad": "video_facial", "roi": "frente_mejillas", "banda_hr_hz": [0.7, 3.0], "no_diagnostico": true}'::jsonb
  ),
  (
    'preconsulta-triage',
    '1.0.0',
    'preconsulta_triage',
    'Fusión determinista y explicable de cuestionario + signos estimados + banderas de alarma. Nivel 1-5 revisable.',
    '{"tipo": "reglas_ponderadas", "niveles": 5, "revision_humana": true, "no_diagnostico": true}'::jsonb
  )
ON CONFLICT (nombre, version) DO NOTHING;
