# Plan de Trabajo (Trello)

Tablero: [ConsultorioClínico — Trello](https://trello.com/b/IsvzW9RW/consultorioclinico)

Objetivo: entregar el sistema de control médico y clínico completo (web + móvil + API + base de datos).

## Sprints

### Sprint 0 — Setup inicial ✅
- Estructura del proyecto.
- Configuración de repositorios y ramas.
- Definición del stack tecnológico (Flutter + Node.js/Express + Supabase + Vercel).

### Sprint 1 — Backend base (Camila) ✅
- Configuración Node.js/Express.
- Autenticación JWT (login, registro, perfil, logout).
- Middlewares de roles (`checkRole`).
- Conexión con Supabase.
- Despliegue inicial en Vercel.

### Sprint 2 — CRUDs backend (Camila) ✅
- CRUD Especialidades (21/08).
- CRUD Médicos (22/08).
- CRUD Horarios (22/08).
- API Citas (23/08).
- API Agenda (23/08).
- API Mis Citas (24/08).
- API Disponibilidad (24/08).
- Confirmar/Cancelar/Reprogramar (25/08).
- Plus: CRUD Pacientes, Consultas, Pagos, Reportes, Dashboard y suite de pruebas (62/62).

### Sprint 3 — Frontend (Brayan) ✅
- Configuración Flutter Web/App.
- Landing page.
- Paneles: Administrador, Médico, Recepción, Paciente.
- Integración con backend (cliente HTTP + providers, fallback a datos mock).

### Sprint 4 — Base de datos (Jhilian) ✅
- Migración a Supabase.
- Tablas: usuarios, pacientes, medicos, especialidades, horarios, citas, consultas, pagos, sesiones, notificaciones.
- RLS, triggers (normalizar email, updated_at, recordatorios) y constraints de integridad.
- Configuración de conexión.

### Sprint 5 — Integración y despliegue (Camila) ✅
- Integración backend completo.
- Pruebas de endpoints (62 pruebas HTTP).
- Despliegue en Vercel.
- Revisión de base de datos (docs/REVISION_BASE_DE_DATOS.md).

## Pendientes

- [ ] Documentación completa (en curso).
- [ ] README.md actualizado.
- [ ] Guía de API (docs/API.md). ✅
- [ ] Guía de despliegue (docs/DEPLOY.md). ✅
- [ ] Revisión de pendientes técnicos de la BD (migración 007+ ya aplicada parcialmente).
- [ ] Restringir rutas de diagnóstico `/api/test/*` en producción.
- [ ] Rotar/eliminar credenciales sensibles (`credenciales.txt`, service role key).

## Convención de commits

Conventional Commits: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`.

Ejemplos reales del historial:

```
feat(backend): agregar API Citas
fix(auth): corregir login
test(backend): suite de pruebas de API 62/62 y correcciones de robustez
feat(db): revisión de integridad, validaciones
```

Formato: `tipo(alcance): descripción`

## Requisitos de calidad

- Código documentado en español.
- README claro y completo.
- Convenciones de Git seguidas.
- Estructura de proyecto ordenada.
- Todos los endpoints documentados en docs/API.md.