---
name: git-workflow
description: Convenciones de Git de ConsultorioClinico: Conventional Commits en español (feat, fix, docs, chore, ui...), ramas por integrante y tipo/nombre, flujo de Pull Requests hacia main y protección de secretos. Use when committing, creating branches, opening/merging PRs, writing commit messages or cleaning git history.
---

# Skill: Convenciones de Git (ConsultorioClínico)

Aplica SIEMPRE que hagas commits, ramas o PRs en este repositorio. Detalle completo: `docs/GIT_CONVENTION.md` y `CONTRIBUTING.md`.

## Commits — Conventional Commits en español
Formato: `<tipo>(<scope opcional>): descripción en imperativo, minúscula, ≤ 72 caracteres`

Tipos: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `ui` (custom de este repo para cambios visuales).

Ejemplos reales del repo:
```
feat: ficha completa del medico en 'Ver perfil' + datos completados
fix: horarios de atencion con franjas correctas (agrupadas por rango)
docs: README completo - stack tecnologico, ramas, configuracion y agente
ui: fotos medicas reales (Unsplash) para medicos, especialidades y hero
chore: empty file (requisito del docente)
```

Reglas: un commit = un cambio lógico; sin secretos JAMÁS (.env, service-account.json, keystore, service_role); sin archivos de build (`build/`, `node_modules/`).

## Ramas
- `main` — estable, siempre desplegable. Protegida: solo vía PR.
- Rama personal por integrante: `brayan`, `Camila`, `Jhilian` (ya existen en origin).
- Ramas cortas de trabajo: `<tipo>/<descripcion-kebab-case>` → `feat/agenda-filtros`, `fix/login-rate-limit`, `docs/readme`.

## Pull Requests
1. Rama desde `main` actualizada (`git pull origin main` antes de empezar).
2. Título del PR con el mismo formato de commit.
3. Descripción: qué cambia, por qué, cómo probarlo.
4. **Revisión de otro integrante antes del merge** (regla del equipo).
5. Merge a `main` (merge commit, como en la historia del repo) y borrar la rama si es de trabajo corto.

## Antes de pedir/ hacer merge
- `flutter analyze` sin warnings y `flutter test` OK (frontend).
- `npm test` en verde (backend).
