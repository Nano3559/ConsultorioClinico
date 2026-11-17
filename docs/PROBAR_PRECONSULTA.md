# Cómo probar la PreConsulta IA en local

> Guía para levantar el módulo completo en Windows: Flutter web → API Node →
> Supabase, con el microservicio de visión en Python.
>
> **Estado real del repo:** el código y los tests están listos, pero **no existe
> `backend/.env`**. Sin ese archivo el backend arranca (responde `/api/health`),
> pero no puede leer ni escribir en Supabase, ni validar el login de la app.
> Ese es el único bloqueo para probarlo en pantalla.

---

## 0. Qué se va a levantar

```text
Chrome (Flutter web)  ->  http://localhost:5173
        |
        v
API Node/Express      ->  http://localhost:3000/api
        |                         |
        v                         v
Supabase (Postgres)       Visión Python/FastAPI
                          http://127.0.0.1:8000
```

Servicios y puertos:

| Servicio | Carpeta | Puerto | Para qué |
|---|---|---|---|
| Visión (FastAPI) | `backend/vision` | 8000 | rPPG + FaceMesh |
| API (Express) | `backend` | 3000 | auth, reglas, Supabase |
| Flutter web | `frontend` | 5173 | interfaz |

---

## 1. Lo que necesitás configurar (una sola vez)

### 1.1 Crear `backend/.env`

```powershell
cd backend
Copy-Item .env.example .env
```

Abrí `backend/.env` en VS Code y completá **sin borrar las demás claves**:

```dotenv
PORT=3000
NODE_ENV=development

# Generá uno con:
# node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
JWT_SECRET=<cadena-larga-y-aleatoria>
JWT_EXPIRE=24h

# El puerto debe coincidir con --web-port de Flutter
CORS_ORIGINS=http://localhost:5173

# Supabase -> Project Settings -> API
SUPABASE_URL=https://<tu-ref>.supabase.co
SUPABASE_ANON_KEY=<anon-key>
SUPABASE_SERVICE_ROLE_KEY=<service-role-key>

# Supabase -> Database -> Connection string -> Transaction pooler (6543)
SUPABASE_DB_URL=postgresql://postgres.<ref>:<password>@aws-0-<region>.pooler.supabase.com:6543/postgres

# Visión
VISION_ENABLED=true
VISION_SERVICE_URL=http://127.0.0.1:8000

# PreConsulta
PRECONSULTA_ENABLED=true

# Firebase Admin -> Project settings -> Service accounts -> Generate new private key
# Pegá el JSON COMPLETO en UNA sola línea, sin saltos.
FIREBASE_SERVICE_ACCOUNT={"type":"service_account","project_id":"...","private_key_id":"...","private_key":"...","client_email":"...","client_id":"...","auth_uri":"...","token_uri":"...","auth_provider_x509_cert_url":"...","client_x509_cert_url":"..."}
```

> **Seguridad:** `backend/.env` está en `.gitignore`. No lo subas, no lo pegues
> en el chat y no pongas `SUPABASE_SERVICE_ROLE_KEY` en Flutter. Si el JSON de
> Firebase tiene `\n` dentro de `private_key`, dejalo tal cual viene en el
> archivo descargado (una línea).

### 1.2 ¿Por qué hace falta Firebase?

La app Flutter inicia sesión con **Firebase Auth** y envía el ID token al
backend. `verifyFlexible` lo valida con Firebase Admin y busca el usuario por
email en Supabase. Sin `FIREBASE_SERVICE_ACCOUNT`, el backend responde **401
Token inválido**.

- Para probar **la interfaz** (login real) → hace falta el JSON.
- Para probar **solo la API** con email/contraseña de Supabase
  (`POST /api/auth/login`) → **no** hace falta Firebase.
- Los tests automáticos tampoco lo necesitan.

### 1.3 Aplicar la migración 015

> **Ojo:** además de la 015, en este repo hay migraciones **013 y 014
> pendientes** (rostro InsightFace/SFace). Si solo querés probar PreConsulta,
> aplicá **únicamente la 015**; `npm run db:migrate` intentaría aplicar también
> 013 y 014.

**Opción A (recomendada, sin compartir la contraseña de la base).**
Supabase → **SQL Editor** → **New query** → pegá el contenido completo de
`backend/db/migrations/015_preconsulta.sql` → **Run**.

**Opción B (con `SUPABASE_DB_URL` real en `backend/.env`).**

```powershell
cd backend
cmd /c npm run db:migrate:status
```

Si `015_preconsulta.sql` figura como pendiente, aplicá solo esa migración. La
015 es idempotente (`CREATE TABLE IF NOT EXISTS` + `ON CONFLICT DO NOTHING`).
No uses `npm run db:migrate` si no querés aplicar también 013/014.

