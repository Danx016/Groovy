# Directrices Obligatorias para Groovy (Windows & Android)

## ⚠️ REGLA DE ORO: PARIDAD ABSOLUTA ENTRE WINDOWS Y ANDROID

En este repositorio, **TODO cambio, función, corrección de errores, ajuste de interfaz o mejora técnica DEBE implementarse y verificarse SIEMPRE TANTO EN WINDOWS COMO EN ANDROID.**

### 1. Interfaz de Usuario y Temas
- Todo cambio de diseño, tipografía, tamaños de texto, colores, espaciados y componentes de interfaz debe verse idéntico y consistente tanto en Windows (escritorio) como en Android (móvil y tabletas).
- Los estilos globales se deben definir en `AppTheme` (`lib/theme/app_theme.dart`) para garantizar que apliquen uniformemente a ambos entornos.

### 2. Motores de Búsqueda y Streaming (yt-dlp e Innertube)
- Siempre que se modifique o mejore la resolución de carátulas, extracción de streams, calidad de audio o lógica de búsqueda:
  - **Windows:** Actualizar en `lib/services/ytdlp_service.dart` y `lib/services/youtube_service.dart`.
  - **Android:** Actualizar en `android/app/src/main/python/ytdlp_helper.py` (Chaquopy Python) y `lib/services/youtube_service.dart`.
- Mantener siempre la misma resolución máxima (`1200x1200px` para YouTube Music y `sddefault` para YouTube) y los mismos filtros de relevancia en ambos motores.

### 3. Groovy Connect y Conectividad Remota
- El flujo de control remoto y transferencia de reproducción entre dispositivos debe funcionar de forma bidireccional y robusta entre Windows y Android a través del servidor en la nube sin depender de redes locales directas.

### 4. Caché de Carátulas y Renderizado
- La caché de disco para carátulas debe guardarse en resolución completa (`1200px`) y utilizar `FilterQuality.medium` para evitar borrosidad en pantallas de alta densidad (DPI alto en Android y monitores 1080p/2K/4K en Windows).
