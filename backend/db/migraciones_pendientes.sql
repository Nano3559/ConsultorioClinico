-- ============================================================================
-- MIGRACIONES CONSOLIDADAS PENDIENTES - Consultorio Clínico (Supabase)
-- Ejecuta TODO este bloque UNA sola vez en: Supabase Dashboard -> SQL Editor
-- -> New query -> pegar -> Run.
--
-- Incluye (en orden de dependencia) las migraciones que faltan por aplicar:
--   002 -> tabla especialidades
--   003 -> usuarios.ultimo_acceso / password_actualizado_en + tabla sesiones
--   004 -> especialidades.icono/color + medicos.especialidad_id (FK)
--   005 -> tabla notificaciones + funciones marcar_leida / recordatorio / limpieza
--
-- Todos los statements usan IF NOT EXISTS / DO body, por lo que es IDEMPOTENTE
-- y seguro de re-ejecutar.
-- ============================================================================

-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- INICIO: 002_especialidades.sql
-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

-- ============================================================
-- Migración 002: tabla catálogo de especialidades
-- Ejecutar en el SQL Editor de Supabase.
-- ============================================================

CREATE TABLE IF NOT EXISTS especialidades (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre VARCHAR(120) NOT NULL UNIQUE,
  descripcion TEXT DEFAULT '',
  activo BOOLEAN DEFAULT true NOT NULL,
  creado_en TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

INSERT INTO especialidades (nombre, descripcion)
VALUES
  ('Medicina General', 'Atención médica primaria y preventiva'),
  ('Pediatría', 'Salud infantil y del adolescente'),
  ('Cardiología', 'Enfermedades del corazón y sistema circulatorio'),
  ('Dermatología', 'Enfermedades de la piel, cabello y uñas'),
  ('Ginecología', 'Salud femenina y sistema reproductivo'),
  ('Traumatología', 'Lesiones del sistema musculoesquelético'),
  ('Odontología', 'Salud bucal y dental')
ON CONFLICT (nombre) DO NOTHING;

ALTER TABLE especialidades ENABLE ROW LEVEL SECURITY;



-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- INICIO: 003_auth.sql
-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

-- ============================================================================
-- MIGRACIÓN 003 - Seguridad y sesiones para el login por roles
-- Proyecto: Consultorio Clínico
--
-- Ejecutar en Supabase Dashboard -> SQL Editor -> New query -> pegar y Run.
-- Depende de la migración 001 (tabla usuarios).
--
-- Qué agrega:
--   1) usuarios.ultimo_acceso / password_actualizado_en
--   2) Normalización automática del email (trim + minúsculas) al insertar o
--      actualizar usuarios, evitando logins duplicados por mayúsculas/espacios.
--   3) Tabla sesiones: registro de tokens JWT activos por dispositivo.
--      Permite logout real (revocación) y auditoría de accesos por rol.
--   4) Función de limpieza de sesiones expiradas/cerradas.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1) Nuevas columnas en usuarios
-- ---------------------------------------------------------------------------
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS ultimo_acceso TIMESTAMPTZ;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS password_actualizado_en TIMESTAMPTZ NOT NULL DEFAULT NOW();

COMMENT ON COLUMN usuarios.ultimo_acceso IS 'Fecha/hora del último login exitoso';
COMMENT ON COLUMN usuarios.password_actualizado_en IS 'Fecha/hora del último cambio de contraseña';

-- ---------------------------------------------------------------------------
-- 2) Normalización de email (trim + lowercase) vía trigger
--    Evita conflictos tipo Admin@X.com vs admin@x.com al hacer login.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION normalizar_email_usuario()
RETURNS TRIGGER AS $$
BEGIN
  NEW.email = LOWER(BTRIM(NEW.email));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_usuarios_email_normalizado ON usuarios;
CREATE TRIGGER trg_usuarios_email_normalizado
  BEFORE INSERT OR UPDATE OF email ON usuarios
  FOR EACH ROW EXECUTE FUNCTION normalizar_email_usuario();

-- Normaliza los emails ya existentes (idempotente)
UPDATE usuarios SET email = LOWER(BTRIM(email)) WHERE email <> LOWER(BTRIM(email));

-- ---------------------------------------------------------------------------
-- 3) Tabla sesiones (una fila por token JWT emitido)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sesiones (
  id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  usuario_id   BIGINT NOT NULL REFERENCES usuarios (id) ON DELETE CASCADE,
  token_id     UUID NOT NULL UNIQUE,          -- jti incluido dentro del JWT
  ip_address   VARCHAR(64),
  user_agent   VARCHAR(255),
  activa       BOOLEAN NOT NULL DEFAULT TRUE,
  expira_en    TIMESTAMPTZ NOT NULL,
  creado_en    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  cerrada_en   TIMESTAMPTZ
);

ALTER TABLE sesiones ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_sesiones_usuario ON sesiones (usuario_id);
CREATE INDEX IF NOT EXISTS idx_sesiones_token ON sesiones (token_id);
CREATE INDEX IF NOT EXISTS idx_sesiones_activa ON sesiones (activa);

COMMENT ON TABLE sesiones IS 'Sesiones JWT activas por usuario/dispositivo. El middleware valida el JWT (stateless); esta tabla permite cerrar sesión realmente y auditar accesos.';