Verificación rápida en SQL Editor:

```sql
select nombre, aplicada_en
from _migraciones
where nombre like '015%';
```

También podés comprobar que la tabla existe:

```sql
select count(*) from preconsultas;
```

> **No ejecutes `npm run db:seed` sobre una base que ya usás.** El seed
> restablece contraseñas de usuarios demo. Usalo solo en un proyecto Supabase
> nuevo de prueba.

---

## 2. Levantar los tres servicios

Abrí **tres terminales** y dejá cada una abierta.

### Terminal 1 — Visión (Python)

```powershell
cd backend/vision
cmd /c ".venv\Scripts\python.exe -m uvicorn main:app --host 127.0.0.1 --port 8000"
```

Comprobá en el navegador o con PowerShell:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/health
Invoke-RestMethod http://127.0.0.1:8000/api/preconsulta/version
```

Esperado: `status: OK` y `preconsulta-vision-1.0.0`.

### Terminal 2 — API Node

```powershell
cd backend
cmd /c npm run dev
```

Comprobá:

```powershell
Invoke-RestMethod http://localhost:3000/api/health
```

Esperado: `{"status":"OK","message":"API funcionando"}`.

En los logs deberías ver `[Supabase] Cliente creado OK` la primera vez que una
ruta use la base.

### Terminal 3 — Flutter web

```powershell
cd frontend
flutter run -d chrome --web-port=5173 --dart-define=API_BASE_URL=http://localhost:3000/api
```

Notas:

- **No omitas `--dart-define`**: sin eso la app apunta al backend desplegado en
  Vercel, que todavía no tiene este módulo (daría 404).
- El puerto 5173 debe coincidir con `CORS_ORIGINS`.
- La primera compilación tarda 1–3 minutos.
- Aceptá el permiso de cámara. `localhost` cuenta como contexto seguro; no hace
  falta HTTPS.
- Si Chrome no aparece: `flutter devices`.

Si preferís Windows nativo:

```powershell
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:3000/api
```

---

## 3. Recorrido de prueba en la app

### 3.1 Iniciar sesión

- **Personal:** usá los botones de acceso rápido de la pantalla de login
  (admin, médico, recepción).
- **Paciente:** pestaña de paciente con cédula + fecha de nacimiento de un
  paciente registrado.

Si el login falla:

| Error | Causa probable |
|---|---|
| `auth/user-not-found` | La cuenta no existe en Firebase Auth |
| `auth/wrong-password` | Contraseña de Firebase distinta |
| `401 Token inválido` | Falta o está mal `FIREBASE_SERVICE_ACCOUNT` |
| `401 Usuario no registrado en el sistema` | El email no existe en `usuarios` de Supabase |

### 3.2 Personal: cola y métricas

En el menú lateral:

- **PreConsulta IA** → cola del día (admin, recepción, médico).
- **Métricas IA** → agregados (admin, médico).
- Botón **Nueva preconsulta** → asistente.

### 3.3 Asistente (5 pasos)

1. **Consentimiento:** leer y aceptar.
2. **Paciente y contexto:** el personal elige paciente (y cita si aplica); el
   paciente ve sus datos.
3. **Captura:** 20–30 s con el rostro centrado, luz frontal y sin moverse.
4. **Cuestionario:** síntomas, dolor, factores de riesgo.
5. **Resultado:** nivel 1–5, confianza, motivos con peso, banderas,
   recomendaciones y aviso de que **no es un diagnóstico**.

### 3.4 Verificación visual

- [ ] El nivel se muestra con su color y etiqueta correctos.
- [ ] Los motivos indican **fuente** (cuestionario, signos, facial, contexto).
- [ ] Las banderas críticas se ven destacadas.
- [ ] El botón de revisión solo aparece a médico/admin.
- [ ] Al cambiar el nivel, queda la revisión y el nivel revisado manda.
- [ ] La tarjeta aparece en la cola con calidad y estado.
- [ ] El detalle muestra vitales, rostro, respuestas, auditoría y tendencia.
- [ ] Métricas: 7/30/90 días, distribución y top de motivos/banderas.
- [ ] Paciente: última evaluación e historial.

---

## 4. Smoke test automático de la API (recomendado antes de tocar la UI)

Recorre todo el flujo real contra Supabase + Firebase **sin abrir la app** y
**sin dejar datos**: crea una preconsulta de prueba, valida errores 422/409,
responde el cuestionario, genera el triage, verifica cola/métricas/eventos/
tendencias, aplica la revisión clínica y borra lo que creó.

Requisitos: `backend/.env` completo y el backend corriendo en `3000`.

```powershell
cd backend
cmd /c npm run preconsulta:smoke
```

Salida esperada (todo en `OK`, conteos finales en `0`):

```
OK   | POST /preconsulta | HTTP 201
OK   | PUT /preconsulta/:id/respuestas | HTTP 200
OK   | POST /preconsulta/:id/finalizar | HTTP 200
OK   | triage nivel | 1 — Atención inmediata
OK   | la preconsulta aparece en la cola
OK   | estado tras revisión | revisada
OK   | PUT respuestas tras cierre → 409 | HTTP 409
CONTEO | preconsultas: 0
```

El script está en `backend/scripts/preconsulta_smoke.js`. Obtiene un ID token
con un custom token de Firebase Admin y usa `admin@consultorio.com`. Solo
elimina las filas cuyo `id` creó él mismo.

---

## 5. Probar solo la API (sin Firebase)

Requiere Supabase configurado y un usuario con contraseña (seed o existente).

```powershell
$login = Invoke-RestMethod -Method Post `
  -Uri http://localhost:3000/api/auth/login `
  -ContentType 'application/json' `
  -Body (@{ email = '<correo>'; password = '<clave>' } | ConvertTo-Json)

$headers = @{ Authorization = "Bearer $($login.data.token)" }

Invoke-RestMethod -Uri http://localhost:3000/api/preconsulta/consentimiento -Headers $headers
Invoke-RestMethod -Uri http://localhost:3000/api/preconsulta/cola -Headers $headers
Invoke-RestMethod -Uri http://localhost:3000/api/preconsulta/metricas?dias=30 -Headers $headers
```

