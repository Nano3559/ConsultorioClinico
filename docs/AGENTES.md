# 🤖 Agentes y Skills de OpenCode — ConsultorioClínico

> Este proyecto se desarrolla asistido por **OpenCode** con tres agentes
> principales (uno por modelo), tres **respaldos gratuitos** de OpenCode Zen y
> cinco **skills** con el conocimiento específico del repositorio.

---

## 1. Proveedores y modelos

El proyecto usa **dos puertas de enlace** de modelos:

### 1.1 Principales — OpenCode GO (`opencode-go/...`)
Modelos de pago que usan los tres agentes principales del proyecto. Requieren
la autenticación/credencial de OpenCode GO en tu instalación.

| Modelo (ID exacto) | Agente | Fortaleza | Temp. |
|---|---|---|---|
| `opencode-go/glm-5.3` | **glm-architect** | Planificación, arquitectura, razonamiento profundo | 0.3 |
| `opencode-go/deepseek-v4-pro` | **deepseek-coder** | Implementación de código, refactors, bugs, tests | 0.2 |
| `opencode-go/gpt-5.6-luna` | **gpt-luna-reviewer** | Code review, QA, seguridad (solo lectura) | 0.2 |

Modelo auxiliar para tareas internas (títulos/resúmenes):
`small_model: opencode-go/glm-5.3-flash`.

