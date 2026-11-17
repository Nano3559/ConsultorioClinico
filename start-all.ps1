# =====================================================================
# ConsultorioClínico - Script de inicio unificado (Hito 5)
# Levanta: Backend Node.js (puerto 3000), IA Cardiología (puerto 8000),
#          Frontend Flutter Web (puerto 5000)
# Evita procesos duplicados y conflictos de puertos.
# =====================================================================

$ErrorActionPreference = "Continue"

$rootDir = "C:\Users\camii\Documents\ConsultorioClinico"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  ConsultorioClínico - Inicio de todos los servicios" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

# ---------------------------------------------------------------------
# Función: matar procesos existentes
# ---------------------------------------------------------------------
function Detener-Procesos() {
    Write-Host "`n[1/4] Deteniendo procesos existentes..." -ForegroundColor Cyan
    Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Get-Process python -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Get-Process flutter -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Get-Process dart -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    Write-Host "  [OK] Procesos detenidos." -ForegroundColor Green
}

# ---------------------------------------------------------------------
# 1. Detener procesos previos
# ---------------------------------------------------------------------
Detener-Procesos

# ---------------------------------------------------------------------
# 2. Iniciar Backend Node.js
# ---------------------------------------------------------------------
Write-Host "`n[2/4] Iniciando Backend Node.js (puerto 3000)..." -ForegroundColor Cyan
Start-Process -FilePath "$rootDir/start-backend.bat" -WindowStyle Hidden -PassThru
Start-Sleep -Seconds 5

# Verificar backend
$backendOk = $false
for ($i = 0; $i -lt 10; $i++) {
    try {
        $resp = Invoke-RestMethod -Uri "http://localhost:3000/api/health" -TimeoutSec 3 -ErrorAction SilentlyContinue
        if ($resp) { $backendOk = $true; break }
    } catch {}
    Start-Sleep -Seconds 1
}

if ($backendOk) {
    Write-Host "  [OK] Backend responde en http://localhost:3000/api/health" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Backend no responde." -ForegroundColor Red
}

# ---------------------------------------------------------------------
# 3. Iniciar IA Cardiología
# ---------------------------------------------------------------------
Write-Host "`n[3/4] Iniciando IA Cardiología (puerto 8000)..." -ForegroundColor Cyan
Start-Process -FilePath "$rootDir/start-ia.bat" -WindowStyle Hidden -PassThru
Start-Sleep -Seconds 8

# Verificar IA
$iaOk = $false
for ($i = 0; $i -lt 15; $i++) {
    try {
        $resp = Invoke-RestMethod -Uri "http://127.0.0.1:8000/health" -TimeoutSec 3 -ErrorAction SilentlyContinue
        if ($resp) { $iaOk = $true; break }
    } catch {}
    Start-Sleep -Seconds 2
}

if ($iaOk) {
    Write-Host "  [OK] IA Cardiología responde en http://127.0.0.1:8000/health" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] IA Cardiología no responde." -ForegroundColor Red
}

# ---------------------------------------------------------------------
# 4. Iniciar Frontend Flutter Web
# ---------------------------------------------------------------------
Write-Host "`n[4/4] Iniciando Frontend Flutter Web (puerto 5000)..." -ForegroundColor Cyan
Start-Process -FilePath "$rootDir/start-frontend.bat" -WindowStyle Hidden -PassThru
Write-Host "  [INFO] Flutter está compilando (puede tardar 1-2 minutos)..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Verificar frontend
$frontendOk = $false
for ($i = 0; $i -lt 20; $i++) {
    try {
        $resp = Invoke-RestMethod -Uri "http://localhost:5000" -TimeoutSec 3 -ErrorAction SilentlyContinue
        if ($resp) { $frontendOk = $true; break }
    } catch {}
    Start-Sleep -Seconds 3
}

if ($frontendOk) {
    Write-Host "  [OK] Frontend disponible en http://localhost:5000" -ForegroundColor Green
} else {
    Write-Host "  [INFO] Frontend aún compilando. Revisa http://localhost:5000." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------
# Resumen
# ---------------------------------------------------------------------
Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "  RESUMEN DE SERVICIOS" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  Backend Node.js:        http://localhost:3000/api/health`t$(if ($backendOk) { 'OK' } else { 'FALLO' })" -ForegroundColor $(if ($backendOk) { 'Green' } else { 'Red' })
Write-Host "  IA Cardiología:         http://127.0.0.1:8000/health`t$(if ($iaOk) { 'OK' } else { 'FALLO' })" -ForegroundColor $(if ($iaOk) { 'Green' } else { 'Red' })
Write-Host "  Frontend Flutter:       http://localhost:5000`t`t$(if ($frontendOk) { 'OK' } else { 'Compilando...' })" -ForegroundColor $(if ($frontendOk) { 'Green' } else { 'Yellow' })
Write-Host ""
Write-Host "  URL para probar: http://localhost:5000" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Para probar como cardiólogo:" -ForegroundColor Yellow
Write-Host "    1. Inicia sesión con un médico de especialidad Cardiología"
Write-Host "    2. Módulo 'PreConsulta IA' -> crear y analizar preconsulta"
Write-Host "    3. Módulo 'Evaluar ECG con IA' -> subir CSV y ejecutar inferencia"
Write-Host ""
Write-Host "  Para detener todos los servicios:" -ForegroundColor Yellow
Write-Host "    Get-Process node | Stop-Process -Force"
Write-Host "    Get-Process python | Stop-Process -Force"
Write-Host "    Get-Process flutter | Stop-Process -Force"
Write-Host "========================================================" -ForegroundColor Cyan
