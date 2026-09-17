# 📷 Estudio del plugin de cámara (Kiosco de auto-check-in) — KIO-03

Documento técnico del estudio realizado el **15/09/2026** para la pantalla
"Bienvenido, mire a la cámara" del kiosco de auto-check-in con
reconocimiento facial. Tareas: `KIO-03` (Frontend), con soporte `KIO-02`
(Backend/Visión) y `KIO-01` (Database).

## 1. Decisión de librería

Se eligió el plugin oficial **`camera`** de `flutter.dev/packages` (versión
instalada **0.12.1**). Es la opción estándar del ecosistema Flutter, con
implementaciones federadas por plataforma:

| Plataforma | Implementación | Versión | Motor |
|---|---|---|---|
| Web | `camera_web` | 0.3.5+6 | `getUserMedia` del navegador |
| Android | `camera_android_camerax` | 0.7.4+8 | **CameraX** (androidx.camera) |
| iOS | `camera_avfoundation` | 0.10.3 | AVFoundation |

*Alternativa evaluada:* `image_picker` con `ImageSource.camera`. Se descartó
para el modo kiosco porque abre el selector/diálogo del sistema (interacción
manual), mientras que `camera` permite **vista previa en vivo** con captura
automática y silenciosa, que es justo lo que necesita la tablet de recepción.

## 2. Soporte web

- **Requisito de contexto seguro:** la cámara web solo funciona en `https`
  o `localhost`. El hosting de Firebase ya despliega el frontend con HTTPS;
  en desarrollo usar `flutter run -d chrome` (localhost funciona).
- En web el permiso se pide **automáticamente por el navegador** al crear el
  stream (`getUserMedia`); no se usa `permission_handler` (no aplica en web).
- `camera_web` soporta `CameraPreview`, `takePicture()` y la enumeración de
  cámaras con `availableCameras()` (frontal/delantera según `label`).
- No requiere cambios en `web/` (HTML/JS) para el caso de uso actual.

## 3. Soporte Android

Se aplicaron los siguientes cambios en `frontend/android/`:

```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-feature android:name="android.hardware.camera" android:required="false"/>
<uses-feature android:name="android.hardware.camera.front" android:required="false"/>
```

- **Permiso en tiempo de ejecución:** en Android el `camera` plugin **no**
  solicita el permiso por sí mismo. Se añadió `permission_handler` (13.0.2)
  y el servicio pide `Permission.camera` antes de `availableCameras()`.
- **minSdk:** `camera_android_camerax` exige **minSdk 24**. El SDK de Flutter
  3.47 ya usa `minSdkVersion = 24` por defecto, por lo que `build.gradle.kts`
  no requirió cambios.
- **Graphics/surface:** CameraX gestiona automáticamente la superficie de la
  vista previa; `CameraPreview` solo necesita el `CameraController`
  inicializado.
- Las tablets Android del consultorio deben tener cámara frontal y Android 7+.

## 4. Cómo lo usa la app

`frontend/lib/features/public/kiosk/kiosk_camera_service.dart`

```
KioskCameraService.initialize()
  → Permission.camera.request()        (solo móvil)
  → availableCameras()                 (web usa getUserMedia internamente)
  → primera cámara frontal (fallback: trasera)
  → CameraController(frontal, ResolutionPreset.high, enableAudio: false)
  → initialize()                        (lista la vista previa)

KioskCameraService.capture()
  → controller.takePicture()  →  XFile  →  bytes  →  base64 (payload)
```

La pantalla `kiosk_page.dart` envuelve el preview en un recorte redondeado con
guía de rostro (óvalo teal), conteo automático de 4 s, captura manual y estados
de error/cámara denegada. La foto se entrega por `onPhotoCaptured(base64)` para
la verificación (`POST /api/kiosco/verificar-rostro`, KIO-09 del 17/09).

## 5. Rutas

- Página: `frontend/lib/features/public/kiosk/kiosk_page.dart` → **`/kiosco`**
- Servicio: `frontend/lib/features/public/kiosk/kiosk_camera_service.dart`
- Dependencias nuevas: `camera ^0.12.1`, `permission_handler ^13.0.2`

## 6. Notas de despliegue

- Web: no requiere configuración, solo HTTPS (Firebase Hosting).
- Android: el permiso `CAMERA` ya está en el manifiesto; la app lo pide en
  tiempo de ejecución al iniciar el kiosco.
- Emuladores: `availableCameras()` puede devolver lista vacía en algunos
  emuladores virtualizados; la pantalla muestra el estado "no se detectó
  cámara" con opción de pasar a recepción.