# errores.md — Bitácora de errores, soluciones y prompts

> **Proyecto:** ConsultorioClínico — módulo **PreConsulta IA**
> **Rama:** `main` (base `c28e06c`)
> **Fecha:** 16 de noviembre de 2026
> **Estado:** el módulo se subió al repositorio privado nuevo
> `Xlart5/ConsultorioClinico` (commit `adf0af4`, rama `main`). El repositorio
> local original conserva cambios sin commit (kiosco y registrantes generados).
> **Alcance del documento:** todo lo que falló durante el desarrollo, la
> instalación de dependencias y la verificación, con la solución aplicada, más
> el registro de los prompts del usuario.

Este archivo es una bitácora viva. Cuando aparezca un error nuevo, se añade una
entrada al final con la plantilla de la sección 8. **Nunca** se escriben aquí
secretos, tokens ni credenciales: solo el síntoma, la causa y la solución.

---

## 0. Resumen ejecutivo

| ID | Área | Síntoma | Solución | Estado |
|---|---|---|---|---|
| E-01 | Shell | `npm` no se puede ejecutar en PowerShell (`npm.ps1`) | Usar `cmd /c npm ...` | Resuelto |
| E-02 | Node | `EBADENGINE`: Node 24 vs `engines` 20.x/22.x | Solo advertencia; no bloquea tests ni build | Aceptado |
| E-03 | npm 12 | `install-scripts blocked` en varias dependencias | Advertencia de seguridad de npm; no afecta el runtime | Aceptado |
| E-04 | Python | Python 3.15 no tiene wheel de `mediapipe==0.10.21` | Instalar Python 3.12 y crear `.venv` | Resuelto |
| E-05 | Python | `ModuleNotFoundError: preconsulta_metrics` al ejecutar un script desde `%TEMP%` | Ejecutar con `cwd` en `backend/vision` o añadir el directorio del script a `sys.path` | Resuelto |
| E-06 | PowerShell | `python -c "..."` falla con “Falta una expresión después de ','” | Escribir el código en un archivo `.py` y ejecutarlo | Resuelto |
| E-07 | PowerShell | `npm test` devuelve exit code 1 al canalizar la salida | `NativeCommandError` por stderr; los tests sí pasan (108/108) | Aclarado |
| E-08 | Backend | Timeout de 15 s insuficiente para `/analizar` | Timeout opcional en `ApiClient` + 90 s para el análisis | Resuelto |
| E-09 | Datos | `NUMERIC` de PostgreSQL llega como texto (`"78.4"`) | Parseo defensivo en el modelo Flutter + tests de contrato | Resuelto |
| E-10 | Express | `/cita/:citaId` podía chocar con `/:id` | Declarar la ruta específica antes que la paramétrica | Resuelto |
| E-11 | Flutter | `clamp()` devuelve `num`, no `double` | Encadenar `.toDouble()` | Resuelto |
| E-12 | Dart | `UnsupportedError` al ordenar una lista no modificable | Copiar con `toList()` antes de `..sort()` | Resuelto |
| E-13 | Flutter | Analyzer marca `(_, __)` en `separatorBuilder` | Usar parámetros wildcard `(_, _)` | Resuelto |
| E-14 | Dart | Sintaxis inválida en mapas con entradas condicionales | `if (x != null) 'clave': x` y spread `...?` | Resuelto |
| E-15 | Flutter | APIs de Flutter posterior al SDK fijado | Sustituir por el equivalente disponible en la versión del proyecto | Resuelto |
| E-16 | Dart | Colisión entre el modelo `CamaraPreconsulta` y la clase de captura | Renombrar la implementación de captura y separar archivos | Resuelto |
| E-17 | Git | `flutter pub get` modifica registrantes generados (CRLF/LF) | `git checkout --` de los archivos generados | Resuelto |
| E-18 | Consola | Tildes y `ñ` se ven como `�` en PowerShell | Es solo la consola; los archivos están en UTF-8 | Aclarado |
| E-19 | Kiosco | Warnings de lint impedían `No issues found` | Refactor **solo de lint**, sin cambiar comportamiento | Resuelto |
| E-20 | Config | Faltaban las variables `PRECONSULTA_*` documentadas | Ampliar `backend/.env.example` y `README.md` | Resuelto |
| E-21 | Frontend | El contrato asumía números y JSON completos | Modelo defensivo + 8 tests nuevos | Resuelto |
| E-22 | Config | No existe `backend/.env`; sin Supabase/Firebase no hay login ni datos | Copiar `.env.example`, completar credenciales y aplicar 015 (`docs/PROBAR_PRECONSULTA.md`) | Pendiente de config |
| E-23 | Backend | `POST /:id/finalizar` devolvía 422 porque ignoraba `respuestas` del cuerpo | Helper `persistirRespuestas` compartido por respuestas y finalizar + smoke test del caso | Resuelto |
| E-24 | Frontend | Assertion `ListTile background color or ink splashes may be invisible` | Envolver el `CheckboxListTile` del consentimiento en `Material` transparente y usar `Material` en el selector de pacientes | Resuelto |
| E-25 | Frontend | El contador decía “Obligatorias: 10 de 8” | Contar solo preguntas requeridas para la barra y el texto | Resuelto |
| E-26 | Frontend | Auditoría “Sin eventos registrados” aunque la API devolvía eventos | Leer `data.eventos` según el contrato real | Resuelto (verificación visual pendiente) |

