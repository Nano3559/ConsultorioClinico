# Guía de Despliegue en Vercel

Este documento explica cómo se despliega el backend (Node.js/Express) en Vercel, junto con el frontend.

## Arquitectura de despliegue

```
github.com/.../ConsultorioClinico
         │
         ▼
      Vercel
         │
         ├── api/index.js  (handler serverless raíz → require backend/src/app)
         │
         └── backend/api/index.js  (handler alternativo → require ../src/app)
```

- `vercel.json` (raíz) redirige **todo** el tráfico a `api/index.js` mediante un rewrite.
- `api/index.js` envuelve la app Express exportada en `backend/src/app.js`.
- `package.json` (raíz) incluye `npm run vercel-build` que ejecuta `npm install --prefix backend`.

## Configuración de `vercel.json` (raíz)

```json
{
  "version": 2,
  "installCommand": "npm install",
  "outputDirectory": ".",
  "rewrites": [
    { "source": "/((?!api/).*)", "destination": "/api/index.js" }
  ]
}
```

## Pasos para desplegar

### 1. Requisitos previos

- Repositorio del proyecto en GitHub.
- Cuenta en [vercel.com](https://vercel.com).
- Proyecto de Supabase creado (URL, anon key y service role key).

### 2. Importar el proyecto

1. Entrar a Vercel → **Add New → Project**.
2. Importar el repositorio `ConsultorioClinico`.
3. **Framework Preset:** *Other*.
4. **Root Directory:** root (dejar vacío).

### 3. Variables de entorno

En Vercel → **Project → Settings → Environment Variables** agregar las variables de `backend/.env`:

| Variable | Ejemplo |
|---|---|
| `NODE_ENV` | `production` |
| `JWT_SECRET` | `valor-largo-secreto` |
| `JWT_EXPIRE` | `7d` |
| `SUPABASE_URL` | `https://xxxx.supabase.co` |
| `SUPABASE_ANON_KEY` | `eyJhb...` |
| `SUPABASE_SERVICE_ROLE_KEY` | `eyJhb...` (solo backend) |
| `SUPABASE_DB_URL` | `postgresql://...` (para migraciones) |

> ⚠️ **Nunca** pongas `PORT` en Vercel (Vercel lo gestiona). No subas `backend/.env` al repositorio.

### 4. Deploy

1. En la pestaña **Deployments**, pulsar **Deploy** o hacer push a la rama de producción.
2. Vercel ejecuta `npm install` (raíz) y luego `npm run vercel-build`
   (`npm install --prefix backend`).
3. Esperar a que el build termine y verificar la URL del proyecto
   (ej. `https://consultorio-clinico.vercel.app`).

### 5. Verificar

- `GET https://<proyecto>.vercel.app/api/health` → `200`.
- `GET https://<proyecto>.vercel.app/api/` → JSON con la lista de endpoints.
- Probar login: `POST /api/auth/login`.

## Configuración del frontend (Flutter)

El frontend apunta al backend desplegado por defecto:

```dart
// frontend/lib/services/api_client.dart
static const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://consultorio-clinico.vercel.app/api',
);
```

Para compilar el frontend apuntando a otro entorno:

```bash
flutter build web --dart-define=API_BASE_URL=https://<proyecto>.vercel.app/api
```

## Despliegue local (pruebas)

```bash
# Backend
cd backend
npm install
npm run dev        # http://localhost:3000

# Frontend
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api
```

## Scripts de despliegue y BD

```bash
cd backend
npm run db:migrate        # aplicar migraciones (requiere SUPABASE_DB_URL)
npm run db:seed           # usuarios semilla
npm run db:seed:ficticio  # datos demo vía API
npm run db:init           # inicialización completa
```

## Checklist de producción

- [ ] Las rutas `/api/test/env` y `/api/test/db` están restringidas o deshabilitadas.
- [ ] `credenciales.txt` y `backend/.env` **no** están en el repositorio.
- [ ] `JWT_SECRET` es un valor largo y único.
- [ ] Variables de entorno configuradas en Vercel.
- [ ] Las migraciones se aplicaron en la base de datos de producción.
- [ ] `GET /api/health` responde `200`.