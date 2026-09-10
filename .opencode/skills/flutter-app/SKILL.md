---
name: flutter-app
description: Guía para trabajar en el frontend Flutter de ConsultorioClinico (frontend/): comandos flutter pub/run/build/analyze/test, estructura de lib/ con Provider y GoRouter, Firebase y build Android. Use when the task touches Dart code, the web/Android app, Firebase Auth/Firestore or the Flutter build.
---

# Skill: Frontend Flutter (ConsultorioClínico)

Aplica cuando la tarea toque `frontend/` (app web + Android).

## Comandos (siempre desde `frontend/`)
```bash
flutter pub get                 # dependencias
flutter run -d chrome           # web en desarrollo
flutter run -d windows          # escritorio
flutter analyze                 # lints — DEBE quedar sin warnings antes de terminar
flutter test                    # widget tests
flutter build web               # build web (salida build/web)
flutter build apk               # APK Android (firma en build.gradle.kts)
```

## Estructura de `lib/` (respetarla siempre)
- `main.dart` — Providers + GoRouter.
- `core/` — tema, constantes, utils y widgets compartidos. Reutilizar antes de crear nuevos.
- `data/models/` — entidades (paciente, médico, cita, pago…). `data/mock/` solo para el ejercicio académico.
- `services/` — `api_client.dart` (HTTP al backend Express) y `firestore_service.dart` (Firestore). **Toda red pasa por aquí**; nunca `http` suelto en widgets.
- `state/` — `clinic_provider.dart` y `auth_provider.dart` (Provider). El estado se muta con métodos del provider, no dentro de los widgets.
- `features/public/` — landing, login, solicitar cita. `features/internal/` — dashboard, pacientes, médicos, agenda, historia clínica, pagos, reportes, configuración.

## Reglas
- Navegación SOLO con GoRouter (rutas declarativas en `main.dart`).
- UI en español; fechas/números con `intl`.
- Firebase: proyecto `consultorioclinico-2026`; credenciales en `lib/firebase_options.dart`; el rol del usuario se lee de Firestore tras autenticar con Firebase Auth.
- Reglas RBAC en `firestore.rules`; índices en `firestore.indexes.json` — si añades una consulta compuesta nueva, actualiza los índices.
- API URL configurable con `--dart-define=API_BASE_URL=...` (por defecto apunta a producción en Vercel).
- Correo: `--dart-define=MAIL_API_URL=...` apunta al mail-service.
