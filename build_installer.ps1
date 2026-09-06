# Groovy Windows Installer Build Script
# Usage: .\build_installer.ps1

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Building Groovy Windows Release Installer" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Load .env if present
$envFile = ".env"
$defines = @()
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^(.+?)=(.+)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            if ($value.StartsWith('"') -and $value.EndsWith('"')) {
                $value = $value.Substring(1, $value.Length - 2)
            }
            [Environment]::SetEnvironmentVariable($name, $value, "Process")
        }
    }
    if ($env:COUNTLY_SERVER_URL) {
        $defines += "--dart-define=COUNTLY_SERVER_URL=$env:COUNTLY_SERVER_URL"
    }
    if ($env:COUNTLY_APP_KEY) {
        $defines += "--dart-define=COUNTLY_APP_KEY=$env:COUNTLY_APP_KEY"
    }
}

# 2. Build Flutter Windows Release
Write-Host "`n[1/3] Compilando Flutter para Windows (Release)..." -ForegroundColor Yellow
if ($defines.Count -gt 0) {
    & flutter build windows --release @defines
} else {
    & flutter build windows --release
}

if ($LASTEXITCODE -ne 0) {
    Write-Error "Error al compilar Flutter para Windows."
    exit 1
}

# 3. Locate NSIS compiler (makensis.exe)
Write-Host "`n[2/3] Localizando compilador de instaladores NSIS..." -ForegroundColor Yellow

$nsisPaths = @(
    "makensis.exe",
    "C:\Program Files (x86)\NSIS\makensis.exe",
    "C:\Program Files\NSIS\makensis.exe",
    "$env:LOCALAPPDATA\Programs\NSIS\makensis.exe"
)

$makensis = $null
foreach ($path in $nsisPaths) {
    try {
        $test = Get-Command $path -ErrorAction SilentlyContinue
        if ($test) {
            $makensis = $test.Source
            break
        }
        if (Test-Path $path) {
            $makensis = $path
            break
        }
    } catch {}
}

if (-not $makensis) {
    Write-Host "⚠️ NSIS no encontrado en el sistema. Instalándolo automáticamente vía winget..." -ForegroundColor Yellow
    winget install NSIS.NSIS --accept-source-agreements --accept-package-agreements --silent
    foreach ($path in $nsisPaths) {
        if (Test-Path $path) {
            $makensis = $path
            break
        }
    }
}

if (-not $makensis) {
    Write-Error "No se pudo encontrar makensis.exe. Por favor descarga e instala NSIS desde: https://nsis.sourceforge.io"
    exit 1
}

Write-Host "Compilador NSIS encontrado en: $makensis" -ForegroundColor Green

# 4. Generate Setup Installer
Write-Host "`n[3/3] Generando instalador Groovy-Setup.exe..." -ForegroundColor Yellow
& $makensis installer.nsi

if ($LASTEXITCODE -eq 0 -and (Test-Path "Groovy-Setup.exe")) {
    $size = (Get-Item "Groovy-Setup.exe").Length / 1MB
    Write-Host "`n==========================================" -ForegroundColor Green
    Write-Host " 🎉 ¡Instalador creado con éxito!" -ForegroundColor Green
    Write-Host " Archivo: $(Resolve-Path 'Groovy-Setup.exe')" -ForegroundColor Green
    Write-Host " Tamaño:  $([math]::Round($size, 2)) MB" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
} else {
    Write-Error "Error al generar el instalador con NSIS."
    exit 1
}