Usá un usuario **admin/recepción/médico** para la cola y las métricas. Para
crear una preconsulta, el cuerpo mínimo es:

```json
{
  "consentimiento_version": "2026-11",
  "paciente_id": 1,
  "canal": "recepcion",
  "motivo": "Prueba local"
}
```

`POST /api/preconsulta/:id/analizar` necesita una secuencia real de frames
(cámara); para una prueba sin cámara usá `POST /:id/finalizar` y el triage por
cuestionario.

---

## 6. Probar sin configurar nada (solo código)

Esto ya está en verde y no necesita Supabase, Firebase ni cámara:

```powershell
cd backend
cmd /c npm test

cd frontend
flutter analyze
flutter test

cd ../backend/vision
cmd /c ".venv\Scripts\python.exe -m unittest test_preconsulta_metrics"
```

| Suite | Esperado |
|---|---|
| Backend | 108/108 |
| Frontend | 37/37 |
| Visión | 24/24 |

---

## 7. Problemas frecuentes

| Síntoma | Causa | Solución |
|---|---|---|
| `Supabase no configurado` | Faltan `SUPABASE_URL`/key | Completar `.env` y reiniciar Node |
| `La tabla no existe` / `42P01` | Falta la migración 015 | Ejecutar `015_preconsulta.sql` en el SQL Editor |
| `401 Token inválido` | Firebase Admin sin credencial | Completar `FIREBASE_SERVICE_ACCOUNT` |
| `CORS` en Chrome | `CORS_ORIGINS` no coincide | Agregar `http://localhost:5173` y reiniciar |
| `503` al analizar | Visión apagada o URL mal | Revisar `http://127.0.0.1:8000/health` |
| `422` al analizar | Menos de 60 frames, sin rostro o captura corta | Mejorar luz, centrar el rostro, 20–30 s |
| `EAI_AGAIN` al migrar | Conexión directa IPv6 | Usar **Transaction pooler** (6543) |
| Cámara negra | Permiso denegado u otra app usándola | Permitir cámara y cerrar Zoom/Meet |
| `EADDRINUSE` | Puerto ocupado | Cambiar `PORT` y actualizar `API_BASE_URL`/CORS |
| Login OK pero listas vacías | Proyecto Supabase equivocado o sin seed | Revisar URL/keys y datos |
| Primera análisis lento | Carga de modelos MediaPipe | Esperar; las siguientes son más rápidas |

Para detener: `Ctrl+C` en cada terminal.

---

## 8. Antes de producción

1. Desplegar `backend/vision` en Python 3.11/3.12 (Docker/Render) y definir
   `VISION_SERVICE_URL` en Vercel.
2. Configurar `SUPABASE_*`, `FIREBASE_SERVICE_ACCOUNT`, `JWT_SECRET` y
   `PRECONSULTA_*` en Vercel.
3. Aplicar la migración 015 en el proyecto real (idealmente staging primero).
4. Probar cámara real en web y Android con HTTPS.
5. Calibrar umbrales con casos clínicos y revisión médica.

**No** subir `.env`, **no** desactivar RLS, **no** usar `service_role` en el
frontend y **no** probar la migración directamente en producción sin respaldo.
