# ConsultorioClinico

Sistema de control médico y clínico.

## Estructura

- `frontend/` — Aplicación móvil/web en Flutter
- `backend/` — API en Node.js
- `docs/` — Documentación del proyecto

## Ramas

- `main` — Versiones estables
- `develop` — Integración de funcionalidades
- `feature/*` — Funcionalidades en desarrollo

## Requisitos

- Flutter
- Node.js

## Instalación

_TBD_

## Notas de seguridad

- **Rate limiting del login/registro**: implementado con un contador **en memoria**
  (`backend/src/middleware/rateLimiter.js`). Funciona para instancias únicas, pero
  **no es fiable en entornos serverless/escalados (Vercel)** porque el límite se
  aplica por instancia. Para producción se recomienda un limitador distribuido
  (tabla SQL con los intentos por IP, Upstash Redis, Cloudflare Rate Limiting) o
  el plugin `@upstash/ratelimit`.

- **CORS**: la API solo permite orígenes listados en `CORS_ORIGINS`. Si el valor
  está vacío, se bloquean las peticiones de navegador con `Origin` y se permiten
  las server-to-server (curl/Postman/backends).
