-- ============================================================================
-- MIGRACIÓN 011 - Kiosco de auto-check-in: pgvector + rostro y check-in de cita
-- Proyecto: Consultorio Clínico
-- Tarea:    KIO-01 / KIO-04 (Sprint 6 - Kiosco de reconocimiento facial)
-- Responsable: Jhilian (Backend/Database)
--
-- Ejecutar con: npm run db:migrate   (o Supabase Dashboard -> SQL Editor)
-- Depende de:   001 (tablas pacientes/citas + RLS), 009 (estado 'confirmada').
-- Idempotente:  usa CREATE EXTENSION IF NOT EXISTS y bloques DO $$ que validan
--               information_schema; se puede re-ejecutar sin errores.
--
-- Qué agrega (documentado en el README, sección "Kiosco de auto-check-in"):
--   1) Habilita la extensión **pgvector** (`vector`) para almacenar y consultar
--      descriptores faciales numéricos (LBPH de OpenCV -> vector de 128 dims).
--   2) `pacientes.rostro_embedding` (vector(128)): descriptor facial del
--      paciente generado por el módulo de visión (backend/vision). Permanece
--      NULL mientras el paciente no tenga el rostro registrado.
--   3) `citas.confirmada_por_kiosco` (boolean): true cuando el kiosco reconoce
--      al paciente y confirma su cita del día.
--   4) `citas.hora_checkin` (TIMESTAMPTZ): fecha/hora del check-in (NOW()).
--
-- Rollback: ver nota al final del archivo.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1) Habilitar pgvector (preinstalado en Supabase; IF NOT EXISTS = no-op)
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS vector;

-- ---------------------------------------------------------------------------
-- 2) pacientes.rostro_embedding  -> vector(128) (descriptor facial LBPH)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'pacientes' AND column_name = 'rostro_embedding'
  ) THEN
    ALTER TABLE pacientes
      ADD COLUMN rostro_embedding vector(128);
  END IF;
END $$;

COMMENT ON COLUMN pacientes.rostro_embedding IS
  'Descriptor facial del paciente (LBPH de OpenCV, 128 dimensiones) usado por el kiosco de auto-check-in. NULL mientras el rostro no esté registrado.';

-- Asegura que RLS siga activa tras el ALTER (invariante del proyecto: el
-- backend accede con service_role; el acceso anónimo directo queda bloqueado).
ALTER TABLE pacientes ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- 3) citas.confirmada_por_kiosco -> boolean (check-in automático)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'citas' AND column_name = 'confirmada_por_kiosco'
  ) THEN
    ALTER TABLE citas
      ADD COLUMN confirmada_por_kiosco BOOLEAN NOT NULL DEFAULT FALSE;
  END IF;
END $$;

COMMENT ON COLUMN citas.confirmada_por_kiosco IS
  'True cuando el kiosco de reconocimiento facial confirma la cita del día del paciente.';

-- ---------------------------------------------------------------------------
-- 4) citas.hora_checkin -> timestamp del check-in
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'citas' AND column_name = 'hora_checkin'
  ) THEN
    ALTER TABLE citas
      ADD COLUMN hora_checkin TIMESTAMPTZ;
  END IF;
END $$;

COMMENT ON COLUMN citas.hora_checkin IS
  'Fecha y hora en que el paciente hizo check-in en el kiosco (NOW() al confirmar).';

ALTER TABLE citas ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- 5) Verificación (descomentar para depurar)
-- ---------------------------------------------------------------------------
-- SELECT column_name, data_type
-- FROM information_schema.columns
-- WHERE table_name IN ('pacientes', 'citas')
--   AND column_name IN ('rostro_embedding', 'confirmada_por_kiosco', 'hora_checkin')
-- ORDER BY table_name, column_name;

-- ---------------------------------------------------------------------------
-- ROLLBACK (solo si la migración aún no se ha desplegado a producción):
--   ALTER TABLE citas      DROP COLUMN IF EXISTS hora_checkin;
--   ALTER TABLE citas      DROP COLUMN IF EXISTS confirmada_por_kiosco;
--   ALTER TABLE pacientes  DROP COLUMN IF EXISTS rostro_embedding;
--   (Opcional) DROP EXTENSION IF EXISTS vector CASCADE;
-- ============================================================================