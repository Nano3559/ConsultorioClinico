# Equipo y Roles

Sistema de control médico y clínico **ConsultorioClínico**.

## Equipo de desarrollo

| Miembro | Responsabilidad principal | Áreas |
|---|---|---|
| **Brayan** | Frontend | Flutter (Dart), paneles por rol, landing, integración con la API |
| **Jhilian** | Base de datos y Supabase | Migraciones SQL, esquema, RLS, triggers, deploy de BD |
| **Camila** | Backend Node.js/Express y despliegue | API, autenticación JWT, middlewares, Vercel, documentación |

## Roles del sistema (usuarios)

| Rol | Permisos |
|---|---|
| **Administrador** | Gestión completa: médicos, especialidades, horarios, pacientes, citas, consultas, pagos, reportes y configuración |
| **Médico** | Ver citas de su agenda, consultar pacientes, registrar y actualizar consultas (historia clínica) |
| **Recepción** | Registrar pacientes, crear/confirmar citas, registrar y actualizar pagos, consultar agenda |
| **Paciente** | Registrarse, solicitar citas, consultar/cancelar sus citas |

## Flujo de trabajo

1. `main` — versión estable (se despliega).
2. `develop` — integración de funcionalidades.
3. `feature/*` — cada funcionalidad se desarrolla en una rama propia.
4. `fix/*` — correcciones de errores.
5. Los cambios se integran mediante **Pull Requests** con revisión del equipo.

## Estados de una cita

`programada → confirmada → en_curso → completada` (con `cancelada` y `no_show` como salidas).

## Cuentas demo (semilla)

| Rol | Email | Contraseña |
|---|---|---|
| Administrador | `admin@consultorio.com` | `admin123` |
| Médico | `carlos@consultorio.com` | `medico123` |
| Recepción | `maria@consultorio.com` | `recepcion123` |
| Paciente | `pedro@gmail.com` | `paciente123` |

> Son datos de desarrollo/semilla. Deben cambiarse o eliminarse antes de producción.