---

## 1. Entorno verificado

| Herramienta | Versión | Nota |
|---|---|---|
| Windows | 10.0.26200 | PowerShell 5.1 |
| Git | rama `main` en `c28e06c` | Todo el módulo sin commit |
| Node.js | 24.19.0 | Los `engines` del repo piden 20/22 |
| npm | 12.0.2 | Bloquea `install-scripts` por defecto |
| Flutter | 3.47.0 (stable) | Canal stable |
| Dart | 3.13.0 | Wildcard parameters disponibles |
| Python del sistema | 3.15.0 | **No** sirve para MediaPipe 0.10.21 |
| Python del venv | 3.12.10 | `backend/vision/.venv` |
| OpenCV | 4.11.0 | Instalado en el venv |
| MediaPipe | 0.10.21 | Versión fijada en `requirements.txt` |
| NumPy | 1.26.4 | Compatible con MediaPipe |

Comprobación real del runtime de visión (salida literal):

```text
python 3.12.10
cv2 4.11.0 | mediapipe 0.10.21 | numpy 1.26.4
imports OK
version {'modelo_version': 'preconsulta-vision-1.0.0', 'metricas_version': 'rppg-pos-chrom-1.0.0', 'rostro_version': 'facemesh-geometria-1.0.0', 'min_frames': 60, 'max_frames': 600, 'no_es_diagnostico': True}
```

Y el servicio FastAPI se levantó y respondió:

```text
GET /health                    -> {"status":"OK"}
GET /api/preconsulta/version   -> {"modelo_version":"preconsulta-vision-1.0.0", ...}
```

---

## 2. Prompts del usuario

> Los mensajes largos se registran reconstruidos a partir del encargo; las
> frases entre comillas son literales del mensaje original. Los mensajes cortos
> posteriores se transcriben tal cual.

### 2.1 Encargo inicial — PreConsulta IA

**Objetivo:** implementar en `Nano3559/ConsultorioClinico` un módulo de
**PreConsulta IA** listo para producción: captura multimodal de 20–30 s,
estimación de signos vitales por cámara (rPPG), análisis facial de dolor,
estrés y fatiga, cuestionario clínico, priorización explicable y paneles para
el personal.

Requisitos textuales y de alcance:

- “hazlo pero quiero que lo hagas sabiendo que esto va directo a produccion asi
  que hazlo completamente bien. y perfecto. sin fallas. y bonito. visualmente”.
- Debe usar **IA real** de análisis facial, no un reconocimiento básico; el
  módulo debe ser lo bastante completo para aspirar a “100 de nota”.
- **No tocar ni alterar el kiosco existente**
  (`frontend/lib/features/public/kiosk/`): se pueden reutilizar ideas de cámara
  y visión, pero el comportamiento del kiosco debe quedar igual.
- Flujo clínico real y coherente: consentimiento → contexto del paciente →
  captura → cuestionario → resultado con nivel de prioridad 1–5.
- Interfaz y textos **en español**, alineados con el sistema de diseño actual.
- Triaje **explicable** (motivos, pesos, banderas y recomendaciones), con
  revisión humana; nada de caja negra.
- Privacidad: no conservar imágenes ni video en el servidor; solo métricas
  derivadas, cuestionario, consentimiento y auditoría.
- **No** hacer `git commit` ni `git push` sin pedido explícito.
- Al terminar: `flutter analyze` limpio, `flutter test` en verde y `npm test`
  en verde.

### 2.2 Continuación

> “ya continua entonces. que mas haras ?”

### 2.3 Instalación y bitácora

> “descarga todo lo necesario. ademas quiero recopiles todos los errores con las
> soluciones y los prompts que te doy. y lo pongas en el proyecto. en un archivo
> llamados errores.md”

### 2.4 Cómo probarlo

> “entonces ya lo puedo probar ? si es asi pasame todo para probarlo. y como
> levanto todo.”

---

## 3. Errores y soluciones

### E-01 — PowerShell bloquea `npm` (`npm.ps1`)

**Síntoma.** Al ejecutar `npm install` aparecía un error de política de
ejecución: `npm.ps1 cannot be loaded because running scripts is disabled on
this system`.

**Causa.** PowerShell resuelve `npm` a `npm.ps1`, y la política
`ExecutionPolicy` del equipo bloquea scripts `.ps1`.

**Solución.** Ejecutar npm a través de `cmd.exe`, que usa `npm.cmd` y no pasa
por la política de PowerShell:

```powershell
cmd /c npm install --no-audit --no-fund
cmd /c npm test
```

