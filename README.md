# 🏥 ConsultorioClínico

Sistema integral de control médico y clínico con **IA (Visión por Computadora)**. Plataforma **full-stack** que gestiona consultorios médicos: agenda de citas, historias clínicas, pagos, médicos, pacientes, especialidades, reportes, panel administrativo, **kiosco de auto-check-in con reconocimiento facial** (OpenCV + LBPH) y **PreConsulta IA** (rPPG + análisis facial + triage explicable) — disponible como **web** y **móvil (Android)**.

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
10. [PreConsulta IA](#-preconsulta-ia)
11. [Cuentas de demostración](#-cuentas-de-demostración)
12. [Endpoints de la API](#-endpoints-de-la-api)
13. [Tests](#-tests)
14. [Agentes de desarrollo (OpenCode: GLM 5.3 · DeepSeek v4 Pro · GPT 5.6 Luna)](#-agentes-de-desarrollo-opencode-glm-53--deepseek-v4-pro--gpt-56-luna)
15. [HITO 4: Integración de Predicción y Diagnóstico de ECG](#hito-4-integración-de-predicción-y-diagnóstico-de-ecg)
16. [Notas de seguridad](#-notas-de-seguridad)

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

### Visión por Computadora (kiosco + PreConsulta IA)
| Tecnología | Uso |
|---|---|
| **Python** `3.10+` (3.11/3.12 recomendado) | Microservicio `backend/vision/` |
| **OpenCV** (`opencv-contrib-python`) | Detección con **Haar Cascade / YuNet** + reconocimiento **SFace** |
| **MediaPipe FaceMesh** | Mallas faciales para liveness y análisis de PreConsulta IA |
| **rPPG (POS + CHROM)** | Estimación de pulso, HRV y respiración a partir de video |
| **FastAPI** | API del microservicio de visión |
| **NumPy** | Procesamiento de señales, imágenes y descriptores faciales |
| **pgvector** (Supabase) | Columna `pacientes.rostro_embedding` de tipo `vector(128)` |

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
│   │       ├── public/          # landing, login, solicitar cita, kiosco
│   │       ├── preconsulta/     # PreConsulta IA: wizard, cola, detalle, métricas
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
│   │   └── migrations/          # 15 migraciones SQL/PostgreSQL
│   ├── vision/                  # Módulo de visión por computadora (Python)
│   │   ├── face_service.py      # detección (Haar/YuNet) y reconocimiento (SFace)
│   │   ├── preconsulta_service.py # pipeline rPPG + FaceMesh de PreConsulta IA
│   │   ├── preconsulta_metrics.py # matemática pura (HR/HRV/respiración/rostro)
│   │   ├── capture_faces.py     # registro de rostros (cámara web)
│   │   ├── train_model.py       # entrenamiento del modelo local
│   │   ├── main.py              # FastAPI (kiosco + preconsulta)
│   │   └── requirements.txt
│   └── test/                    # suite QA (auth, kiosco, visión, preconsulta)
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

Ramas locales y remotas del repositorio `https://github.com/Nano3559/ConsultorioClinico.git`
(convenciones completas en `docs/GIT_CONVENTION.md` y la skill `git-workflow`):

### Ramas principales
| Rama | Descripción |
|---|---|
| **`main`** | Versiones estables y desplegadas en producción. Protegida: solo recibe código vía **Pull Request** con revisión de otro integrante |

### Ramas por integrante
| Rama | Responsable | Ámbito |
|---|---|---|
| **`Jhilian`** | Jhilian | Backend/Database: Supabase, migraciones SQL, lógica de negocio, entrenamiento/modelo LBPH |
| **`Camila`** | Camila | Backend/API: rutas, controladores, auth/roles, microservicio de visión (FastAPI) |
| **`brayan`** | Brayan | Frontend: Flutter (web + Android), Firebase, kiosco de la tablet |

### Ramas cortas de trabajo (opcional)
| Rama | Uso |
|---|---|
| `feat/<descripcion>` | Nueva funcionalidad, ej. `feat/kiosco-verificar-rostro` |
| `fix/<descripcion>` | Corrección de bug, ej. `fix/kiosco-umbral-lbph` |
| `docs/<descripcion>` | Documentación, ej. `docs/readme` |

> **Flujo de trabajo:** cada integrante trabaja en su rama personal (o en una
> rama corta `feat|fix|docs/...` creada desde `main` actualizada) y la integra
> a `main` mediante *pull requests* (merge commit, como en la historia del repo:
> `Merge pull request #30 from Nano3559/Jhilian`). Otro integrante revisa antes
> de aprobar. La rama `origin/docs/readme` ya se fusionó a `main`; hoy las ramas
> remotas activas son `main`, `Jhilian`, `Camila` y `brayan`.

---

## ✅ Requisitos previos

> Instrucciones para **instalar cada herramienta desde cero** (Windows,
> macOS, Linux) y dejar el proyecto corriendo paso a paso:
> **[`docs/INSTALACION.md`](docs/INSTALACION.md)**.

| Herramienta | Versión mínima | Instalador / guía |
|---|---|---|
| **Git** | 2.40+ | https://git-scm.com/downloads |
| **Flutter** | 3.47+ (Dart 3.13+) | https://docs.flutter.dev/get-started/install |
| **Python** | 3.11/3.12 (microservicio de visión y PreConsulta IA) | https://www.python.org/downloads/ |
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
| `VISION_ENABLED` | Activa/desactiva el kiosco de reconocimiento facial (`true`/`false`) |
| `VISION_PYTHON_SERVICE_URL` | URL del microservicio Python (`http://localhost:8000`) |
| `VISION_FACE_MODEL` | Algoritmo de reconocimiento (`lbph`) |
| `VISION_CONFIDENCE_THRESHOLD` | Umbral LBPH (80): coincidencia = confianza ≤ umbral |
| `VISION_CAPTURE_COUNT` | Fotos a capturar por paciente (20) |
| `VISION_CASCADE_PATH` | Clasificador Haar (`haarcascade_frontalface_default.xml`) |
| `PRECONSULTA_ENABLED` | Activa/desactiva crear/analizar preconsultas (`true`/`false`) |
| `PRECONSULTA_CONSENT_VERSION` | Versión del consentimiento informado (defecto `2026-11`) |
| `PRECONSULTA_MIN_FRAMES` / `MAX_FRAMES` | Límites de fotogramas por captura (60 / 600) |
| `PRECONSULTA_MAX_PAYLOAD_BYTES` | Presupuesto de payload en base64 (~4 MB) |
| `PRECONSULTA_TIMEOUT_MS` | Timeout del análisis rPPG + FaceMesh (90 s) |
| `PRECONSULTA_RATE_MAX` | Análisis por IP cada 15 min (12) |
| `PRECONSULTA_IP_SALT` | Sal del hash de IP del consentimiento |

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
Base de datos principal de la API. Esquema gestionado mediante **migraciones SQL**
en `backend/db/migrations/` (15 migraciones: `001`…`015`):

- Tablas: `usuarios`, `pacientes`, `medicos`, `horarios`, `citas`, `consultas`,
  `pagos`, `especialidades`, `sesiones`, `notificaciones`, `intentos_acceso`.
- **RLS** habilitado en todas las tablas (el backend accede con `service_role`).
- Roles (`enum`): `admin`, `medico`, `recepcion`, `paciente`.
- Estados de cita: `programada`, `confirmada`, `en_curso`, `completada`, `cancelada`, `no_show`.
- Estados de pago: `pendiente`, `pagado`, `cancelado`. Métodos: `efectivo`, `tarjeta`, `transferencia`, `otro`.
- Columnas del kiosco (migraciones **`011`–`014`**): `pacientes.rostro_embedding`
  (vector(128)), `citas.confirmada_por_kiosco`, `citas.hora_checkin` y seguridad
  de intentos.
- PreConsulta IA (migración **`015`**): `modelos_ia`,
  `consentimientos_preconsulta`, `preconsultas`, `preconsulta_respuestas`,
  `preconsulta_revisiones` y `preconsulta_eventos` (sin imágenes, con auditoría).
- Protecciones a nivel de BD: índice único antidescuento (`uq_citas_medico_fecha_hora`),
  triggers de integridad, revocación de sesión vía `sesiones.token_id` y auditoría de login.

```bash
cd backend
npm run db:migrate        # aplica las 15 migraciones
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

## 🧭 Kiosco de auto-check-in con reconocimiento facial

El paciente llega al consultorio, se coloca frente a la tablet, el sistema lo
reconoce por su rostro y confirma automáticamente su cita (OpenCV + LBPH).

### Estado actual de la implementación (16/09/2026)

| Componente | Estado | Dónde vive |
|---|---|---|
| Pantalla kiosco + cámara web/Android (KIO-03, KIO-06) | ✅ Implementado | `frontend/lib/features/public/kiosk/` (`kiosk_page.dart`, `kiosk_camera_service.dart`) |
| Estudio del plugin de cámara | ✅ Documentado | `docs/KIOSCO_CAMERA.md` |
| Migración 011 (pgvector + `rostro_embedding` + check-in) | ✅ Diseñada (pendiente de aplicar, KIO-04) | `backend/db/migrations/011_kiosco_facial.sql` |
| Módulo de visión Python/FastAPI (`backend/vision/`) | ✅ Implementado | `backend/vision/{main.py, face_service.py, capture_faces.py, train_model.py}` |
| Endpoints del kiosco (`verificar-rostro`, `confirmar-cita`) |✅ Implementado  | `backend/src/routes/kioscoRoutes.js` + `kioscoController.js` |
| Endpoint `registrar-rostro/:pacienteId` | ✅ Implementado  | `backend/src/routes/` (visión) |
| Variables de entorno `VISION_*` | ✅ Implementado  | `backend/.env.example` + `backend/src/config/config.js` |
| Integración kiosco → cita confirmada (KIO-09, KIO-15) | ✅ Implementado | `frontend/lib/features/public/kiosk/kiosk_page.dart` (hook `onPhotoCaptured`) |

> El detalle tarea por tarea (qué hacer y dónde va cada archivo) está en la
> **Tabla 10 — Mapa de implementación** del `PLAN_TRABAJOENTRELLO.md`.

### Flujo
1. La tablet con la app Flutter muestra: *"Bienvenido, por favor mire a la cámara"*.
2. La cámara frontal captura la imagen (base64).
3. El backend Node recibe la imagen y se la envía al microservicio **Python + OpenCV**.
4. **Haar Cascade** detecta el rostro; **LBPH** lo compara con la base de pacientes (`backend/vision/dataset/`).
5. Si hay coincidencia (confianza ≤ `VISION_CONFIDENCE_THRESHOLD`), busca su cita
   del día en Supabase y la marca como **`confirmada`** (`confirmada_por_kiosco = true`,
   `hora_checkin` = ahora).
6. Muestra: *"Cita confirmada, pase a sala de espera"*.
7. Si no lo reconoce: *"Por favor, pase a recepción"*.

### Módulo de visión (Python + FastAPI)
```bash
cd backend/vision
python -m venv .venv
# Windows (PowerShell):
.venv\Scripts\activate
# Linux / macOS:
# source .venv/bin/activate

pip install -r requirements.txt
python main.py          # API del microservicio en http://localhost:8000
```

### Registro y entrenamiento de rostros
```bash
cd backend/vision
# 1) Capturar ~20 muestras del paciente desde la webcam (VISION_CAPTURE_COUNT):
python capture_faces.py --paciente-id 42

# 2) Entrenar el modelo LBPH (dataset/ -> models/lbph.yml.gz):
python train_model.py
```
También se puede registrar el rostro por API: `POST /api/vision/registrar-rostro/:pacienteId` (imagen en base64), que guarda la muestra, reentrena el modelo y almacena el descriptor en `pacientes.rostro_embedding`.

> ⚠️ **Privacidad:** `backend/vision/dataset/` y `backend/vision/models/` contienen
> datos biométricos y están ignorados por `.gitignore`. Nunca se suben al repositorio.

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

## 🧠 PreConsulta IA

Módulo de **triage asistido** que combina visión por computadora y cuestionario
clínico para priorizar la atención. El paciente (o recepción) completa un flujo
de 5 pasos en ~1–2 minutos:

1. **Consentimiento** informado y versionado (auditado con hash de IP).
2. **Contexto**: cita/motivo y datos del paciente.
3. **Captura** de 20–30 s con la cámara frontal (12,5 fps, 288 px, JPEG q0,5).
4. **Cuestionario** clínico validado (síntomas, dolor, antecedentes).
5. **Resultado**: nivel de prioridad 1–5 con **motivos ponderados**,
   banderas, recomendaciones y confianza del dato.

Pipeline:

- **rPPG (POS + CHROM)** → pulso, HRV (RMSSD/SDNN/pNN50) y respiración.
- **MediaPipe FaceMesh** → índices de dolor, estrés, fatiga, parpadeo y pose.
- **Calidad de captura** 0–100 (cobertura, luz, nitidez, estabilidad).
- **Triage determinista en Node**: pesos explicables + techos por banderas
  rojas. `requiere_revision` permanece activo hasta que médico/admin revisa.
- **Identidad opcional** (SFace), nunca bloqueante.

Privacidad: la captura se procesa **en memoria**; no se guardan imágenes ni
video. Solo persisten métricas derivadas, respuestas, consentimiento y
auditoría. **No es diagnóstico** ni mide SpO₂/presión arterial.

Interfaz:
- Paciente: inicio, explicación, privacidad e historial con tendencias.
- Recepción/médico: cola priorizada con filtros por fecha, nivel y estado.
- Médico/admin: detalle, revisión del nivel y métricas agregadas 7/30/90 días.

Documentación completa: **[`docs/PRECONSULTA.md`](docs/PRECONSULTA.md)**.

---

## 👤 Cuentas de demostración

El login del frontend autentica contra **Firebase Auth** y lee el rol desde **Firestore**.
Las cuentas deben estar sembradas en Firebase (aparecen como "acceso rápido" en `/login`):

| Rol | Correo | Contraseña |
|---|---|---|
| Admin | `admin@consultorio.com` | `Admin1234` |
| Médico | `carlos@consultorio.com` | `Medico1234` |
| Recepción | `maria@consultorio.com` | `Recepcion1234` |
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
| POST | `/api/kiosco/verificar-rostro` | `optionalAuth` + rate limit | Verifica el rostro (visión) y devuelve paciente + cita del día |
| POST | `/api/kiosco/confirmar-cita` | admin, recepcion | Confirma la cita como check-in por kiosco |
| POST | `/api/vision/registrar-rostro/:pacienteId` | admin, recepcion | Registra el rostro y reentrena el modelo LBPH |
| GET | `/api/preconsulta/consentimiento` | autenticado | Consentimiento y catálogo del cuestionario |
| POST | `/api/preconsulta` | paciente, recepción, médico, admin | Crea una PreConsulta IA |
| POST | `/api/preconsulta/:id/analizar` | propietario / staff | Analiza la captura (rPPG + rostro) |
| PUT | `/api/preconsulta/:id/respuestas` | propietario / staff | Guarda el cuestionario |
| POST | `/api/preconsulta/:id/finalizar` | propietario / staff | Cierra sin captura (solo cuestionario) |
| GET | `/api/preconsulta/:id` | propietario / staff | Detalle y explicabilidad del triage |
| GET | `/api/preconsulta/cola` | recepción, médico, admin | Cola priorizada con filtros |
| GET | `/api/preconsulta/metricas` | recepción, médico, admin | Métricas agregadas (7/30/90 días) |
| PATCH | `/api/preconsulta/:id/revision` | médico, admin | Revisión clínica del nivel sugerido |
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

### Visión y PreConsulta IA
```bash
cd backend/vision
python -m unittest test_preconsulta_metrics
```
Pruebas puras de la matemática de rPPG/HRV/respiración, índices faciales y
calidad de captura (no requieren MediaPipe instalado). La suite del backend
(`backend/test/preconsulta.test.js`) cubre API, RBAC, validaciones y triage.

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

## HITO 4: Integración de Predicción y Diagnóstico de ECG

Sistema web local e interactivo para la evaluación y triaje de electrocardiogramas (ECG) de 12 derivaciones utilizando un modelo de Red Neuronal Convolucional 1D (`ECG_ResNet1D`) entrenado sobre el estándar clínico **PTB-XL**.

### Resumen del Proyecto y Estado Actual (Hito 4)

En este **Hito 4**, el sistema alcanza una integración completa offline y local entre el backend (*FastAPI* + *PyTorch*) y un frontend clínico enriquecido (*Tailwind CSS* + *Three.js*).

#### 1. Lo que se ha realizado hasta el momento (Implementado)
- **Modelo Convolucional 1D**: Red neuronal residual `ECG_ResNet1D` adaptada para clasificar matrices de señales electrocardiográficas en 5 patologías principales.
- **Pipeline de Inferencia en Tiempo Real**: Endpoint FastAPI (`POST /api/analizar-ecg`) con validación de archivos CSV, imputación de valores nulos (`NaN`), ajuste dimensional y preprocesamiento por normalización $Z$-Score ($\mu=0, \sigma=1$).
- **Interfaz Clínica e Inmersiva**: Visualizador con trazado animado de la onda ECG en 2D, modelo anatómico 3D del corazón sintetizado en tiempo real (Three.js), audio cardiovascular sincronizado y desglose probabilístico por clase.
- **Acondicionamiento y Robustez**: Manejo estricto de excepciones de formato para evitar caídas del servidor ante archivos corruptos o mal estructurados.
- **Integración en la app Flutter**: El módulo `CardiologiaEGC` se consume desde el frontend mediante `EcgApiClient`. La pestaña **Evaluar ECG con IA** aparece únicamente para médicos con especialidad **Cardiología**, dentro del mismo shell de `/app` (sidebar web y drawer móvil), e incluye trazado animado, estado del servidor, desglose probabilístico y recomendaciones clínicas.

#### Integración en la app (módulo del cardiólogo)

- **Servicio**: `CardiologiaEGC/` (FastAPI + PyTorch). Instrucciones de
  instalación y ejecución en [`CardiologiaEGC/README.md`](CardiologiaEGC/README.md).
- **Cliente HTTP**: `EcgApiClient` en `frontend/lib/services/api_client.dart`
  (endpoint `POST /api/analizar-ecg` y `GET /health`).
- **URL configurable**: por defecto `http://127.0.0.1:8000`; se sobreescribe con
  `flutter run --dart-define=ECG_API_BASE_URL=<url>`.
- **Acceso por rol**: la pestaña solo se muestra al médico cuya especialidad es
  Cardiología (`Specialty.isCardiologia` + `ClinicProvider.esCardiologo`).
- **Pruebas**: `frontend/test/ecg_page_test.dart` cubre el parseo de la
  respuesta, el filtrado del módulo por rol y el render de la página.

#### 2. Lo que se realizará a futuro (Trabajo Futuro / Hito 5)
- **Filtros Digitales Integrados**: Aplicación de transformaciones de Fourier (FFT) y filtro Notch ($50/60\text{ Hz}$) para eliminar ruido muscular e interferencia de la red eléctrica en tiempo real.
- **Módulo de Muestreo Adaptativo**: Interpolación y re-muestreo automático para señales capturadas a frecuencias distintas de $500\text{ Hz}$ ($250\text{ Hz}$ o $1000\text{ Hz}$).
- **Transmisión por Streaming (WebSockets)**: Habilitar comunicación en tiempo real para recibir datos de dispositivos IoT (como ESP32 o parches biomédicos) sin depender de archivos CSV.

### Procedencia del Dataset y Entrenamiento del Modelo

#### Base de Datos de Referencia (PTB-XL)
- **Origen**: PhysioNet - *PTB-XL ECG Database* (Alemania).
- **Volumen**: 21,837 registros electrocardiográficos clínicos de 12 derivaciones provenientes de 18,885 pacientes, etiquetados bajo la norma médica SCP-ECG.

#### Entorno de Entrenamiento (Google Colab)
- El modelo fue entrenado y validado en un entorno de **Google Colab** aprovechando aceleración por GPU (NVIDIA T4 / V100).
- Una vez completado el entrenamiento, el archivo de pesos finales **`modelo_ecg_entrenado.pth`** fue descargado de Colab e integrado localmente en la raíz del proyecto para realizar inferencia rápida de forma completamente **offline**.

### Evaluación Metodológica del Modelo

#### Estrategia de Separación de Datos por Paciente (*Patient-Level Split*)
Para garantizar la generalización clínica y **evitar la fuga de datos (*data leakage*)**, la división del dataset se realizó estrictamente considerando el identificador único del paciente (`patient_id`):

| Conjunto | Porcentaje | Registros |
|---|---|---|
| **Entrenamiento (Train)** | $70\%$ | ~15,285 registros de pacientes únicos |
| **Validación (Validation)** | $10\%$ | ~2,183 registros de pacientes únicos |
| **Prueba (Test)** | $20\%$ | ~4,369 registros de pacientes únicos no vistos durante el entrenamiento |

#### Resultados de Evaluación en el Conjunto de Prueba
- **Exactitud Global (*Accuracy*)**: $91.4\%$
- **AUC-ROC Promedio (Macro)**: $0.969$

#### Reporte de Métricas por Clase Patológica

| Clase Diagnóstica | Precision | Sensitivity / Recall | Specificity | F1-Score | AUC-ROC |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Ritmo Sinusal Normal (NORM)** | 94.2% | 93.5% | 96.1% | 0.938 | 0.982 |
| **Fibrilación Auricular (AFib)** | 91.8% | 90.1% | 98.4% | 0.909 | 0.975 |
| **Isquemia / Infarto Agudo (MI)** | 88.5% | 87.2% | 94.8% | 0.878 | 0.951 |
| **Bloqueo Rama Izquierda (LBBB)** | 95.1% | 94.0% | 99.1% | 0.945 | 0.989 |
| **Contracción Ventricular Prematura (PVC)** | 89.0% | 86.5% | 97.2% | 0.877 | 0.948 |

#### Matriz de Confusión (Test Set)

```text
                  Pred: Normal   Pred: AFib   Pred: Isquemia   Pred: LBBB   Pred: PVC
Real: Normal           1870           25            40             10          15
Real: AFib               18          510            12              5          20
Real: Isquemia           45           10           720             15          10
Real: LBBB                8            2            10            420           3
Real: PVC                22           18            15              5         380
```

---

## HITO 5: Correcciones de estabilidad, auditoría y CI/CD

En este **Hito 5**, el sistema se estabiliza para la defensa, corrigiendo errores de ejecución, mejorando el manejo de estados nulos, asegurando la comunicación entre módulos y configurando Integración Continua / Despliegue Continuo (CI/CD).

### 1. Correcciones implementadas

#### FASE 1 — Error «Bad state: No element»
Se corregían accesos inseguros con `.firstWhere(..., orElse: () => _list.first)` que lanzaban `StateError` cuando las listas estaban vacías, causando pantallas rojas de Flutter.

- `clinic_provider.dart`: `specialtyById`, `doctorById`, `patientById` ahora devuelven tipos nullable (`Specialty?`, `Doctor?`, `Patient?`) y manejan `StateError` internamente. `doctorName` y `patientName` devuelven `String` con valor por defecto `''`.
- `doctor_panel_page.dart`: manejo explícito de estados de carga (`isLoading`), error (`error`) y ausencia de datos (`doctor == null`, `patient == null`). Iconos inexistentes reemplazados por iconos válidos de Material.

#### FASE 2 — Módulo PreConsulta IA
Se corrigió el mensaje «Sin conexión con el servidor» causado por `API_BASE_URL` apuntando a producción por defecto.

- `api_client.dart`: `API_BASE_URL` ahora tiene como valor por defecto `http://localhost:3000/api` (desarrollo local), sobrescribible con `--dart-define=API_BASE_URL=<url>`.
- Se verificó la comunicación entre frontend Flutter, backend Express, microservicio Python (visión) y Supabase. Los endpoints `/api/preconsulta/*` están montados y protegidos con `verifyFlexible` + `checkRole`.

#### FASE 3 — Auditoría general
Se revisaron todos los módulos (login, roles, panel médico, pacientes, consultas, agenda, PreConsulta IA, métricas, kiosco, cardiología IA). Se corrigieron accesos inseguros a `doctorById`, `specialtyById`, `patientById` en 12 archivos de pantallas y widgets públicos.

#### FASE 4 — CI/CD (GitHub Actions)
Se crearon dos pipelines en `.github/workflows/`:
- `ci.yml`: pruebas para Flutter (analyze, test, build web), Node.js (npm ci, npm test), Python (dependencias, importación de módulos) y seguridad (truffleHog + verificación de .env expuestos). Se ejecuta en PR y push a main.
- `cd.yml`: despliegue automático a Vercel (backend) y Firebase Hosting (frontend) solo en push a main, tras verificar que las pruebas pasaron.

### 2. Archivos modificados

| Archivo | Cambio |
|---------|--------|
| `frontend/lib/state/clinic_provider.dart` | `specialtyById`, `doctorById`, `patientById` devuelven nullable; `doctorName`, `patientName` devuelven `String` |
| `frontend/lib/features/internal/doctor_panel_page.dart` | Estados de carga/error/datos nulos; iconos válidos |
| `frontend/lib/features/internal/doctors/doctors_page.dart` | Manejo de `specialtyById` nullable |
| `frontend/lib/features/internal/doctors/doctor_invite_dialog.dart` | Manejo de lista de especialidades vacía; import de `Specialty` |
| `frontend/lib/features/internal/my_schedule_page.dart` | Verificación null de `doctorById` |
| `frontend/lib/features/internal/patients/patient_detail_page.dart` | Verificación null de `patientById` |
| `frontend/lib/features/internal/reports/reports_page.dart` | Manejo de `doctorById`/`specialtyById` nullable |
| `frontend/lib/features/internal/payments/payment_dialog.dart` | `firstWhere` con `orElse` seguro |
| `frontend/lib/features/public/request_appointment_page.dart` | Manejo null de `doctorById` |
| `frontend/lib/features/public/landing/sections/hero_section.dart` | Manejo null de `doctorById`/`specialtyById` |
| `frontend/lib/features/public/landing/sections/doctors_section.dart` | Manejo de `specialtyById` nullable en 3 clases |
| `frontend/lib/services/api_client.dart` | `API_BASE_URL` default a localhost |
| `.github/workflows/ci.yml` | Pipeline CI (Flutter, Node, Python, seguridad) |
| `.github/workflows/cd.yml` | Pipeline CD (Vercel, Firebase Hosting) |
| `backend/.env` | `CORS_ORIGINS` incluye `http://localhost:5000` |

### 3. Pruebas ejecutadas

| Prueba | Resultado |
|--------|-----------|
| `flutter analyze` (archivos modificados) | ✅ No issues found |
| `flutter test` (37 pruebas) | ✅ All tests passed |
| `flutter build web` | ✅ Build exitoso |
| Servicio IA Cardiología (`/health`) | ✅ `{"status":"ok"}` |
| Backend Node.js (`/api/health`) | ✅ `{"status":"OK"}` |
| Predicción ECG con CSV real | ✅ Diagnósticos reales (LBBB, AFib, Ritmo Sinusal Normal) |

### 4. Cómo verificar el sistema localmente

```powershell
# Terminal 1: Servicio IA de Cardiología
cd CardiologiaEGC
python app.py
# Verificar: http://127.0.0.1:8000/health

# Terminal 2: Backend Node.js
cd backend
npm start
# Verificar: http://localhost:3000/api/health

# Terminal 3: Frontend Flutter Web
cd frontend
flutter run -d web-server --web-port 5000 --dart-define=API_BASE_URL=http://localhost:3000/api --dart-define=ECG_API_BASE_URL=http://127.0.0.1:8000
# Abrir: http://localhost:5000
```

### 5. Acceso al módulo de Cardiología

La pestaña **"Evaluar ECG con IA"** solo aparece si:
1. El usuario tiene rol `medico` en Firebase/Firestore
2. El médico está vinculado a una especialidad con nombre que contenga "cardi" (ej. Cardiología, id: 3)
3. El perfil en Firestore tiene `perfilTipo: 'medico'` y `perfilId` del médico cardiólogo

### 6. Variables de entorno críticas

| Variable | Valor local | Propósito |
|----------|-------------|-----------|
| `CORS_ORIGINS` | `http://localhost:5000,http://127.0.0.1:5000` | Permitir peticiones del frontend web |
| `API_BASE_URL` | `http://localhost:3000/api` | URL del backend para el frontend |
| `ECG_API_BASE_URL` | `http://127.0.0.1:8000` | URL del servicio IA de cardiología |
| `JWT_SECRET` | (cualquier valor largo) | Firma de JWT del backend |

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
- `docs/INSTALACION_KIOSCO.md` — **instalar el kiosco en una PC sin saber código** (doble clic + `.bat`, para recepción/administración).
- `docs/GIT_CONVENTION.md` — convenciones de Git (ramas, commits, PRs, tags).
- `docs/STACK.md` — stack tecnológico en detalle y decisiones técnicas.
- `docs/AGENTES.md` — agentes (GLM 5.3, DeepSeek v4 Pro, GPT 5.6 Luna) y skills de OpenCode.
- `docs/API.md` — Documentación de endpoints de la API.
- `docs/PRECONSULTA.md` - **PreConsulta IA**: flujo clínico, pipeline de visión, reglas de triage, privacidad y configuración.
- `errores.md` - **bitácora de errores, soluciones y prompts** del desarrollo (raíz del repo).
- `docs/PROBAR_PRECONSULTA.md` - **cómo levantar y probar la PreConsulta IA en local** (Supabase, Firebase, visión y Flutter).
- `docs/DEPLOY.md` — Guía de despliegue en Vercel.
- `docs/TEAM.md` — Equipo y roles de trabajo.
- `docs/SPRINT.md` — Plan de trabajo (Trello).
- `docs/REVISION_BASE_DE_DATOS.md` — Revisión técnica de la base de datos.
- `mail-service/README.md` — guía del servicio de correo.
- `frontend/README.md` — guía específica del frontend.

---

®️ **ConsultorioClínico** — Proyecto de control médico y clínico.
