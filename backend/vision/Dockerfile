# Microservicio de visión (InsightFace) — ConsultorioClínico.
# Python 3.11 OBLIGATORIO: insightface 0.7.3 no trae wheel para 3.12.
FROM python:3.11-slim

# Dependencias de sistema para OpenCV/MediaPipe (sin esto, import cv2 falla).
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Modelos InsightFace (~250 MB) se descargan al primer arranque (warmup).
# En hosting con disco efímero (Render free) se re-descargan en cada cold
# start: primer request tarda 2-4 min; los siguientes, ms.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

# Variables que Render/Railway inyectan (ver render.yaml):
#   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, VISION_* (opcionales)
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
