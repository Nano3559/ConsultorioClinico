-- ============================================================================
-- MIGRACIÓN 006 - Seed mínimo del administrador
-- Proyecto: Consultorio Clínico
--
-- Ejecutar en Supabase Dashboard -> SQL Editor -> New query -> pegar y Run.
-- Depende de 001 (tabla usuarios) y 003 (normalización email).
--
-- Crea el usuario admin inicial si no existe. La contraseña se inserta como
-- texto plano aquí; DESPUÉS se debe ejecutar npm run db:seed -- --reset para
-- reemplazarla con el hash bcrypt correcto.
--
-- NOTA: Esta migración es solo para que la BD tenga un admin mínimo usable
-- desde el primer momento. El script seed.js es la fuente de verdad para
-- las credenciales y perfiles completos.
-- ============================================================================

-- Admin semilla (idempotente: solo inserta si no existe el email)
-- Contraseña temporal: admin123  (seed.js la reemplazará con bcrypt hash)
INSERT INTO usuarios (nombre, email, password, rol, activo)
SELECT
  'Administrador',
  'admin@consultorio.com',
  -- Temporal: seed.js con --reset generará el hash bcrypt correcto
  'PENDIENTE_HASH',
  'admin',
  TRUE
WHERE NOT EXISTS (
  SELECT 1 FROM usuarios WHERE LOWER(email) = 'admin@consultorio.com'
);

-- Médico semilla: Dr. Carlos Ramírez (Medicina General)
INSERT INTO usuarios (nombre, email, password, rol, activo)
SELECT
  'Carlos Ramírez',
  'carlos@consultorio.com',
  'PENDIENTE_HASH',
  'medico',
  TRUE
WHERE NOT EXISTS (
  SELECT 1 FROM usuarios WHERE LOWER(email) = 'carlos@consultorio.com'
);

-- Médico semilla: Dra. Laura Sánchez (Pediatría)
INSERT INTO usuarios (nombre, email, password, rol, activo)
SELECT
  'Laura Sánchez',
  'laura@consultorio.com',
  'PENDIENTE_HASH',
  'medico',
  TRUE
WHERE NOT EXISTS (
  SELECT 1 FROM usuarios WHERE LOWER(email) = 'laura@consultorio.com'
);

-- Recepcionista semilla
INSERT INTO usuarios (nombre, email, password, rol, activo)
SELECT
  'María Pérez',
  'maria@consultorio.com',
  'PENDIENTE_HASH',
  'recepcion',
  TRUE
WHERE NOT EXISTS (
  SELECT 1 FROM usuarios WHERE LOWER(email) = 'maria@consultorio.com'
);

-- Paciente semilla
INSERT INTO usuarios (nombre, email, password, rol, activo)
SELECT
  'Pedro Paciente',
  'pedro@gmail.com',
  'PENDIENTE_HASH',
  'paciente',
  TRUE
WHERE NOT EXISTS (
  SELECT 1 FROM usuarios WHERE LOWER(email) = 'pedro@gmail.com'
);

-- Vincular perfiles de médicos si los usuarios ya existen pero no tienen perfil
DO $$
DECLARE
  medico_user RECORD;
  medico_perfil_id BIGINT;
BEGIN
  FOR medico_user IN
    SELECT u.id AS usuario_id, u.nombre, u.email
    FROM usuarios u
    WHERE u.rol = 'medico'
      AND NOT EXISTS (SELECT 1 FROM medicos m WHERE m.usuario_id = u.id)
  LOOP
    INSERT INTO medicos (usuario_id, nombre, apellido, cedula, especialidad, email)
    VALUES (
      medico_user.usuario_id,
      SPLIT_PART(medico_user.nombre, ' ', 1),
      COALESCE(NULLIF(SPLIT_PART(medico_user.nombre, ' ', 2), ''), 'Por completar'),
      'M' || medico_user.usuario_id || LPAD(EXTRACT(EPOCH FROM NOW())::TEXT, 5, '0'),
      'Medicina General',
      medico_user.email
    );
  END LOOP;
END $$;

-- Vincular perfil de paciente si el usuario existe pero no tiene perfil
DO $$
DECLARE
  paciente_user RECORD;
BEGIN
  FOR paciente_user IN
    SELECT u.id AS usuario_id, u.nombre, u.email
    FROM usuarios u
    WHERE u.rol = 'paciente'
      AND NOT EXISTS (SELECT 1 FROM pacientes p WHERE p.usuario_id = u.id)
  LOOP
    INSERT INTO pacientes (usuario_id, nombre, apellido, cedula, email)
    VALUES (
      paciente_user.usuario_id,
      SPLIT_PART(paciente_user.nombre, ' ', 1),
      COALESCE(NULLIF(SPLIT_PART(paciente_user.nombre, ' ', 2), ''), 'Por completar'),
      'P' || paciente_user.usuario_id || LPAD(EXTRACT(EPOCH FROM NOW())::TEXT, 5, '0'),
      paciente_user.email
    );
  END LOOP;
END $$;

-- Verificación final (descomentar para depurar)
-- SELECT u.id, u.email, u.rol, m.id AS medico_perfil, p.id AS paciente_perfil
-- FROM usuarios u
-- LEFT JOIN medicos m ON m.usuario_id = u.id
-- LEFT JOIN pacientes p ON p.usuario_id = u.id
-- ORDER BY u.id;