**Verificación.** `cmd /c npm test` en `backend/` termina con `108/108` tests
OK y exit code 0. No se cambió la política del sistema (no hace falta).

---

### E-02 — `EBADENGINE`: Node 24 contra `engines` 20.x/22.x

**Síntoma.** Cada `npm install` mostraba:

```text
npm warn EBADENGINE Unsupported engine {
  package: 'consultorio-clinico@1.0.0',
  required: { node: '22.x' },
  current: { node: 'v24.19.0', npm: '12.0.2' }
}
```

Igual en `mail-service` (`20.x`) y en `frontend/functions` (`22`).

**Causa.** El equipo tiene Node 24; el repositorio fija versiones LTS para
Vercel y Firebase Functions.

**Solución.** Es una **advertencia**, no un error de instalación. Se dejó Node 24
para desarrollo local y se mantuvieron los `engines` porque producción
(Vercel/Functions) usa esas versiones. Si se quiere eliminar el warning, usar
Node 22 con `nvm-windows`:

```powershell
nvm install 22
nvm use 22
```

**Verificación.** Backend 108/108, suite de visión 24/24, frontend 37/37 con
Node 24.

---

### E-03 — npm 12 bloquea `install-scripts`

**Síntoma.** En `mail-service`, `frontend/functions`, `frontend/scripts` y
`migracion` aparecía:

```text
npm warn install-scripts 27 packages had install scripts blocked ...
```

**Causa.** npm 12 incorpora una protección que bloquea scripts `postinstall` de
dependencias no aprobadas (por ejemplo `protobufjs`, `@firebase/util`).

**Solución.** No se aprobaron a ciegas. Las dependencias se instalaron y los
tests corren; los scripts bloqueados no son necesarios para el módulo. Si en el
futuro un paquete lo requiere, revisar primero y aprobar de forma explícita:

```powershell
cmd /c npm install-scripts ls
cmd /c npm install-scripts approve <paquete>
```

**Verificación.** `node_modules` creado en los seis `package.json` del repo.

---

### E-04 — Python 3.15 no es compatible con `mediapipe==0.10.21`

**Síntoma.** `pip install -r requirements.txt` fallaba al resolver
`mediapipe==0.10.21` porque no hay wheel para Python 3.15.

**Causa.** MediaPipe publica wheels para versiones concretas de Python; 3.12 es
la última soportada de forma estable para esa versión fijada.

**Solución.** Instalar Python 3.12 **sin reemplazar** el 3.15 del sistema y
crear un entorno virtual exclusivo para visión:

```powershell
winget install --id Python.Python.3.12 --exact --scope user --silent `
  --accept-package-agreements --accept-source-agreements

