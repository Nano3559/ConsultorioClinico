-- ============================================================================
-- MIGRACIÓN 004 - Especialidades y vinculación usuarios ↔ perfiles
-- Proyecto: Consultorio Clínico
--
-- Ejecutar en Supabase Dashboard -> SQL Editor -> New query -> pegar y Run.
-- Depende de 001 (schema inicial) y 003 (auth/sesiones).
--
-- Qué hace:
--   1) Crea tabla especialidades normalizada.
--   2) Migra el texto de medicos.especialidad → especialidades.id.
--   3) Agrega FK especialidad_id en medicos.
--   4) Vincula usuarios ↔ pacientes/medicos faltantes via usuario_id.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1) Tabla especialidades
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS especialidades (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre          VARCHAR(120) NOT NULL UNIQUE,
  descripcion     TEXT,
  icono           VARCHAR(60) DEFAULT 'local_hospital_outlined',
  color           VARCHAR(10) DEFAULT '#0D9488',
  activo          BOOLEAN NOT NULL DEFAULT TRUE,
  creado_en       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  actualizado_en  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE especialidades ENABLE ROW LEVEL SECURITY;

DROP TRIGGER IF EXISTS trg_especialidades_updated_at ON especialidades;
CREATE TRIGGER trg_especialidades_updated_at
  BEFORE UPDATE ON especialidades
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE UNIQUE INDEX IF NOT EXISTS uq_especialidades_nombre
  ON especialidades (LOWER(TRIM(nombre)));

COMMENT ON TABLE especialidades IS 'Catálogo normalizado de especialidades médicas.';

-- ---------------------------------------------------------------------------
-- 2) Insertar especialidades únicas desde medicos existentes
--    Solo crea las que no existan aún (idempotente).
-- ---------------------------------------------------------------------------
INSERT INTO especialidades (nombre)
SELECT DISTINCT TRIM(especialidad)
FROM medicos
WHERE TRIM(especialidad) IS NOT NULL
  AND TRIM(especialidad) <> ''
  AND NOT EXISTS (
    SELECT 1 FROM especialidades e
    WHERE LOWER(TRIM(e.nombre)) = LOWER(TRIM(medicos.especialidad))
  );

-- ---------------------------------------------------------------------------
-- 3) Agregar FK especialidad_id a medicos
-- ---------------------------------------------------------------------------
ALTER TABLE medicos
  ADD COLUMN IF NOT EXISTS especialidad_id BIGINT
  REFERENCES especialidades (id) ON DELETE SET NULL;

-- Mapear el texto existente → FK
UPDATE medicos m
SET especialidad_id = e.id
FROM especialidades e
WHERE LOWER(TRIM(m.especialidad)) = LOWER(TRIM(e.nombre))
  AND m.especialidad_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_medicos_especialidad_id
  ON medicos (especialidad_id);

COMMENT ON COLUMN medicos.especialidad_id IS 'FK a especialidades normalizada.';

-- ---------------------------------------------------------------------------
-- 4) Vincular usuarios ↔ pacientes (usuario_id) donde falta
--    Un paciente puede existir en pacientes sin estar linkeado a usuarios.
--    Se vincula por email si coincide.
-- ---------------------------------------------------------------------------
UPDATE pacientes p
SET usuario_id = u.id
FROM usuarios u
WHERE LOWER(TRIM(p.email)) = LOWER(TRIM(u.email))
  AND p.usuario_id IS NULL
  AND u.rol = 'paciente';

-- ---------------------------------------------------------------------------
-- 5) Vincular usuarios ↔ medicos (usuario_id) donde falta
-- ---------------------------------------------------------------------------
UPDATE medicos m
SET usuario_id = u.id
FROM usuarios u
WHERE LOWER(TRIM(m.email)) = LOWER(TRIM(u.email))
  AND m.usuario_id IS NULL
  AND u.rol = 'medico';

-- ---------------------------------------------------------------------------
-- 6) Reporte de estado (ejecutar para verificar)
-- ---------------------------------------------------------------------------
-- SELECT 'especialidades' AS tabla, COUNT(*) AS total FROM especialidades
-- UNION ALL
-- SELECT 'medicos con FK', COUNT(*) FROM medicos WHERE especialidad_id IS NOT NULL
-- UNION ALL
-- SELECT 'pacientes vinculados', COUNT(*) FROM pacientes WHERE usuario_id IS NOT NULL
-- UNION ALL
-- SELECT 'medicos vinculados', COUNT(*) FROM medicos WHERE usuario_id IS NOT NULL;
