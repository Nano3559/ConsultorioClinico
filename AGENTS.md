# AGENTS.md — Reglas para agentes de IA en ConsultorioClínico

Este archivo se carga como instrucción base en cada sesión de OpenCode
(registrado en `instructions` de `opencode.json`). Cualquier agente que
trabaje en este repositorio debe cumplirlo.

## 1. Qué es este proyecto
Sistema integral de gestión de consultorio médico (citas, historias clínicas,
pagos, médicos, pacientes, reportes). Monorepo:

- `frontend/` — Flutter 3.13+ (web + Android), Provider + GoRouter + Firebase.
- `backend/` — Node 22 + Express 4 + Supabase (PostgreSQL), JWT + roles.
- `mail-service/` — correo (Vercel + Gmail SMTP).
- `frontend/functions/` — Cloud Functions de correo alternativas.
- `migracion/` — scripts de migración/seed de Firebase.
- `docs/` — documentación (GIT_CONVENTION, STACK, AGENTES, enunciado).

## 2. Fuentes de verdad
- Convenciones de Git: `docs/GIT_CONVENTION.md` y `CONTRIBUTING.md`.
- Stack y arquitectura: `docs/STACK.md`.
- Agentes y skills: `docs/AGENTES.md`.
- API y despliegue: `README.md`.
- **Skills del repo**: `.opencode/skills/` — flutter-app, express-backend,
  git-workflow, deploy, email-service. Úsalas cuando la tarea coincida.

## 3. Reglas de código
- Backend: capas `routes → controllers → supabase`; validación SIEMPRE con
  `express-validator`; respuestas con `utils/helpers.js`; auth con
  `verifyToken` + middleware de roles (admin, medico, recepcion, paciente).
- Cambios de esquema: SOLO con migración SQL nueva en `backend/db/migrations/`
  (nunca editar una aplicada).
- Frontend: Provider para estado, GoRouter para navegación, red solo por
  `services/api_client.dart`; widgets compartidos desde `core/`.
- UI y textos en español.

## 4. Seguridad (inviolable)
- NUNCA leer, commitear ni imprimir secretos: `.env`, `service-account.json`,
  `firebase-migrator-key.json`, `upload-keystore.jks`, `key.properties`,
  `SUPABASE_SERVICE_ROLE_KEY`.
- La clave `service_role` de Supabase solo se usa en el backend.
- No desactivar RLS, rate limiting, helmet ni CORS.

## 5. Definición de "terminado"
- `flutter analyze` sin warnings y `flutter test` OK (frontend).
- `npm test` en verde (backend) — añadir test al corregir un bug.
- Sin secretos ni temporales en el diff.
- Commits en Conventional Commits en español (skill `git-workflow`); nunca
  `git commit`/`git push` sin que el usuario lo pida.

## 6. Equipo de agentes (OpenCode)
| Agente | Modelo | Gateway | Rol |
|---|---|---|---|
| `glm-architect` | `opencode-go/glm-5.3` | OpenCode GO | Planifica y diseña |
| `deepseek-coder` | `opencode-go/deepseek-v4-pro` | OpenCode GO | Implementa |
| `gpt-luna-reviewer` | `opencode-go/gpt-5.6-luna` | OpenCode GO | Revisa (solo lectura) |
| `free-planner` / `free-coder` / `free-reviewer` | ver `docs/AGENTES.md` | OpenCode Zen (free) | Respaldo costo 0 (mismos roles) |

Flujo recomendado: planificar → implementar → revisar → PR (con revisión de
otro integrante antes del merge a `main`).
