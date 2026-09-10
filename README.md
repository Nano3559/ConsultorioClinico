# 🏥 ConsultorioClínico

Sistema integral de control médico y clínico. Plataforma **full-stack** que gestiona consultorios médicos: agenda de citas, historias clínicas, pagos, médicos, pacientes, especialidades, reportes y panel administrativo — disponible como **web** y **móvil (Android)**.

---

## 📚 Tabla de contenidos

1. [Stack tecnológico](#-stack-tecnológico)
2. [Arquitectura del proyecto](#-arquitectura-del-proyecto)
3. [Ramas](#-ramas)
4. [Requisitos previos](#-requisitos-previos)
5. [Configuración del entorno](#-configuración-del-entorno)
6. [Configuración y puesta en marcha](#-configuración-y-puesta-en-marcha)
7. [Bases de datos](#-bases-de-datos)
8. [Despliegue](#-despliegue)
9. [Servicio de correo](#-servicio-de-correo)
10. [Cuentas de demostración](#-cuentas-de-demostración)
11. [Endpoints de la API](#-endpoints-de-la-api)
12. [Tests](#-tests)
13. [Agentes de desarrollo (OpenCode: GLM 5.3 · DeepSeek v4 Pro · GPT 5.6 Luna)](#-agentes-de-desarrollo-opencode-glm-53--deepseek-v4-pro--gpt-56-luna)
14. [Notas de seguridad](#-notas-de-seguridad)

> 🖥️ **¿PC nuevo?** Sigue la guía paso a paso completa (instalar Git, Node,
> Flutter, clonar, configurar y correr):
> **[`docs/INSTALACION.md`](docs/INSTALACION.md)**

---

## 🧰 Stack tecnológico

### Frontend — Flutter
| Tecnología | Versión | Uso |
|---|---|---|
| **Flutter / Dart** | SDK `^3.13.0` (Flutter 3.47+) | Framework multiplataforma (web + Android) |
| **Provider** | `^6.1.5+1` | Gestión de estado |
| **GoRouter** | `^17.5.0` | Enrutamiento declarativo |
| **fl_chart** | `^1.2.0` | Gráficas de reportes/dashboard |
| **http** | `^1.6.0` | Cliente HTTP |
| **flutter_map + latlong2** | `^7.0.2` / `^0.9.1` | Mapa real (ubicación del consultorio) |
| **Lottie** | `^3.5.1` | Animaciones (splash, hero) |
| **intl** | `^0.20.3` | Formato de fechas/números en español |

### Backend — Node.js (Express)
| Tecnología | Versión | Uso |
|---|---|---|
| **Node.js** | `22.x` | Runtime |
| **Express** | `^4.21.2` | Framework HTTP |
| **Supabase (@supabase/supabase-js)** | `^2.49.1` | Cliente de base de datos PostgreSQL |
| **pg** | `^8.23.0` | Driver Postgres para migraciones |
| **jsonwebtoken** | `^9.0.2` | Autenticación JWT |
| **bcryptjs** | `^3.0.2` | Hash de contraseñas |
| **helmet** | `^8.0.0` | Cabeceras de seguridad |
| **cors** | `^2.8.5` | Control de orígenes |
| **express-validator** | `^7.2.1` | Validación de entrada |
| **compression** | `^1.8.0` | Compresión gzip |
| **morgan** | `^1.10.0` | Logs de peticiones |
| **dotenv** | `^16.4.7` | Variables de entorno |

### Bases de datos
- **Supabase (PostgreSQL)** — base de datos principal del backend (migraciones SQL, RLS).
- **Firebase Firestore** — base de datos principal del frontend (autenticación, reglas RBAC, datos en tiempo real).

### Autenticación
- **Firebase Auth** — autenticación de usuarios en el frontend.
- **JWT** — autenticación de la API del backend (con revocación de sesión vía tabla `sesiones`).

### Servicios externos
- **Firebase Cloud Functions** — funciones serverless de correo (`functions/index.js`).
- **Firebase App Distribution** — distribución privada del APK firmado.
- **Vercel** — despliegue del backend (serverless Express) y del `mail-service`.
- **Firebase Hosting** — hosting del frontend web.
- **Gmail SMTP (App Password)** — envío de correos (confirmación y reset de contraseña).
- **Unsplash** — fotos médicas reales para médicos, especialidades y hero.

### Herramientas de desarrollo
- `nodemon` — recarga en caliente del backend.
- `supertest` + `mock-require` + `node:test` — suite de pruebas del backend.
- `flutter_lints` — lints de calidad de código.
- Scripts de migración/seed en Node (`firebase-admin`, `@supabase/supabase-js`).

### Agente de desarrollo (IA)
- **OpenCode** (`opencode`) — CLI/agente de desarrollo asistido por IA.
- **OpenCode Zen** (`opencode/*`) — gateway de modelos del equipo de OpenCode.
- **Agentes del proyecto**: `glm-architect` (**GLM 5.3** · `opencode/glm-5.3`),
  `deepseek-coder` (**DeepSeek v4 Pro** · `opencode/deepseek-v4-pro`) y
  `gpt-luna-reviewer` (**GPT 5.6 Luna** · `opencode/gpt-5.6-luna`).
- **Skills del repo**: flutter-app, express-backend, git-workflow, deploy,
  email-service (en `.opencode/skills/`). Detalle en `docs/AGENTES.md`.

---

## 🗂️ Arquitectura del proyecto

Monorepo con los siguientes módulos:

```
ConsultorioClinico/
├── frontend/            # App Flutter (web + Android) + Firebase
│   ├── lib/
│   │   ├── main.dart            # Providers + GoRouter
│   │   ├── core/                # tema, constantes, utils, widgets compartidos
│   │   ├── data/
│   │   │   ├── models/          # entidades (paciente, médico, cita, pago…)
│   │   │   └── mock/            # datos ficticios del ejercicio académico
│   │   ├── services/            # api_client.dart + firestore_service.dart
│   │   ├── state/               # clinic_provider.dart + auth_provider.dart
│   │   └── features/
│   │       ├── public/          # landing, login, solicitar cita
│   │       └── internal/        # dashboard, pacientes, médicos, agenda,
│   │                            # historia clínica, pagos, reportes, configuración
│   ├── functions/               # Firebase Cloud Functions (correo)
│   ├── scripts/                 # seed de cuentas demo en Firebase
│   ├── android/                 # build Android (firma release)
│   ├── firebase.json            # config Firebase (hosting, firestore, functions)
│   ├── firestore.rules          # reglas RBAC de Firestore
│   └── firestore.indexes.json   # índices compuestos
├── backend/              # API en Node.js (Express + Supabase)
│   ├── api/index.js             # shim serverless para Vercel
│   ├── src/
│   │   ├── app.js               # configuración de Express
│   │   ├── server.js            # arranque del servidor
│   │   ├── config/              # config.js + supabase.js
│   │   ├── controllers/         # 12 controladores
│   │   ├── middleware/          # auth, roles, rateLimiter, validation
│   │   ├── routes/              # 13 archivos de rutas
│   │   ├── utils/               # constants.js + helpers.js
│   │   └── views/               # sitio web EJS (mock)
│   ├── db/
│   │   ├── index.js             # CLI unificado (init/check/seed/migrate)
│   │   ├── migrate.js           # aplica migraciones SQL
│   │   ├── seed.js              # siembra usuarios por roles
│   │   ├── seed_ficticio.js     # siembra datos demo vía API
│   │   └── migrations/          # 11 migraciones SQL/PostgreSQL
│   └── test/                    # suite QA de autenticación
├── mail-service/         # Servicio de correo propio (Vercel + Gmail SMTP)
│   └── api/
│       ├── _lib/mail.js         # plantillas HTML
│       ├── _lib/firebase.js     # Admin SDK
│       ├── send-confirm.js      # POST alta de médico / confirmación
│       └── send-reset.js        # POST restablecimiento de contraseña
├── migracion/            # Scripts de migración/seed de Firebase
├── api/index.js          # Función serverless raíz → backend
├── docs/                 # Documentación y enunciado del ejercicio
├── vercel.json           # Config de despliegue Vercel
└── package.json          # scripts y dependencias raíz
```

---

## 🌿 Ramas

Ramas locales y remotas del repositorio `https://github.com/Nano3559/ConsultorioClinico.git`:

### Ramas principales
| Rama | Descripción |
|---|---|
| **`main`** | Versiones estables y desplegadas en producción |

### Ramas remotas
| Rama | Descripción |
|---|---|
| **`origin/main`** | Rama principal en GitHub (`HEAD` apunta aquí) |
| **`origin/Jhilian`** | Trabajo de Jhilian (Backend/Database) |
| **`origin/Camila`** | Trabajo de Camila (backend/API) |
| **`origin/brayan`** | Trabajo de Brayan (Frontend) |
| **`origin/docs/readme`** | Documentación |

> **Flujo de trabajo:** se trabaja en ramas por integrante y se integra a `main`
> mediante *pull requests* (merge). Ejemplo: `Merge pull request #22 from Nano3559/Camila`.
> y junto a ello el resto de integrantes pasa a revisar antes de aprobar.

---

## ✅ Requisitos previos

> Instrucciones para **instalar cada herramienta desde cero** (Windows,
> macOS, Linux) y dejar el proyecto corriendo paso a paso:
> **[`docs/INSTALACION.md`](docs/INSTALACION.md)**.

| Herramienta | Versión mínima | Instalador / guía |
|---|---|---|
| **Git** | 2.40+ | https://git-scm.com/downloads |
| **Flutter** | 3.47+ (Dart 3.13+) | https://docs.flutter.dev/get-started/install |
| **Node.js** | 22.x (LTS) | https://nodejs.org |
| **npm** | 10+ | (incluido con Node) |
| **Android Studio** | para build de APK y licencias SDK | https://developer.android.com/studio |
| **Firebase CLI** (`firebase-tools`) | v13+ (para deploy de hosting/functions) | `npm i -g firebase-tools` |
| **Vercel CLI** (`vercel`) | solo si despliegas Vercel manualmente | `npm i -g vercel` |
| **Cuenta de Supabase** | proyecto PostgreSQL | https://supabase.com |
| **Cuenta de Firebase** | proyecto + Firebase Auth + Firestore | https://console.firebase.google.com |

---

## ⚙️ Configuración del entorno

### 1. Clonar el repositorio
```bash
git clone https://github.com/Nano3559/ConsultorioClinico.git
cd ConsultorioClinico
```

### 2. Variables de entorno del backend
Copia la plantilla y completa los valores reales:

```bash
cp backend/.env.example backend/.env
```

Edita `backend/.env` con tus credenciales:

| Variable | Descripción |
|---|---|
| `PORT` | Puerto del servidor (por defecto `3000`) |
| `NODE_ENV` | `development` o `production` |
| `JWT_SECRET` | **Obligatorio en producción** — secreto largo y aleatorio |
| `JWT_EXPIRE` | Tiempo de expiración del token (ej. `24h`) |
| `CORS_ORIGINS` | Orígenes permitidos separados por coma (vacío bloquea navegadores) |
| `SUPABASE_URL` | URL del proyecto Supabase |
| `SUPABASE_ANON_KEY` | Clave anónima de Supabase |
| `SUPABASE_SERVICE_ROLE_KEY` | Clave `service_role` (**solo backend, nunca el frontend**) |
| `SUPABASE_DB_URL` | Conexión directa a Postgres (solo para `npm run db:migrate`) |

### 3. Configuración Firebase del frontend
Las credenciales de Firebase web y Android están en `frontend/lib/firebase_options.dart`
(proyecto `consultorioclinico-2026`). El `google-services.json` (formato base64)
está en `frontend/android/app/`. No requiere configuración manual adicional.

---

## 🚀 Configuración y puesta en marcha

### Frontend (Flutter)
```bash
cd frontend

# Instalar dependencias
flutter pub get

# Configurar la URL de la API (opcional, por defecto apunta a producción)
# --dart-define=API_BASE_URL=https://consultorio-clinico.vercel.app/api

# Ejecutar en navegador
flutter run -d chrome

# Ejecutar en escritorio (Windows)
flutter run -d windows

# Build web (salida en build/web)
flutter build web

# Build APK de Android
flutter build apk

# Analizar código (lints)
flutter analyze
```

### Backend (Node.js/Express)
```bash
cd backend

# Instalar dependencias
npm install

# Arrancar en modo desarrollo (nodemon, recarga en caliente)
npm run dev

# Arrancar en producción
npm start

# Inicializar/verificar la base de datos
npm run db:init          # inicializa BD
npm run db:check         # verifica conexión y esquema
npm run db:migrate       # aplica las migraciones SQL
npm run db:migrate:status # estado de las migraciones

# Sembrar datos de prueba
npm run db:seed          # siembra usuarios por roles
npm run db:seed:ficticio # siembra doctores/pacientes/citas vía API

# Ejecutar tests
npm test
```

### Scripts de la raíz
```bash
# Instalar dependencias raíz
npm install

# Build de Vercel (instala dependencias del backend)
npm run vercel-build
```

---

## 🗄️ Bases de datos

### Supabase (PostgreSQL) — backend
Base de datos principal de la API. Esquema gestionado mediante **11 migraciones SQL**
en `backend/db/migrations/`:

- Tablas: `usuarios`, `pacientes`, `medicos`, `horarios`, `citas`, `consultas`,
  `pagos`, `especialidades`, `sesiones`, `notificaciones`, `intentos_acceso`.
- **RLS** habilitado en todas las tablas (el backend accede con `service_role`).
- Roles (`enum`): `admin`, `medico`, `recepcion`, `paciente`.
- Estados de cita: `programada`, `confirmada`, `en_curso`, `completada`, `cancelada`, `no_show`.
- Estados de pago: `pendiente`, `pagado`, `cancelado`. Métodos: `efectivo`, `tarjeta`, `transferencia`, `otro`.
- Protecciones a nivel de BD: índice único antidescuento (`uq_citas_medico_fecha_hora`),
  triggers de integridad, revocación de sesión vía `sesiones.token_id` y auditoría de login.

```bash
cd backend
npm run db:migrate        # aplica las 11 migraciones
npm run db:seed           # usuarios demo por roles
```

### Firebase Firestore — frontend
Base de datos del frontend con **reglas RBAC** (`frontend/firestore.rules`) e
**índices compuestos** (`frontend/firestore.indexes.json`).

Colecciones: `usuarios`, `medicos`, `pacientes`, `especialidades`, `citas`,
`consultas`, `pagos`, `horarios`, `disponibilidad`.

Despliegue de reglas e índices:
```bash
cd frontend
firebase deploy --only firestore:rules --project consultorioclinico-2026
firebase deploy --only firestore:indexes --project consultorioclinico-2026
```

---

## ☁️ Despliegue

### Backend → Vercel
```bash
cd backend
vercel login
vercel            # primer despliegue
vercel --prod     # despliegue a producción
```
> El `vercel.json` enruta todo hacia `api/index.js` (función serverless que envuelve
> la app de Express). La raíz tiene otro `vercel.json` que enruta a `/api/index.js`.

### Frontend web → Firebase Hosting
```bash
cd frontend
flutter build web
firebase deploy --only hosting --project consultorioclinico-2026
```

### Firebase Cloud Functions (correo)
```bash
cd frontend/functions
npm install
cd ..
firebase deploy --only functions --project consultorioclinico-2026
```
> Configura las credenciales Gmail con `firebase functions:config:set gmail.user ...`.

### APK Android firmado
La firma release está configurada en `frontend/android/app/build.gradle.kts`
(keystore `upload-keystore.jks` con alias `upload`). Distribución privada vía
**Firebase App Distribution**.

---

## 📧 Servicio de correo

Dos opciones de envío de correos (confirmación de alta de médico y restablecimiento
de contraseña):

### Opción A — `mail-service` (Vercel + Gmail SMTP)
```bash
cd mail-service
npm install
vercel login
vercel          # primer despliegue
```
Variables de entorno en Vercel:
- `GMAIL_USER` — tu correo Gmail
- `GMAIL_APP_PASSWORD` — contraseña de aplicación de 16 letras
- `FIREBASE_SERVICE_ACCOUNT` — contenido del `firebase-migrator-key.json`
- `FROM_EMAIL` (opcional)

### Opción B — Firebase Cloud Functions
Implementadas en `frontend/functions/index.js` con Gmail SMTP (`smtp.gmail.com:587`).

Endpoints:
- `POST /api/send-confirm` — body `{ email, nombre }` → invitación al médico.
- `POST /api/send-reset` — body `{ email }` → restablecimiento de contraseña.

> Para conectar la app: `flutter build web --release --dart-define=MAIL_API_URL=https://...`

---

## 👤 Cuentas de demostración

El login del frontend autentica contra **Firebase Auth** y lee el rol desde **Firestore**.
Las cuentas deben estar sembradas en Firebase (aparecen como "acceso rápido" en `/login`):

| Rol | Correo | Contraseña |
|---|---|---|
| Admin | `admin@consultorio.com` | `admin123` |
| Médico | `carlos@consultorio.com` | `medico123` |
| Recepción | `maria@consultorio.com` | `recepcion123` |
| Paciente | `pedro@gmail.com` | `paciente123` |

### Sembrar cuentas en Firebase (una sola vez)
1. Firebase Console → *Project settings* → *Service accounts* → *Generate new private key*
   y guarda el JSON como `frontend/scripts/service-account.json` (ignorado por git).
2. Ejecuta el seed:
```bash
cd frontend/scripts
npm install
$env:GOOGLE_APPLICATION_CREDENTIALS=".\service-account.json"   # PowerShell
node seed_firebase.mjs
```

El backend también tiene cuentas demo equivalentes sembrables con:
```bash
cd backend
npm run db:seed
```
(Cuentas: `admin@consultorio.com/admin123`, `carlos@consultorio.com/medico123`,
`maria@consultorio.com/recepcion123`, `pedro@gmail.com/paciente123`, etc.)

---

## 🔌 Endpoints de la API

La API autenticada requiere cabecera `Authorization: Bearer <JWT>`.

| Método | Ruta | Auth / Roles | Propósito |
|---|---|---|---|
| GET | `/` | público | Info de la API + índice |
| GET | `/api/health` | público | Health check |
| POST | `/api/auth/register` | público (limitado 5/h) | Registro de usuario |
| POST | `/api/auth/login` | público (limitado 10/15min) | Login, devuelve JWT + perfil |
| GET | `/api/auth/profile` | `verifyToken` | Perfil del usuario actual |
| POST | `/api/auth/logout` | `verifyToken` | Revoca la sesión |
| GET | `/api/pacientes` | admin, recepcion, medico | Listar pacientes |
| GET/POST/PUT/DELETE | `/api/pacientes/:id` | según rol | CRUD de pacientes |
| GET | `/api/medicos` | público (`optionalAuth`) | Listar médicos |
| POST/PUT/PATCH/DELETE | `/api/medicos...` | admin | CRUD de médicos |
| GET | `/api/especialidades` | público | Catálogo de especialidades |
| GET | `/api/horarios` / `/api/horarios/disponibles` | público | Horarios |
| GET/POST/PUT/DELETE | `/api/citas...` | según rol | Citas, agenda, confirmación |
| GET | `/api/disponibilidad/...` | público | Turnos libres |
| GET/POST/PUT | `/api/consultas...` | admin, medico | Historia clínica |
| GET/POST/PATCH | `/api/pagos...` | admin, recepcion | Pagos |
| GET | `/api/reportes/citas` / `/api/reportes/ingresos` | admin, recepcion | Reportes |
| GET | `/api/dashboard` | `verifyToken` | Resumen del dashboard |
| GET | `/api/test/db` | **solo dev** + admin | Diagnóstico de BD |

---

## 🧪 Tests

### Backend (QA de autenticación)
```bash
cd backend
npm test
```
Suite con `node:test` + `supertest` que cubre login/registro, rate limiting y
endpoints protegidos, usando un mock de Supabase en memoria
(`test/mocks/supabaseMock.js`).

### Frontend (widget test)
```bash
cd frontend
flutter test
```

---

## 🤖 Agentes de desarrollo (OpenCode: GLM 5.3 · DeepSeek v4 Pro · GPT 5.6 Luna)

Este proyecto se desarrolla con el asistente de codificación **OpenCode**.
La configuración vive en el repositorio: `opencode.json` (modelo y permisos),
`.opencode/agent/` (6 agentes) y `.opencode/skills/` (skills del proyecto).
Hay **dos puertas de enlace**: los agentes principales corren en **OpenCode
GO** y hay **respaldos gratuitos** con modelos free de **OpenCode Zen**.

### Los 6 agentes del proyecto

| Agente | Modelo (ID) | Gateway | Rol |
|---|---|---|---|
| **`glm-architect`** | `opencode-go/glm-5.3` | GO | Planifica y diseña: arquitectura, tareas, cambios de esquema |
| **`deepseek-coder`** | `opencode-go/deepseek-v4-pro` | GO | Implementa: features, refactors, bugs y tests |
| **`gpt-luna-reviewer`** | `opencode-go/gpt-5.6-luna` | GO | Revisa: code review, seguridad, QA (**solo lectura**) |
| **`free-planner`** | `opencode/glm-5-free` | Zen (free) | Respaldo de glm-architect |
| **`free-coder`** | `opencode/deepseek-v4-flash-free` | Zen (free) | Respaldo de deepseek-coder |
| **`free-reviewer`** | `opencode/kimi-k2.5-free` | Zen (free) | Respaldo del reviewer (**solo lectura**) |

Todos son `mode: primary` (se alternan con **Tab** o `/agents`). Los modelos
free de Zen **rotan con frecuencia**: si uno desaparece, elige otro con
sufijo `-free` en `/models` y edita la línea `model:` del agente
(`.opencode/agent/free-*.md`). Detalle completo en `docs/AGENTES.md`.

Flujo recomendado: **glm-architect planifica → deepseek-coder implementa →
gpt-luna-reviewer revisa → PR** según `docs/GIT_CONVENTION.md` (sin cuota de
GO: mismo flujo con los `free-*`, costo 0).

También se reconfiguraron los agentes base: `build` y `plan` usan
`opencode-go/glm-5.3`, y el subagente `general` usa
`opencode-go/deepseek-v4-pro`. El `small_model` interno es
`opencode-go/glm-5.3-flash`.

> Alternativa sin GO/Zen: proveedores directos con tu propia API key
> (`zhipuai/glm-5.3`, `deepseek/deepseek-v4-pro`, `openai/gpt-5.6-luna`).

### Skills del proyecto (`.opencode/skills/`)

| Skill | Se activa cuando la tarea toca... |
|---|---|
| `flutter-app` | `frontend/`: Dart, Provider, GoRouter, Firebase, build web/APK |
| `express-backend` | `backend/`: rutas, controladores, JWT, Supabase, migraciones, tests |
| `git-workflow` | Commits, ramas y PRs (Conventional Commits en español) |
| `deploy` | Despliegues: Vercel, Firebase Hosting/Functions, APK |
| `email-service` | `mail-service/`, Cloud Functions, Gmail SMTP |

### Puesta en marcha
1. Abrir OpenCode en la raíz del repo.
2. Agentes principales: autenticar tu instalación de **OpenCode GO**.
   Respaldo gratuito: `/connect` → *OpenCode Zen* → API key de
   https://opencode.ai/auth (una sola vez).
3. `/models` lista los modelos; **Tab** (o `/agents`) alterna entre los seis
   agentes. `AGENTS.md` se carga como regla base en cada sesión.
4. Los permisos están en `opencode.json`: edición permitida, pero
   `git commit`/`git push` piden confirmación y `rm` está denegado.

> ⚠️ Tras editar `opencode.json`, agentes o skills, **reinicia OpenCode** para
> aplicar los cambios (la configuración no se recarga en caliente).

### Configuración (resumen)

```jsonc
// opencode.json (raíz del repo)
{
  "$schema": "https://opencode.ai/config.json",
  "model": "opencode-go/glm-5.3",
  "small_model": "opencode-go/glm-5.3-flash",
  "instructions": ["AGENTS.md"],
  "agent": {
    "build":   { "model": "opencode-go/glm-5.3" },
    "plan":    { "model": "opencode-go/glm-5.3" },
    "general": { "model": "opencode-go/deepseek-v4-pro" }
  }
}
```

Los agentes completos están en `.opencode/agent/*.md` y su documentación
detallada en **`docs/AGENTES.md`**.

---

## 🔒 Notas de seguridad

- **Rate limiting del login/registro**: implementado con un contador **en memoria**
  (`backend/src/middleware/rateLimiter.js`). Funciona para instancias únicas, pero
  **no es fiable en entornos serverless/escalados (Vercel)** porque el límite se
  aplica por instancia. Para producción se recomienda un limitador distribuido
  (tabla SQL con los intentos por IP, Upstash Redis, Cloudflare Rate Limiting) o
  el plugin `@upstash/ratelimit`.

- **CORS**: la API solo permite orígenes listados en `CORS_ORIGINS`. Si el valor
  está vacío, se bloquean las peticiones de navegador con `Origin` y se permiten
  las server-to-server (curl/Postman/backends).

- **JWT y revocación de sesión**: los tokens llevan un `jti` que referencia la tabla
  `sesiones`; al hacer logout se marca la sesión como inactiva y el token deja de
  ser válido.

- **Hash de contraseñas**: con `bcryptjs` en el backend y Firebase Auth en el frontend.

- **Protección de secretos**: los archivos `.env`, `service-account.json`,
  `firebase-migrator-key.json`, `upload-keystore.jks` y `key.properties` están
  en `.gitignore` y **nunca deben subirse al repositorio**.

---

## 📝 Documentación adicional

- `CONTRIBUTING.md` — guía rápida de contribución (flujo git del equipo).
- `AGENTS.md` — reglas que debe cumplir cualquier agente de IA en el repo.
- `docs/INSTALACION.md` — **guía de instalación desde cero en un PC nuevo** (Git, Node, Flutter, clonar, configurar y correr).
- `docs/GIT_CONVENTION.md` — convenciones de Git (ramas, commits, PRs, tags).
- `docs/STACK.md` — stack tecnológico en detalle y decisiones técnicas.
- `docs/AGENTES.md` — agentes (GLM 5.3, DeepSeek v4 Pro, GPT 5.6 Luna) y skills de OpenCode.
- `docs/API.md` — Documentación de endpoints de la API.
- `docs/DEPLOY.md` — Guía de despliegue en Vercel.
- `docs/TEAM.md` — Equipo y roles de trabajo.
- `docs/SPRINT.md` — Plan de trabajo (Trello).
- `docs/REVISION_BASE_DE_DATOS.md` — Revisión técnica de la base de datos.
- `mail-service/README.md` — guía del servicio de correo.
- `frontend/README.md` — guía específica del frontend.

---

®️ **ConsultorioClínico** — Proyecto de control médico y clínico.
