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
