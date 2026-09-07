#!/bin/bash
# ==============================================================================
# 🚀 Groovy - Script de Despliegue Automático en VPS / Servidor Linux
# ==============================================================================
set -e

echo "🎵 Iniciando actualización y despliegue de Groovy en el VPS..."

# 1. Obtener los últimos cambios de Git
echo "📥 1/4 Descargando últimos cambios de GitHub..."
git pull origin main

# 2. Compilar el Frontend de React (incluyendo Landing Page y Descargas)
echo "⚛️ 2/4 Compilando Frontend React (Landing & Web Player)..."
cd react-website
npm install
npm run build
cd ..

# 3. Instalar dependencias del Backend de Node.js
echo "📦 3/4 Instalando dependencias del backend..."
cd groovy-backend
npm install
cd ..

# 4. Reiniciar el servicio con PM2 (o systemd)
echo "🔄 4/4 Reiniciando el servidor Node.js..."
if command -v pm2 &> /dev/null; then
    pm2 restart groovy-backend || pm2 start groovy-backend/server.js --name "groovy-backend"
    pm2 save
    echo "✅ Servidor reiniciado con PM2 con éxito."
else
    echo "⚠️ PM2 no está instalado globalmente. Puedes iniciarlo con: node groovy-backend/server.js"
fi

echo "🎉 ¡Despliegue completado con éxito! Tu web y descargas están en vivo en tu servidor."
