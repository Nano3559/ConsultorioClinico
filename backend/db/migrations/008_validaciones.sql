-- ============================================================================
-- MIGRACIÓN 005 - Validaciones a nivel de base de datos
-- Proyecto: Consultorio Clínico
--
-- Ejecutar en Supabase Dashboard -> SQL Editor -> New query -> pegar y Run.
-- Depende de 001 (schema inicial) y 004 (especialidades).
--
-- Qué hace:
--   1) Extensión btree_gist (necesaria para la exclusión de solapamientos).
--   2) CHECKs en horarios: día de la semana válido (catálogo) y horas coherentes
--      (hora_fin > hora_inicio).
--   3) Constraint de EXCLUSIÓN que impide horarios solapados por médico/día
--      (refuerza a nivel BD la validación que ya hace /api/horarios).
--   4) CHECK en medicos: tarifa_consulta no negativa.
--
-- IMPORTANTE: antes de ejecutar, correr el reporte del paso 5 para detectar
-- horarios solapados ya existentes; si hay, limpialos primero (o el constraint
-- fallará).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1) Extensión btree_gist (tipos base dentro de constraints de exclusión)
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- ---------------------------------------------------------------------------
-- 2) CHECKs en horarios
-- ---------------------------------------------------------------------------
ALTER TABLE horarios
  ADD CONSTRAINT chk_horarios_dia_semana
  CHECK (dia_semana IN ('Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'));

ALTER TABLE horarios
  ADD CONSTRAINT chk_horarios_hora_coherente
  CHECK (hora_fin > hora_inicio);

-- ---------------------------------------------------------------------------
-- 3) Sin solapamientos de horario por médico y día
--    tsrange '[)' (inicio inclusivo, fin exclusivo) reproduce la regla del
--    backend: dos bloques se solapan si inicio1 < fin2 y fin1 > inicio2.
-- ---------------------------------------------------------------------------
ALTER TABLE horarios
  ADD CONSTRAINT excl_horarios_solapamiento
  EXCLUDE USING gist (
    medico_id WITH =,
    dia_semana WITH =,
    tsrange(
      DATE '2020-01-01' + hora_inicio,
      DATE '2020-01-01' + hora_fin,
      '[)'
    ) WITH &&
  );

-- ---------------------------------------------------------------------------
-- 4) CHECK en medicos: tarifa de consulta no negativa
-- ---------------------------------------------------------------------------
ALTER TABLE medicos
  ADD CONSTRAINT chk_medicos_tarifa_no_negativa
  CHECK (tarifa_consulta >= 0);

-- ---------------------------------------------------------------------------
-- 5) Reporte de verificación (opcional): horarios solapados existentes
-- ---------------------------------------------------------------------------
-- SELECT h1.id AS horario_a, h2.id AS horario_b, h1.medico_id, h1.dia_semana
-- FROM horarios h1
-- JOIN horarios h2
--   ON h1.medico_id = h2.medico_id
--  AND h1.dia_semana = h2.dia_semana
--  AND h1.id < h2.id
--  AND h1.hora_inicio < h2.hora_fin
--  AND h1.hora_fin   > h2.hora_inicio;