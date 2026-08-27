-- ============================================================================
-- MIGRACIÓN 007 - Integridad pendiente (repeticiones y validaciones BD)
-- Proyecto: Consultorio Clínico
--
-- Ejecutar en Supabase Dashboard -> SQL Editor -> New query -> pegar y Run.
-- Depende de 001 (set_updated_at), 002 (especialidades), 004 (especialidad_id).
--
-- Qué agrega:
--   1) Índice único funcional sobre especialidades.nombre normalizado
--      (insensible a mayúsculas y tildes) -> evita duplicados tipo
--      'Cardiología' vs 'CARDIOLOGIA'.
--   2) CHECK en horarios: hora_fin > hora_inicio.
--   3) Índice único parcial en pagos: máximo un pago por cita.
--   4) Índice único parcial en consultas: máximo un registro clínico por cita.
--   5) Limpieza preventiva de posibles duplicados de especialidades antes
--      de crear el índice único.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 0) Depurar duplicados de especialidades (insensible) antes de indexar.
--    Conserva la fila con menor id y "funde" los medicos hacia ella.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  dupe RECORD;
  canónico BIGINT;
BEGIN
  FOR dupe IN
    SELECT id, nombre_normalizado
    FROM (
      SELECT id, nombre,
             LOWER(TRANSLATE(nombre, 'ÁÉÍÓÚÜáéíóúü', 'AEIOUUAeio uu')) AS nombre_normalizado,
             ROW_NUMBER() OVER (
               PARTITION BY LOWER(TRANSLATE(nombre, 'ÁÉÍÓÚÜáéíóúü', 'AEIOUUAeio uu'))
               ORDER BY id
             ) AS rn
      FROM especialidades
    ) s
    WHERE rn > 1
  LOOP
    SELECT MIN(id) INTO canónico
    FROM especialidades
    WHERE LOWER(TRANSLATE(nombre, 'ÁÉÍÓÚÜáéíóúü', 'AEIOUUAeio uu'))
        = dupe.nombre_normalizado;

    UPDATE medicos
    SET especialidad_id = canónico
    WHERE especialidad_id = dupe.id;

    UPDATE medicos
    SET especialidad = (SELECT nombre FROM especialidades WHERE id = canónico)
    WHERE especialidad_id = dupe.id;

    DELETE FROM especialidades WHERE id = dupe.id;
  END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- 1) Índice único funcional sobre especialidades.nombre (normalizado)
-- ---------------------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS uq_especialidades_nombre_normalizado
  ON especialidades (LOWER(TRANSLATE(nombre, 'ÁÉÍÓÚÜáéíóúü', 'AEIOUUAeio uu')));

-- ---------------------------------------------------------------------------
-- 2) CHECK en horarios: hora_fin > hora_inicio
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'chk_horarios_hora_fin' AND conrelid = 'horarios'::regclass
  ) THEN
    ALTER TABLE horarios
      ADD CONSTRAINT chk_horarios_hora_fin CHECK (hora_fin > hora_inicio);
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 3) Índice único parcial en pagos: máximo un pago por cita
-- ---------------------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS uq_pagos_cita
  ON pagos (cita_id) WHERE cita_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 4) Índice único parcial en consultas: máximo un registro clínico por cita
-- ---------------------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS uq_consultas_cita
  ON consultas (cita_id) WHERE cita_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- Verificación (descomentar para depurar)
-- ---------------------------------------------------------------------------
-- SELECT conname, pg_get_constraintdef(oid) FROM pg_constraint
-- WHERE conrelid IN ('horarios'::regclass, 'pagos'::regclass, 'consultas'::regclass);
