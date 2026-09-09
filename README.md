# ConsultorioClínico

Sistema de control médico y clínico: gestión de pacientes, médicos, especialidades, citas, agenda, historia clínica, pagos y reportes.

## Descripción

Plataforma full-stack para la administración de un consultorio médico con paneles por rol:

- **Página pública** (landing) para conocer el consultorio y solicitar citas.
- **Panel de administrador**: gestión completa del sistema.
- **Panel de médico**: agenda de citas, pacientes e historia clínica.
- **Panel de recepción**: pacientes, citas y pagos.
- **Panel de paciente**: solicitad de citas y consulta de sus propias citas.

## Stack Tecnológico

| Capa | Tecnología |
|---|---|
| Frontend | Flutter (Dart 3.13+, Flutter 3.47+) — web y móvil |
| Backend | Node.js 22 + Express 4 |
| Base de datos | Supabase (PostgreSQL) con Row Level Security |
| Autenticación | JWT (jsonwebtoken) + bcryptjs |
| Despliegue | Vercel |
| Control de versiones | Git + GitHub |

### Dependencias principales del backend

`@supabase/supabase-js`, `bcryptjs`, `compression`, `cors`, `dotenv`, `express`, `express-validator`, `helmet`, `jsonwebtoken`, `morgan`.

### Dependencias principales del frontend

`provider`, `go_router`, `intl`, `fl_chart`, `http`, `lottie`.

## Estructura del Proyecto

```
ConsultorioClinico/
├── api/
│   └── index.js                  # Handler serverless raíz para Vercel (envuelve backend/src/app)
├── backend/
│   ├── api/index.js              # Handler serverless del backend para Vercel
│   ├── db/
│   │   ├── migrations/           # Migraciones SQL (001_initial_schema ... 009_estado_confirmada)
│   │   ├── migrate.js            # Aplicador de migraciones
│   │   ├── seed.js               # Usuarios semilla
│   │   ├── seed_ficticio.js      # Datos demo vía API REST
│   │   └── index.js              # Inicialización unificada (check/seed/migrate)
│   ├── src/
│   │   ├── app.js                # App Express (middlewares globales + montaje de rutas)
│   │   ├── server.js             # Arranque del servidor HTTP
│   │   ├── config/               # config.js (env) y supabase.js (cliente)
│   │   ├── controllers/          # lógica de negocio por módulo
│   │   ├── middleware/           # auth.js (JWT), roles.js, validation.js
│   │   ├── routes/               # definición de endpoints
│   │   ├── utils/                # constants.js, helpers.js
│   │   ├── data/mockData.js      # datos mock en memoria
│   │   └── views/, public/       # plantillas EJS y assets de la landing (código muerto)
│   ├── test/apiTest.js           # Suite de pruebas HTTP (62 pruebas)
│   ├── .env                      # variables de entorno (NO se sube a git)
│   └── package.json
├── docs/
│   ├── API.md                    # Documentación de endpoints
│   ├── DEPLOY.md                 # Guía de despliegue en Vercel
│   ├── TEAM.md                   # Equipo y roles
│   ├── SPRINT.md                 # Plan de trabajo (Trello)
│   └── REVISION_BASE_DE_DATOS.md # Revisión técnica de la BD
├── frontend/
│   ├── lib/
│   │   ├── main.dart             # Punto de entrada (Providers + GoRouter)
│   │   ├── core/                 # constantes, tema, utilidades, widgets compartidos
│   │   ├── data/models/          # modelos (User, Patient, Doctor, ...)
│   │   ├── data/mock/            # datos ficticios (fallback sin backend)
│   │   ├── services/             # api_client.dart (cliente HTTP + URL base)
│   │   ├── state/                # auth_provider.dart, clinic_provider.dart
│   │   └── features/             # public (landing/login/cita) e internal (paneles)
│   ├── test/                     # widget tests
│   └── pubspec.yaml
├── vercel.json                   # configuración de despliegue Vercel
├── package.json                  # scripts raíz (build de Vercel)
├── .gitignore
└── README.md
```

## Instalación y Configuración

### Requisitos

- Node.js 22.x
- Flutter 3.47+ (Dart 3.13+)
- Proyecto de Supabase (PostgreSQL)
- Cuenta de Vercel (opcional, para desplegar)

### Backend

```bash
cd backend
npm install
cp .env.example .env   # si existe; si no, crear .env con las variables indicadas abajo
npm run dev            # o npm start
```

La API queda disponible en `http://localhost:3000`.

### Frontend

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

Para apuntar a un backend local:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:3000/api
```

La URL por defecto de producción es `https://consultorio-clinico.vercel.app/api`
(se define en `frontend/lib/services/api_client.dart`).

### Base de datos (Supabase)

