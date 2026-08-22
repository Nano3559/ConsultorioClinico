-- ============================================================================
-- Esquema de base de datos - Consultorio Clínico
-- Motor: MySQL 8+ / 9.x   Charset: utf8mb4
--
-- Uso manual (opcional): primero crea la base de datos y luego ejecuta
-- las tablas, o simplemente corre `npm run db:setup` en backend/.
--
--   CREATE DATABASE consultorio_clinico CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
-- ============================================================================

CREATE TABLE IF NOT EXISTS usuarios (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre     VARCHAR(120) NOT NULL,
  email      VARCHAR(160) NOT NULL UNIQUE,
  password   VARCHAR(100) NOT NULL COMMENT 'Hash bcrypt',
  rol        ENUM('admin','medico','recepcion','paciente') NOT NULL DEFAULT 'paciente',
  activo     TINYINT(1) NOT NULL DEFAULT 1,
  creado_en  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS pacientes (
  id                   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  usuario_id           INT UNSIGNED NULL,
  nombre               VARCHAR(120) NOT NULL,
  apellido             VARCHAR(120) NOT NULL,
  cedula               VARCHAR(20) NOT NULL UNIQUE,
  telefono             VARCHAR(30) NULL,
  email                VARCHAR(160) NULL,
  fecha_nacimiento     DATE NULL,
  sexo                 ENUM('M','F','O') NULL,
  direccion            VARCHAR(255) NULL,
  tipo_sangre          VARCHAR(5) NULL,
  alergias             TEXT NULL,
  contacto_emergencia  VARCHAR(160) NULL,
  activo               TINYINT(1) NOT NULL DEFAULT 1,
  creado_en            TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_pacientes_usuario FOREIGN KEY (usuario_id)
    REFERENCES usuarios (id) ON DELETE SET NULL
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS medicos (
  id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  usuario_id      INT UNSIGNED NULL,
  nombre          VARCHAR(120) NOT NULL,
  apellido        VARCHAR(120) NOT NULL,
  cedula          VARCHAR(20) NOT NULL UNIQUE,
  especialidad    VARCHAR(120) NOT NULL,
  telefono        VARCHAR(30) NULL,
  email           VARCHAR(160) NULL,
  consulorio      VARCHAR(60) NULL,
  tarifa_consulta DECIMAL(10,2) NULL DEFAULT 0,
  activo          TINYINT(1) NOT NULL DEFAULT 1,
  creado_en       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_medicos_usuario FOREIGN KEY (usuario_id)
    REFERENCES usuarios (id) ON DELETE SET NULL
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
