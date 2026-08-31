-- ============================================================================
-- MIGRACIÓN 009 - Nuevo estado de cita: 'confirmada'
-- Proyecto: Consultorio Clínico
--
-- Ejecutar en Supabase Dashboard -> SQL Editor -> New query -> pegar y Run,
-- o con: npm run db:migrate
--
-- Qué hace:
--   Agrega el estado 'confirmada' al CHECK de citas.estado para soportar el
--   flujo: programada -> confirmada -> en_curso -> completada.
--   El CHECK original fue creado inline en la migración 001, por lo que
--   PostgreSQL le asignó el nombre automático citas_estado_check.
-- ============================================================================

ALTER TABLE citas
  DROP CONSTRAINT IF EXISTS citas_estado_check;

ALTER TABLE citas
  DROP CONSTRAINT IF EXISTS chk_citas_estado;

ALTER TABLE citas
  ADD CONSTRAINT chk_citas_estado
  CHECK (estado IN ('programada', 'confirmada', 'en_curso', 'completada', 'cancelada', 'no_show'));