cd backend/vision
py -3.12 -m venv .venv
cmd /c ".venv\Scripts\python.exe -m pip install --upgrade pip"
cmd /c ".venv\Scripts\python.exe -m pip install -r requirements.txt"
```

Ruta del intérprete: `C:\Users\braya\AppData\Local\Programs\Python\Python312\python.exe`.
`.venv/` está en `.gitignore`, así que no entra al repositorio.

**Verificación.** Instalación correcta de FastAPI, Uvicorn, OpenCV, MediaPipe,
NumPy y `supabase`; 24/24 tests de métricas y arranque real de Uvicorn.

---

### E-05 — `ModuleNotFoundError` al ejecutar el smoke test desde `%TEMP%`

**Síntoma.**

```text
ModuleNotFoundError: No module named 'preconsulta_metrics'
```

al ejecutar un script guardado en `%TEMP%` con el Python del venv.

**Causa.** Python añade al `sys.path` el directorio **del script**, no el
directorio de trabajo. El script estaba en `%TEMP%`, así que no encontraba los
módulos de `backend/vision`.

**Solución.** Ejecutar el smoke test desde `backend/vision` con el archivo dentro
de ese directorio, o añadir explícitamente la ruta:

```python
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import preconsulta_service
```

**Verificación.** `imports OK` + `version {...}` (ver sección 1).

---

### E-06 — PowerShell interpreta el código Python inline

**Síntoma.** Un comando `python -c "import cv2; print(cv2.__version__)"` falló
con mensajes de PowerShell:

```text
Falta una expresión después de ','
Token 'cv2.__version__' inesperado en la expresión o la instrucción.
```

**Causa.** Las comillas, paréntesis y `__` del código Python chocan con el
parser de PowerShell al pasarlos como argumento.

**Solución.** No usar `-c` para código con comillas; escribir un archivo `.py`
y ejecutarlo. Se usó un archivo temporal dentro de `backend/vision` y se borró
después.

**Verificación.** El mismo código funcionó a la primera desde archivo.

---

### E-07 — `npm test` “falla” con exit code 1 al canalizar la salida

**Síntoma.** `cmd /c npm test 2>&1 | Select-Object -Last 25` mostraba
`108/108` tests OK pero PowerShell reportaba `Exit code: 1` y un
`NativeCommandError`.

**Causa.** Node escribe trazas de algunos tests en **stderr**; al canalizar,
PowerShell las trata como error nativo aunque el proceso termine bien. Lo mismo
pasa con `flutter build web`: el aviso de *Wasm dry run* va por stderr y
PowerShell marca exit code 1 aunque el build termine con `✓ Built build\web`.

**Solución.** Redirigir a un archivo y leer el código real, o ejecutar sin
pipeline:

```powershell
cmd /c npm test > "$env:TEMP\backend-test.log" 2>&1
"EXIT=$LASTEXITCODE"
Get-Content "$env:TEMP\backend-test.log" -Tail 12
```

**Verificación.** `EXIT=0`, `tests 108`, `pass 108`, `fail 0`.

---

### E-08 — Timeout de 15 s insuficiente para el análisis de visión

**Síntoma.** La llamada a `/api/preconsulta/:id/analizar` podía abortar con
timeout antes de que el microservicio terminara el rPPG y FaceMesh sobre
cientos de fotogramas.

**Causa.** `ApiClient` usaba el timeout global de 15 s, pensado para consultas
CRUD normales.

**Solución.**

- `ApiClient` acepta ahora un `Duration? timeout` opcional por petición.
- `preconsultaAnalizar` usa **90 s**.
- En el backend, `visionService.llamarVision` acepta `{ timeoutMs, retries }` y
  aplica un timeout amplio solo a esta operación.

**Verificación.** Tests de API en verde; el análisis real necesita cámara y
credenciales para medir latencia de extremo a extremo.

---

### E-09 — PostgreSQL devuelve `NUMERIC` como texto

**Síntoma.** Campos como `hr_bpm`, `calidad` o `similitud` llegaban a Flutter
como `"78.4"` y un `as double` provocaba `TypeError`.

**Causa.** `pg`/PostgREST serializan `NUMERIC` como string para no perder
precisión.

**Solución.** El modelo `preconsulta.dart` usa helpers `_num`, `_int` y `_fecha`
que aceptan `num`, `String` y `null`. Las listas y JSONB también se leen de
forma defensiva.

**Verificación.** `preconsulta_models_test.dart` cubre números como texto,
detalle vacío, cola, métricas, tendencias, eventos y `colorDesdeHex`
(8 pruebas).

---

### E-10 — Orden de rutas en Express: `/cita/:citaId` vs `/:id`

**Síntoma.** La ruta `GET /api/preconsulta/cita/:citaId` podía ser capturada por
`GET /api/preconsulta/:id`, interpretando `cita` como un id y devolviendo 400.

**Causa.** Express resuelve en orden de declaración; una ruta paramétrica
demasiado general declarada antes “se come” a la específica.

**Solución.** Declarar primero las rutas literales
(`/consentimiento`, `/cola`, `/metricas`, `/cita/:citaId`,
`/paciente/:id/tendencias`) y al final `/:id`.

**Verificación.** `backend/test/preconsulta.test.js` cubre cola, métricas,
detalle, por cita y tendencias; 108/108 tests OK.

---

### E-11 — `clamp()` devuelve `num` y el widget espera `double`

**Síntoma.** El analyzer rechazaba:

```dart
maxX: (puntos.length - 1).toDouble().clamp(1, 999),
```

con “A value of type 'num' can't be assigned to a parameter of type 'double'”.

**Causa.** `num.clamp()` devuelve `num`, aunque el receptor sea `double`.

**Solución.** Convertir el resultado:

```dart
maxX: (puntos.length - 1).toDouble().clamp(1, 999).toDouble(),
```

**Verificación.** `flutter analyze` → `No issues found!`.

---

### E-12 — Ordenar una lista no modificable

**Síntoma.** `UnsupportedError` (lista fija/no modificable) al ordenar
preguntas o puntos de una serie que venían de un getter o de una lista `const`.

**Causa.** `..sort()` muta la lista; si la lista es `const` o de longitud fija,
falla.

**Solución.** Copiar antes de ordenar:

```dart
preguntas.where((p) => p.seccion == seccion).toList()
  ..sort((a, b) => a.orden.compareTo(b.orden));
