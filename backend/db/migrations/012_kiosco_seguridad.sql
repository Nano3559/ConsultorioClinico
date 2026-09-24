-- ============================================================================
-- MIGRACIÓN 012 - Kiosco: auditoría de verificación + índice HNSW pgvector
-- Proyecto: Consultorio Clínico
-- Tarea:    KIO-19 (auditoría de intentos), KIO-20 (límite por IP),
--           KIO-22 (índice HNSW + revisión RLS), KIO-28 (optimización pgvector)
-- Responsable: Jhilian (Backend/Database)
--
-- Ejecutar con: npm run db:migrate   (o Supabase Dashboard -> SQL Editor)
-- Depende de:   011_kiosco_facial.sql (columna pacientes.rostro_embedding
--               vector(128)), y 010_seguridad_avanzada.sql (tabla intentos_acceso).
-- Idempotente:  usa DO $$ / CREATE INDEX IF NOT EXISTS; se puede re-ejecutar.
--
-- Qué agrega (detallado en docs/API.md y docs/REVISION_BASE_DE_DATOS.md):
--   1) Columnas nuevas en `intentos_acceso` para auditar el kiosco:
--      - `tipo_acceso`  (VARCHAR): 'login' (auditoría previa) o
--        'kiosco_verificacion' (intentos del auto-check-in facial, KIO-19).
--      - `referencia_id` (BIGINT): id del paciente en las verificaciones del
--        kiosco (NULL en logins, que ya apuntan a usuario_id).
--      - `detalle`      (VARCHAR): observación legible (ej. 'reconocido',
--        'no_reconocido', 'imagen_invalida', credential_error).
--   2) Índice `idx_intentos_ip_fecha` por (ip_address, creado_en): acelera la
--      consulta de "verificación reciente del mismo paciente/IP" que valida el
--      check-in (ventana KIOSCO_VERIFICATION_WINDOW_MIN, KIO-20/28) y el límite
--      por IP.
--   3) Índice parcial `idx_pacientes_rostro_hnsw` tipo **HNSW** de pgvector
--      (KIO-22): aceleración ANN (aprox. nearest neighbor) para búsquedas por
--      similitud de descriptores faciales cuando se consulta por vector.
--      Solo indexa pacientes con raster registrado. Representación por coseno.
--   4) Revisión de RLS: re-habilita RLS en las tablas tocadas (invariante del
--      proyecto: el backend accede vía service_role; el acceso anónimo queda
--      bloqueado) y deja sin políticas nuevas: el kiosco opera a través del
--      backend, nunca contra la BD directa.
--
-- Rollback completo al final del archivo.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1) Columnas de auditoría del kiosco en intentos_acceso (KIO-19)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'intentos_acceso' AND column_name = 'tipo_acceso'
  ) THEN
    ALTER TABLE intentos_acceso
      ADD COLUMN tipo_acceso VARCHAR(40) NOT NULL DEFAULT 'login';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'intentos_acceso' AND column_name = 'referencia_id'
  ) THEN
    ALTER TABLE intentos_acceso
      ADD COLUMN referencia_id BIGINT;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'intentos_acceso' AND column_name = 'detalle'
  ) THEN
    ALTER TABLE intentos_acceso
      ADD COLUMN detalle VARCHAR(200);
  END IF;
END $$;

COMMENT ON COLUMN intentos_acceso.tipo_acceso IS
  'Tipo de intento: login (autenticación) o kiosco_verificacion (reconocimiento facial del auto-check-in).';
COMMENT ON COLUMN intentos_acceso.referencia_id IS
  'ID del paciente cuando tipo_acceso = kiosco_verificacion (NULL en logins).';
COMMENT ON COLUMN intentos_acceso.detalle IS
  'Observación del resultado (ej. reconocido, no_reconocido, imagen_invalida).';

ALTER TABLE intentos_acceso ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- 2) Índice por IP + fecha para la "ventana de verificación" y el límite por IP
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_intentos_ip_fecha
  ON intentos_acceso (ip_address, creado_en);

-- ---------------------------------------------------------------------------
-- 3) Índice HNSW de pgvector sobre el descriptor facial (KIO-22 / KIO-28)
-- ---------------------------------------------------------------------------
-- Crea el índice ANN solo si la extensión pgvector está disponible (ya
-- habilitada por la migración 011). La operación de similitud elegida es la
-- distancia coseno, la estándar para embeddings de 128 dimensiones.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'vector'
  ) THEN
    EXECUTE format(
      'CREATE INDEX IF NOT EXISTS idx_pacientes_rostro_hnsw
         ON pacientes USING hnsw (rostro_embedding vector_cosine_ops)
         WHERE rostro_embedding IS NOT NULL'
    );
  END IF;
END $$;

COMMENT ON INDEX idx_pacientes_rostro_hnsw IS
  'Índice HNSW (pgvector, coseno) sobre rostro_embedding: aceleración ANN para búsquedas por similitud facial (KIO-22/28).';

-- ---------------------------------------------------------------------------
-- 4) Revisión RLS: re-habilitar en las tablas tocadas (invariante del proyecto)
-- ---------------------------------------------------------------------------
ALTER TABLE pacientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE citas ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- Verificación (descomentar para depurar)
-- ---------------------------------------------------------------------------
-- SELECT indexname FROM pg_indexes
-- WHERE tablename IN ('pacientes', 'intentos_acceso') ORDER BY indexname;
-- SELECT column_name, data_type, column_default
-- FROM information_schema.columns
-- WHERE table_name = 'intentos_acceso' AND column_name IN ('tipo_acceso', 'referencia_id', 'detalle');

-- ---------------------------------------------------------------------------
-- ROLLBACK (solo si aún no se ha desplegado a producción):
--   DROP INDEX IF EXISTS idx_pacientes_rostro_hnsw;
--   DROP INDEX IF EXISTS idx_intentos_ip_fecha;
--   ALTER TABLE intentos_acceso DROP COLUMN IF EXISTS detalle;
--   ALTER TABLE intentos_acceso DROP COLUMN IF EXISTS referencia_id;
--   ALTER TABLE intentos_acceso DROP COLUMN IF EXISTS tipo_acceso;
-- ============================================================================