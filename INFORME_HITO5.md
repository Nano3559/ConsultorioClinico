# Informe de Resultados — Hito 5: CI/CD

**Repositorio:** https://github.com/Nano3559/ConsultorioClinico  
**Rama:** Camila  
**Usuario autenticado (gh):** crmv1  
**Fecha:** 17 de noviembre de 2026  
**Merge a main:** No realizado (pendiente de autorización)

---

## 1. Resumen ejecutivo

Se revisó, corrigió y verificó la configuración de CI/CD (`.github/workflows/ci.yml` y `.github/workflows/cd.yml`) para el Hito 5. Se eliminaron los `|| true` que ocultaban fallos de pruebas, se corrigieron errores de formato Dart, de `flutter analyze` y del middleware de autenticación del kiosco. Todas las verificaciones locales pasan satisfactoriamente.

---

## 2. Configuración de archivos CI/CD

### `.github/workflows/ci.yml` (CI - Hito 5)
**Estado:** Activo en GitHub Actions

Jobs configurados:
| Job | Descripción | Bloqueante |
|-----|-------------|------------|
| frontend | Flutter: pub get, dart format, flutter analyze, flutter test, build web | No (antes) |
| backend | Node.js: npm ci, npm test, validar config | No (antes) |
| python | Microservicios Visión + Cardiología IA: pytest, import app | No (antes) |
| security | truffleHog + verificación de .env commiteados | No (antes) |
| summary | Resumen de resultados (needs: todos) | N/A |

**Cambio crítico aplicado:** Se eliminaron todos los operadores `|| true` de los pasos `run` del CI. Anteriormente, los `|| true` hacían que cualquier fallo de prueba se silenciará y el CI reportara éxito aunque las pruebas fallaran. Ahora las pruebas fallan realmente si hay errores, cumpliendo el requisito de "no omitir pruebas para conseguir resultados exitosos".

### `.github/workflows/cd.yml` (CD - Despliegue Continuo)
**Estado:** Activo en GitHub Actions

Despliegue solo en rama `main`:
- `verify-tests`: verificación previa (solo main)
- `deploy-backend`: Vercel (requiere `VERCEL_TOKEN`)
- `deploy-frontend`: Firebase Hosting (requiere `FIREBASE_TOKEN`)
- `deploy-python`: notificación Render/Railway/Vercel

---

## 3. Autenticación con GitHub CLI

```
gh auth status
  ✓ Logged in to github.com account crmv1 (keyring)
  - Active account: true
  - Git operations protocol: https
  - Token scopes: 'gist', 'read:org', 'repo', 'workflow'
```

**Resultado:** Autenticación verificada. Token con scopes `repo` y `workflow`.

---

## 4. Estado de Pull Requests

| PR | Rama origen | Rama destino | Estado | URL |
|----|-------------|--------------|--------|-----|
| #53 | Camila | main | **MERGED** | https://github.com/Nano3559/ConsultorioClinico/pull/53 |
| #54 | Camila | main | **OPEN** (sin merge) | https://github.com/Nano3559/ConsultorioClinico/pull/54 |

- El PR #53 ya estaba merged antes de este trabajo.
- Se creó el PR #54 con las correcciones del Hito 5. **No se realizó merge a main** (pendiente de autorización del usuario).

---

## 5. Errores encontrados y corregidos

### 5.1 CI ocultaba fallos (`|| true`)
**Problema:** Todos los pasos de `ci.yml` usaban `|| true`, impidiendo que las pruebas fallaran realmente.

**Corrección:** Se eliminaron todos los `|| true` de `ci.yml` para que las pruebas se ejecuten de forma real y fallen si hay errores.

### 5.2 Frontend: `dart format` — 101 archivos sin formatear
**Problema:** El paso "Verificar formato (dart format)" falló en CI porque 101 archivos de Dart no cumplían el formato estándar. El CI reportó "Formatted 101 files (94 changed)".

**Corrección:** Se ejecutó `dart format lib/ test/` en el frontend, aplicando el formato a 93 archivos. Verificado con `dart format --set-exit-if-changed lib/ test/` → **0 changed** (formato limpio).

### 5.3 Frontend: `flutter analyze` — 7 issues de `curly_braces_in_flow_control_structures`
**Problema:** `flutter analyze lib/ test/` reportó 7 issues (tipo `info`) por sentencias `if` de una sola línea sin llaves `{}`.

**Archivos corregidos:**
- `frontend/lib/features/internal/clinical/consult_form_page.dart:192`
- `frontend/lib/features/internal/patient_my_appointments_page.dart:34`
- `frontend/lib/features/internal/reports/reports_page.dart:33,41`
- `frontend/lib/features/public/kiosk/kiosk_page.dart:130`
- `frontend/lib/features/public/kiosk/kiosk_service.dart:28`
- `frontend/lib/state/clinic_provider.dart:96`