```

**Verificación.** Test de catálogo comprueba el orden por `orden` y que las
opciones se conservan.

---

### E-13 — `separatorBuilder: (_, __)` marcado por el analyzer

**Síntoma.** Advertencia por el segundo parámetro sin usar en
`ListView.separated`.

**Causa.** Dart 3.13 admite wildcards `_` repetidos; `__` sigue siendo un
identificador normal y el lint lo señala.

**Solución.**

```dart
separatorBuilder: (_, _) => const SizedBox(height: 12),
```

**Verificación.** Analyzer limpio; el comportamiento visual no cambia.

---

### E-14 — Sintaxis inválida en mapas con entradas condicionales

**Síntoma.** Errores de compilación al construir cuerpos JSON con claves
opcionales usando sintaxis tipo `?{}` o un `if` mal colocado.

**Causa.** Dart no tiene “null-aware map entry” con esa forma; la forma correcta
es una colección-`if` o un spread condicional.

**Solución.**

```dart
final cuerpo = <String, dynamic>{
  'motivo': motivo,
  if (citaId != null) 'cita_id': citaId,
  ...?extra,
};
```

**Verificación.** `flutter analyze` y `flutter test` en verde; el payload de los
endpoints se construye sin claves nulas.

---

### E-15 — APIs de Flutter posteriores al SDK fijado

**Síntoma.** El analyzer no reconocía algunas APIs nuevas usadas inicialmente en
las pantallas (temas, colores o propiedades de widgets).

**Causa.** El código se escribió contra una versión más reciente que la fijada
por el proyecto; el CI usa Flutter 3.47.0.

**Solución.** Sustituir cada API por su equivalente disponible en el SDK del
proyecto y volver a ejecutar `flutter analyze` hasta `No issues found!`. Regla
para el futuro: no introducir APIs que no existan en la versión fijada en
`frontend/pubspec.yaml`/CI.

**Verificación.** `flutter analyze` sin issues y 37/37 tests.

---

### E-16 — Colisión de nombres entre el modelo y la captura de cámara

**Síntoma.** Errores de tipo/import al existir `CamaraPreconsulta` como modelo
de datos y como clase de captura.

**Causa.** Dos declaraciones con el mismo nombre en archivos que se importan
juntos.

**Solución.**

- Modelo de datos: `PreconsultaCaptura` en `data/models/preconsulta.dart`.
- Captura: `CamaraPreconsulta` en
  `features/preconsulta/capture/captura_preconsulta.dart` (+ variantes
  `_web`, `_nativa`, `_stub` y `_tipos`).
- La fábrica condicional mantiene web, Android y stub separados.

**Verificación.** `flutter analyze` limpio; el wizard compila en web y Android.

---

### E-17 — Ruido de fin de línea en registrantes generados

**Síntoma.** `flutter pub get`/`flutter test` modificaban:

- `frontend/android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`
- `frontend/windows/flutter/generated_plugin_registrant.cc/.h`
- `frontend/windows/flutter/generated_plugins.cmake`

**Causa.** Los generadores escriben CRLF/LF distinto al índice de Git.

**Solución.** Revertir esos archivos generados, que no forman parte del módulo:

```powershell
git checkout -- frontend/android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java `
  frontend/windows/flutter/generated_plugin_registrant.cc `
  frontend/windows/flutter/generated_plugin_registrant.h `
  frontend/windows/flutter/generated_plugins.cmake
```

**Verificación.** `git status --short` ya no muestra los registrantes;
`git diff --check` sin errores de whitespace.

> También apareció `migracion/package-lock.json` como modificado tras
> `npm install`, pero `git diff` estaba vacío: era **solo** cambio de fin de
> línea. Se revirtió con `git checkout -- migracion/package-lock.json`.

---

### E-18 — Tildes y `ñ` como `�` en la consola

**Síntoma.** Las salidas de PowerShell mostraban `m�dulo`, `visi��n`, etc.

**Causa.** La consola usa una página de códigos distinta de UTF-8; **no** es un
problema de los archivos.

**Solución.** No “arreglar” el código por esto. Verificar en el editor (UTF-8) o
forzar la salida:

```powershell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001
```

**Verificación.** Los textos se ven correctos en la app y en los tests; los
archivos fuente están en UTF-8.

---

### E-19 — Warnings del kiosco impedían `No issues found`

**Síntoma.** `flutter analyze` reportaba avisos en
`frontend/lib/features/public/kiosk/captura_web.dart` y el módulo nuevo no
podía declararse limpio.

**Causa.** Código antiguo con imports/parámetros sin usar.

**Solución.** Refactor **solo de lint**: quitar imports y parámetros no usados,
sin tocar la lógica de captura ni el comportamiento del kiosco. Se respetó la
restricción de no alterar el kiosco.

**Verificación.** `flutter analyze` → `No issues found!`; los tests existentes
siguen pasando (37/37).

---

### E-20 — Faltaban variables de entorno y documentación del módulo

**Síntoma.** `backend/.env.example` no incluía `PRECONSULTA_*`; el README y
`docs/API.md` no describían el módulo; no había guía de despliegue del servicio
de visión.

**Causa.** El módulo se implementó antes de cerrar la documentación.

**Solución.**

- `backend/.env.example`: bloque `PRECONSULTA_*` (habilitado, límites de
  frames, tamaño, salt de IP, etc.).
- `docs/PRECONSULTA.md`: flujo clínico, pipeline, triage, privacidad,
  configuración, puesta en marcha y tests.
- `docs/API.md`: 12 endpoints con roles, cuerpos, límites y errores.
- `README.md`: módulo, stack, endpoints, variables y sección propia.

**Verificación.** `git diff --stat` muestra los tres archivos actualizados y
`docs/PRECONSULTA.md` creado.

---

### E-21 — El frontend asumía un contrato “perfecto”

**Síntoma.** Riesgo de pantallas rotas si el backend devolvía `null`, listas
vacías o JSONB incompleto.

**Causa.** El detalle combina `NUMERIC`, `JSONB`, listas y campos opcionales.

