# PreConsulta IA — triage asistido multimodal

Módulo de **pre-consulta asistida por IA** para ConsultorioClínico. El paciente
(o recepción en su nombre) completa una captura breve con la cámara y un
cuestionario estructurado; el sistema estima signos vitales por **rPPG**,
analiza señales faciales de dolor/estrés/fatiga y calcula un **nivel de
prioridad 1–5 explicable** que el personal clínico revisa y confirma.

> **No es un diagnóstico.** No mide SpO₂, presión arterial ni saturación, y no
> reemplaza la valoración médica. Es una ayuda de **priorización** con revisión
> humana obligatoria.

---

## 1. Flujo clínico

```
Paciente / recepción
   │
   ├─ 1. Consentimiento informado  (versión configurable, queda auditado)
   ├─ 2. Contexto: cita/motivo y datos disponibles
   ├─ 3. Captura 20–30 s con cámara frontal  (12,5 fps, 288 px, JPEG q0,5)
   ├─ 4. Cuestionario clínico  (síntomas, dolor, antecedentes)
   └─ 5. Resultado: nivel 1–5 + motivos + recomendaciones
            │
            ▼
   Backend Node  ──►  Microservicio Python (rPPG + FaceMesh)
            │
            ├─ Triage determinista y explicable (Node)
            ├─ Persistencia de métricas derivadas (Supabase, migración 015)
            └─ Evento de auditoría por cada transición de estado
            │
            ▼
   Cola de recepción/médico  ──►  Detalle + revisión humana
                              └─►  Métricas agregadas (7/30/90 días)
```

### Roles

| Rol | Puede |
|---|---|
| `paciente` | Crear y completar **sus** preconsultas; ver su historial y tendencias |
| `recepcion` | Crear preconsultas en nombre del paciente, ver cola y detalle |
| `medico` | Ver cola/detalle, **revisar y ajustar** el nivel sugerido, ver métricas |
| `admin` | Todo lo anterior |

El paciente solo accede a sus propios registros (verificación de propiedad en el
controlador). La revisión clínica está limitada a `admin` y `medico`.

---

## 2. Arquitectura

```
frontend/lib/features/preconsulta/
  preconsulta_wizard_page.dart      # asistente de 5 pasos
  preconsulta_queue_page.dart       # cola del personal con filtros
  preconsulta_detail_page.dart      # detalle, explicabilidad, revisión, auditoría
  preconsulta_metrics_page.dart     # panel agregado (7/30/90 días)
  preconsulta_paciente_page.dart    # inicio e historial del paciente
  capture/
    captura_preconsulta.dart        # fachada + contrato de captura
    captura_preconsulta_web.dart    # getUserMedia + frames JPEG
    captura_preconsulta_nativa.dart # paquete camera + resize
    captura_preconsulta_stub.dart   # stub para tests/escritorio
  widgets/preconsulta_ui.dart       # tarjetas, chips y helpers visuales

frontend/lib/state/preconsulta_provider.dart
frontend/lib/data/models/preconsulta.dart
frontend/lib/services/api_client.dart   # endpoints /preconsulta/*

backend/src/routes/preconsultaRoutes.js
backend/src/controllers/preconsultaController.js
backend/src/services/preconsultaTriage.js      # catálogo + triage determinista
backend/src/services/preconsultaContenido.js   # consentimiento y textos
backend/src/services/visionService.js          # proxy al microservicio
backend/src/middleware/validation.js           # validadores express-validator
backend/db/migrations/015_preconsulta.sql

backend/vision/preconsulta_service.py   # pipeline MediaPipe/OpenCV
backend/vision/preconsulta_metrics.py   # matemática pura (rPPG/HRV/rostro/calidad)
backend/vision/test_preconsulta_metrics.py
```

### Modelo de datos (015)

| Tabla | Contenido |
|---|---|
| `modelos_ia` | Registro y versión de los modelos usados (trazabilidad) |
| `consentimientos_preconsulta` | Aceptación por paciente, versión, fecha y hash de IP |
| `preconsultas` | Métricas derivadas, triage, estado, revisión y captura (sin imágenes) |
| `preconsulta_respuestas` | Una fila por pregunta del cuestionario, con etiqueta legible |
| `preconsulta_revisiones` | Historial de ajustes del nivel por el personal clínico |
| `preconsulta_eventos` | Auditoría inmutable de transiciones (`creada`, `analizada`, `revisada`…) |

RLS habilitado en todas las tablas; el backend accede con `service_role`.
**No se almacenan fotogramas, video ni plantillas faciales nuevas**: solo
valores derivados, respuestas, consentimiento y eventos.

