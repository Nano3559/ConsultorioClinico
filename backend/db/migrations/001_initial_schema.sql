-- ============================================================================
-- MIGRACIÓN 001 - Esquema inicial para Supabase (PostgreSQL)
-- Proyecto: Consultorio Clínico
--
-- Cómo ejecutarla:
--   Opción A) Supabase Dashboard -> SQL Editor -> New query -> pegar y Run.
--   Opción B) supabase db push (si usas Supabase CLI con este archivo en
--             supabase/migrations/).
--
-- Nota de seguridad: RLS queda HABILITADO en todas las tablas sin políticas
-- públicas. El backend accede con la clave service_role (bypasea RLS), por lo
-- que el acceso anónimo directo queda bloqueado por diseño.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Función reutilizable: actualiza updated_at/actualizado_en en cada UPDATE
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.actualizado_en = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- usuarios
-- ============================================================================
CREATE TABLE IF NOT EXISTS usuarios (
  id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre     VARCHAR(120) NOT NULL,
  email      VARCHAR(160) NOT NULL UNIQUE,
  password   VARCHAR(100) NOT NULL,
  rol        TEXT NOT NULL DEFAULT 'paciente'
             CHECK (rol IN ('admin', 'medico', 'recepcion', 'paciente')),
  activo     BOOLEAN NOT NULL DEFAULT TRUE,
  creado_en  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON COLUMN usuarios.password IS 'Hash bcrypt generado por el backend';

ALTER TABLE usuarios ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- pacientes
-- ============================================================================
CREATE TABLE IF NOT EXISTS pacientes (
  id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  usuario_id          BIGINT NULL REFERENCES usuarios (id) ON DELETE SET NULL,
  nombre              VARCHAR(120) NOT NULL,
  apellido            VARCHAR(120) NOT NULL,
  cedula              VARCHAR(20) NOT NULL UNIQUE,
  telefono            VARCHAR(30),
  email               VARCHAR(160),
  fecha_nacimiento    DATE,
  sexo                TEXT CHECK (sexo IN ('M', 'F', 'O')),
  direccion           VARCHAR(255),
  tipo_sangre         VARCHAR(5),
  alergias            TEXT,
  contacto_emergencia VARCHAR(160),
  activo              BOOLEAN NOT NULL DEFAULT TRUE,
  creado_en           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  actualizado_en      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE pacientes ENABLE ROW LEVEL SECURITY;

DROP TRIGGER IF EXISTS trg_pacientes_updated_at ON pacientes;
CREATE TRIGGER trg_pacientes_updated_at
  BEFORE UPDATE ON pacientes
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX IF NOT EXISTS idx_pacientes_activo ON pacientes (activo);
CREATE INDEX IF NOT EXISTS idx_pacientes_usuario ON pacientes (usuario_id);

-- ============================================================================
-- medicos
-- ============================================================================
CREATE TABLE IF NOT EXISTS medicos (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  usuario_id      BIGINT NULL REFERENCES usuarios (id) ON DELETE SET NULL,
  nombre          VARCHAR(120) NOT NULL,
  apellido        VARCHAR(120) NOT NULL,
  cedula          VARCHAR(20) NOT NULL UNIQUE,
  especialidad    VARCHAR(120) NOT NULL,
  telefono        VARCHAR(30),
  email           VARCHAR(160),
  consulorio      VARCHAR(60),
  tarifa_consulta NUMERIC(10, 2) DEFAULT 0,
  activo          BOOLEAN NOT NULL DEFAULT TRUE,
  creado_en       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  actualizado_en  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE medicos ENABLE ROW LEVEL SECURITY;

DROP TRIGGER IF EXISTS trg_medicos_updated_at ON medicos;
CREATE TRIGGER trg_medicos_updated_at
  BEFORE UPDATE ON medicos
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX IF NOT EXISTS idx_medicos_activo ON medicos (activo);
CREATE INDEX IF NOT EXISTS idx_medicos_especialidad ON medicos (especialidad);
CREATE INDEX IF NOT EXISTS idx_medicos_usuario ON medicos (usuario_id);

-- ============================================================================
-- horarios
-- ============================================================================
CREATE TABLE IF NOT EXISTS horarios (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  medico_id   BIGINT NOT NULL REFERENCES medicos (id) ON DELETE CASCADE,
  dia_semana  VARCHAR(20) NOT NULL,
  hora_inicio TIME NOT NULL,
  hora_fin    TIME NOT NULL,
  activo      BOOLEAN NOT NULL DEFAULT TRUE
);

ALTER TABLE horarios ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_horarios_medico ON horarios (medico_id);

-- ============================================================================
-- citas
-- ============================================================================
CREATE TABLE IF NOT EXISTS citas (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  paciente_id    BIGINT NOT NULL REFERENCES pacientes (id) ON DELETE CASCADE,
  medico_id      BIGINT NOT NULL REFERENCES medicos (id) ON DELETE CASCADE,
  fecha          DATE NOT NULL,
  hora           TIME NOT NULL,
  motivo         TEXT,
  estado         TEXT NOT NULL DEFAULT 'programada'
                 CHECK (estado IN ('programada', 'en_curso', 'completada', 'cancelada', 'no_show')),
  observaciones  TEXT DEFAULT '',
  creado_en      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  actualizado_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE citas ENABLE ROW LEVEL SECURITY;

DROP TRIGGER IF EXISTS trg_citas_updated_at ON citas;
CREATE TRIGGER trg_citas_updated_at
  BEFORE UPDATE ON citas
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Evita doble agenda a nivel de BD: un médico no puede tener dos citas no
-- canceladas el mismo día y hora.
CREATE UNIQUE INDEX IF NOT EXISTS uq_citas_medico_fecha_hora
  ON citas (medico_id, fecha, hora)
  WHERE estado <> 'cancelada';

CREATE INDEX IF NOT EXISTS idx_citas_fecha ON citas (fecha);
CREATE INDEX IF NOT EXISTS idx_citas_paciente ON citas (paciente_id);
CREATE INDEX IF NOT EXISTS idx_citas_medico ON citas (medico_id);
CREATE INDEX IF NOT EXISTS idx_citas_estado ON citas (estado);

-- ============================================================================
-- consultas (historia clínica)
-- ============================================================================
CREATE TABLE IF NOT EXISTS consultas (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  cita_id         BIGINT NULL REFERENCES citas (id) ON DELETE SET NULL,
  paciente_id     BIGINT NOT NULL REFERENCES pacientes (id) ON DELETE CASCADE,
  medico_id       BIGINT NOT NULL REFERENCES medicos (id) ON DELETE CASCADE,
  fecha           DATE NOT NULL DEFAULT CURRENT_DATE,
  diagnostico     TEXT,
  tratamiento     TEXT,
  notas_clinicas  TEXT DEFAULT '',
  signos_vitales  JSONB,
  creado_en       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  actualizado_en  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE consultas ENABLE ROW LEVEL SECURITY;

DROP TRIGGER IF EXISTS trg_consultas_updated_at ON consultas;
CREATE TRIGGER trg_consultas_updated_at
  BEFORE UPDATE ON consultas
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX IF NOT EXISTS idx_consultas_paciente ON consultas (paciente_id);
CREATE INDEX IF NOT EXISTS idx_consultas_medico ON consultas (medico_id);
CREATE INDEX IF NOT EXISTS idx_consultas_cita ON consultas (cita_id);

-- ============================================================================
-- pagos
-- ============================================================================
CREATE TABLE IF NOT EXISTS pagos (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  paciente_id BIGINT NOT NULL REFERENCES pacientes (id) ON DELETE CASCADE,
  cita_id     BIGINT NULL REFERENCES citas (id) ON DELETE SET NULL,
  monto       NUMERIC(10, 2) NOT NULL CHECK (monto >= 0),
  metodo_pago TEXT NOT NULL DEFAULT 'efectivo'
              CHECK (metodo_pago IN ('efectivo', 'tarjeta', 'transferencia', 'otro')),
  estado      TEXT NOT NULL DEFAULT 'pagado'
              CHECK (estado IN ('pendiente', 'pagado', 'cancelado')),
  descripcion TEXT DEFAULT '',
  fecha_pago  TIMESTAMPTZ,
  creado_en   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE pagos ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_pagos_paciente ON pagos (paciente_id);
CREATE INDEX IF NOT EXISTS idx_pagos_estado ON pagos (estado);
CREATE INDEX IF NOT EXISTS idx_pagos_fecha_pago ON pagos (fecha_pago);
