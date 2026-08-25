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
