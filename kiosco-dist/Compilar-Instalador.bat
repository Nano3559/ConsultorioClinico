@echo off
REM =====================================================================
REM  Compilar-Instalador - Kiosco ConsultorioClinico (SOLO persona técnica)
REM ---------------------------------------------------------------------
REM  Hace todo de una vez: compila el .exe + genera Setup_KioscoConsultorio.exe
REM  Uso:
REM    Compilar-Instalador.bat [API_URL] [KIOSK_API_KEY]
REM  Ejemplo:
REM    Compilar-Instalador.bat https://consultorio-clinico-brayan.vercel.app/api MI_CLAVE
REM
REM  Aclaración de qué NECESITA (pregunta frecuente):
REM    1. Flutter SDK 3.47+ instalado (https://docs.flutter.dev)
REM    2. Visual Studio 2022+ con "Desktop development with C++"
REM       (incluye MSBuild + CMake + compilador C++)
REM    3. Inno Setup 6 (https://jrsoftware.org/isdl.php) para empaquetar.
REM       El script busca ISCC.exe en su ruta por defecto de usuario.
REM    4. Este repo clonado + dependencias (flutter pub get lo hace solo).
REM    5. Internet (descarga paquetes Dart la primera vez).
REM  Tarda ~10 min la primera vez (compila C++), ~2 min las siguientes.
REM =====================================================================
setlocal

if "%~2"=="" (
  echo.
  echo  Uso: Compilar-Instalador.bat [API_URL] [KIOSK_API_KEY]
  echo  Ejemplo:
  echo    Compilar-Instalador.bat https://consultorio-clinico-brayan.vercel.app/api MI_CLAVE
  echo.
  echo  La KIOSK_API_KEY sale de tu Vercel - Settings - Environment Variables.
  echo  NUNCA la escribas directo en este archivo: viajaria al git.
  exit /b 1
)

set API_URL=%~1
set KIOSK_KEY=%~2
set ISCC=%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe
if not exist "%ISCC%" set ISCC=C:\Program Files (x86)\Inno Setup 6\ISCC.exe
if not exist "%ISCC%" (
  echo  [ERROR] No encuentro ISCC.exe. Instala Inno Setup 6 primero.
  exit /b 1
)

where flutter >nul 2>nul
if errorlevel 1 (
  echo  [ERROR] Flutter no esta en el PATH.
  exit /b 1
)

echo  [1/3] Compilando .exe (esto tarda varios minutos)...
pushd "%~dp0..\frontend"
call flutter build windows --release --dart-define=API_BASE_URL=%API_URL% --dart-define=KIOSK_API_KEY=%KIOSK_KEY% --dart-define=RUTA_INICIAL=/kiosco
if errorlevel 1 (
  echo  [ERROR] Fallo la compilacion Flutter.
  popd
  exit /b 1
)
popd

echo  [2/3] Generando instalador...
call "%ISCC%" "%~dp0instalador-kiosco.iss"
if errorlevel 1 (
  echo  [ERROR] Fallo Inno Setup.
  exit /b 1
)

echo  [3/3] Listo:
dir /b "%~dp0Setup_KioscoConsultorio.exe"
echo  Pasa ese archivo por Drive/USB a cada PC del kiosco.
