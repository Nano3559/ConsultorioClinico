# ConsultorioClínico — Frontend (Flutter)

Aplicación móvil + web para la gestión de un consultorio médico. Este frontend
implementa la página pública, el sistema interno por roles y toda la lógica de
negocio (agenda, citas, historias clínicas, pagos y reportes).

## Requisitos

- Flutter 3.47+ (Dart 3.13+)
- Android SDK (para el APK) o navegador (para web)

## Ejecutar

```bash
flutter pub get
flutter run -d chrome     # web
flutter run -d windows    # escritorio
flutter build apk         # APK de Android
flutter build web         # build web (docs: build/web)
```

## Arquitectura

```
lib/
  main.dart                # Providers + GoRouter
  core/                    # tema, constantes, utilidades, widgets compartidos
  data/
    models/                # entidades (paciente, médico, cita, pago, consulta…)
    mock/                  # datos ficticios del ejercicio académico
  services/
    api_client.dart        # cliente HTTP + contrato de endpoints del backend
  state/
    clinic_provider.dart   # estado global + reglas de negocio
    auth_provider.dart     # sesión y roles
  features/
    public/                # landing, login, solicitar cita
    internal/              # dashboard, pacientes, médicos, agenda, citas,
                           # historia clínica, pagos, reportes, configuración
```

## Backend (a integrar)

El backend lo desarrolla otro equipo (Node.js). El contrato de endpoints esperado
está documentado en `lib/services/api_client.dart`. Actualmente la app funciona
con datos ficticios; al tener la API lista solo hay que:

1. Configurar `ApiConfig.baseUrl` en `lib/services/api_client.dart`.
2. Delegar las operaciones de `ClinicProvider` y `AuthProvider` a los métodos
   HTTP ya definidos en `ApiClient`.

## Reglas de negocio implementadas

- Un horario reservado deja de aparecer como disponible.
- Cancelar una cita libera el horario automáticamente.
- La cita aparece en la agenda del médico y puede ser confirmada por recepción.
- Estados de cita: Pendiente, Confirmada, Atendida, Cancelada, No asistió.
- Roles: Administrador, Médico, Recepción, Paciente (login demo en `/login`).

## Cuentas de demostración

| Rol        | Correo              |
|------------|---------------------|
| Admin      | admin@clinica.com   |
| Médico     | maria@clinica.com   |
| Recepción  | recepcion@clinica.com |
| Paciente   | juan@clinica.com    |

Cualquier contraseña con 4+ caracteres funciona en modo demo.