-- ============================================================================
-- MIGRACIÓN 004 - Especialidades: icono, color, trigger, vinculación FK
-- Proyecto: Consultorio Clínico
--
-- Ejecutar en Supabase Dashboard -> SQL Editor -> New query -> pegar y Run.
-- Depende de 001 (schema inicial + set_updated_at) y 002 (tabla especialidades).
--
-- Qué hace:
--   1) Agrega columnas icono/color a especialidades si faltan.
--   2) Crea trigger updated_at en especialidades si falta.
--   3) Agrega FK especialidad_id en medicos para vinculación normalizada.
--   4) Migra el texto de medicos.especialidad → especialidades.id.
--   5) Vincula usuarios ↔ pacientes/medicos faltantes via usuario_id.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1) Agregar columnas icono/color a especialidades (idempotente)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'especialidades' AND column_name = 'icono'
  ) THEN
    ALTER TABLE especialidades ADD COLUMN icono VARCHAR(60) DEFAULT 'local_hospital_outlined';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'especialidades' AND column_name = 'color'
  ) THEN
    ALTER TABLE especialidades ADD COLUMN color VARCHAR(10) DEFAULT '#0D9488';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'especialidades' AND column_name = 'actualizado_en'
  ) THEN
    ALTER TABLE especialidades ADD COLUMN actualizado_en TIMESTAMPTZ NOT NULL DEFAULT NOW();
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 2) Trigger updated_at en especialidades (si no existe)
-- ---------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_especialidades_updated_at ON especialidades;
CREATE TRIGGER trg_especialidades_updated_at
  BEFORE UPDATE ON especialidades
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- 3) Agregar FK especialidad_id a medicos (idempotente)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'medicos' AND column_name = 'especialidad_id'
  ) THEN
    ALTER TABLE medicos
      ADD COLUMN especialidad_id BIGINT
      REFERENCES especialidades (id) ON DELETE SET NULL;
  END IF;
END $$;

-- Mapear el texto existente → FK (solo los que tengan NULL)
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
-- 6) Reporte de estado (descomentar para verificar)
-- ---------------------------------------------------------------------------
-- SELECT 'especialidades' AS tabla, COUNT(*) AS total FROM especialidades
-- UNION ALL
-- SELECT 'medicos con FK', COUNT(*) FROM medicos WHERE especialidad_id IS NOT NULL
-- UNION ALL
-- SELECT 'pacientes vinculados', COUNT(*) FROM pacientes WHERE usuario_id IS NOT NULL
-- UNION ALL
-- SELECT 'medicos vinculados', COUNT(*) FROM medicos WHERE usuario_id IS NOT NULL;
