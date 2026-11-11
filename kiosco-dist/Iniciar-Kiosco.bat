@echo off
REM =====================================================================
REM  Iniciar-Kiosco - ConsultorioClinico
REM ---------------------------------------------------------------------
REM  Doble clic y listo: abre la app del consultorio en pantalla completa.
REM  Luego toca el boton "Kiosco" en la pagina principal.
REM  No necesita saber nada de codigo.
REM
REM  Requisitos (los instala la persona tecnica una sola vez):
REM    1. Esta carpeta debe contener consultorio_clinico.exe
REM       (compilado con flutter build windows --release)
REM    2. Internet (el kiosco consulta la nube).
REM =====================================================================
setlocal

cd /d "%~dp0"

if not exist "consultorio_clinico.exe" (
  echo.
  echo  [ERROR] No encuentro consultorio_clinico.exe en esta carpeta.
  echo  Pide a la persona de sistemas que copie aqui la carpeta del kiosco.
  echo.
  pause
  exit /b 1
)

echo  Abriendo kiosco en pantalla completa...
echo  Cuando abra, toca el boton "Kiosco" en la pagina principal.
echo  Para salir: presiona F11 y cierra la ventana.
echo.
start "" /max "consultorio_clinico.exe"

REM --- Acceso directo en el escritorio (solo primera vez) ---
if not exist "%USERPROFILE%\Desktop\Kiosco Consultorio.lnk" (
  echo.
  set /p ACCESO="¿Crear acceso directo en el escritorio? (S/N): "
  if /i "%ACCESO%"=="S" (
    powershell -NoProfile -Command "$s=(New-Object -ComObject WScript.Shell).CreateShortcut(\"$env:USERPROFILE\Desktop\Kiosco Consultorio.lnk\"); $s.TargetPath='%~dp0Iniciar-Kiosco.bat'; $s.WorkingDirectory='%~dp0'; $s.Save()"
    echo  Acceso directo creado.
  )
)

REM --- Arranque automatico con Windows (opcional) ---
echo.
set /p AUTO="¿Abrir el kiosco solo al encender la PC? (S/N): "
if /i "%AUTO%"=="S" (
  powershell -NoProfile -Command "$s=(New-Object -ComObject WScript.Shell).CreateShortcut(\"$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\Kiosco Consultorio.lnk\"); $s.TargetPath='%~dp0Iniciar-Kiosco.bat'; $s.WorkingDirectory='%~dp0'; $s.Save()"
  echo  Listo: el kiosco abrira solo al encender la PC.
)

echo.
echo  Kiosco iniciado. Puedes cerrar esta ventana negra.
timeout /t 5 >nul
