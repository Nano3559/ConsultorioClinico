-- ============================================================================
-- MIGRACIÓN 010 - Seguridad avanzada e integridad de la base de datos
-- Proyecto: Consultorio Clínico
--
-- Ejecutar en Supabase Dashboard -> SQL Editor -> New query -> pegar y Run,
-- o con: npm run db:migrate
--
-- Qué agrega:
--   1) CHECK de formato en usuarios.email (evita emails mal formados).
--   2) CHECK de longitud bcrypt en usuarios.password (cualquier hash bcrypt
--      válido generado por el backend tiene siempre 60 caracteres).
--      (NOT VALID: no rompe la migración si hay filas legadas, pero sí valida
--      los INSERT/UPDATE nuevos.)
--   3) Trigger que impide agendar una cita para un paciente o médico
--      desactivado (integridad de negocio a nivel BD).
--   4) Trigger que impide desactivar un paciente/médico que tenga citas
--      futuras no canceladas (protege la agenda).
--   5) Tabla intentos_acceso: auditoría de intentos de login (éxitos y
--      fallos) para detectar fuerza bruta.
--   6) Índices adicionales para búsquedas frecuentes (email, cédula).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1) Formato de email en usuarios (NOT VALID para tolerar filas legadas)
-- ---------------------------------------------------------------------------
ALTER TABLE usuarios DROP CONSTRAINT IF EXISTS chk_usuarios_email_formato;
ALTER TABLE usuarios
  ADD CONSTRAINT chk_usuarios_email_formato
  CHECK (email ~ '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') NOT VALID;

-- ---------------------------------------------------------------------------
-- 2) Longitud del hash bcrypt (siempre 60). NOT VALID: no valida filas viejas.
-- ---------------------------------------------------------------------------
ALTER TABLE usuarios DROP CONSTRAINT IF EXISTS chk_usuarios_password_bcrypt;
ALTER TABLE usuarios
  ADD CONSTRAINT chk_usuarios_password_bcrypt
  CHECK (length(password) = 60) NOT VALID;

-- ---------------------------------------------------------------------------
-- 3) No citas para pacientes/médicos inactivos o inexistentes
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION valida_cita_participantes()
RETURNS TRIGGER AS $$
DECLARE
  paciente_activo BOOLEAN;
  medico_activo   BOOLEAN;
BEGIN
  SELECT activo INTO paciente_activo FROM pacientes WHERE id = NEW.paciente_id;
  IF paciente_activo IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'El paciente no existe';
  END IF;
  IF NOT paciente_activo THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'No se puede agendar una cita para un paciente desactivado';
  END IF;

  SELECT activo INTO medico_activo FROM medicos WHERE id = NEW.medico_id;
  IF medico_activo IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'El médico no existe';
  END IF;
  IF NOT medico_activo THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'No se puede agendar una cita con un médico desactivado';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_citas_valida_participantes ON citas;
CREATE TRIGGER trg_citas_valida_participantes
  BEFORE INSERT OR UPDATE OF paciente_id, medico_id ON citas
  FOR EACH ROW EXECUTE FUNCTION valida_cita_participantes();

-- ---------------------------------------------------------------------------
-- 4) No desactivar paciente/médico con citas futuras activas
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION protege_agenda_futura()
RETURNS TRIGGER AS $$
BEGIN
  IF NOT NEW.activo AND OLD.activo THEN
    IF EXISTS (
      SELECT 1 FROM citas
      WHERE (paciente_id = OLD.id OR medico_id = OLD.id)
        AND estado NOT IN ('cancelada', 'completada', 'no_show')
        AND fecha >= CURRENT_DATE
    ) THEN
      RAISE EXCEPTION USING ERRCODE = 'P0001',
        MESSAGE = 'No se puede desactivar: tiene citas futuras sin resolver';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_pacientes_protege_agenda ON pacientes;
CREATE TRIGGER trg_pacientes_protege_agenda
  BEFORE UPDATE OF activo ON pacientes
  FOR EACH ROW EXECUTE FUNCTION protege_agenda_futura();

DROP TRIGGER IF EXISTS trg_medicos_protege_agenda ON medicos;
CREATE TRIGGER trg_medicos_protege_agenda
  BEFORE UPDATE OF activo ON medicos
  FOR EACH ROW EXECUTE FUNCTION protege_agenda_futura();

-- ---------------------------------------------------------------------------
-- 5) Auditoría de intentos de acceso
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS intentos_acceso (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  usuario_id    BIGINT REFERENCES usuarios (id) ON DELETE SET NULL,
  email         VARCHAR(160),
  ip_address    VARCHAR(64),
  user_agent    VARCHAR(255),
  exitoso       BOOLEAN NOT NULL,
  creado_en     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE intentos_acceso ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_intentos_usuario ON intentos_acceso (usuario_id);
CREATE INDEX IF NOT EXISTS idx_intentos_email ON intentos_acceso (email);
CREATE INDEX IF NOT EXISTS idx_intentos_fecha ON intentos_acceso (creado_en);

COMMENT ON TABLE intentos_acceso IS 'Auditoría de intentos de login (éxito/fallo) para detectar fuerza bruta';

-- ---------------------------------------------------------------------------
-- 6) Índices para búsquedas frecuentes
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_usuarios_email ON usuarios (email);
CREATE INDEX IF NOT EXISTS idx_usuarios_rol ON usuarios (rol);
CREATE INDEX IF NOT EXISTS idx_pacientes_cedula ON pacientes (cedula);
CREATE INDEX IF NOT EXISTS idx_medicos_cedula ON medicos (cedula);

-- ---------------------------------------------------------------------------
-- Limpieza de intentos antiguos (más de 90 días)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION limpiar_intentos_antiguos()
RETURNS INTEGER AS $$
DECLARE
  eliminados INTEGER;
BEGIN
  DELETE FROM intentos_acceso WHERE creado_en < NOW() - INTERVAL '90 days';
  GET DIAGNOSTICS eliminados = ROW_COUNT;
  RETURN eliminados;
END;
$$ LANGUAGE plpgsql;