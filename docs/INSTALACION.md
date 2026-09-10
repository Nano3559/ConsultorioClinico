# 🖥️ Guía de instalación desde cero — ConsultorioClínico

> Para cualquier integrante (o docente) que quiera correr el proyecto en un PC
> nuevo. Pasos verificados para **Windows**; al final hay notas para macOS/Linux.
> Tiempo estimado: 30–45 min (depende de descargas).

---

## Paso 0 — Instalar Git y clonar el repo

```powershell
# Instalar Git (opción A: winget — PowerShell como administrador)
winget install --id Git.Git -e

# (Opción B: descargar el instalador de https://git-scm.com/download/win)

# Verificar
git --version

# Identidad (usa tu nombre y correo de GitHub)
git config --global user.name "Tu Nombre"
git config --global user.email "tu-correo@ejemplo.com"

# Clonar
git clone https://github.com/Nano3559/ConsultorioClinico.git
cd ConsultorioClinico
```

---

## Paso 1 — Instalar Node.js 22 LTS (backend)

```powershell
winget install OpenJS.NodeJS.LTS
# cerrar y reabrir la terminal, luego verificar:
node -v    # debe mostrar v22.x
npm -v     # debe mostrar 10.x o superior
```
> Descarga manual: https://nodejs.org (versión **22 LTS**, que es la que exige
> `engines` del proyecto).

---

## Paso 2 — Backend: dependencias y entorno

```powershell
cd backend
npm install

# Plantilla de variables de entorno
Copy-Item .env.example .env
```

Edita `backend/.env` (con VS Code o bloc de notas). Hay dos caminos:

### Opción A (recomendada para el equipo): pedir las credenciales compartidas
Pídele a un integrante que ya tenga el proyecto corriendo:
- `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_DB_URL` (solo si vas a ejecutar migraciones)

Y genera TU propio `JWT_SECRET` (no compartas el mismo secreto por chat):
```powershell
node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
# copia el resultado en JWT_SECRET del .env
```

### Opción B: proyecto Supabase propio (para probar aislado)
1. Crea cuenta/proyecto gratis en https://supabase.com.
2. *Project Settings → API* → copia `URL`, `anon key` y `service_role` al `.env`.
3. *Project Settings → Database → Connection string → URI* → pégala en `SUPABASE_DB_URL`.
4. Aplica el esquema y los datos demo:
```powershell
npm run db:migrate        # aplica las 11 migraciones SQL
npm run db:seed           # usuarios demo por rol
```

### Levantar y verificar
```powershell
npm run dev
# En otra terminal (o el navegador):
#   http://localhost:3000/api/health  ->  {"status":"OK",...}
```
Opcional: `npm test` para correr la suite QA (no necesita BD real, usa mocks).

---

## Paso 3 — Instalar Flutter (frontend)

```powershell
# 1) Descargar el SDK (Flutter 3.47+ / Dart 3.13+):
#    https://docs.flutter.dev/get-started/install/windows
# 2) Extraer en C:\dev\flutter (NO en Program Files)
# 3) Agregar C:\dev\flutter\bin al PATH (Variables de entorno)

# Verificar el entorno (este comando te dice qué falta):
flutter doctor
```

`flutter doctor` mostrará checks en rojo según lo que quieras compilar:

| Objetivo | Qué necesita | Arreglo típico |
|---|---|---|
| **Web (Chrome)** | Google Chrome instalado | Instala Chrome y listo |
| **Windows desktop** | Visual Studio 2022 con "Desktop development with C++" | Instala la carga de trabajo desde https://visualstudio.microsoft.com |
| **Android (APK)** | Android Studio | Instala https://developer.android.com/studio, abre el SDK Manager, acepta licencias (abajo) |

Para Android, tras instalar Android Studio:
```powershell
flutter doctor --android-licenses   # aceptar todo con 'y'
flutter doctor                       # todo en verde para tu objetivo
```

---

## Paso 4 — Frontend: correr la app

```powershell
cd frontend
flutter pub get

# Web (lo más rápido para empezar)
flutter run -d chrome

# Windows desktop
flutter run -d windows

# Android (emulador abierto o celular con depuración USB)
flutter run
```

> **Firebase ya viene configurado en el repo** (`lib/firebase_options.dart` y
> `android/app/google-services.json` del proyecto `consultorioclinico-2026`):
> la app corre sin pasos extra. No necesitas crear proyecto Firebase propio
> salvo que quieras un entorno aislado.

### Cuentas de demostración (login en `/login`)
| Rol | Correo | Contraseña |
|---|---|---|
| Admin | `admin@consultorio.com` | `admin123` |
| Médico | `carlos@consultorio.com` | `medico123` |
| Recepción | `maria@consultorio.com` | `recepcion123` |
| Paciente | `pedro@gmail.com` | `paciente123` |

Si tu proyecto Firebase está vacío, siembra esas cuentas (ver
"Sembrar las cuentas en Firebase" más abajo o en `frontend/README.md`).

---

## Paso 5 — Verificación rápida (checklist final)

```powershell
# Backend
cd backend
npm test                 # suite QA en verde
npm run dev              # /api/health responde OK

# Frontend
cd ..\frontend
flutter analyze          # sin warnings
flutter test             # widget tests en verde
flutter run -d chrome    # landing + login visibles
```

Si todo pasó, tu PC está listo para desarrollar. Flujo de trabajo Git:
`CONTRIBUTING.md` y `docs/GIT_CONVENTION.md`.

---

## Extras (solo si vas a desplegar)

| Herramienta | Cuándo la necesitas | Instalación |
|---|---|---|
| Firebase CLI | Deploy de hosting/reglas/functions | `npm i -g firebase-tools` → `firebase login` (con cuenta del proyecto) |
| Vercel CLI | Deploy manual del backend/mail-service | `npm i -g vercel` → `vercel login` |
| Keystore Android | Firmar el APK release | Pídeselo al equipo (`upload-keystore.jks` + `key.properties`, **nunca por Git**) |

Guías de despliegue: `docs/` → skill `deploy` y README §Despliegue.

---

## Notas para macOS / Linux

- **Git**: `sudo apt install git` (Debian/Ubuntu) o `brew install git` (mac).
- **Node 22**: `nvm install 22` (recomendado) o el instalador de nodejs.org.
- **Flutter**: guía oficial https://docs.flutter.dev/get-started/install
  (macOS usa `brew install --cask flutter`; Linux, el tarball + PATH).
- Todo lo demás (npm, flutter, migraciones) es idéntico; solo cambian
  `Copy-Item` → `cp` y las rutas del PATH.
