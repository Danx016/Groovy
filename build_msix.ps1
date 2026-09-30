# Groovy Windows MSIX Build Script
# Usage: .\build_msix.ps1

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Building Groovy Windows MSIX Package     " -ForegroundColor Cyan
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
Write-Host "`n[1/2] Compilando Flutter para Windows (Release)..." -ForegroundColor Yellow
if ($defines.Count -gt 0) {
    & flutter build windows --release @defines
} else {
    & flutter build windows --release
}

if ($LASTEXITCODE -ne 0) {
    Write-Error "Error al compilar Flutter para Windows."
    exit 1
}

# 3. Create MSIX package
Write-Host "`n[2/2] Empaquetando en formato nativo MSIX..." -ForegroundColor Yellow
& dart run msix:create --build-windows false --sign-msix false

if ($LASTEXITCODE -eq 0 -and (Test-Path "build\windows\x64\runner\Release\groovy.msix")) {
    Copy-Item -Path "build\windows\x64\runner\Release\groovy.msix" -Destination "Groovy.msix" -Force
    $size = (Get-Item "Groovy.msix").Length / 1MB
    Write-Host "`n==========================================" -ForegroundColor Green
    Write-Host " 🎉 ¡Paquete MSIX creado con éxito!" -ForegroundColor Green
    Write-Host " Archivo: $(Resolve-Path 'Groovy.msix')" -ForegroundColor Green
    Write-Host " Tamaño:  $([math]::Round($size, 2)) MB" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
} else {
    Write-Error "Error al empaquetar con msix."
    exit 1
}
