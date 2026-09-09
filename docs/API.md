# API — Documentación de Endpoints

Base URL (producción): `https://consultorio-clinico.vercel.app/api`
Base URL (local): `http://localhost:3000/api`

## Autenticación

La mayoría de endpoints requieren un token JWT en el encabezado:

```
Authorization: Bearer <token>
```

El token se obtiene en `POST /api/auth/login`.

## Roles permitidos

| Rol | Descripción |
|---|---|
| `admin` | Administrador: acceso total |
| `medico` | Médico |
| `recepcion` | Recepción |
| `paciente` | Paciente |

## Formato de respuesta

**Éxito:**

```json
{ "success": true, "message": "...", "data": { ... } }
```

**Error:**

```json
{ "success": false, "message": "...", "errors": [ { "campo": "...", "mensaje": "..." } ] }
```

Errores: `400` (solicitud inválida), `401` (no autenticado), `403` (sin permiso),
`404` (no encontrado), `422` (validación), `500` (error interno).

---

## Índice de recursos

| Endpoint | Descripción |
|---|---|
| [`GET /`](#get-) | Información de la API y lista de rutas |
| [`GET /health`](#get-health) | Health check |
| [`POST /auth/register`](#post-authregister) | Registrar usuario |
| [`POST /auth/login`](#post-authlogin) | Iniciar sesión (JWT) |
| [`GET /auth/profile`](#get-authprofile) | Perfil del usuario autenticado |
| [`POST /auth/logout`](#post-authlogout) | Cerrar sesión (revoca token) |
| [`GET /pacientes`](#get-pacientes) | Listar pacientes |
| [`GET /pacientes/:id`](#get-pacientesid) | Detalle de paciente |
| [`POST /pacientes`](#post-pacientes) | Crear paciente |
| [`PUT /pacientes/:id`](#put-pacientesid) | Actualizar paciente |
| [`DELETE /pacientes/:id`](#delete-pacientesid) | Eliminar paciente (soft delete) |
| [`GET /medicos`](#get-medicos) | Listar médicos |
| [`GET /medicos/:id`](#get-medicosid) | Detalle de médico |
| [`GET /medicos/:id/horarios`](#get-medicosidhorarios) | Horarios de un médico |
| [`POST /medicos/:id/horarios`](#post-medicosidhorarios) | Crear horario de médico |
| [`POST /medicos`](#post-medicos) | Crear médico |
| [`PUT /medicos/:id`](#put-medicosid) | Actualizar médico |
| [`PATCH /medicos/:id/estado`](#patch-medicosidestado) | Activar/desactivar médico |
| [`DELETE /medicos/:id`](#delete-medicosid) | Eliminar médico |
| [`GET /especialidades`](#get-especialidades) | Listar especialidades |
| [`GET /especialidades/medico/:medicoId`](#get-especialidadesmedicomedicoid) | Especialidades de un médico |
| [`GET /especialidades/:id`](#get-especialidadesid) | Detalle de especialidad |
| [`POST /especialidades`](#post-especialidades) | Crear especialidad |
| [`PUT /especialidades/:id`](#put-especialidadesid) | Actualizar especialidad |
| [`DELETE /especialidades/:id`](#delete-especialidadesid) | Eliminar especialidad |
| [`GET /horarios`](#get-horarios) | Listar horarios |
| [`GET /horarios/disponibles`](#get-horariosdisponibles) | Horarios disponibles |
| [`GET /horarios/medico/:medicoId`](#get-horariosmedicomedicoid) | Horarios por médico |
| [`POST /horarios`](#post-horarios) | Crear horario |
| [`PUT /horarios/:id`](#put-horariosid) | Actualizar horario |
| [`DELETE /horarios/:id`](#delete-horariosid) | Eliminar horario |
| [`GET /citas`](#get-citas) | Listar citas |
| [`GET /citas/mis-citas`](#get-citasmis-citas) | Citas del paciente autenticado |
| [`GET /citas/agenda/hoy`](#get-citasagendahoy) | Agenda del día |
| [`GET /citas/medico/:medicoId`](#get-citasmedicomedicoid) | Citas de un médico |
| [`GET /citas/paciente/:pacienteId`](#get-citaspacientepacienteid) | Citas de un paciente |
| [`GET /citas/:id`](#get-citasid) | Detalle de cita |
| [`POST /citas`](#post-citas) | Crear cita |
| [`PUT /citas/:id`](#put-citasid) | Reprogramar cita |
| [`PATCH /citas/:id/estado`](#patch-citasidestado) | Cambiar estado de cita |
| [`POST /citas/:id/confirmar`](#post-citasidconfirmar) | Confirmar cita |
| [`DELETE /citas/:id`](#delete-citasid) | Cancelar cita |
| [`GET /disponibilidad/medico/:medicoId/fecha/:fecha`](#get-disponibilidadmedicomedicoidfechafecha) | Slots libres de un médico en una fecha |
| [`GET /disponibilidad/especialidad/:especialidadId`](#get-disponibilidadespecialidadespecialidadid) | Médicos activos de una especialidad |
| [`GET /consultas`](#get-consultas) | Listar consultas |
| [`GET /consultas/paciente/:id`](#get-consultaspacienteid) | Historia clínica de un paciente |
| [`GET /consultas/:id`](#get-consultasid) | Detalle de consulta |
| [`POST /consultas`](#post-consultas) | Registrar consulta |
| [`PUT /consultas/:id`](#put-consultasid) | Actualizar consulta |
| [`GET /pagos`](#get-pagos) | Listar pagos |
| [`GET /pagos/paciente/:id`](#get-pagospacienteid) | Pagos de un paciente |
| [`POST /pagos`](#post-pagos) | Registrar pago |
| [`PATCH /pagos/:id/estado`](#patch-pagosidestado) | Cambiar estado de pago |
| [`GET /reportes/citas`](#get-reportescitas) | Reporte de citas |
| [`GET /reportes/ingresos`](#get-reportesingresos) | Reporte de ingresos |
| [`GET /dashboard`](#get-dashboard) | Resumen de métricas |

---

## Raíz y salud

### `GET /`

Información de la API con lista de rutas disponibles. **Público.**

### `GET /health`

Health check. **Público.**

---

## Autenticación

### `POST /auth/register`

Registrar un usuario nuevo.

- **Acceso:** público (con `optionalAuth`). Solo `admin` puede crear roles `admin`, `medico` o `recepcion`.
- **Body:**

```json
{
  "nombre": "Juan Pérez",
  "email": "juan@correo.com",
  "password": "claveSegura123",
  "rol": "paciente"
}
```

- **Respuesta:** `201` con los datos del usuario y un token JWT.

### `POST /auth/login`

Iniciar sesión.

- **Acceso:** público.
- **Body:**

```json
{ "email": "admin@consultorio.com", "password": "admin123" }
```

- **Respuesta:** `200` con `{ token, usuario: { id, nombre, email, rol, perfilTipo, perfilId } }`.

### `GET /auth/profile`

Datos del usuario autenticado.

- **Acceso:** 🔒 autenticado.

### `POST /auth/logout`

Cierra sesión revocando el token (`sesiones.token_id` se marca inactiva).

- **Acceso:** 🔒 autenticado.

---

## Pacientes

### `GET /pacientes`

Lista de pacientes activos. **Público.**

### `GET /pacientes/:id`

Detalle de un paciente. **Público.**

### `POST /pacientes`

Crear paciente.

- **Acceso:** 🔒 `admin`, `recepcion`.
- **Body:** `{ cedula, nombre, apellido, telefono, email, fecha_nacimiento, sexo, direccion, tipo_sangre, alergias, contacto_emergencia }`.

### `PUT /pacientes/:id`

Actualizar paciente.

- **Acceso:** 🔒 `admin`, `recepcion`.

### `DELETE /pacientes/:id`

Eliminar paciente (soft delete: `activo = false`).

- **Acceso:** 🔒 `admin`.

---

## Médicos

### `GET /medicos`

Lista de médicos. **Público.**

### `GET /medicos/:id`

Detalle de un médico. **Público.**

### `GET /medicos/:id/horarios`

Horarios de un médico.

- **Acceso:** 🔒 autenticado.

### `POST /medicos/:id/horarios`

Crear un horario para un médico.

- **Acceso:** 🔒 `admin`.
- **Body:** `{ dia_semana, hora_inicio, hora_fin, activo }`.
- Valida que `hora_fin > hora_inicio` y que no se solape con horarios existentes.

### `POST /medicos`

Crear médico.

- **Acceso:** 🔒 `admin`.
- **Body:** `{ nombre, apellido, cedula, especialidad (nombre o id), especialidad_id, telefono, email, tarifa_consulta, activo }`.

### `PUT /medicos/:id`

Actualizar médico.

- **Acceso:** 🔒 `admin`.

### `PATCH /medicos/:id/estado`

Activar/desactivar médico.

- **Acceso:** 🔒 `admin`.
- **Body:** `{ "activo": true }`.

### `DELETE /medicos/:id`

Eliminar médico. Bloqueado si tiene citas activas.

- **Acceso:** 🔒 `admin`.

---

## Especialidades

### `GET /especialidades`

Lista de especialidades. **Público.** (Con fallback derivándolas de `medicos.especialidad` si la tabla no existe.)

### `GET /especialidades/medico/:medicoId`

Especialidades de un médico. **Público.**

### `GET /especialidades/:id`

Detalle de especialidad. **Público.**

### `POST /especialidades`

Crear especialidad.

- **Acceso:** 🔒 `admin`.
- **Body:** `{ nombre, descripcion, icono, color, activo }`.

### `PUT /especialidades/:id`

Actualizar especialidad.

- **Acceso:** 🔒 `admin`.

### `DELETE /especialidades/:id`

Eliminar especialidad (soft delete).

- **Acceso:** 🔒 `admin`.

---

## Horarios

### `GET /horarios`

Lista de horarios. **Público.**

### `GET /horarios/disponibles`

Horarios disponibles. **Público.**

### `GET /horarios/medico/:medicoId`

Horarios de un médico. **Público.**

### `POST /horarios`

Crear horario.

- **Acceso:** 🔒 `admin`.
- **Body:** `{ medico_id, dia_semana, hora_inicio, hora_fin, activo }`.

### `PUT /horarios/:id`

Actualizar horario.

- **Acceso:** 🔒 `admin`.

### `DELETE /horarios/:id`

Eliminar horario.

- **Acceso:** 🔒 `admin`.

---

## Citas

> Todas las rutas de `/api/citas` requieren autenticación (`verifyToken` a nivel de router).

### `GET /citas/mis-citas`

Citas del paciente autenticado.

- **Acceso:** 🔒 `paciente`.

### `GET /citas/agenda/hoy`

Agenda del día (citas de hoy).

- **Acceso:** 🔒 `admin`, `medico`, `recepcion`.

### `GET /citas/medico/:medicoId`

Citas de un médico.

- **Acceso:** 🔒 autenticado.

### `GET /citas/paciente/:pacienteId`

Citas de un paciente.

- **Acceso:** 🔒 autenticado.

### `GET /citas`

Lista de citas.

- **Acceso:** 🔒 `admin`, `recepcion`.

### `GET /citas/:id`

Detalle de una cita.

- **Acceso:** 🔒 autenticado.

### `POST /citas`

Crear cita.

- **Acceso:** 🔒 `admin`, `recepcion`, `paciente`.
- **Body:** `{ paciente_id, medico_id, fecha (YYYY-MM-DD), hora (HH:mm), motivo, observaciones }`.
- Valida horario del médico y evita doble agenda (médico+fecha+hora).

### `PUT /citas/:id`

Reprogramar cita (cambia fecha/hora; si estaba `confirmada`, vuelve a `programada`).

- **Acceso:** 🔒 `admin`, `recepcion`, `paciente`.
- **Body:** `{ fecha, hora }`.

### `PATCH /citas/:id/estado`

Cambia el estado de la cita.

- **Acceso:** 🔒 `admin`, `recepcion`, `medico`.
- **Body:** `{ "estado": "confirmada" | "en_curso" | "completada" | "cancelada" | "no_show" }`.
- Máquina de transiciones coherente entre estados.

### `POST /citas/:id/confirmar`

Confirma la cita (estado → `confirmada`).

- **Acceso:** 🔒 `admin`, `recepcion`, `medico`.

### `DELETE /citas/:id`

Cancela la cita (soft delete / estado `cancelada`; libera el horario).

- **Acceso:** 🔒 `admin`, `recepcion`.

---

## Disponibilidad

### `GET /disponibilidad/medico/:medicoId/fecha/:fecha`

Slots libres de 30 minutos para un médico en una fecha concreta (formato `YYYY-MM-DD`).

- **Acceso:** público.
- Descarta: horarios inactivos del médico, citas ya ocupadas y horas pasadas del día.

### `GET /disponibilidad/especialidad/:especialidadId`

Médicos activos de una especialidad con sus días de atención.

- **Acceso:** público.

---

## Consultas (historia clínica)

> Todas las rutas de `/api/consultas` requieren autenticación.

### `GET /consultas`

Lista de consultas.

- **Acceso:** 🔒 `admin`, `medico`, `recepcion`.

### `GET /consultas/paciente/:id`

Historia clínica de un paciente.

- **Acceso:** 🔒 autenticado.

### `GET /consultas/:id`

Detalle de una consulta.

- **Acceso:** 🔒 autenticado.

### `POST /consultas`

Registrar consulta.

- **Acceso:** 🔒 `admin`, `medico`.
- **Body:** `{ cita_id, paciente_id, medico_id, fecha, diagnostico, tratamiento, notas_clinicas, signos_vitales }`.

### `PUT /consultas/:id`

Actualizar consulta.

- **Acceso:** 🔒 `admin`, `medico`.

---

## Pagos

> Todas las rutas de `/api/pagos` requieren autenticación.

### `GET /pagos`

Lista de pagos.

- **Acceso:** 🔒 `admin`, `recepcion`.

### `GET /pagos/paciente/:id`

Pagos de un paciente.

- **Acceso:** 🔒 autenticado.

### `POST /pagos`

Registrar pago.

- **Acceso:** 🔒 `admin`, `recepcion`.
- **Body:** `{ paciente_id, cita_id, monto, metodo_pago (efectivo|tarjeta|transferencia|otro), descripcion, estado }`.

### `PATCH /pagos/:id/estado`

Cambia el estado del pago (`pendiente | pagado | cancelado`).

- **Acceso:** 🔒 `admin`, `recepcion`.
- Al marcar `pagado`, se registra `fecha_pago`.

---

## Reportes

### `GET /reportes/citas`

Reporte de citas con filtros.

- **Acceso:** 🔒 `admin`, `recepcion`.
- **Query params:** `desde` (YYYY-MM-DD), `hasta`, `medico_id`, `especialidad_id`, `estado`.

### `GET /reportes/ingresos`

Reporte de ingresos por período y método de pago.

- **Acceso:** 🔒 `admin`, `recepcion`.
- **Query params:** `desde`, `hasta`, `metodo_pago`.

---

## Dashboard

### `GET /dashboard`

Resumen de métricas: pacientes activos, citas de hoy, médicos activos, ingresos del mes y citas por estado.

- **Acceso:** 🔒 autenticado.

---

## Rutas de diagnóstico (⚠️ deshabilitar en producción)

- `GET /api/test/env` — estado de variables de entorno (expone prefijos de claves y la URL de Supabase).
- `GET /api/test/db` — prueba de conexión a la base de datos.

> Estas rutas **no requieren autenticación** y filtran información sensible. Se recomienda
> restringirlas al entorno de desarrollo antes del despliegue final.

---

## Constantes utilizadas por la API

| Constante | Valores |
|---|---|
| Roles | `admin`, `medico`, `recepcion`, `paciente` |
| Estados de cita | `programada`, `confirmada`, `en_curso`, `completada`, `cancelada`, `no_show` |
| Intervalo de cita | 30 minutos |
| Métodos de pago | `efectivo`, `tarjeta`, `transferencia`, `otro` |
| Estados de pago | `pendiente`, `pagado`, `cancelado` |
| Días de atención | `Lunes` a `Domingo` |