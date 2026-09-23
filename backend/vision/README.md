# Módulo de Visión - Consultorio Clínico

Microservicio Python + FastAPI para el reconocimiento facial del
ConsultorioClínico.

## Descripción

Este módulo expone una API HTTP que procesa imágenes para identificación
facial (kiosco de auto-check-in). Detecta rostros con Haar Cascade,
reconoce con LBPH, y registra descriptores de 128 dimensiones (pgvector).

## Instalación

```bash
cd backend/vision
python -m venv venv
venv\Scripts\activate        # Windows
# source venv/bin/activate   # Linux/macOS
pip install -r requirements.txt
```

## Variables de entorno (KIO-16)

Copia `backend/.env.example` a `backend/vision/.env` (o exporta las
variables). Valores por defecto entre paréntesis:

| Variable | Descripción | Defecto |
|---|---|---|
| `VISION_CONFIDENCE_THRESHOLD` | Umbral LBPH: por debajo = "rostro reconocido" | `80` |
| `VISION_FACE_MODEL` | Ruta del modelo LBPH entrenado | `modelo_lbph.yml` |
| `VISION_CASCADE_PATH` | Ruta del clasificador Haar Cascade | `haarcascade_frontalface_default.xml` |
| `VISION_CAPTURE_COUNT` | Cuántas muestras captura `capture_faces.py` | `20` |
| `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` | Supabase (para buscar el paciente + cita) | — |

## Ejecución

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

## Reconocimiento facial

### Capturar imágenes de un paciente

```bash
python capture_faces.py <paciente_id>
```

Guarda las imágenes en `backend/vision/dataset/paciente_{id}/`.

### Entrenar el modelo LBPH

```bash
python train_model.py
```

Genera `backend/vision/modelo_lbph.yml` usando todas las imágenes del
dataset.

## Endpoints

| Método | Ruta    | Descripción              |
|--------|---------|--------------------------|
| GET    | /health | Estado del servicio.     |
| POST   | /api/kiosco/verificar-rostro | Recibe una imagen base64 y devuelve el paciente reconocido + su cita del día. |
| POST   | /api/vision/registrar-rostro/{paciente_id} | Recibe `{ imagenes: [base64...] }`, guarda las muestras, reentrena el modelo y devuelve el descriptor de 128 dims (KIO-10/KIO-07). |
| GET    | /docs   | Documentación interactiva (Swagger UI). |

> ⚠️ **Privacidad:** `backend/vision/dataset/` y `backend/vision/models/`
> contienen datos biométricos; están en `.gitignore` y **nunca** se suben.