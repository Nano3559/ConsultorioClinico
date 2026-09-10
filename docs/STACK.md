# 🧰 Stack tecnológico — ConsultorioClínico

> Detalle completo del stack y de las decisiones técnicas. Versión resumida en el `README.md`.
> Última revisión: septiembre 2026.

---

## 1. Visión general

Monorepo **full-stack** de gestión de consultorio médico con dos clientes
(web y Android) y una API única. Dos backends de datos conviven por diseño
del ejercicio académico:

```
┌─────────────────────┐        ┌──────────────────────────┐
│  Flutter (web/APK)  │──HTTP──▶  Express en Vercel      │──▶ Supabase (PostgreSQL)
│  Firebase Auth      │        │  JWT + roles + validación │
│  Firestore          │        └──────────────────────────┘
└─────────────────────┘
        │  (además, el frontend opera directamente contra Firebase)
        ▼
   Firebase (Auth, Firestore, Functions, Hosting, App Distribution)
```

---

## 2. Frontend — Flutter 3.13+ (web + Android)

| Tecnología | Versión | Rol |
|---|---|---|
| Flutter / Dart | SDK `^3.13.0` (Flutter 3.47+) | Framework multiplataforma |
| Provider | `^6.1.5+1` | Gestión de estado (`state/`) |
| GoRouter | `^17.5.0` | Enrutamiento declarativo |
| fl_chart | `^1.2.0` | Gráficas de reportes/dashboard |
| http | `^1.6.0` | Cliente HTTP (solo en `services/api_client.dart`) |
| flutter_map + latlong2 | `^7.0.2` / `^0.9.1` | Mapa real del consultorio |
| Lottie | `^3.5.1` | Animaciones (splash, hero) |
| intl | `^0.20.3` | Fechas/números en español |
| flutter_lints | dev | Calidad de código (`flutter analyze`) |

Decisiones clave:
- El login autentica contra **Firebase Auth** y lee el **rol desde Firestore**.
- La API REST del backend es opcional para el frontend (configurable con
  `--dart-define=API_BASE_URL`); por defecto apunta a la versión desplegada en Vercel.
- Firma Android release con `upload-keystore.jks` (alias `upload`), configurada
  en `frontend/android/app/build.gradle.kts`.

---

## 3. Backend — Node.js 22 + Express 4

| Tecnología | Versión | Rol |
|---|---|---|
| Node.js | `22.x` | Runtime |
| Express | `^4.21.2` | Framework HTTP |
| @supabase/supabase-js | `^2.49.1` | Cliente PostgreSQL (RLS + service_role) |
| pg | `^8.23.0` | Driver Postgres directo para migraciones |
| jsonwebtoken | `^9.0.2` | JWT con `jti` + revocación vía tabla `sesiones` |
| bcryptjs | `^3.0.2` | Hash de contraseñas |
| helmet | `^8.0.0` | Cabeceras de seguridad |
| cors | `^2.8.5` | Orígenes controlados por `CORS_ORIGINS` |
| express-validator | `^7.2.1` | Validación de entrada en todas las rutas |
| compression | `^1.8.0` | Compresión gzip |
| morgan | `^1.10.0` | Logs de peticiones |
| dotenv | `^16.4.7` | Configuración por entorno |
| nodemon, supertest, mock-require, node:test | dev | DX y suite QA con mock de Supabase |

Arquitectura: `routes → controllers → supabase`, con middleware transversal
(`auth`, `roles`, `rateLimiter`, `validation`). Despliegue **serverless** en
Vercel mediante el shim `api/index.js`.

---

## 4. Bases de datos

### Supabase (PostgreSQL) — backend
- 11 archivos de migración SQL en `backend/db/migrations/`, aplicados por
  `db/migrate.js` en orden alfabético con registro en la tabla `_migraciones`
  (cada uno en transacción; requiere `SUPABASE_DB_URL`).
- Tablas: `usuarios`, `pacientes`, `medicos`, `horarios`, `citas`, `consultas`,
  `pagos`, `especialidades`, `sesiones`, `notificaciones`, `intentos_acceso`.
- **RLS** en todas las tablas; backend con `service_role` (nunca frontend).
- Enum de roles: `admin`, `medico`, `recepcion`, `paciente`.
- Integridad: índice único `uq_citas_medico_fecha_hora`, triggers, auditoría de
  login (`intentos_acceso`) y revocación de sesión (`sesiones.token_id`).
- Auditoría técnica y deuda conocida (duplicidad de textos/FK en
  `especialidad`, numeración de migraciones, UNIQUEs sensibles a tildes):
  `docs/REVISION_BASE_DE_DATOS.md`.

### Firebase Firestore — frontend
- Reglas RBAC: `frontend/firestore.rules`; índices compuestos: `firestore.indexes.json`.
- Colecciones: `usuarios`, `medicos`, `pacientes`, `especialidades`, `citas`,
  `consultas`, `pagos`, `horarios`, `disponibilidad`.

---

## 5. Autenticación

| Capa | Mecanismo |
|---|---|
| Frontend | Firebase Auth + rol en Firestore (RBAC en reglas) |
| Backend API | JWT firmado con `JWT_SECRET`, `jti` contra `sesiones`, logout revoca |
| Contraseñas backend | `bcryptjs` |
| Rate limiting | En memoria (`rateLimiter.js`): login 10/15 min, registro 5/h |

> ⚠️ El rate limiter en memoria no es fiable en serverless escalado; para
> producción real usar un limitador distribuido (tabla SQL, Upstash, etc.).

---

## 6. Servicios externos

| Servicio | Uso |
|---|---|
| **Vercel** | Backend serverless + `mail-service` |
| **Firebase Hosting** | Frontend web (`flutter build web`) |
| **Firebase Cloud Functions** | Correo alternativo (`frontend/functions/`) |
| **Firebase App Distribution** | Distribución privada del APK |
| **Gmail SMTP (App Password)** | Correos de confirmación y reset |
| **Unsplash** | Fotos reales (médicos, especialidades, hero) |

Correo: dos rutas equivalentes — `mail-service/` (preferida, Vercel) y Cloud
Functions. Endpoints: `POST /api/send-confirm`, `POST /api/send-reset`.

---

## 7. Herramientas de desarrollo e IA

- **OpenCode** — agente de codificación CLI/TUI del equipo.
  Configuración del proyecto: `opencode.json` + `.opencode/`.
- **Agentes principales** (vía **OpenCode GO**): GLM 5.3 (`opencode-go/glm-5.3`),
  DeepSeek v4 Pro (`opencode-go/deepseek-v4-pro`), GPT 5.6 Luna
  (`opencode-go/gpt-5.6-luna`).
- **Respaldos gratuitos** (vía **OpenCode Zen**, catálogo free — rota con
  frecuencia): `free-planner`, `free-coder`, `free-reviewer`. Detalle y
  rotación en `docs/AGENTES.md`.
- **Skills del proyecto**: `.opencode/skills/` (flutter-app, express-backend,
  git-workflow, deploy, email-service).
- Scripts de migración/seed en Node (`firebase-admin`, `@supabase/supabase-js`).

---

## 8. Pruebas

| Suite | Comando | Alcance |
|---|---|---|
| Backend | `cd backend && npm test` | `node:test` + `supertest` con mock de Supabase en memoria (`test/mocks/supabaseMock.js`): login/registro, rate limiting, endpoints protegidos |
| Frontend | `cd frontend && flutter test` | Widget tests |
| Lints | `flutter analyze` | Debe quedar sin warnings |
