# Módulo de Visión - Consultorio Clínico

Microservicio Python + FastAPI para el reconocimiento facial del
ConsultorioClínico.

## Descripción

Este módulo expone una API HTTP que procesará imágenes para identificación
facial. Actualmente contiene la estructura inicial con un endpoint de salud.

## Instalación

```bash
cd backend/vision
python -m venv venv
venv\Scripts\activate        # Windows
# source venv/bin/activate   # Linux/macOS
pip install -r requirements.txt
```

## Ejecución

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

## Endpoints

| Método | Ruta    | Descripción              |
|--------|---------|--------------------------|
| GET    | /health | Estado del servicio.     |
| GET    | /docs   | Documentación interactiva (Swagger UI). |