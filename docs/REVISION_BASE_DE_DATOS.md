# REVISIÓN DE LA BASE DE DATOS — Consultorio Clínico

Fecha: 27/08/2026
Alcance: `backend/db/migrations/*.sql`, `backend/db/seed*.js`, `backend/db/migrate.js`,
controladores y rutas (`backend/src/controllers`, `backend/src/routes`,
`backend/src/middleware/validation.js`).

Objetivo: detectar **repeticiones / desnormalización**, **huecos de validación** con la
BD, e inconsistencias entre el esquema físico y el código que lo utiliza.

---

## 1. RESUMEN EJECUTIVO

La base de datos (Supabase/PostgreSQL) está **bien diseñada en general**: usa claves
`BIGINT IDENTITY`, relaciones con `ON DELETE` coherentes, `RLS` habilitado, CHECK en
columnas críticas, índice único parcial contra doble agenda de citas, y normalización de
emails vía trigger. Sin embargo hay **desnormalización parcial en `medicos`**, **duplicidad
de nombres de migración**, **restricciones UNIQUE sensibles a mayúsculas/tildes**, y
**varias rutas sin validación aplicada** (especialmente en `UPDATE`).

---

## 2. PROBLEMAS ENCONTRADOS

### 2.1 Desnormalización: `medicos.especialidad` (TEXTO) vs `medicos.especialidad_id` (FK)

- La migración `004_especialidades.sql` agrega `medicos.especialidad_id` (FK → `especialidades`)
  y migra los datos existentes.
- Pero los controladores **siguen escribiendo/leyendo el TEXTO `especialidad`**:
  - `medicoController.js` (`create`, `update`) escribe `especialidad` (texto), NO `especialidad_id`.
  - `especialidadController.deleteEspecialidad` consulta por texto: `.ilike('especialidad', ...)`.
  - `disponibilidadController.getMedicosByEspecialidad` consulta por FK: `.eq('especialidad_id', ...)`.
- **Consecuencia**: la misma información vive en dos lugares. Si alguien actualiza el texto pero
  no la FK (o viceversa), `especialidad_id` queda `NULL` o desactualizado y las consultas por FK
  devuelven resultados incompletos/incorrectos. Es la fuente más probable de "repeticiones".

**Corrección**: normalizar todo el flujo hacia `especialidad_id`; dejar el texto solo como
campo legible o eliminarlo.

### 2.2 Duplicidad de nombres de migración

- `002_especialidades.sql` (crea la tabla) y `004_especialidades.sql` (altera la misma tabla)
  comparten tema "especialidades". `migrate.js` ordena por nombre de archivo y las aplica en
  orden, así que **funciona**, pero la numeración no refleja la secuencia real y es confusa.

**Corrección**: renumerar (opcional, requiere historial de `_migraciones`) o, al menos,
documentar la dependencia en los comentarios de cada archivo (ya hecho en 004).

### 2.3 Restricciones UNIQUE sensibles a mayúsculas/tildes

- `especialidades.nombre` tiene `UNIQUE` **case/accent-sensitive**. El backend hace la comprobación
  de duplicados con `normalizar()` (insensible), pero la BD **no** la garantiza: se puede insertar
  `Cardiología` y `CARDIOLOGIA` a la vez por fuera de la API.
- Igual aplica a `usuarios.email` (mitigado por el trigger de migración 003) y a `medicos.cedula` /
  `pacientes.cedula` (cédulas, sin tildes/mayúsculas, riesgo bajo).

**Corrección**: agregar índice único funcional sobre la forma normalizada:
```sql
CREATE UNIQUE INDEX IF NOT EXISTS uq_especialidades_nombre_normalizado
  ON especialidades (LOWER(TRANSLATE(nombre,
    'ÁÉÍÓÚÜáéíóúü', 'AEIOUUAeio uu')));
```

### 2.4 `horarios` sin regla de "hora fin > hora inicio"

No existe CHECK que impida `hora_fin <= hora_inicio`. El backend tampoco lo valida en
`medicoController.createHorario`.

**Corrección**:
```sql
ALTER TABLE horarios
  ADD CONSTRAINT chk_horarios_hora_fin CHECK (hora_fin > hora_inicio);
```
y validar en el controlador y en `validation.js`.