---

## 3. Pipeline de visión

1. El cliente captura ~12,5 fps a 288 px de ancho y comprime cada fotograma en
   JPEG (calidad 0,5), con un presupuesto de payload de ~4 MB base64 (compatible
   con Vercel Functions).
2. Node valida límites (`PRECONSULTA_*`) y reenvía al microservicio Python.
3. Python decodifica los frames, detecta el rostro con **MediaPipe FaceMesh** y
   extrae ROIs de piel.
4. Sobre la serie temporal RGB:
   - **rPPG POS + CHROM** → frecuencia cardíaca, SNR y confianza.
   - **HRV** → RMSSD, SDNN, pNN50 con confianza propia.
   - **Respiración** → estimación por variación de luminancia/pose.
5. Geometría facial (ojos, cejas, boca, tensión) → índices de **dolor**,
   **estrés** y **fatiga**, parpadeo y microexpresiones.
6. Calidad de captura 0–100 (cobertura, brillo, nitidez, estabilidad, tamaño del
   rostro, duración). Si la cobertura es insuficiente, el análisis se rechaza
   con un motivo claro para repetir la captura.
7. Identidad **opcional y no bloqueante** mediante el embedding SFace existente.

La respuesta incluye `modelo_version`, `metricas_version`, `no_es_diagnostico`
y `advertencias` para que el frontend explique cualquier limitación.

> La captura se procesa **en memoria** y se descarta al terminar. Ver
> `docs/KIOSCO_CAMERA.md` para consideraciones de cámara/HTTPS.

---

## 4. Triage explicable

El nivel se calcula **en Node**, de forma determinista (mismas entradas ⇒ mismo
resultado) y versionada (`preconsulta-triage-1.0.0`):

- Cada factor aporta un **peso** con su `fuente` (`cuestionario`, `signos`,
  `rostro`, `antecedentes`, `edad`) y un `detalle` legible.
- La **suma ponderada** se traduce a un nivel inicial:
  `≥55 → 1`, `≥38 → 2`, `≥24 → 3`, `≥12 → 4`, resto `5`.
- Las **banderas rojas** (p. ej. dolor torácico + disnea, sangrado activo,
  rigidez de cuello, cefalea súbita) imponen un **techo de nivel**: solo pueden
  subir la urgencia, nunca relajarla.
- Sin cuestionario **ni** signos válidos no se inventa un nivel "tranquilo":
  se devuelve nivel 3 con confianza reducida.
- La **confianza** refleja la calidad de los datos (no la certeza clínica) y
  baja si falta señal, HRV o cuestionario.
- `requiere_revision` permanece en `true` hasta que un médico/admin revisa el
  caso; `nivel_revisado` y `nota_revision` conservan el criterio humano.

| Nivel | Etiqueta | Objetivo orientativo |
|---|---|---|
| 1 | Atención inmediata | Ahora |
| 2 | Urgente | ≤ 30 min |
| 3 | Prioritario | ≤ 2 h |
| 4 | Programado | ≤ 4 h |
| 5 | No urgente | Según agenda |

Cada resultado expone `motivos` ordenables por peso, `banderas`,
`recomendaciones` y un `resumen` en español para la cola y el detalle.

---

## 5. Endpoints

Base: `/api/preconsulta` (auth `verifyFlexible`: JWT propio o ID token de
Firebase). Detalle de contratos en [`docs/API.md`](API.md).

| Método | Ruta | Roles | Descripción |
|---|---|---|---|
| `GET` | `/consentimiento` | autenticado | Texto, versión y estado del consentimiento |
| `POST` | `/` | paciente, recepción, médico, admin | Crea la preconsulta |
| `POST` | `/:id/analizar` | paciente, recepción, médico, admin | Analiza frames/video |
| `PUT` | `/:id/respuestas` | paciente, recepción, médico, admin | Guarda el cuestionario |
| `POST` | `/:id/finalizar` | paciente, recepción, médico, admin | Cierra sin captura (solo cuestionario) |
| `GET` | `/:id` | autenticado (propiedad/roles) | Detalle completo |
| `GET` | `/cita/:citaId` | autenticado | Preconsulta asociada a una cita |
| `GET` | `/paciente/:id/tendencias` | autenticado (propiedad/roles) | Serie histórica del paciente |
| `GET` | `/cola` | recepción, médico, admin | Cola filtrable por fecha/nivel/estado |
| `GET` | `/metricas` | recepción, médico, admin | Agregados por rango (máx. 366 días) |
| `PATCH` | `/:id/revision` | médico, admin | Ajusta el nivel y deja nota |
| `GET` | `/:id/eventos` | recepción, médico, admin | Auditoría del caso |

