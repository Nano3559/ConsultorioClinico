---
name: express-backend
description: Guía del backend Express + Supabase de ConsultorioClinico (backend/): capas routes→controllers→supabase, middleware de auth/roles, validación con express-validator, migraciones SQL y tests con node:test+supertest. Use when the task touches backend/ Node code, API endpoints, JWT auth, Supabase queries or SQL migrations.
---

# Skill: Backend Express + Supabase (ConsultorioClínico)

Aplica cuando la tarea toque `backend/` (API REST) o la base de datos.

## Comandos (siempre desde `backend/`)
```bash
npm install
npm run dev                 # desarrollo con nodemon
npm start                   # producción
npm test                    # suite QA (node:test + supertest, mock de Supabase en test/mocks/)
npm run db:check            # verifica conexión y esquema
npm run db:migrate          # aplica migraciones SQL
npm run db:migrate:status   # estado de migraciones
npm run db:seed             # usuarios demo por roles
npm run db:seed:ficticio    # datos demo vía API
```

## Arquitectura de capas (obligatoria)
`src/routes/` → `src/controllers/` → `src/config/supabase.js`
- Un recurso = un archivo en `routes/` + uno en `controllers/`. Montar en `src/app.js`.
- **Validación de entrada SIEMPRE** con `express-validator` (patrón de rutas existentes).
- Respuestas con los helpers de `src/utils/helpers.js` (formato JSON uniforme).
- Constantes (roles, estados) en `src/utils/constants.js`.

## Autenticación y roles
- JWT con `jti` ligado a la tabla `sesiones` (logout revoca). Middleware `verifyToken` + middleware de roles.
- Roles: `admin`, `medico`, `recepcion`, `paciente`. Si añades una ruta protegida, mira cómo lo hacen `routes/auth.js` y `routes/pacientes.js` y copia el patrón.
- Rate limiting en memoria (`middleware/rateLimiter.js`): login 10/15min, register 5/h.

## Base de datos (Supabase PostgreSQL)
- Tablas: `usuarios`, `pacientes`, `medicos`, `horarios`, `citas`, `consultas`, `pagos`, `especialidades`, `sesiones`, `notificaciones`, `intentos_acceso`.
- RLS habilitado en todas las tablas; el backend usa `service_role` (SOLO backend, jamás frontend).
- Estados de cita: `programada, confirmada, en_curso, completada, cancelada, no_show`. Pagos: `pendiente, pagado, cancelado`.
- **Cambios de esquema**: SOLO con migración SQL nueva numerada en `db/migrations/`; nunca editar una ya aplicada. Índice único antiduplicados: `uq_citas_medico_fecha_hora`.
- `api/index.js` (raíz y `backend/`) es el shim serverless para Vercel — no romperlo.

## Tests
- Al corregir un bug, añade test en `backend/test/`. La suite usa `supertest` + `mock-require` con el mock de Supabase en `test/mocks/supabaseMock.js`; mantén ese patrón.
- `npm test` debe quedar en verde antes de terminar.