### 2.5 Pagos: permite cobrar dos veces la misma cita

La tabla `pagos` no impide crear más de un pago por `cita_id`. Un cliente puede ser cobrado
dos veces sin que la BD lo bloquee.

**Corrección**:
```sql
CREATE UNIQUE INDEX IF NOT EXISTS uq_pagos_cita
  ON pagos (cita_id) WHERE cita_id IS NOT NULL;
```

### 2.6 `consultas.cita_id` sin unicidad

Distintas consultas pueden apuntar a la misma cita (historial clínico duplicado por cita).
Si el negocio es "máximo un registro clínico por cita", conviene un índice único parcial.

```sql
CREATE UNIQUE INDEX IF NOT EXISTS uq_consultas_cita
  ON consultas (cita_id) WHERE cita_id IS NOT NULL;
```

### 2.7 Generación de cédulas "temporales" con colisión potencial

- `medicoController.create`: si no envían cédula genera `M${Date.now()}`. Dos creaciones en el
  mismo milisegundo colisionan con el UNIQUE de `medicos.cedula`.
- `006_seed_usuarios.sql` y `authController.crearPerfilSegunRol` generan cédulas combinando
  `id` + fragmentos de `EXTRACT(EPOCH ...)`, con `LPAD(...)` a 5 caracteres que trunca el epoch:
  riesgo de colisión si dos filas comparten prefijo.

**Corrección**: usar `crypto.randomUUID()` o `M${Date.now()}${Math.random().toString(36).slice(2)}`.
Mejor aún: obligar a ingresar la cédula.

---

## 3. VALIDACIÓN DEL BACKEND (coherencia con la BD)

### 3.1 Rutas sin validación aplicada

| Ruta | Problema |
|------|----------|
| `PUT /api/pacientes/:id` | Sin `validate` ni validación de body. Cambiar la cédula a una ya existente lanza el 23505 de la BD y del controlador **no se captura el 23505 en `update`** → responde 500 genérico. |
| `PATCH /api/pagos/:id/estado` | Sin validación; el controlador sí valida contra `ESTADOS_PAGO`, OK, pero falta middleware. |
| `POST /api/pagos` | `metodo_pago` solo `.notEmpty()`, no se valida contra `METODOS_PAGO` (la BD sí, pero el error llega crudo). |
| `medicoController.update` | No captura `23505` al cambiar la cédula por una existente → 500 en vez de mensaje claro. |
| `horarioController` / `medicoController.createHorario` | No valida `hora_fin > hora_inicio`. |
| `medicoController.create` | La cédula es opcional y autocadena; debilita la unicidad por cédula. |

### 3.2 Validaciones que sobran/faltan sobre campos obligatorios

- `pacienteValidation` en `pacienteRoutes` exige `email` y `telefono` con `.notEmpty()` para CREAR,
  pero el modelo `Patient` y el formulario permiten email/teléfono vacíos → la API rechaza pacientes
  válidos. Conviene definir email/teléfono como **opcionales**.
- Falta validar `fecha` en consultas, y que `medico_id`/`paciente_id` de una consulta correspondan
  a la cita (integridad referencial lógica).

---

## 4. BUENAS PRÁCTICAS YA PRESENTES (conservar)

- `citas`: índice único parcial `uq_citas_medico_fecha_hora WHERE estado <> 'cancelada'` evita
  doble agenda a nivel BD, y el controlador valida disponibilidad + horario del médico.
- Trigger `normalizar_email_usuario` evita logins duplicados por mayúsculas/espacios.
- `set_updated_at` mantiene `actualizado_en` automáticamente.
- Soft delete con `activo` en `pacientes`, `medicos`, `especialidades`.
- Validaciones de rol con `checkRole` y JWT con `jti` para logout real.

---

## 5. PLAN DE CORRECCIÓN (archivo de migración nuevo)

Crear `backend/db/migrations/007_integridad_pendiente.sql` con los índices y CHECK de
los puntos 2.3, 2.4, 2.5 y 2.6, y ajustar los controladores/rutas del punto 3.