**Solución.** Modelo defensivo (`_num`, `_int`, `_fecha`, `_mapa`) y pruebas
explícitas:

- Detalle completo con números como texto.
- Detalle vacío sin excepciones y con valores seguros.
- Catálogo, cola, métricas, tendencias, eventos y color hex.

**Verificación.** `flutter test test/preconsulta_models_test.dart` → 8/8 OK;
suite completa 37/37.

---

### E-22 — Sin `backend/.env` no hay login ni datos en local

**Síntoma.** Al preparar la prueba local, `backend/.env` no existía. El backend
arrancaba y `/api/health` respondía OK, pero cualquier ruta que usa Supabase
fallaba con `Supabase no configurado` y el login de la app devolvía `401 Token
inválido`.

**Causa.** Es correcto que el repo **no** versione `.env`; las credenciales
viven en Supabase/Vercel. Además, la app inicia sesión con Firebase Auth y el
backend necesita `FIREBASE_SERVICE_ACCOUNT` para validar ese token.

**Solución.** Copiar `backend/.env.example` a `backend/.env` y completar:

- `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`.
- `SUPABASE_DB_URL` (Transaction pooler) para las migraciones.
- `JWT_SECRET`, `CORS_ORIGINS=http://localhost:5173`.
- `VISION_SERVICE_URL=http://127.0.0.1:8000`.
- `FIREBASE_SERVICE_ACCOUNT` (JSON completo en una línea).

Después aplicar la migración 015 y levantar visión, backend y Flutter. La guía
completa está en **`docs/PROBAR_PRECONSULTA.md`**.

**Verificación.** `/api/health` OK, log `[Supabase] Cliente creado OK`, login
correcto y `GET /api/preconsulta/consentimiento` con el token de sesión.

**Prevención.** No commitear `.env`; documentar toda variable nueva en
`backend/.env.example` y probar el arranque en un clon limpio antes de desplegar.

---

### E-23 — `POST /preconsulta/:id/finalizar` ignoraba las respuestas del cuerpo

**Fecha.** 2026-11-17
**Área.** backend

**Síntoma.** En la prueba visual del asistente, al pulsar **Finalizar y ver
resultado** sin cámara el paso 4 no avanzaba y el backend registraba:

```
POST /api/preconsulta/5/finalizar 422 1400.375 ms - 85
```

con el mensaje `Complete el cuestionario antes de finalizar sin captura`,
aunque el cuestionario tenía las 8 preguntas obligatorias respondidas en
pantalla.

**Causa.** El asistente Flutter (`PreconsultaWizardPage._finalizar`) envía el
cuestionario **en la misma llamada** a `finalizar`
(`body: { respuestas: [...] }`), pero el controlador solo validaba y persistía
`respuestas` en `PUT /:id/respuestas`. `finalizarSinCaptura` leía únicamente lo
que ya estuviera en `preconsulta_respuestas`; como en ese flujo nunca se había
llamado al `PUT`, la tabla estaba vacía y respondía 422.

**Solución.** Extraer el guardado a un helper reutilizable
`persistirRespuestas(preconsultaId, respuestas)` en
`backend/src/controllers/preconsultaController.js` (upsert + limpieza de los
códigos que ya no vienen en el envío, sin tocar nada si el upsert falla) y
usarlo desde:

- `guardarRespuestas` (`PUT /:id/respuestas`), que antes tenía la lógica inline.
- `finalizarSinCaptura` (`POST /:id/finalizar`), que ahora acepta
  `req.body.respuestas` opcional, lo valida con `validarRespuestas`, lo persiste
  y registra el evento de auditoría `respuestas` antes de calcular el triage.

El contrato quedó documentado en `docs/API.md` (`Body: { "respuestas": [...] }`,
opcional si ya se guardaron) y el smoke test cubre el caso.

**Verificación.** `npm run preconsulta:smoke` incluye el escenario 12
("finalizar con respuestas en el cuerpo") y comprueba el `triage.nivel`, las
8 respuestas persistidas y el evento `respuestas`; además la prueba visual
llegó al Paso 5 con nivel, motivos y banderas.

**Prevención.** Un solo camino de persistencia para el cuestionario y un test
E2E que use exactamente el mismo payload que la app.

---

### E-24 — Assertion de Flutter: `ListTile background color or ink splashes may be invisible`

**Fecha.** 2026-11-17
**Área.** frontend

**Síntoma.** En modo debug, al abrir el paso 1 del asistente la consola del
navegador se llenaba con la misma excepción repetida:

```
══╡ EXCEPTION CAUGHT BY FLUTTER FRAMEWORK ╞══════════════════════════════════
The following assertion was thrown:
ListTile background color or ink splashes may be invisible.
The ListTile is wrapped in a DecoratedBox that has a background color. [...]
```

