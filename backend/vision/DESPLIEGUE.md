# ☁️ Desplegar el microservicio de visión (una sola vez)

> Sin esto en la nube, el kiosco NO reconoce (el `verificar-rostro` de Vercel
> devuelve 502). El backend y el frontend ya están desplegados; falta esta
> pieza. Tiempo: ~15 min (más la primera descarga de modelos).

## Opción A — Render (recomendada, gratis)

1. Crea cuenta en **https://render.com** (con GitHub).
2. **New → Blueprint** → conecta el repo `Nano3559/ConsultorioClinico`.
3. Render detecta `backend/vision/render.yaml` y pide las variables:
   - `SUPABASE_URL` → Project URL del Supabase **compartido**.
   - `SUPABASE_SERVICE_ROLE_KEY` → secret key (`sb_secret_...`) del compartido.
   - El resto ya viene con defaults (no tocar).
4. **Deploy**. La primera vez tarda varios minutos (descarga ~250 MB de
   modelos InsightFace). Verifica: `https://tu-servicio.onrender.com/health`
   debe responder `{"status":"OK"}`.
5. Copia la URL del servicio (ej. `https://consultorio-vision.onrender.com`).

> Render free duerme el servicio sin tráfico: el primer reconocimiento del
> día tarda 2-4 min (re-descarga modelos); luego responde en ms. Si eso
> molesta, plan pago o disco persistente.

## Opción B — Railway / VPS

- **Railway**: New Project → Deploy from repo → Root Directory `backend/vision`
  (usa el `Dockerfile` automáticamente) → mismas variables → Deploy.
- **VPS propio**: Python 3.11 + `pip install -r requirements.txt` +
  `uvicorn main:app --host 0.0.0.0 --port 8000` (con systemd/supervisor).

## Conectar Vercel con el microservicio (obligatorio después)

1. Vercel → proyecto `consultorio-clinico` → **Settings → Environment Variables**:
   - `VISION_SERVICE_URL` = la URL del paso 5 (ej. `https://consultorio-vision.onrender.com`)
   - `VISION_ENABLED` = `true`
   - Verifica que `SUPABASE_URL` / keys apunten al proyecto **compartido**.
2. **Deployments → Redeploy** con la rama `main` actual (producción está
   desactualizada: aún no tiene `/api/kiosco/manifest` ni `/api/kiosco/modelo`).
3. Verificación:
```bash
curl https://consultorio-clinico.vercel.app/api/kiosco/modelo
# esperado: 401 (la ruta EXISTE pero exige auth) — si da 404, sigue viejo
```
