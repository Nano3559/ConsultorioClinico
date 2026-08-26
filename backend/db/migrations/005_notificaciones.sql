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