**Causa.** El `CheckboxListTile` del consentimiento (que internamente es un
`ListTile` con `selectedColor`) estaba dentro de la tarjeta del paso, que es un
`Container` con `BoxDecoration(color: blanco)`. El `ListTile` pinta su fondo y
sus *ink splashes* sobre el `Material` más cercano, y esa caja decorada los
tapa; Flutter lo detecta y lanza la assertion en debug.

**Solución.** Envolver solo ese `CheckboxListTile` en un
`Material(type: MaterialType.transparency, ...)` en
`frontend/lib/features/preconsulta/preconsulta_wizard_page.dart`, con un
comentario que explica el motivo. No se quitó el fondo de la tarjeta porque es
parte del diseño.

El mismo patrón apareció después en el **selector de pacientes** (paso 2): su
`DraggableScrollableSheet` usaba un `Container` con
`BoxDecoration(color: AppColors.surface)` y dentro había `ListTile`. Ahí se
cambió el `Container` por un
`Material(color: AppColors.surface, borderRadius: ..., clipBehavior: Clip.antiAlias)`,
que conserva el aspecto y da el ancestro `Material` que la lista necesita.

**Verificación.** Rebuild del Flutter web, recorrido del asistente hasta el
paso 5 y consola del navegador sin la assertion.

**Prevención.** Cuando un `ListTile`/`CheckboxListTile`/`RadioListTile` viva
dentro de una tarjeta con color propio, envolverlo en un `Material`
transparente o usar un `Material` como contenedor de la tarjeta.

---

### E-25 — El contador del cuestionario mostraba “Obligatorias: 10 de 8”

**Fecha.** 2026-11-17
**Área.** frontend

**Síntoma.** Durante la prueba visual, tras responder las 8 preguntas
obligatorias y además el motivo y la intensidad del dolor, el paso 4 mostraba
`Obligatorias: 10 de 8` y la barra de progreso recibía un valor mayor que 1.

**Causa.** `_pasoCuestionario` contaba **todas** las respuestas del mapa
(`_respuestas.values.length`) y lo comparaba con el número de preguntas
obligatorias. El total de respuestas siempre puede superar al de obligatorias
porque hay preguntas opcionales (motivo, contexto clínico, etc.). Además
`LinearProgressIndicator.value` debe estar entre 0 y 1, así que el valor podía
disparar una assertion en debug.

**Solución.** Separar los dos conteos en
`frontend/lib/features/preconsulta/preconsulta_wizard_page.dart`:

- `respondidas` (todas) se sigue usando para la insignia “N respuestas”.
- `obligatoriasRespondidas` cuenta solo las preguntas con `requerida == true`
  que tienen valor, y es la que alimenta la barra y el texto
  `Obligatorias: X de 8`.

**Verificación.** Recorrido del asistente respondiendo las 8 obligatorias más
dos opcionales: el texto muestra `Obligatorias: 8 de 8`, la barra llega al
100 % y no hay assertions en consola. `flutter analyze` y `flutter test` en
verde.

**Prevención.** Nunca usar el tamaño de un mapa de respuestas como si fuera el
número de obligatorias cubiertas; derivar ambos valores de `catalogo.preguntas`.

### E-26 — La auditoría de la preconsulta mostraba “Sin eventos registrados”

**Fecha.** 2026-11-17
**Área.** frontend

**Síntoma.** En el detalle clínico, la sección **Auditoría** decía “Sin
eventos registrados.” aunque `GET /api/preconsulta/7/eventos` respondía 200 con
3 eventos (`creada`, `respuestas`, `finalizada_sin_captura`).

**Causa.** `PreconsultaProvider.cargarEventos` esperaba que `data` fuera una
**lista** (`if (data is List)`). El backend responde
`{ data: { eventos: [...] } }`, así que la condición nunca se cumplía y la lista
quedaba vacía. El error se tragaba en el `catch` porque la auditoría se
considera informativa.

**Solución.** En `frontend/lib/state/preconsulta_provider.dart` se acepta el
contrato real (`data['eventos']`) y se mantiene la lista directa por
compatibilidad:

```dart
final lista = data is List
    ? data
    : (data is Map<String, dynamic> ? data['eventos'] : null);
```

**Verificación.** `flutter analyze` sin issues y `flutter test` 37/37. La
respuesta del endpoint se comprobó por API en el smoke test (3 eventos). **Pendiente:**
confirmar en pantalla; tras una recarga de Flutter web el inicio de sesión dejó de
llegar al backend y no se pudo repetir la prueba visual en esta sesión.

**Prevención.** Mismo criterio que E-21: el cliente Flutter debe leer el
contrato documentado en `docs/API.md`, no suponer la forma del `data`.

---

## 4. Riesgos evitados por diseño (no fueron errores)

Estas decisiones se tomaron antes de que se convirtieran en fallos:

1. **Sin retención de imágenes/video.** El servicio de visión devuelve solo
   métricas derivadas; Node persiste únicamente métricas, cuestionario,
   consentimiento y eventos de auditoría.
2. **Triaje determinista y explicable.** `preconsultaTriage.js` aplica reglas y
   pesos conocidos; cada nivel incluye motivos, banderas y recomendaciones.