```bash
cd backend
npm run db:migrate      # aplica las migraciones (requiere SUPABASE_DB_URL)
npm run db:seed         # usuarios semilla (admin, médico, recepción, paciente)
npm run db:seed:ficticio# datos demo vía API
npm run db:check        # verifica conexión y migraciones
```

## Variables de Entorno

Se definen en `backend/.env`:

| Variable | Descripción |
|---|---|
| `PORT` | Puerto del servidor (por defecto 3000) |
| `NODE_ENV` | `development` o `production` |
| `JWT_SECRET` | Secreto para firmar tokens JWT |
| `JWT_EXPIRE` | Tiempo de expiración (ej. `7d`) |
| `SUPABASE_URL` | URL del proyecto de Supabase |
| `SUPABASE_ANON_KEY` | Clave pública (anon) de Supabase |
| `SUPABASE_SERVICE_ROLE_KEY` | Clave de servicio (bypasa RLS, SOLO backend) |
| `SUPABASE_DB_URL` | Cadena de conexión directa a PostgreSQL (para migraciones) |

> ⚠️ **Seguridad**: `backend/.env`, `SUPABASE_SERVICE_ROLE_KEY` y el archivo `credenciales.txt`
> no deben subirse nunca a git ni compartirse. Véase `.gitignore`.

## Endpoints de la API

Todos los endpoints viven bajo `/api`. La documentación completa está en [docs/API.md](docs/API.md).

Resumen:

| Recurso | Métodos |
|---|---|
| `/api/auth` | `POST /register`, `POST /login`, `GET /profile`, `POST /logout` |
| `/api/pacientes` | `GET /`, `GET /:id`, `POST /`, `PUT /:id`, `DELETE /:id` |
| `/api/medicos` | `GET /`, `GET /:id`, `POST /`, `PUT /:id`, `PATCH /:id/estado`, `DELETE /:id`, horarios |
| `/api/especialidades` | CRUD + consultas por médico |
| `/api/horarios` | CRUD + disponibles |
| `/api/citas` | CRUD, agenda del día, mis citas, confirmar, estados |
| `/api/disponibilidad` | Slots libres por médico/fecha y por especialidad |
| `/api/consultas` | CRUD + historia clínica por paciente |
| `/api/pagos` | CRUD + estado |
| `/api/reportes` | Reporte de citas e ingresos |
| `/api/dashboard` | Resumen de KPIs |
| `/api/health` | Health check |

## Roles del Sistema

| Rol | Permisos |
|---|---|
| Administrador | Gestión completa del sistema |
| Médico | Ver citas, consultar pacientes, registrar consultas |
| Recepción | Registrar pacientes, crear/confirmar citas, registrar pagos |
| Paciente | Registrarse, solicitar citas, consultar sus citas |

## Convención de Commits (Git)

El proyecto usa **Conventional Commits**. Tipos utilizados: `feat`, `fix`, `test`, `docs`, `chore`, `refactor`, `style`.

Formato:

```
tipo(alcance): descripción
```

Ejemplos:

```
feat(backend): agregar API Citas
fix(auth): corregir login
test(backend): suite de pruebas de API 62/62
feat(db): integridad, validaciones y migraciones
```

Ramas: `main` (estable), `develop` (integración), `feature/*` (funcionalidades),
`fix/*` (correcciones). Se integran mediante Pull Requests con merge a `main`.

## Despliegue en Vercel

La guía detallada está en [docs/DEPLOY.md](docs/DEPLOY.md). Resumen:

1. Conectar el repositorio de GitHub a Vercel.
2. Framework preset: *Other*.
3. Variables de entorno: las de `backend/.env` (excepto `PORT`).
4. `npm run vercel-build` instala las dependencias del backend automáticamente.
5. `vercel.json` redirige todo el tráfico a `api/index.js`, que envuelve la app Express.

## Pruebas

```bash
cd backend
npm run test:api     # suite de pruebas HTTP (62 pruebas, puerto 3998)
```

```bash
cd frontend
flutter test         # widget tests (login, shells, landing)
```

## Contribuciones

1. Clonar el repositorio y crear rama `feature/*` o `fix/*` desde `develop`.
2. Implementar y probar los cambios.
3. Commit con Conventional Commits.
4. Abrir un Pull Request hacia `develop`.
5. Solicitar revisión del equipo antes del merge a `main`.

## Documentación Adicional

- [docs/API.md](docs/API.md) — Documentación de endpoints de la API
- [docs/DEPLOY.md](docs/DEPLOY.md) — Guía de despliegue en Vercel
- [docs/TEAM.md](docs/TEAM.md) — Equipo y roles de trabajo
- [docs/SPRINT.md](docs/SPRINT.md) — Plan de trabajo (Trello)
- [docs/REVISION_BASE_DE_DATOS.md](docs/REVISION_BASE_DE_DATOS.md) — Revisión técnica de la base de datos

## Licencia

Proyecto académico/privado. No se distribuye bajo licencia pública.