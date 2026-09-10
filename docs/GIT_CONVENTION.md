# 🌿 Convenciones de Git — ConsultorioClínico

> Reglas oficiales del repositorio. Cualquier agente de IA que trabaje aquí
> también debe seguirlas (ver `AGENTS.md` y la skill `git-workflow`).

---

## 1. Ramas

### Modelo de ramas

| Tipo | Patrón | Ejemplo | Propósito |
|---|---|---|---|
| Principal | `main` | `main` | Estable y desplegable. Protegida: solo recibe código vía **Pull Request**. |
| Personal | `Nombre` | `brayan`, `Camila`, `Jhilian` | Línea de trabajo de cada integrante (ya existen en `origin`). |
| Corta de trabajo | `<tipo>/<descripcion>` | `feat/agenda-filtros`, `fix/login-rate-limit`, `docs/readme` | Una feature o arreglo concreto; vive poco tiempo y se integra por PR. |

### Reglas de ramas
1. **Nunca commitear directo a `main`.** Todo entra por PR con revisión.
2. Crear la rama desde `main` actualizada: `git pull origin main` antes de empezar.
3. Nombres en `kebab-case`, en español, descriptivos y cortos.
4. Una rama corta = un tema. Si se mezclan temas, se divide el PR.
5. Tras el merge, borrar la rama corta (las personales se conservan).

---

## 2. Commits — Conventional Commits (en español)

### Formato
```
<tipo>(<scope opcional>): descripción corta en imperativo
```
- Descripción **en minúscula**, ≤ 72 caracteres, sin punto final.
- **`ui`** es un tipo *custom* de este repo para cambios puramente visuales.
- Cuerpo opcional (línea en blanco después del título) para explicar el *por qué*.

### Tipos permitidos

| Tipo | Uso |
|---|---|
| `feat` | Nueva funcionalidad |
| `fix` | Corrección de bug |
| `docs` | Solo documentación (README, docs/) |
| `style` | Formato (espacios, comillas) sin cambio de lógica |
| `refactor` | Cambio de código que ni arregla ni agrega |
| `perf` | Mejora de rendimiento |
| `test` | Tests (añadir, corregir) |
| `build` | Dependencias, builds, config de despliegue |
| `ci` | Integración continua |
| `chore` | Tareas varias que no tocan código de prod |
| `ui` | Cambios visuales/estéticos de la app |

### Ejemplos reales del repo
```
feat: ficha completa del medico en 'Ver perfil' + datos completados
fix: horarios de atencion con franjas correctas (agrupadas por rango)
docs: README completo - stack tecnologico, ramas, configuracion y agente
ui: fotos medicas reales (Unsplash) para medicos, especialidades y hero
chore: empty file (requisito del docente)
```

### Reglas de contenido
1. **Un commit = un cambio lógico.** Nada de "varios fixes juntos".
2. **JAMÁS commitear secretos**: `.env`, `service-account.json`,
   `firebase-migrator-key.json`, `upload-keystore.jks`, `key.properties`,
   claves `service_role`. Están en `.gitignore` por algo.
3. Nunca commitear artefactos de build (`build/`, `node_modules/`, `.dart_tool/`).
4. Verificar `git status` y `git diff` antes de cada commit: solo archivos intencionales.

---

## 3. Pull Requests

### Flujo
```
git pull origin main
git checkout -b feat/mi-feature        # o tu rama personal
...commits con la convención...
git push -u origin feat/mi-feature
→ Abrir PR hacia main en GitHub
→ Revisión de OTRO integrante (obligatoria)
→ Merge (merge commit) y borrar la rama
```

### Requisitos del PR
- **Título**: mismo formato que un commit (`feat: ...`).
- **Descripción**: qué cambia, por qué y cómo probarlo.
- **Revisión**: al menos un integrante distinto del autor debe aprobar
  (regla del equipo, como en los merges anteriores:
  `Merge pull request #25 from Nano3559/docs/readme`).
- **Checklist antes de pedir revisión**:
  - [ ] `flutter analyze` sin warnings (si tocaste frontend)
  - [ ] `flutter test` en verde (si tocaste frontend)
  - [ ] `npm test` en verde (si tocaste backend)
  - [ ] Sin secretos ni archivos temporales en el diff
  - [ ] Documentación actualizada si el cambio lo requiere

---

## 4. Migraciones de base de datos (backend)

Archivos: `backend/db/migrations/NNN_descripcion.sql`, aplicados por
`npm run db:migrate` en orden alfabético y registrados **por nombre de archivo**
en la tabla `_migraciones`.

1. Numeración `NNN` **única y secuencial** — no repetir un número ni reusar
   temas antiguos. Precedente a evitar: existen `002_especialidades.sql` y
   `004_especialidades.sql` (mismo tema) y dos migraciones `008_*`
   (`008_completar_schema.sql` y `008_validaciones.sql`). Funciona porque
   `migrate.js` ordena alfabéticamente, pero es confuso (ver
   `docs/REVISION_BASE_DE_DATOS.md` §2.2). El siguiente número es **011**.
2. **Nunca renombrar** una migración ya aplicada (rompe el registro) ni editar
   una ya aplicada: los cambios van en una migración nueva e idempotente.
3. Documentar en el encabezado del SQL: qué hace y de qué migraciones depende.
4. Commits de migraciones: `feat(db): ...` o `fix(db): ...` — una migración
   nueva = su propio commit.

---

## 5. Versionado y tags

- SemVer: `v<mayor>.<menor>.<parche>` (ej. `v1.0.0`).
- Taguear en `main` tras cada release/despliegue mayor:
  ```bash
  git tag -a v1.1.0 -m "Agenda con filtros y reportes"
  git push origin v1.1.0
  ```

---

## 6. Limpieza e higiene

- `git pull --rebase` antes de push si hubo avances en remoto (evita merges basura).
- No reescribir historia de `main` (`force push` prohibido).
- Archivos que ya no usan: eliminarlos en su propio commit `chore: eliminar ...`.
- Los lockfiles (`package-lock.json`) **sí deben versionarse** para builds
  reproducibles en Vercel; resolver conflictos regenerando con `npm install`.

---

## 7. Mensajería rápida (chuleta)

```bash
# Feature
git checkout -b feat/<corto> ; git commit -m "feat: <qué hace>"

# Bug
git checkout -b fix/<corto> ; git commit -m "fix: <qué corrigió>"

# Docs
git checkout -b docs/<corto> ; git commit -m "docs: <qué documentó>"
```