3. **Revisión humana obligatoria en casos críticos.** El nivel revisado manda
   sobre el sugerido y queda auditado.
4. **RBAC y propiedad.** Paciente solo ve lo suyo; recepción/médico/admin según
   rol; `PATCH /revision` solo médico/admin.
5. **Límites de entrada.** Máximo de frames, tamaño de payload y tasa por IP;
   `422` si la captura no alcanza.
6. **Idempotencia del análisis.** El microservicio no escribe en la base; Node
   decide qué persistir.
7. **RLS y `service_role`.** La clave de servicio solo se usa en el backend; no
   se desactiva RLS, helmet, CORS ni rate limiting.

---

## 5. Instalaciones ejecutadas

| Componente | Comando | Resultado |
|---|---|---|
| Dependencias raíz | `cmd /c npm install --no-audit --no-fund` | 107 paquetes |
| Backend | `cmd /c npm install --no-audit --no-fund` | OK |
| Mail service | idem en `mail-service/` | 168 paquetes |
| Cloud Functions | idem en `frontend/functions/` | 240 paquetes |
| Scripts de seed | idem en `frontend/scripts/` | 167 paquetes |
| Migración | idem en `migracion/` | 299 paquetes |
| Python 3.12 | `winget install --id Python.Python.3.12 ...` | 3.12.10 |
| Venv de visión | `py -3.12 -m venv .venv` | Creado |
| pip | `.venv\Scripts\python.exe -m pip install --upgrade pip` | 26.3 |
| Requirements | `.venv\Scripts\python.exe -m pip install -r requirements.txt` | OK |
| Flutter | `flutter pub get` (vía analyze/test) | OK |

> `node_modules/` y `.venv/` están ignorados por Git. Nada de esto se commitea.

---

## 6. Verificación final reproducible

```powershell
# Backend
cd backend
cmd /c npm test

# Visión (Python 3.12 del venv)
cd backend/vision
cmd /c ".venv\Scripts\python.exe -m unittest test_preconsulta_metrics"

# Frontend
cd frontend
flutter analyze
flutter test

# Limpieza del diff
cd ..
git diff --check
```

| Comprobación | Resultado |
|---|---|
| Backend (`npm test`) | **108/108** OK |
| Visión (unittest) | **24/24** OK |
| `flutter analyze` | **No issues found!** |
| `flutter test` | **37/37** OK |
| Runtime de visión (imports) | OK (`cv2`, `mediapipe`, `numpy`, servicio) |
| FastAPI `/health` + `/api/preconsulta/version` | OK |
| `git diff --check` | Sin errores |

---

## 7. Pendientes que **no** son errores de código

Para llevar el módulo a producción falta configuración y validación con datos
reales:

1. Aplicar `backend/db/migrations/015_preconsulta.sql` en Supabase.
2. Desplegar `backend/vision` en un runtime con Python 3.11/3.12
   (Docker/Render) y definir `VISION_SERVICE_URL`.
3. Configurar en Vercel: `PRECONSULTA_*`, `VISION_*`, `JWT_SECRET` y las claves
   de Supabase.
4. Probar con cámara real (HTTPS o `localhost`) en web y Android.
5. Calibrar umbrales de rPPG, dolor y estrés con casos clínicos y revisión
   médica.
6. Ejecutar la migración en un entorno de staging antes de producción.

---

## 8. Plantilla para nuevas entradas

```markdown
### E-XX — <título corto>

**Fecha.** AAAA-MM-DD
**Área.** <shell | backend | frontend | visión | datos | docs>
**Síntoma.** <qué se vio, con el mensaje literal>
**Causa.** <por qué ocurría>
**Solución.** <qué se cambió, con comandos o diff mínimo>
**Verificación.** <test/comando que confirma la corrección>
**Prevención.** <regla o test para que no vuelva>
```

Reglas:

- No incluir secretos, tokens, correos reales ni datos de pacientes.
- Preferir el mensaje literal del error entre bloques de código.
- Si el error no se pudo reproducir, indicarlo explícitamente.
- Enlazar al archivo y la línea cuando aporte contexto.

---

## 9. Registro de prompts posteriores

- 2026-11-16 — “ya continua entonces. que mas haras ?”
- 2026-11-16 — “descarga todo lo necesario. ademas quiero recopiles todos los
  errores con las soluciones y los prompts que te doy. y lo pongas en el
  proyecto. en un archivo llamados errores.md”
- 2026-11-16 — “entonces ya lo puedo probar ? si es asi pasame todo para
  probarlo. y como levanto todo.”
- 2026-11-17 — “continua”
- 2026-11-17 — “continua. con el trabajo”
- 2026-11-17 — “pero ya esta en global” (dicho dos veces; se adjuntó captura del
  SQL Editor de Supabase, proyecto `ConsultorioClinico`, rama `main`, marcado
  PRODUCTION, con `_migraciones` filtrada por `015%` y `count(*)` de
  `preconsultas` = 0)

> Añadir aquí cada prompt nuevo, con fecha, sin resumir.
