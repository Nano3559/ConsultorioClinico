-- ============================================================================
-- MIGRACIÓN 008 - Completar esquema: columnas faltantes para el guardado completo
-- Proyecto: Consultorio Clínico
--
-- Ejecutar en Supabase Dashboard -> SQL Editor -> New query -> pegar y Run.
-- Depende de 001 (schema inicial) y 004 (especialidad_id en medicos).
--
-- Qué agrega (campos que el frontend/backend ya capturan pero no se podían
-- guardar correctamente porque faltaban columnas):
--   1) pacientes.antecedentes           -> antecedentes/historial médico previo
--   2) medicos.titulo                   -> tratamiento del médico (Dr., Dra., etc.)
--   3) medicos.descripcion              -> perfil / bio del médico
--   4) medicos.anios_experiencia        -> años de experiencia profesional
--   5) consultas.motivo                 -> motivo de la consulta
--   6) consultas.proximo_control        -> fecha sugerida del próximo control
--   7) Índices complementarios para las consultas y horarios usados en los
--      filtros frecuentes (agenda, disponibilidad, historial).
--
-- Todo es idempotente: se puede ejecutar más de una vez sin errores.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1) pacientes.antecedentes
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'pacientes' AND column_name = 'antecedentes'
  ) THEN
    ALTER TABLE pacientes
      ADD COLUMN antecedentes TEXT NOT NULL DEFAULT '';
  END IF;
END $$;

COMMENT ON COLUMN pacientes.antecedentes IS 'Historial / antecedentes médicos del paciente (enfermedades previas, quirúrgicos, familiares, etc.).';

-- ---------------------------------------------------------------------------
-- 2) medicos.titulo / descripcion / anios_experiencia
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'medicos' AND column_name = 'titulo'
  ) THEN
    ALTER TABLE medicos
      ADD COLUMN titulo VARCHAR(30) NOT NULL DEFAULT 'Dr./Dra.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'medicos' AND column_name = 'descripcion'
  ) THEN
    ALTER TABLE medicos
      ADD COLUMN descripcion TEXT NOT NULL DEFAULT '';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'medicos' AND column_name = 'anios_experiencia'
  ) THEN
    ALTER TABLE medicos
      ADD COLUMN anios_experiencia INTEGER NOT NULL DEFAULT 0
      CHECK (anios_experiencia >= 0);
  END IF;
END $$;

COMMENT ON COLUMN medicos.titulo IS 'Tratamiento del médico (Dr., Dra., Lic., etc.).';
COMMENT ON COLUMN medicos.descripcion IS 'Perfil profesional / bio del médico para la ficha pública.';
COMMENT ON COLUMN medicos.anios_experiencia IS 'Años de experiencia profesional del médico.';

-- ---------------------------------------------------------------------------
-- 3) consultas.motivo / proximo_control
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'consultas' AND column_name = 'motivo'
  ) THEN
    ALTER TABLE consultas
      ADD COLUMN motivo TEXT NOT NULL DEFAULT '';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'consultas' AND column_name = 'proximo_control'
  ) THEN
    ALTER TABLE consultas
      ADD COLUMN proximo_control DATE;
  END IF;
END $$;

COMMENT ON COLUMN consultas.motivo IS 'Motivo por el cual se realiza la consulta.';
COMMENT ON COLUMN consultas.proximo_control IS 'Fecha sugerida para el próximo control/seguimiento.';

-- ---------------------------------------------------------------------------
-- 4) Índices complementarios (consultas, horarios)
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_consultas_fecha        ON consultas (fecha DESC);
CREATE INDEX IF NOT EXISTS idx_consultas_proximo      ON consultas (proximo_control) WHERE proximo_control IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_horarios_medico_activo ON horarios (medico_id, activo);
CREATE INDEX IF NOT EXISTS idx_horarios_dia           ON horarios (dia_semana);

-- ---------------------------------------------------------------------------
-- Verificación (descomentar para depurar)
-- ---------------------------------------------------------------------------
-- SELECT table_name, column_name, data_type, is_nullable, column_default
-- FROM information_schema.columns
-- WHERE table_name IN ('pacientes', 'medicos', 'consultas')
--   AND column_name IN ('antecedentes', 'titulo', 'descripcion', 'anios_experiencia', 'motivo', 'proximo_control')
-- ORDER BY table_name, column_name;