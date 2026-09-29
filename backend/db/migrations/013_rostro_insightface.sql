-- ============================================================================
-- MIGRACIÓN 013 - Rostro InsightFace: embeddings 512-d, muestras por pose,
-- vigencia del registro y bucket privado de fotos
-- Proyecto: Consultorio Clínico
--
-- Ejecutar con: npm run db:migrate   (o Supabase Dashboard -> SQL Editor)
-- Depende de:   001 (pacientes + RLS), 011 (rostro_embedding vector(128)).
-- Idempotente:  bloques DO $$ + IF NOT EXISTS en todo.
--
-- Qué cambia y por qué:
--   1) `pacientes.rostro_embedding` pasa de vector(128) a vector(512):
--      InsightFace/ArcFace genera descriptores reales de 512 dimensiones
--      (el vector(128) anterior era un promedio de píxeles del prototipo
--      LBPH, incompatible: se descarta y cada paciente se registra de nuevo
--      con el flujo multi-pose).
--   2) `pacientes.rostro_actualizado_en` (TIMESTAMPTZ): fecha del último
--      registro facial. Sirve la política de vigencia (ver KIOSCO_REENROLL_DIAS
--      en el backend): si el registro es más viejo, la reserva online vuelve
--      a pedir foto.
--   3) Tabla `rostro_muestras`: una fila por pose registrada
--      (frontal/izquierda/derecha/arriba/abajo) con su embedding 512-d,
--      puntaje de calidad y ruta en Storage. Permite comparar por pose y
--      auditar la calidad del registro.
--   4) Bucket privado `rostros` en Supabase Storage + políticas RLS:
--      las fotos se organizan por persona en carpetas
--      `rostros/{cedula}_{nombre-slug}/`. Solo service_role (backend) y
--      personal autenticado leen; el kiosco accede con URLs firmadas de
--      corta expiración. Nada de lectura pública (las fotos biométricas
--      nunca son públicas).
--
-- Rollback: ver nota al final del archivo.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1) rostro_embedding vector(128) -> vector(512) (se descarta el dato viejo)
-- ---------------------------------------------------------------------------
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
    ALTER TABLE pacientes ADD COLUMN rostro_embedding vector(512);
  END IF;
END $$;

COMMENT ON COLUMN pacientes.rostro_embedding IS
  'Descriptor facial InsightFace/ArcFace (512 dims, L2-normalizado) para el kiosco. NULL si no hay registro vigente.';

-- ---------------------------------------------------------------------------
-- 2) rostro_actualizado_en -> vigencia del registro facial
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'pacientes' AND column_name = 'rostro_actualizado_en'
  ) THEN
    ALTER TABLE pacientes
      ADD COLUMN rostro_actualizado_en TIMESTAMPTZ;
  END IF;
END $$;

COMMENT ON COLUMN pacientes.rostro_actualizado_en IS
  'Fecha del último registro facial multi-pose. Si supera KIOSCO_REENROLL_DIAS, la reserva vuelve a pedir foto.';

-- ---------------------------------------------------------------------------
-- 3) Tabla rostro_muestras: una fila por pose del registro
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rostro_muestras (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  paciente_id   BIGINT NOT NULL REFERENCES pacientes(id) ON DELETE CASCADE,
  pose          TEXT NOT NULL CHECK (pose IN ('frontal','izquierda','derecha','arriba','abajo')),
  storage_path  TEXT NOT NULL,
  embedding     vector(512) NOT NULL,
  calidad       NUMERIC(5,2) NOT NULL DEFAULT 0 CHECK (calidad >= 0 AND calidad <= 100),
  creada_en     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (paciente_id, pose)
);

COMMENT ON TABLE rostro_muestras IS
  'Muestras del registro facial por pose: embedding 512-d + foto en Storage + puntaje de calidad.';

CREATE INDEX IF NOT EXISTS idx_rostro_muestras_paciente
  ON rostro_muestras (paciente_id);

ALTER TABLE rostro_muestras ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'rostro_muestras_service_role') THEN
    CREATE POLICY rostro_muestras_service_role ON rostro_muestras
      FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'rostro_muestras_staff_read') THEN
    CREATE POLICY rostro_muestras_staff_read ON rostro_muestras
      FOR SELECT TO authenticated USING (true);
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 4) Bucket privado `rostros` + RLS (carpetas por persona)
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('rostros', 'rostros', false)
ON CONFLICT (id) DO NOTHING;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'rostros_service_role') THEN
    CREATE POLICY rostros_service_role ON storage.objects
      FOR ALL TO service_role USING (bucket_id = 'rostros') WITH CHECK (bucket_id = 'rostros');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'rostros_staff_read') THEN
    CREATE POLICY rostros_staff_read ON storage.objects
      FOR SELECT TO authenticated USING (bucket_id = 'rostros');
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- ROLLBACK (solo si la migración aún no se ha desplegado a producción):
--   DROP POLICY IF EXISTS rostros_staff_read ON storage.objects;
--   DROP POLICY IF EXISTS rostros_service_role ON storage.objects;
--   DELETE FROM storage.buckets WHERE id = 'rostros';
--   DROP TABLE IF EXISTS rostro_muestras;
--   ALTER TABLE pacientes DROP COLUMN IF EXISTS rostro_actualizado_en;
--   ALTER TABLE pacientes DROP COLUMN IF EXISTS rostro_embedding;
-- ============================================================================
