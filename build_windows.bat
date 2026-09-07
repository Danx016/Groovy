@echo off
setlocal enabledelayedexpansion

echo ========================================================
echo   COMPILANDO GROOVY PARA WINDOWS (RELEASE + FIRMA)
echo ========================================================

:: 1. Compilar Flutter Release
echo [1/4] Compilando binarios de Flutter Windows...
call flutter build windows --release
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Fallo al compilar con Flutter.
    pause
    exit /b %ERRORLEVEL%
)

:: 2. Firmar ejecutable principal con certificado Authenticode
echo [2/4] Firmando groovy.exe con certificado digital Authenticode...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2('windows\groovy_codesign.pfx', 'Groovy2026!'); Set-AuthenticodeSignature -FilePath 'build\windows\x64\runner\Release\groovy.exe' -Certificate $cert -TimestampServer 'http://timestamp.digicert.com' -HashAlgorithm SHA256"

:: 3. Compilar instalador con Inno Setup
echo [3/4] Generando instalador Groovy-Setup.exe...
set ISCC="C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if not exist %ISCC% set ISCC="C:\Program Files\Inno Setup 6\ISCC.exe"
if not exist %ISCC% set ISCC="%LOCALAPPDATA%\Programs\Antigravity IDE\resources\app\node_modules\innosetup\bin\ISCC.exe"

if exist %ISCC% (
    %ISCC% installer.iss
    echo [4/4] Firmando instalador Groovy-Setup.exe...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2('windows\groovy_codesign.pfx', 'Groovy2026!'); Set-AuthenticodeSignature -FilePath 'Groovy-Setup.exe' -Certificate $cert -TimestampServer 'http://timestamp.digicert.com' -HashAlgorithm SHA256"
) else (
    echo [ADVERTENCIA] Inno Setup no encontrado en rutas por defecto. Solo se genero la version portable.
)

:: 4. Generar archivo ZIP portable
echo [EXTRA] Generando Groovy-Windows-Portable.zip...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Compress-Archive -Path 'build\windows\x64\runner\Release\*' -DestinationPath 'Groovy-Windows-Portable.zip' -Force"

echo ========================================================
echo   COMPILACION Y FIRMADO COMPLETADOS CON EXITO!
echo   - Instalador: Groovy-Setup.exe
echo   - Portable:   Groovy-Windows-Portable.zip
echo ========================================================
