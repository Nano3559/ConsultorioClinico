# CardiologiaEGC - Servicio de análisis de ECG con IA

Microservicio **FastAPI + PyTorch** que clasifica electrocardiogramas (ECG) de
12 derivaciones con el modelo `ECG_ResNet1D`, entrenado sobre el estándar
clínico **PTB-XL**. Expone una API HTTP y una interfaz web de demostración.

> Uso académico/demostrativo. **No sustituye** el criterio de un profesional de
> la salud.

## Estructura

| Archivo | Descripción |
|---|---|
| `app.py` | API FastAPI, preprocesamiento del CSV y carga del modelo. |
| `modelo_ecg_entrenado.pth` | Pesos entrenados de `ECG_ResNet1D` (5 clases). |
| `index.html` | Visor web de demostración (Tailwind CSS + Three.js). |
| `requirements.txt` | Dependencias de Python. |

## Requisitos

- Python 3.10+
- ~500 MB de espacio para PyTorch (CPU es suficiente)

## Instalación

```bash
cd CardiologiaEGC
python -m venv .venv
# Windows
.venv\Scripts\activate
# Linux/macOS
source .venv/bin/activate

pip install -r requirements.txt
```

## Ejecución

```bash
python app.py
```

O con Uvicorn:

```bash
uvicorn app:app --host 127.0.0.1 --port 8000
```

- Interfaz web de demo: <http://127.0.0.1:8000/>
- Documentación interactiva: <http://127.0.0.1:8000/docs>

Al iniciar, el servicio carga `modelo_ecg_entrenado.pth` y hace un calentamiento
del modelo para que la primera inferencia no pague el costo de inicialización.

## API

### `GET /health`

```json
{ "status": "ok" }
```

### `POST /api/analizar-ecg`

Recibe un archivo **CSV** por `multipart/form-data` en el campo `file`.

```bash
curl -X POST http://127.0.0.1:8000/api/analizar-ecg \
  -F "file=@registro.csv"
```

Respuesta:

```json
{
  "diagnostico_principal": "Ritmo Sinusal Normal",
  "confianza": 96.0,
  "desglose": {
    "Fibrilación Auricular (AFib)": 1.0,
    "Bloqueo de Rama Izquierda (LBBB)": 1.0,
    "Isquemia / Infarto Agudo": 1.0,
    "Ritmo Sinusal Normal": 96.0,
    "Contracción Ventricular Prematura (PVC)": 1.0
  },
  "bpm": "72 BPM (Ritmo Regular)",
  "causas": ["..."],
  "recomendaciones": ["..."]
}
```

Los errores de formato responden `400` con `{ "detail": "..." }`.

## Formato del CSV

- 12 derivaciones (`I`, `II`, `III`, `aVR`, `aVL`, `aVF`, `V1`...`V6`).
- Se aceptan tanto `12 x N` (derivaciones en filas) como `N x 12`
  (derivaciones en columnas); el servicio detecta la orientación.
- Se recortan o rellenan a **2500 muestras** por derivación.
- Delimitadores soportados: `,`, `;`, tabulador y `|`.
- Tolerante a encabezados/metadatos, celdas vacías/`NaN`, coma decimal y
  columnas de índice/tiempo.
- Si el nombre del archivo contiene la patología (`normal`, `afib`,
  `isquemia`, `lbbb`, `pvc`), se prioriza ese dictamen (modo demostración).

## Integración con la app Flutter

El módulo del cardiólogo vive en
`frontend/lib/features/internal/ecg/ecg_page.dart` y consume este servicio con
`EcgApiClient` (`frontend/lib/services/api_client.dart`). Por defecto apunta a
`http://127.0.0.1:8000`; se puede cambiar al compilar:

```bash
flutter run --dart-define=ECG_API_BASE_URL=http://localhost:8000
```

La pestaña **Evaluar ECG con IA** solo aparece para médicos cuya especialidad es
**Cardiología**.