### 1.2 Respaldo gratuito — OpenCode Zen (`opencode/...`)
Modelos a **costo 0** del catálogo free de OpenCode Zen (se conectan una vez
con `/connect` y la API key de https://opencode.ai/auth). Sirven para seguir
trabajando cuando no hay cuota o credencial de GO.

| Modelo (ID exacto) | Agente | Respalda a | Temp. |
|---|---|---|---|
| `opencode/glm-5-free` | **free-planner** | glm-architect | 0.3 |
| `opencode/deepseek-v4-flash-free` | **free-coder** | deepseek-coder | 0.2 |
| `opencode/kimi-k2.5-free` | **free-reviewer** | gpt-luna-reviewer (solo lectura) | 0.2 |

> ⚠️ **El catálogo gratuito rota con frecuencia**: un modelo `-free` puede
> desaparecer en cualquier momento. Cuando eso pase:
> 1. Ejecuta `/models` (o `opencode models`) y busca otro con sufijo `-free`.
> 2. Edita **solo la línea `model:`** del archivo del agente en
>    `.opencode/agent/free-*.md`.
> 3. Reinicia OpenCode.
>
> La lista completa de modelos free del día está en
> https://models.dev (proveedor `opencode`).

---

## 2. Los 6 agentes

Definidos como archivos en `.opencode/agent/` (uno por modelo). Los seis son
`mode: primary`: se cambian con **Tab** en la TUI o con `/agents`.

### Principales (OpenCode GO)

#### 🧠 `glm-architect` — GLM 5.3
- **Qué hace**: planifica antes de codificar; diseña soluciones respetando la
  arquitectura (routes→controllers→supabase, Provider/GoRouter); descompone
  tareas complejas; decide cuándo hace falta migración SQL.
- **Cuándo usarlo**: features grandes, cambios de esquema, dudas de diseño,
  análisis del monorepo.
- Config: `.opencode/agent/glm-architect.md`

#### 💻 `deepseek-coder` — DeepSeek v4 Pro
- **Qué hace**: escribe features completas y tests; corrige bugs; refactoriza
  siguiendo las convenciones de capas del backend y de estado del frontend;
  deja `npm test` y `flutter analyze` en verde.
- **Cuándo usarlo**: cuando el plan ya está claro y toca escribir código.
- Config: `.opencode/agent/deepseek-coder.md`

#### 🔍 `gpt-luna-reviewer` — GPT 5.6 Luna
- **Qué hace**: revisa código antes de cada PR; detecta bugs, fugas de
  seguridad (secretos, rutas sin auth/roles, reglas Firestore) y problemas de
  rendimiento; emite reporte con veredicto `APROBADO`/`CAMBIOS REQUERIDOS`.
- **Restricción**: **solo lectura** (`edit: deny` en su permiso).
- Config: `.opencode/agent/gpt-luna-reviewer.md`

### Respaldo gratuito (OpenCode Zen free)

#### 🧠 `free-planner` — GLM 5 free
Respaldo de `glm-architect` con prompt reducido (las convenciones las cargan
`AGENTS.md` y las skills). Config: `.opencode/agent/free-planner.md`

#### 💻 `free-coder` — DeepSeek v4 Flash free
Respaldo de `deepseek-coder`. Config: `.opencode/agent/free-coder.md`

#### 🔍 `free-reviewer` — Kimi K2.5 free
Respaldo de `gpt-luna-reviewer`, también **solo lectura** (`edit: deny`).
Config: `.opencode/agent/free-reviewer.md`

### Agentes base reconfigurados (en `opencode.json`)
| Agente interno | Modelo asignado | Uso |
|---|---|---|
| `build` | `opencode-go/glm-5.3` | Agente por defecto de la sesión |
| `plan` | `opencode-go/glm-5.3` | Modo planificación |
| `general` | `opencode-go/deepseek-v4-pro` | Subagente para tareas multipaso |

**Flujo de trabajo recomendado**: `glm-architect` planifica →
`deepseek-coder` implementa → `gpt-luna-reviewer` revisa → PR según
`docs/GIT_CONVENTION.md`. Sin cuota de GO: `free-planner` → `free-coder` →
`free-reviewer` (mismo flujo, costo 0).

---

## 3. Skills del proyecto

Ubicadas en `.opencode/skills/<nombre>/SKILL.md`. OpenCode las carga
automáticamente cuando la tarea coincide con su descripción (todos los
agentes, principales y gratuitos, las usan).

| Skill | Carpeta | Se activa cuando... |
|---|---|---|
| **flutter-app** | `.opencode/skills/flutter-app/` | La tarea toca `frontend/`: Dart, Provider, GoRouter, Firebase, build web/APK |
| **express-backend** | `.opencode/skills/express-backend/` | La tarea toca `backend/`: rutas, controladores, JWT, Supabase, migraciones, tests |
| **git-workflow** | `.opencode/skills/git-workflow/` | Se van a crear commits, ramas o PRs (Conventional Commits en español) |
| **deploy** | `.opencode/skills/deploy/` | Despliegues: Vercel, Firebase Hosting/Functions, APK + App Distribution |
| **email-service** | `.opencode/skills/email-service/` | Correos: `mail-service/`, Cloud Functions, plantillas, Gmail SMTP |

Cada skill contiene los comandos exactos, la estructura de carpetas que hay
que respetar y las reglas del módulo correspondiente.

---

## 4. Configuración y permisos

### Archivos de configuración
```
opencode.json                  # config del proyecto (modelo, permisos, agentes base)
.opencode/
├── agent/
│   ├── glm-architect.md       # GLM 5.3 (OpenCode GO)
│   ├── deepseek-coder.md      # DeepSeek v4 Pro (OpenCode GO)
│   ├── gpt-luna-reviewer.md   # GPT 5.6 Luna (OpenCode GO, solo lectura)
│   ├── free-planner.md        # GLM 5 free (Zen, respaldo)
│   ├── free-coder.md          # DeepSeek v4 Flash free (Zen, respaldo)
│   └── free-reviewer.md       # Kimi K2.5 free (Zen, respaldo, solo lectura)
└── skills/
    ├── flutter-app/SKILL.md
    ├── express-backend/SKILL.md
    ├── git-workflow/SKILL.md
    ├── deploy/SKILL.md
    └── email-service/SKILL.md
```

### Permisos (en `opencode.json`)
- Edición de archivos: permitida.
- `git commit` y `git push`: **piden confirmación** (`ask`).
- `rm *`: denegado.
- Los dos reviewers además no pueden editar (`edit: deny`).

### Puesta en marcha
1. Abrir OpenCode en la raíz del repo.
2. Agentes principales: autenticar tu instalación de **OpenCode GO**.
   Respaldo gratuito: `/connect` → *OpenCode Zen* → API key de
   https://opencode.ai/auth (una sola vez).
3. `/models` lista los modelos disponibles; **Tab** (o `/agents`) alterna
   entre los seis agentes. `AGENTS.md` se carga como regla base en cada sesión.
4. Los permisos están en `opencode.json`: edición permitida, pero
   `git commit`/`git push` piden confirmación y `rm` está denegado.

> ⚠️ Tras editar `opencode.json`, agentes o skills, **reiniciar OpenCode**
> para que los cambios se apliquen (la config no se recarga en caliente).