**Resultado:** `flutter analyze lib/ test/` → **No issues found!** (exit code 0).

### 5.4 Backend: middleware `kioskAuth` — 5 fallos de autorización
**Problema:** 5 pruebas fallaban en `test/rostro.test.js` para endpoints `GET /api/kiosco/manifest`, `/api/kiosco/modelo`, `/api/kiosco/paquete/:id`. Todas devolvían 403 en lugar de 200/401/404.

**Causa raíz:** El middleware `backend/src/middleware/kioscoAuth.js` solo aceptaba JWT personal (admin/recepcion) cuando `KIOSK_API_KEY` estaba vacío. Si tenía valor, solo aceptaba el header `x-kiosk-key` y rechazaba cualquier JWT con 403.

**Corrección:** Se modificó `kioscoAuth.js` para aceptar **ambos caminos siempre**:
1. Kiosco físico con `x-kiosk-key` válida (acceso directo, sin JWT)
2. Personal autenticado con JWT (rol admin/recepcion) — siempre disponible

El camino 2 sigue exigiendo JWT válido con roles autorizados, por lo que no debilita la seguridad.

**Resultado:** `npm test` → **108/108 pruebas pasan, 0 fallos.**

---

## 6. Resultados de pruebas locales (evidencia)

### Frontend (Flutter)
```
flutter analyze lib/ test/
  No issues found! (ran in 8.4s)

flutter test
  All tests passed! (41 pruebas)
```

### Backend (Node.js + Express)
```
npm test
  ℹ tests 108
  ℹ suites 19
  ℹ pass 108
  ℹ fail 0
```

### Formato Dart
```
dart format --output=none --set-exit-if-changed lib/ test/
  Formatted 101 files (0 changed)  ← exit code 0
```

---

## 7. Ejecución de GitHub Actions

### CI - Hito 5
Los workflows están activos en GitHub Actions:
- `CI - Hito 5` (ID: 421780005) — activo
- `CD - Despliegue Continuo (Hito 5)` (ID: 421780556) — activo

**Observación:** El PR #54 (Camila → main) fue creado pero los checks de CI no se ejecutaron automáticamente en GitHub Actions (`statusCheckRollup: []` tras varios minutos de monitoreo). Esto parece ser un problema de configuración del repositorio de GitHub Actions, no de los cambios de código, ya que todas las verificaciones locales pasan correctamente.

Ejecución previa de CI en PR #53 (falló por `dart format`): https://github.com/Nano3559/ConsultorioClinico/actions/runs/44159731963

### CD - Despliegue Continuo
El CD se activó en pushes a la rama Camila pero no desplegó (es esperado: los jobs de despliegue tienen `if: github.ref == 'refs/heads/main'`). El CD solo despliega en push a `main` y requiere secrets `VERCEL_TOKEN` / `FIREBASE_TOKEN`.

---

## 8. Archivos modificados

| Archivo | Cambio |
|---------|--------|
| `.github/workflows/ci.yml` | Quitados `|| true` de todos los pasos |
| `backend/src/middleware/kioscoAuth.js` | Permitir JWT personal siempre (no solo cuando `KIOSK_API_KEY` está vacío) |
| `frontend/lib/*.dart` (93 archivos) | Formato aplicado con `dart format` |
| `frontend/test/*.dart` (5 archivos) | Formato aplicado con `dart format` |
| Otros archivos generados (android/windows) | Cambios automáticos de Flutter |

**Total:** 96 archivos cambiados, 4,647 inserciones, 2,119 eliminaciones.  
**Commit:** `91aaa6e` + `895cfb4` (commit vacío para forzar CI) en rama `Camila`.

---

## 9. Conclusiones y recomendaciones

### Conclusiones
1. Todos los errores de CI/CD identificados fueron corregidos y verificados localmente.
2. Las pruebas pasan completamente: Flutter 41/41, Backend 108/108, Dart format limpio, Flutter analyze sin issues.
3. El CI ahora ejecuta pruebas reales (sin `|| true` que ocultaran fallos).
4. El PR #54 está listo para revisión y merge, pendiente de autorización.

### Recomendaciones
1. **Merge del PR #54 a main** solo tras autorización del usuario.
2. **Investigar por qué GitHub Actions no ejecuta el CI automáticamente** en el PR #54 (posible problema de configuración del repositorio o de GitHub Actions).
3. **Configurar secrets de despliegue** (`VERCEL_TOKEN`, `FIREBASE_TOKEN`) para habilitar el CD en producciÛn.
4. **Mantener los `|| true` eliminados** para que el CI siga detectando fallos reales de pruebas.

---

**No se expusieron credenciales ni secretos en este informe.**  
**No se omitieron pruebas para obtener resultados exitosos.**