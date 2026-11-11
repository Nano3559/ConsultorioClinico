# 🖥️ Instalar el Kiosco en una PC nueva (sin saber código)

> Guía para personas NO técnicas (recepción, administración).
> Tiempo: 5 minutos por PC. Solo necesitas internet y una carpeta que te pasa
> la persona de sistemas.

---

## Qué es el kiosco (en palabras simples)

Es la pantalla de la entrada del consultorio donde el paciente **se confirma
solo con su cara**, sin pasar por recepción:

1. El paciente se acerca a la pantalla y se toma una foto.
2. El kiosco reconoce su rostro y busca su cita de hoy.
3. En pantalla aparece: *"Su consulta es a las 10:30 con el Dr. García"*.
4. La cita queda confirmada automáticamente. El doctor la ve en su agenda.
5. Si no lo reconoce o no tiene cita hoy: *"Pase a recepción"*.

La foto viaja a la nube, se compara con las fotos registradas y **nada se
guarda en la PC del kiosco** (si se rompe o roban la PC, no hay datos que
perder).

---

## PARTE A — Persona de sistemas (una sola vez)

1. En tu PC de desarrollo, compila la app para Windows:
```powershell
cd frontend
flutter build windows --release --dart-define=API_BASE_URL=https://consultorio-clinico.vercel.app/api --dart-define=KIOSK_API_KEY=LA_CLAVE_DEL_KIOSCO
```
2. Copia la carpeta `frontend\build\windows\x64\runner\Release\` completa a un
   pendrive o Drive, junto con el archivo `Iniciar-Kiosco.bat` (carpeta
   `kiosco-dist/` del repositorio).
3. Pásale esa carpeta a cada consultorio. Desde aquí ya no se toca código.

> La `KIOSK_API_KEY` es la misma del `backend/.env` del servidor. Sin ella el
> kiosco no puede confirmar citas.

## PARTE B — Persona NO técnica (en cada PC del kiosco)

Opción 1 — Instalador (recomendada):
1. Copia **`Setup_KioscoConsultorio.exe`** a la PC (pendrive, Drive, WhatsApp: pesa ~15 MB).
2. Doble clic → **Siguiente, Siguiente, Instalar**. No pide permisos de
   administrador (se instala en tu carpeta de usuario).
3. Marca lo que quieras: acceso directo en escritorio y/o abrir solo al
   encender la PC (recomendado).
4. Al terminar marca **"Abrir el kiosco ahora"** → se abre directo en la
   pantalla del auto-check-in. Listo.
5. Para desinstalar: Panel de control → Programas (deja acceso limpio).

Opción 2 — Carpeta portable: copia toda la carpeta `kiosco-dist` y doble
clic a `Iniciar-Kiosco.bat` (misma app, sin instalar).

### Si algo sale mal
| Qué ves | Qué hacer |
|---|---|
| *"No encuentro consultorio_clinico.exe"* | La carpeta está incompleta: pide a sistemas que la vuelva a pasar. |
| *"No se pudo conectar"* al verificar | Revisa el internet de la PC. Si hay internet, avisa a sistemas (puede ser el servidor). |
| *"Pase a recepción"* a un paciente con cita | Su rostro no está registrado o venció: recepción lo registra en 1 minuto (pantalla "Rostro del paciente"). |

---

## Requisitos de la PC del kiosco

- Windows 10/11 con cámara web (frontal) y pantalla táctil (recomendado).
- Internet permanente (el reconocimiento consulta la nube).
- **Microsoft Visual C++ Redistributable** (gratis, 2 min): lo piden casi
  todas las apps de Windows. Descárgalo de
  https://learn.microsoft.com/cpp/windows/latest-supported-vc-redist
  (elige `X64`). Sin esto, el `.exe` no abre.
- Nada que instalar: ni Python, ni Flutter, ni programas. Todo viene en la carpeta.