**Rate limiting** por IP (ventana de 15 min): creación 30, respuestas 40,
análisis 12. El análisis tiene timeout de 90 s.

---

## 6. Privacidad y guardrails

- Consentimiento **explícito y versionado** antes de la primera captura.
- **Sin retención de imágenes/video**; solo métricas derivadas.
- La IP del consentimiento se guarda **hasheada con sal** (`PRECONSULTA_IP_SALT`).
- La identidad facial es opcional y **nunca bloquea** la atención.
- Toda transición de estado genera un evento de auditoría con usuario y detalle.
- El nivel de IA siempre es **sugerencia**: requiere revisión humana.
- Prohibido presentar los valores como medición médica o diagnóstico.
- RLS activo; `service_role` solo en backend.

---

## 7. Configuración

Variables en `backend/.env` (ver `backend/.env.example`):

| Variable | Default | Uso |
|---|---|---|
| `PRECONSULTA_ENABLED` | `true` | Interruptor maestro (crear/analizar) |
| `PRECONSULTA_CONSENT_VERSION` | `2026-11` | Versión del consentimiento |
| `PRECONSULTA_MIN_FRAMES` | `60` | Mínimo de fotogramas |
| `PRECONSULTA_MAX_FRAMES` | `600` | Máximo de fotogramas |
| `PRECONSULTA_MAX_FRAME_BYTES` | `600000` | Tamaño por fotograma |
| `PRECONSULTA_MAX_PAYLOAD_BYTES` | `4000000` | Payload total (base64) |
| `PRECONSULTA_MAX_VIDEO_BYTES` | `3800000` | Video opcional |
| `PRECONSULTA_MIN_SEGUNDOS` | `10` | Duración mínima |
| `PRECONSULTA_MAX_SEGUNDOS` | `120` | Duración máxima |
| `PRECONSULTA_TIMEOUT_MS` | `90000` | Timeout del análisis |
| `PRECONSULTA_RATE_MAX` | `12` | Análisis por IP / 15 min |
| `PRECONSULTA_CREATE_RATE_MAX` | `30` | Creaciones por IP / 15 min |
| `PRECONSULTA_ANSWERS_RATE_MAX` | `40` | Envíos de cuestionario / 15 min |
| `PRECONSULTA_IP_SALT` | vacío | Sal del hash de IP |

El microservicio reutiliza `VISION_ENABLED`, `VISION_SERVICE_URL` y
`VISION_TIMEOUT_MS`; `PRECONSULTA_MODELO_VERSION` permite etiquetar el pipeline
(p. ej. `preconsulta-vision-1.0.0`).

> **Producción:** el análisis exige un runtime con Python + OpenCV/MediaPipe
> (contenedor). En Vercel el backend Node funciona serverless, pero el
> microservicio de visión debe desplegarse aparte (Render/Docker) y apuntarse
> con `VISION_SERVICE_URL`.

---

## 8. Puesta en marcha

```bash
# 1) Migración
cd backend
npm run db:migrate

# 2) Backend
npm run dev

# 3) Microservicio de visión (Python 3.11/3.12; mediapipe 0.10.21)
cd backend/vision
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
python main.py

# 4) Frontend
cd frontend
flutter pub get
flutter run -d chrome
```

La web requiere **HTTPS o localhost** para acceder a la cámara. En Android se
solicita el permiso en tiempo de ejecución.

---

## 9. Tests

```bash
# Backend (API, validación y triage)
cd backend
npm test

# Matemática del pipeline de visión (pura, sin MediaPipe)
cd backend/vision
python -m unittest test_preconsulta_metrics

# Frontend
cd frontend
flutter analyze
flutter test
```

Cobertura actual del módulo:

- `backend/test/preconsulta.test.js`: consentimiento, creación, RBAC,
  validaciones, análisis (con visión simulada), respuestas, finalización,
  cola, métricas, revisión, eventos y casos límite.
- `backend/vision/test_preconsulta_metrics.py`: estimación de HR/HRV/
  respiración, índices faciales, calidad y respuestas degradadas.
- `frontend/test/preconsulta_nav_test.dart`: visibilidad del módulo por rol.
- `frontend/test/preconsulta_models_test.dart`: contrato defensivo (NUMERIC como
  texto, JSONB incompleto, cola, métricas y tendencias).

> La inferencia real de MediaPipe/OpenCV requiere el runtime Python completo.
> Si el entorno local no lo tiene, los tests puros siguen validando la
> matemática y el backend prueba el contrato con el servicio simulado.