-- ---------------------------------------------------------------------------
-- 4) Limpieza de sesiones vencidas o cerradas hace más de 30 días.
--    Se puede invocar manualmente desde el SQL Editor:
--      SELECT limpiar_sesiones_antiguas();
--    O programarla con pg_cron si el proyecto lo tiene habilitado.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION limpiar_sesiones_antiguas()
RETURNS INTEGER AS $$
DECLARE
  eliminadas INTEGER;
BEGIN
  DELETE FROM sesiones
  WHERE activa = FALSE AND cerrada_en < NOW() - INTERVAL '30 days'
     OR expira_en < NOW() - INTERVAL '30 days';
  GET DIAGNOSTICS eliminadas = ROW_COUNT;
  RETURN eliminadas;
END;
$$ LANGUAGE plpgsql;



-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- INICIO: 004_especialidades.sql
-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

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



-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- INICIO: 005_notificaciones.sql
-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

-- ============================================================================
-- MIGRACIÓN 005 - Tabla de notificaciones del sistema
-- Proyecto: Consultorio Clínico
--
-- Ejecutar en Supabase Dashboard -> SQL Editor -> New query -> pegar y Run.
-- Depende de 001 (schema inicial + set_updated_at).
--
-- Tabla para notificaciones push / in-app:
--   - Recordatorios de cita (24h antes)
--   - Confirmaciones de cita
--   - Cancelaciones
--   - Pagos recibidos
--   - Mensajes del sistema
-- ============================================================================

CREATE TABLE IF NOT EXISTS notificaciones (
  id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  usuario_id   BIGINT NOT NULL REFERENCES usuarios (id) ON DELETE CASCADE,
  titulo       VARCHAR(200) NOT NULL,
  mensaje      TEXT NOT NULL,
  tipo         TEXT NOT NULL DEFAULT 'sistema'
               CHECK (tipo IN (
                 'sistema',
                 'cita_recordatorio',
                 'cita_confirmada',
                 'cita_cancelada',
                 'cita_reprogramada',
                 'pago_recibido',
                 'mensaje'
               )),
  leida        BOOLEAN NOT NULL DEFAULT FALSE,
  referencia   JSONB,       -- { tipo: 'cita'|'pago', id: 123 } para enlace rápido
  creado_en    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  leida_en     TIMESTAMPTZ
);

ALTER TABLE notificaciones ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_notificaciones_usuario ON notificaciones (usuario_id);
CREATE INDEX IF NOT EXISTS idx_notificaciones_leida ON notificaciones (leida);
CREATE INDEX IF NOT EXISTS idx_notificaciones_tipo ON notificaciones (tipo);
CREATE INDEX IF NOT EXISTS idx_notificaciones_creado ON notificaciones (creado_en DESC);

COMMENT ON TABLE notificaciones IS 'Notificaciones in-app para usuarios del sistema (recordatorios, confirmaciones, pagos, etc.).';

-- Función para marcar notificación como leída
CREATE OR REPLACE FUNCTION marcar_notificacion_leida(notificacion_id BIGINT)
RETURNS BOOLEAN AS $$
DECLARE
  actualizadas INTEGER;
BEGIN
  UPDATE notificaciones
  SET leida = TRUE, leida_en = NOW()
  WHERE id = notificacion_id AND leida = FALSE;
  GET DIAGNOSTICS actualizadas = ROW_COUNT;
  RETURN actualizadas > 0;
END;
$$ LANGUAGE plpgsql;

-- Función para crear notificación de recordatorio de cita (24h antes)
-- Se puede llamar desde el backend o programar con pg_cron
CREATE OR REPLACE FUNCTION crear_recordatorio_cita(
  p_cita_id BIGINT,
  p_usuario_id BIGINT,
  p_medico_nombre TEXT,
  p_fecha DATE,
  p_hora TIME
)
RETURNS BIGINT AS $$
DECLARE
  nueva_id BIGINT;
BEGIN
  INSERT INTO notificaciones (usuario_id, titulo, mensaje, tipo, referencia)
  VALUES (
    p_usuario_id,
    'Recordatorio de cita',
    'Tiene una cita programada con ' || p_medico_nombre ||
    ' el ' || TO_CHAR(p_fecha, 'DD/MM/YYYY') ||
    ' a las ' || TO_CHAR(p_hora, 'HH24:MI'),
    'cita_recordatorio',
    jsonb_build_object('tipo', 'cita', 'id', p_cita_id)
  )
  RETURNING id INTO nueva_id;
  RETURN nueva_id;
END;
$$ LANGUAGE plpgsql;

-- Función para limpiar notificaciones leídas mayores a 60 días
CREATE OR REPLACE FUNCTION limpiar_notificaciones_antiguas()
RETURNS INTEGER AS $$
DECLARE
  eliminadas INTEGER;
BEGIN
  DELETE FROM notificaciones
  WHERE leida = TRUE AND leida_en < NOW() - INTERVAL '60 days';
  GET DIAGNOSTICS eliminadas = ROW_COUNT;
  RETURN eliminadas;
END;
$$ LANGUAGE plpgsql;



