-- ============================================================================
-- MIGRACIÓN 014 - Motor SFace: embeddings de 512-d a 128-d
-- Proyecto: Consultorio Clínico
--
-- Ejecutar con: npm run db:migrate   (o Supabase Dashboard -> SQL Editor)
-- Depende de:   011 (rostro_embedding), 013 (vector(512), rostro_muestras).
-- Idempotente:  bloques DO $$ + IF NOT EXISTS en todo.
--
-- Por qué: el plan free de hosting (512 MB RAM) no aguanta ArcFace (~1 GB
-- y OOM al arrancar). Se cambia el motor a YuNet + SFace (modelos ~40 MB,
-- ~200 MB en RAM): embeddings de 128 dimensiones, ~98% de precisión,
-- suficiente para check-in asistido con liveness + derivación a recepción.
-- La columna rostro_embedding y rostro_muestras.embedding pasan a
-- vector(128). No hay datos que migrar: en producción aún no existen
-- plantillas 512-d (el registro InsightFace nunca llegó a operar), así que
-- se descartan y cada paciente se registra de nuevo con el flujo multi-pose.
--
-- Rollback: ver nota al final del archivo.
-- ============================================================================

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'pacientes' AND column_name = 'rostro_embedding'
  ) THEN
    ALTER TABLE pacientes DROP COLUMN rostro_embedding;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'pacientes' AND column_name = 'rostro_embedding'
  ) THEN
    ALTER TABLE pacientes ADD COLUMN rostro_embedding vector(128);
  END IF;
END $$;

COMMENT ON COLUMN pacientes.rostro_embedding IS
  'Descriptor facial SFace (128 dims, L2-normalizado) para el kiosco de auto-check-in. NULL mientras el rostro no esté registrado.';

-- Los templates 512-d existentes (si los hay) son incompatibles con SFace
-- y se descartan: se vacía la tabla antes de cambiar el tipo de columna
-- (ADD COLUMN ... NOT NULL fallaría con filas viejas).
TRUNCATE rostro_muestras;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'rostro_muestras' AND column_name = 'embedding'
  ) THEN
    ALTER TABLE rostro_muestras DROP COLUMN embedding;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'rostro_muestras' AND column_name = 'embedding'
  ) THEN
    ALTER TABLE rostro_muestras ADD COLUMN embedding vector(128) NOT NULL;
  END IF;
END $$;

COMMENT ON COLUMN rostro_muestras.embedding IS
  'Embedding SFace 128-d de la pose (migración 014: antes 512-d de ArcFace).';

-- ---------------------------------------------------------------------------
-- ROLLBACK (solo si la migración aún no se ha desplegado a producción):
--   (recrear como vector(512) implicaría re-registrar; no hay rollback de
--   datos: las plantillas se regeneran con el flujo multi-pose.)
-- ============================================================================
