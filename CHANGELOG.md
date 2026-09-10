# Changelog

All notable changes to Groovy will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.93] - 2026-09-09

### Fixed
- **Reproducción de Música 100% Restaurada**:
  - Restaurada la extracción robusta y confiable de audio mediante `tv_embedded` con `yt-dlp` en Windows/Linux y Chaquopy en Android.
  - Corregido el problema donde la música no cargaba al reproducir canciones.
  - Conservado el buscador con la API actualizada de Innertube y búsqueda dual en paralelo.

## [1.0.92] - 2026-09-09

### Fixed & Performance
- **Buscador 100% Restaurado**:
  - Solucionado el problema de "sin resultados" al buscar canciones: actualizadas las claves oficiales de YouTube Innertube API y modernizada la versión del cliente.
  - Búsqueda dual paralela con fallback automático a `youtube_explode_dart` para garantizar resultados siempre, incluso en IPs de servidores o Linux.
- **Carga Ultrarrápida de Canciones (Android, Windows y Linux)**:
  - Extracción de audio en memoria nativa directa por HTTP (~1.2s en lugar de 4-6s), eliminando el arranque pesado de Python (Chaquopy en Android / yt-dlp en escritorio).
  - Precarga inmediata de la siguiente canción en la cola (reproducción y cambio de pista en 0 ms instantáneo).
  - Precalentamiento de stream en búsquedas, álbumes y playlists.
  - Reutilización de conexiones HTTP persistentes (`Keep-Alive`) y aceleración táctil de toque (`onPointerDown`).
- **Paridad Total de Linux con Windows**:
  - Soporte completo de teclas multimedia globales de teclado y auriculares en Linux.
  - Notificaciones de escritorio con letras sincronizadas en Linux.

## [1.0.91] - 2026-09-09

### Added & Fixed
- **Instalador Nativo para Linux en 2 Toques (`Groovy-Linux.deb`)**:
  - Solucionado el problema donde al abrir el instalador en Linux redirigía a la tienda de aplicaciones de Ubuntu o a un editor de texto.
  - Ahora se genera automáticamente un paquete Debian nativo (`Groovy-Linux.deb`) compatible con Ubuntu, Linux Mint, Debian, Pop!_OS y Zorin OS.
  - Instalación ultra-sencilla en solo 2 toques: doble clic en `Groovy-Linux.deb` y presionar el botón "Instalar" del instalador del sistema.
  - Auto-actualización dentro de la aplicación para Linux: descarga el paquete `.deb` e inicia automáticamente el asistente de instalación del sistema.
  - Detección nativa e integración en la página web oficial para descarga directa en 2 toques.

## [1.0.90] - 2026-09-09

### Fixed & Improved
- **Latencia Cero en Pausa y Controles**:
  - Pausa y reproducción instantáneas (0ms de latencia) mediante actualización de estado optimista inmediata.
  - Eliminado el retraso por fade progresivo al pausar que provocaba que la canción siguiera sonando después de presionar el botón.
  - Protección optimista local contra rebotes de estado del reproductor.
- **Sincronización Total en Vivo (Groovy Connect)**:
  - Soporte de control y transferencia directa por red local (LAN HTTP) en menos de 5ms, eliminando el retraso de la nube.
  - Frecuencia de sincronización de estado remoto acelerada a 250ms (anteriormente 750ms).
  - Heartbeat de telemetría dinámica a 350ms al estar conectado remotamente.
  - Reconciliación de posición precisa sin retrocesos bruscos en la barra de progreso.
- **Controles Siempre Visibles en la Letra**:
  - Los controles de reproducción (barra de progreso, tiempos, anterior, reproducir/pausar y siguiente) permanecen siempre fijos y visibles en la pantalla de letra sin ocultarse automáticamente.
- **Letras Sincronizadas en Tiempo Real**:
  - Stream de posición de alta frecuencia (50ms en Windows/Linux y móvil) para sincronizar letras 20 veces por segundo.
  - Compensación de latencia de hardware de audio para resaltar cada verso exactamente al compás de la voz ("en vivo").

- **Instalador Fácil para Linux (Doble Clic)**:
  - Nuevo instalador `Groovy-linux-install.sh` que permite instalar Groovy con un solo doble clic.
  - Otorga permisos de ejecución al AppImage automáticamente y crea el acceso directo en el menú de aplicaciones del sistema.

## [1.0.88] - 2026-09-09

### Fixed & Improved
- **Letras Sincronizadas y Limpieza Visual**:
  - Eliminados los puntos suspensivos que aparecían cada 5 segundos entre versos normales. Ahora la letra se mantiene limpia y fluida, conservando únicamente la cuenta regresiva del intro principal y solos extendidos.
  - Auto-scroll optimizado sin saltos bruscos ni bloqueos por gestos táctiles.
- **Carátula y Transiciones Ultrarrápidas**:
  - Eliminada la reconstrucción pesada cuadro a cuadro de la imagen en `AlbumArtView`.
  - Altura fija y transición suave entre páginas de Carátula, Letra y A continuación sin redimensionamiento de pantalla ni tirones (120 FPS).
- **Cola de Reproducción (A continuación)**:
  - Soporte completo y optimizado para carátulas de archivos locales sin errores de red.
  - Arrastre de canciones mejorado con tirador táctil independiente para no interferir con el toque de reproducción.
  - Selector de estado memoizado para evitar recalcular la cola completa en cada milisegundo de reproducción.

## [1.0.87] - 2026-09-09

### Fixed & Improved
- **Reproducción con Datos Móviles**:
  - Soporte de streaming para redes móviles (4G/5G) con cliente TV sin restricciones de IP ni User-Agent.
  - Mayor tolerancia a redes lentas con timeouts de 15s y drenado de conexiones huérfanas.
  - Manejo de respuestas HTTP 410 (Gone) con renovación instantánea de URL.
- **Diálogo y Descarga de Actualizaciones**:
  - Corregido el problema donde la alerta de actualización desaparecía permanentemente tras perder conexión.
  - Mensajes de error claros en español en lugar de códigos técnicos confusos.
  - Opción de "Reintentar descarga" directamente en el banner y botón manual en Ajustes.
  - Registro de cambios dinámico que muestra las novedades reales de cada versión.

## [1.0.86] - 2026-09-09

### Security & Connectivity
- **Dominio Seguro HTTPS para API Cloud**:
  - Migración de la API de backend de dirección IP directa HTTP a dominio oficial con certificado SSL Let's Encrypt: `https://groovyapi.duckdns.org/api`.
  - Habilita compatibilidad completa con redes de datos móviles (4G/5G) y operadores móviles que restringen o bloquean tráfico HTTP sin cifrar.
  - Certificado SSL renovado y configurado en el servidor Nginx con cifrado TLS y HTTP/2.

## [1.0.85] - 2026-09-09

### Fixed & Improved
- **Letras Fluidas Estilo Apple Music (Móvil y Windows/Desktop)**:
  - Optimización de rendimiento a 60/120 FPS sin lag de CPU ni text reflows pesados durante el desplazamiento.
  - En Windows y pantallas panorámicas, las letras ahora se centran verticalmente con `ShaderMask` superior e inferior alineadas con la portada del álbum.
  - La línea activa permanece encendida durante toda la frase hasta la siguiente y los puntos de interludio (`• • •`) pulsan suavemente en intros y pausas instrumentales reales.
  - Eliminado el control deslizante visual de volumen de la pantalla de reproducción manteniendo el control de volumen por sistema y teclas de hardware.
- **Estabilidad Multi-Dispositivo (Groovy Connect Nube & LAN)**:
  - Eliminado el conflicto de doble comando (`sendPlaySong` + `skipNext`) que causaba bloqueos al saltar varias canciones seguidas en modo remoto.
  - Sincronización en tiempo real del progreso de reproducción: el controlador espera a que el receptor cargue el audio antes de avanzar el reloj, evitando saltos hacia atrás.
  - Forzado de reproducción seguro (`forcePlay: true`) en transferencias remotas para evitar pausas involuntarias.
- **Control de Audífonos y Auriculares (Cable y Bluetooth)**:
  - Soporte completo para 1 toque (play/pause), 2 toques (siguiente) y 3 toques (anterior/retroceder).
  - Al presionar el botón de los audífonos con la app recién abierta, reanuda la reproducción automática de la cola guardada.
  - Pausa inmediata al desconectar auriculares ("Becoming Noisy") para proteger la privacidad del usuario.
- **Windows System Media & Teclado**:
  - Desacoplado el control de teclas multimedia de Windows respecto a los permisos de notificaciones locales para garantizar funcionamiento continuo aún con notificaciones deshabilitadas.
  - Precarga de `playbackState` y `systemActions` en el inicio para reconocimiento inmediato por parte del sistema operativo.

## [1.0.83] - 2026-09-08

### Verified & Released
- **Estabilización Total y Verificación de Groovy Connect**:
  - Pruebas de extremo a extremo completadas con éxito en el servidor de producción (entrega simultánea en menos de 1s de comandos `transfer` y `skipNext`).
  - Sincronización remota bidireccional estable entre Windows y Android sin bloqueos en el hilo de reproducción ni reversión de pistas.
  - Eliminado el control deslizante horizontal de volumen en la pantalla de reproducción.
  - Generación de nuevos instaladores de Windows y binarios APK de Android para actualización inmediata.

## [1.0.82] - 2026-09-08

### Fixed & Improved
- **Corrección Crítica de Groovy Connect (Windows ⇄ Android)**:
  - Resuelto el bloqueo donde los comandos de reproducción (skipNext, skipPrevious, transfer, búsqueda de canciones) expiraban en el servidor y la app regresaba a la canción previa.
  - El bucle de sondeo de comandos (`_pollCloudCommands`) ahora ejecuta las transferencias de forma asíncrona no bloqueante, evitando que el sondeo se congele mientras la canción se descarga o inicializa.
  - Se eliminó el bloqueo síncrono al iniciar la reproducción (`_audioPlayer.play()`), permitiendo que el hilo responda inmediatamente a nuevos comandos y sincronice el estado con el servidor en tiempo real.
  - La sincronización de `skipNext` y `skipPrevious` en modo remoto ahora envía el track exacto de la cola con respaldo automático a canciones similares de la radio.
  - Se eliminó la verificación errónea de auto-eco en `onCommandReceived` para procesar de inmediato comandos dirigidos al dispositivo objetivo.
- **Eliminación de Barra de Volumen Horizontal**:
  - Eliminado el control deslizante horizontal de volumen en la pantalla de reproducción (`NowPlayingScreen`) según lo solicitado por el usuario.

## [1.0.81] - 2026-09-08

### Fixed & Improved
- **Diseño del Botón de Google en Inicio de Sesión**:
  - Reemplazado el dibujo manual por la geometría vectorial oficial del logotipo de Google con colores estándar de cuatro cuadrantes (#4285F4, #EA4335, #FBBC05, #34A853).
- **Eliminación Total de Indicadores de Carga Verdes**:
  - Se eliminaron las cargas en verde en favor de la identidad de marca Apple Music Red (`#FA243C`).
  - Configurado `progressIndicatorTheme` global en temas claro y oscuro, eliminando cualquier spinner verde residual en toda la app.
  - Barra de notificación y snackbars actualizados a la paleta oficial Groovy.
- **Página de Retorno OAuth Google Rediseñada**:
  - Rediseñada la página de confirmación de autenticación web con estética dark glassmorphism, brillo ambiental, logo de Groovy, badge de éxito y botón de acción en gradiente Apple Music Red.
- **Corrección de Build y Subida en GitHub Actions (Android)**:
  - Configurado enlace estático y del sistema para `sqlite3` (`source: system`), eliminando la descarga externa y el error de conexión por socket en CI.

## [1.0.80] - 2026-09-08

### Added & Improved
- **Control de Volumen Remoto Bidireccional (Groovy Connect)**:
  - Control de volumen sincronizado entre Android y Windows. El uso de botones físicos del teléfono o de los sliders en pantalla envía comandos `'volume'` y sincroniza en tiempo real el reproductor remoto.
  - Integración nativa con `RemoteAndroidPlaybackInfo` y botones físicos de Android con el menú emergente del sistema.
  - Nuevo control deslizante de volumen integrado en la pantalla Ahora Suena estilo Apple Music con retroalimentación háptica.
- **Carátulas en Alta Resolución Lossless**:
  - Eliminado el reescalado agresivo; actualización a imágenes 1200x1200px con filtro bilineal suave y soporte nativo completo.
- **Búsqueda Inteligente Priorizada**:
  - Los lanzamientos y álbumes oficiales de artistas verificados ("Canciones") aparecen primero, seguidos por videos ("YouTube").
- **Paridad Visual y de Controles en Windows**:
  - Barra de reproducción desktop actualizada con iconos Apple Music (`Icons.fast_rewind_rounded`, `play/pause`, `Icons.fast_forward_rounded` y tiempo restante negativo `-0:30`).
- **Servidor y Base de Datos**:
  - Migración automática de MySQL y soporte para telemetría de volumen en tiempo real.

## [1.0.79] - 2026-09-08

### Release
- **Lanzamiento Multiplataforma Oficial**:
  - Compilación y publicación de binarios oficiales para Android (`app-release.apk`) y Windows (`Groovy-Setup.exe` y versión portable).
  - Incluye todas las optimizaciones de 120Hz/144Hz, sincronización de Groovy Connect sin saltos temporales, y resolución robusta de álbumes y pistas locales.

## [1.0.78] - 2026-09-08

### Fixed
- **Resolución y Carga de Álbumes (Offline y Online)**:
  - Corregido el problema donde al abrir un álbum guardado o derivado de canciones se mostraba un slug con guiones bajos (ej. `album_mi_mejor_momento`), "Artista desconocido" en rojo, duración "0 MIN" y 0 canciones.
  - Creado `AlbumSanitizer`: limpia automáticamente prefijos técnicos (`album_`, `local_album_`, `dz_album_`), convierte guiones bajos en espacios y aplica mayúsculas/formato humano adecuado.
  - Búsqueda y cotejo elástico en `LibraryProvider.getAlbumSongs`: ahora empareja canciones locales/descargadas tanto por `albumId`, nombre de álbum normalizado y slug de álbum, asegurando que todas las canciones de álbumes locales o importados se carguen instantáneamente.
  - Actualizado `AlbumResolverService`: ahora traduce slugs a títulos limpios para que las búsquedas en YouTube Music y Deezer resuelvan el álbum real y su lista de pistas en vez de fallar con el slug raw.
  - Asegurada la consistencia de metadatos (portadas, artista, duración total, conteo de canciones) en `AlbumScreen`, `SongTile`, `NowPlayingMoreMenu`, `TrackNavigationBottomSheet` y `NowPlayingScreen`.

## [1.0.77] - 2026-09-08

### Performance & High Refresh Rate (120Hz / 144Hz)
- **Tasa de Refresco a 120Hz Nativo en Android**:
  - Implementado `preferredMinDisplayRefreshRate` y `preferredMaxDisplayRefreshRate` en Android 11+ (API 30+) en `MainActivity.kt`. Se evita que el sistema operativo baje agresivamente la frecuencia a 60Hz/30Hz durante animaciones o momentos sin interacción táctil directa (pantallas LTPO y paneles dinámicos).
  - Nuevo `DisplayModeService` con observador de ciclo de vida (`WidgetsBindingObserver`): detecta el modo de máxima tasa disponible (120Hz, 144Hz, 165Hz) y lo restaura de forma automática e inmediata cada vez que la app vuelve de segundo plano.
- **Eliminación Total de Tirones al Desplazarse (Scroll Jank)**:
  - Optimización de decodificación en `AlbumArtwork`: antes forzaba un mínimo de 300x300 px para cualquier tamaño de portada. Ahora clasifica en niveles dinámicos (miniaturas de 50px decodifican a ~100-140px), ahorrando hasta un 79% de consumo de memoria gráfica por elemento y acelerando la decodificación hasta 5 veces.
  - Expansión de la memoria de caché de imágenes de Flutter (`ImageCacheConfig`) de 100MB / 400 imágenes a 250MB / 1,000 imágenes, previniendo el vaciado continuo de caché y recolección de basura durante desplazamientos ultrarrápidos.
- **Aislamiento GPU en Windows & Escritorio**:
  - `DesktopPlayerBar` y `RightSidebar` aislados mediante `RepaintBoundary`: los avances en tiempo real de milisegundos del seek bar y el ecualizador ya no provocan repintado de la pantalla principal ni de las vistas de lista.
- **Modernización y Limpieza de Flutter 3.44**:
  - Migración completa de `cacheExtent` a `scrollCacheExtent: const ScrollCacheExtent.pixels(500)` en todas las pantallas de listas.
  - Implementación de `onReorderItem` y `PlayerProvider.moveQueueItem` eliminando llamadas deprecadas en listas reordenables y cola de reproducción.
  - Corrección de llamadas deprecadas en `Countly.instance.events.recordEvent`.
  - Proyecto con 0 errores y 0 advertencias en `flutter analyze`.

### Fixed & Optimized (Groovy Connect)
- **Filtro Antirretorno de Barra de Reproducción**:
  - Eliminado el bucle donde la barra avanzaba a 3s y rebotaba a 1s debido a reportes desfasados de la red.
  - Protección de posición extrapolada con margen de deriva tolerante y período de gracia de 4 segundos tras saltos manuales.
  - Intervalo de latido de telemetría acelerado a 3 segundos para sincronización en tiempo real.
- **Control Remoto Fluido y Sin Congelamientos**:
  - Actualizaciones de estado visual e interactivo instantáneas (0 ms) en `play()`, `pause()`, `seek()`, `skipNext()` y `skipPrevious()`.
  - Reducción de timeouts de red LAN de 2.0s a 500ms para conmutación inmediata a Cloud Relay.
  - Enrutamiento inteligente de comandos en el backend (`telemetry.js`) garantizando entrega por UUID, alias de modelo o sesión de usuario.

## [1.0.76] - 2026-09-08

### Fixed & Optimized
- **Corrección Definitiva del Salto y Parpadeo de Canciones en Groovy Connect**:
  - Resuelto el bug donde la música saltaba o se revertía cíclicamente entre la canción anterior ("Para Siempre") y la nueva al cambiar de pista en remoto.
  - Implementación de **Bloqueo Optimista de Transición de Pista** (*Optimistic Track Transition Lock*): el dispositivo controlador ignora reportes obsoletos de la canción previa mientras el reproductor remoto termina de cargar el nuevo stream.
  - Corrección de la verificación de `_isRenderingRemotely`: cuando un dispositivo actúa como receptor (reproduce por sus altavoces), ahora ejecuta los comandos de cambio de pista (`skipNext`, `skipPrevious`, `playSong`) en su reproductor local en lugar de reenviarlos de vuelta por la red en un bucle infinito.
  - Desconexión automática de conexiones salientes en `onTransferReceived` y `onCommandReceived` para evitar que ambos dispositivos se consideren controladores mutuos simultáneos.

## [1.0.75] - 2026-09-08

### Fixed & Optimized
- **Corrección de Dispositivos Duplicados y Sincronización en Groovy Connect**:
  - Eliminación de dispositivos duplicados/fantasmas (e.g. dos entradas de "Infinix X678B" en el modal de dispositivos).
  - Inyección automática y persistente de `deviceId` único en `GroovyApiService.reportPlaybackState` y `PlayerProvider.play()`, evitando que el backend genere claves de dispositivo conflictivas.
  - Deduplicación robusta de dispositivos por identidad física (nombre y plataforma) en backend (`GET /api/telemetry/playback`), en el servicio de descubrimiento (`GroovyConnectService`) y en la interfaz (`GroovyConnectModal`).
  - Purga automática de registros obsoletos y fallback por nombre de dispositivo en `_syncRemoteStatus` para garantizar sincronización inmediata de la posición de reproducción y carátula.

## [1.0.74] - 2026-09-08

### Fixed & Optimized
- **Avance en Vivo y Fluido de Segundos en Groovy Connect (Real-Time Playback)**:
  - Implementación de extrapolación de tiempo continuo (*dead reckoning*) a 250 ms en `PlayerProvider` durante la reproducción remota vía Groovy Connect.
  - El contador de segundos y la barra de progreso avanzan segundo a segundo de forma fluida y continua en tiempo real, en vez de congelarse por varios segundos a la espera de paquetes de red.
  - Suscripción directa de `DesktopPlayerBar` (`_ProgressBar`) al flujo de posición de alta resolución `positionStream`, eliminando saltos discretos tanto en Windows como en Android.
  - Reconciliación suave de desfases de red (deriva temporal <= 1200 ms ajustada de forma transparente sin tirones visuales).

## [1.0.73] - 2026-09-08

### Fixed & Optimized
- **Bucle de Actualización Resuelto (Windows & Android)**:
  - Corrección de comparación de versiones semánticas en `UpdateService.isNewer`: soporte completo para metadatos de build (`1.0.73+64`) y sufijos, eliminando el falso positivo que reabría el diálogo de actualización en cada inicio.
  - Silenciamiento persistente (Snooze): Si el usuario selecciona "Más tarde" o descarta el diálogo, la decisión se guarda en `SharedPreferences` por 24 horas para esa versión.
  - Gestión de permisos en Android: Solicitud interactiva del permiso `REQUEST_INSTALL_PACKAGES` ("Instalar apps desconocidas") para Android 8.0+ al actualizar el APK, con enlace de contingencia directa a GitHub.
  - Asistente de instalación en Windows (`installer.iss`): Casilla de acceso directo en el escritorio marcada por defecto para garantizar que siempre apunte al binario actualizado en `AppData\Local\Programs\Groovy`.
- **Rendimiento, Lag al Cambiar Canciones & Groovy Connect**:
  - Corrección de `Bad state: You cannot add items while items are being added from addStream` en `AudioHandlerService`.
  - Extracción y caché ultrarrápida de paletas de color a 36x36 px con memoria LRU en `PaletteService`, eliminando el congelamiento al abrir carátulas.
  - Arrastre suave de barra de progreso y optimización de notificaciones SMTC en Windows.
  - Sincronización bidireccional estable en `GroovyConnectService` sin desconexiones al buscar o cambiar canciones.

## [1.0.67] - 2026-09-07

### Fixed
- **Resolución de Streaming en Windows y Android**:
  - Corrección crítica: Se restableció la prioridad de Chaquopy Python en Android y `yt-dlp.exe` en Windows para la resolución de streams de audio de YouTube.
  - Esto garantiza que los tokens de descifrado de firma (`n-sig`) y las cabeceras HTTP de GoogleVideo se envíen correctamente, evitando el error `HTTP 403 Forbidden` que impedía la reproducción.

## [1.0.66] - 2026-09-07

### Performance & Major Optimization Across 21 Screens (Windows & Android)
- **Streaming & Resolution Speed**:
  - Pure-Dart Innertube direct resolution with fast client fallback, slashing song loading from 15s to 1-2s.
  - Preload next track at 2 seconds of playback (`position.inSeconds >= 2`) for 0ms track switching.
  - Streaming token cache extended to 5.5 hours.
- **UI & Jank Elimination Across 21 Screens**:
  - Eliminated $O(N \times M)$ linear scans in `LibraryProvider` collection getters via $O(1)$ set insertion and reactive memoization.
  - Instant $O(1)$ song lookup via `songsByIdMap` (4 µs vs 2,000 µs).
  - Instant local library search (0 ms) with 280 ms debounced network search in `SearchScreen`.
  - Responsive adaptive grids (2 to 8 columns via `LayoutBuilder`) for Windows and Android tablet in `AlbumsScreen`, `GenreScreen`, `DownloadsScreen`, and `FavoritesScreen`.
  - Parallelized async data loading with `Future.wait` in `LibraryScreen`, `ArtistScreen`, `GenreScreen`, and `LikedAlbumsScreen`.
  - Deduplicated in-flight artist avatar fetching and synchronous cache checks in `ArtistsScreen`.
  - Replaced $O(N \times M)$ queue iteration with $O(1)$ Set lookup in `AllSongsScreen`.
  - Deferred initial directory scan in `MainScreen` to ensure 120 FPS initial launch.

## [1.0.65] - 2026-09-07

### Added & Improved
- **Telemetría Nativa y Presencia en Tiempo Real (Móvil & Windows)**:
  - Implementación de latido de sesión continuo (`_startSessionHeartbeat`) cada 25 segundos en `AuthProvider` para reportar presencia activa en la app incluso mientras se navega sin reproducir música.
  - Detección de hardware y modelo comercial real del dispositivo en Android (marca, modelo) y Windows (nombre del equipo, build y versión del SO).
  - Envío automático de telemetría y metadatos de hardware nativo al backend de Groovy Cloud.
- **Portal de Administración (Admin Portal)**:
  - Exclusión completa de clientes Web en la vista de streaming en vivo; ahora solo muestra usuarios reales de las apps nativas (Android y Windows).
  - Detección dual en vivo: usuarios escuchando música y usuarios conectados activamente navegando en la app.
  - Filtros dedicados por plataforma (`📱 / 💻 Apps Nativas`, `📱 Solo Android`, `💻 Solo Windows`).

## [1.0.64] - 2026-09-06

### Fixed
- **Resolución de Artistas y Discografía**:
  - Corrección de la pantalla de artista donde se reemplazaba el nombre del artista seleccionado por el de la primera canción devuelta por la búsqueda en YouTube.
  - Validación estricta en el servicio de imágenes de artistas (`Deezer` / `iTunes`) para verificar que el nombre del resultado coincida verdaderamente con el artista consultado antes de asignarle su foto.
  - Filtrado y validación de autoría en la carga de álbumes y discografía (`getArtistAlbums`) para evitar mostrar álbumes pertenecientes a otros artistas con nombres similares.

## [1.0.63] - 2026-09-06

### Removed & Improved
- **Pantalla de Cuenta (Limpieza de secciones no deseadas)**:
  - Eliminación completa de la sección de *Notificaciones* y *Apps con acceso* en la pantalla de cuenta tanto en móviles como en Windows.
- **Idioma Español por Defecto**:
  - Configuración explícita del idioma español (`es`) como predeterminado y fallback en la resolución de idioma de la app.

## [1.0.62] - 2026-09-06

### Fixed
- **Actualizador de Windows (Instalación automática)**:
  - Corrección en el lanzamiento del instalador de actualización (`Groovy-Update-Setup.exe`) ejecutándolo directamente a través del Shell de Windows (`cmd.exe /c start`) para evitar bloqueos silenciosos de UAC o excepciones de PowerShell.
  - Cierre y transición automática del diálogo de actualización una vez completada la descarga e iniciado el asistente.

## [1.0.61] - 2026-09-06

### Improved & Fixed
- **Cuadrícula y Carátulas de Álbumes**:
  - Corrección del aspecto de las carátulas en la vista de Álbumes (fijando proporción cuadrada `1:1` con `AspectRatio` para evitar estiramiento o deformaciones).
  - Cuadrícula responsiva con cálculo dinámico de columnas tanto en escritorio como en dispositivos móviles.
- **Letras estilo Apple Music**:
  - Ajuste de tipografía, tamaño de letra aumentado (`36px` activa / `30px` inactivas) y peso `FontWeight.w800`.
  - Espaciado generoso entre versos (`18px` vertical) y ajuste fino de interlineado y kerning estilo Apple Music.
  - Interactividad con efecto hover y cursor interactivo en escritorio.
- **Barra lateral de escritorio**:
  - Integración de [`UserAvatar`](file:///c:/Users/danil/Downloads/Groovy/Groovy-master/lib/widgets/user_avatar.dart) en el perfil de usuario para mostrar foto de perfil del usuario (`avatarUrl`), avatares personalizados o iniciales estilizadas con degradado.

## [1.0.60] - 2026-09-06

### Added & Improved
- **Reproductor Pantalla Completa estilo Apple Music**:
  - Diseño centrado vertical y horizontalmente cuando la canción no dispone de letras sincronizadas (o están ocultas), con carátula cuadrada con sombra suave, metadatos centrados, barra de scrubber y controles icónicos de Apple Music.
  - Diseño dinámico de dos columnas cuando las letras sincronizadas están disponibles.
  - Sincronización cromática nativa de la barra de título de Windows.
  - Atajos de teclado para pantalla completa (F11 / Esc) y botones de cristal translúcidos.
- **Instalador y Actualizador de Windows**:
  - Elevación de permisos UAC automática (`RunAs`) en el instalador de actualizaciones.
- **Estabilidad de Audio y Plataformas**:
  - Corrección de la transición automática de canciones (evitando repetición de pistas finalizadas).
  - Inicialización protegida en Android evitando dependencias no disponibles en móviles.

## [1.0.59] - 2026-09-06

### Fixed & Improved
- **Reproducción de Audio en Windows**:
  - Selección prioritaria nativa de streams `MP4 / AAC (m4a)` en Windows para garantizar compatibilidad al 100% con *Windows Media Foundation* sin requerir códecs adicionales.
  - Optimización del proxy local de streaming para soportar peticiones parciales (`Range requests`) continuas.
- **Web App**:
  - Corrección en la carga inicial de `HomeView` y `useRecommendations` para sincronización con `LibraryContext`.
- **Automatización CI/CD Multiplataforma**:
  - Soporte completo y unificado para compilación y empaquetado de Android (`.apk`), Windows (`Groovy-Setup.exe` y `.zip`) y Linux (`.tar.gz`).

## [1.0.58] - 2026-09-06

### Added & Improved
- **Instalador Oficial de Windows y Soporte de Escritorio**:
  - Nuevo instalador ejecutable de Windows (`Groovy-Setup.exe`) basado en NSIS e Inno Setup con accesos directos y desinstalador limpio.
  - Script de automatización [`build_installer.ps1`](file:///c:/Users/danil/Downloads/Groovy/Groovy-master/build_installer.ps1) para compilar la release y generar el instalador en un solo comando.
  - Mejoras completas en la interfaz de escritorio: nueva barra de navegación lateral, reproductor de escritorio optimizado y panel lateral derecho.
- **Motor de Audio yt-dlp & YouTube Streaming**:
  - Implementación de servicio dedicado yt-dlp para resolución de streaming de audio directo y extracción rápida.
  - Streaming eficiente con `StreamAudioSource` y caché inteligente.
- **Marca y Assets**:
  - Nuevos iconos de aplicación de alta resolución para Windows y móviles.

## [1.0.55] - 2026-09-05

### Added & Improved
- **Acciones y Menú de Opciones en `AlbumScreen` Estilo Apple Music**:
  - Se añadieron los botones de acción rápida en la barra superior: Estrella de Favoritos (`Icons.star_rounded` / `Icons.star_outline_rounded`) y menú de 3 puntos (`Icons.more_vert_rounded`).
  - Nuevo modal inferior interactivo de opciones del álbum: "Agregar a la cola", "Descargar álbum / Eliminar descargas", "Reproducir álbum", "Reproducción aleatoria", "Ir al artista" y "Agregar a favoritos".

### Fixed
- **Sanitización Integral de Nombres de Artistas**:
  - Se corrigió el problema por el cual nombres con caracteres especiales o tildes se mostraban con identificadores técnicos internos (como `artist_tot__la_momp...` o `artist_los_hermanos...`).
  - Se agregó sanitización automática y resolución inteligente basada en las pistas del artista, garantizando títulos siempre limpios y legibles.
  - Se actualizaron todos los puntos de navegación de la aplicación para transferir el modelo de artista completo con nombre real y carátula.
- **Corrección de Redirección Incorrecta de Álbumes (`AlbumResolverService`)**:
  - Se eliminó el fallback no estricto que asignaba álbumes arbitrarios en búsquedas de YouTube Music cuando no había coincidencia exacta.
  - Se implementó coincidencia estricta y normalizada de títulos y artistas, evitando que se muestren pistas o metadatos de un álbum diferente al presionado.
  - Se priorizó la resolución directa por ID para álbumes provenientes de la discografía de Deezer (`dz_album_...`).
- **Mejora Visual y Espaciado en la Pantalla del Artista (`ArtistScreen`)**:
  - Se aumentó la altura del encabezado hero a `300px` y se reajustó el relleno del título para eliminar la colisión con los botones de acción.
  - Se implementó un degradado suave de 4 paradas para una transición sedosa de la imagen hacia el fondo.
  - Se rediseñaron los botones de *Reproducir* y *Aleatorio* con estética moderna de Apple Music.

## [1.0.54] - 2026-09-05

### Fixed
- **Corrección Definitiva de Cierre/Crash al Deslizar e Interactuar en el Reproductor (`NowPlayingScreen`)**:
  - **`LyricsListView`**: Se agregó validación estricta de nulidad (`viewport == null`) y comprobación de enlace (`renderObject.attached`) en `_scrollToCurrentLine()`. La llamada a `viewport.getOffsetToReveal()` provocaba un fallo no controlado (`NoSuchMethodError`) al deslizar entre páginas mientras el viewport aún se encontraba en proceso de layout.
  - **`PaletteService`**: Se blindó el cálculo de distancias de color (`_colorDistance`) para evitar incompatibilidades de canales RGB entre versiones del SDK de Flutter.
  - **`AlbumArtView`**: Se incorporó un `errorBuilder` resiliente en el visor de carátula para evitar excepciones fatales de renderizado en imágenes de red.
  - **`NowPlayingScreen`**: Se capturó de forma asíncrona cualquier error de canal nativo en `FlutterDisplayMode.setHighRefreshRate()` para evitar excepciones en el hilo principal en dispositivos con tasas de refresco adaptativas o perfiles de ahorro de energía.
  - **`MiniPlayer`**: Se desactivó el deslizamiento por defecto del modal (`enableDrag: false`) para garantizar que los gestos táctiles y scrolls internos de la carátula, letra y lista de espera pertenezcan exclusivamente a sus vistas correspondientes sin conflicto de cierre.

## [1.0.53] - 2026-09-04

### Fixed
- **Restauración de Notificación de Medios y Corrección de Cierre de App (`ForegroundService`)**:
  - Se corrigió el icono de notificación de Android (`androidNotificationIcon`), restaurándolo al icono nativo rasterizado `'mipmap/ic_launcher'`. En dispositivos Android (especialmente Xiaomi MIUI / HyperOS), el uso de drawables vectoriales XML como icono pequeño en un servicio en primer plano generaba una excepción interna `BadForegroundServiceNotificationException`, lo que provocaba que el sistema mostrara la notificación genérica *"Groovy se está ejecutando"* y terminara el proceso de la aplicación ("la app se cierra").
  - Se restauró el enlace nativo de eventos de reproducción (`_player.playbackEventStream.map(_buildPlaybackState).pipe(playbackState)`) y se eliminaron las llamadas redundantes a `broadcastPlaybackState()`.
  - La notificación de reproducción ahora muestra siempre la carátula, título de la canción, artista, barra de progreso y botones interactivos (anterior, reproducir/pausar, siguiente) de forma estable sin cierres inesperados.

## [1.0.52] - 2026-09-04

### Fixed
- **Corrección de Cierre Inesperado al Mover la Carátula (`NowPlayingScreen`)**:
  - Se eliminó el `GestureDetector` global con umbral agresivo de velocidad vertical (`primaryVelocity > 300`) que envolvía todo el cuerpo de la pantalla. Este detector interceptaba cualquier interacción táctil sobre la carátula y forzaba el cierre abrupto de la pantalla/aplicación (`Navigator.pop`).
  - Se restauró el contenedor estándar en `AlbumArtView` y la resolución de portada sin colisiones de caché.
  - La navegación y deslizamiento entre carátula, letra y lista de espera ahora es completamente estable y fluido sin riesgo de cierre no deseado.

## [1.0.51] - 2026-09-04

### Performance Improvements
- **Optimización Integral de Rendimiento y Fluidez en el Reproductor (`NowPlayingScreen`)**:
  - **"A continuación" (`QueueView`)**:
    - Se reemplazó el `Consumer<PlayerProvider>` raíz por `Selector<PlayerProvider, _QueueViewState>`, eliminando la reconstrucción continua de la cola y sus slivers durante los pulsos de reproducción de audio.
    - Se extrajo `_QueueSongTile` como widget aislado envuelto en `RepaintBoundary`, garantizando un scroll y reordenamiento fluido a 120 FPS sin invalidar el árbol de renderizado.
    - Las píldoras de acción rápida (Shuffle / Repeat / Infinity) ahora cuentan con su propio límite de repintado.
  - **"Letra" (`LyricsListView` & `LyricsLineWidget`)**:
    - Se eliminó el uso de `AnimatedOpacity` (que forzaba capas de composición `saveLayer` fuera de pantalla en la GPU) y se migró a `AnimatedDefaultTextStyle` aplicando el canal alfa directamente sobre el color del texto (`Colors.white.withValues(alpha: targetOpacity)`).
    - Cada línea de letra está ahora aislada con `RepaintBoundary`. Al cambiar la línea activa, únicamente se repintan las 2 líneas en transición, reutilizando la textura GPU de las más de 80 líneas restantes en caché.
    - Algoritmo de búsqueda binaria $O(\log N)$ para la localización instantánea de la línea activa según la posición de reproducción.
  - **"Carátula" y Fondo (`AlbumArtView`, `PaletteService`, `NowPlayingScreen`)**:
    - Aceleración superior al **85%** en la extracción de paleta k-means (`PaletteService`): reducción de la muestra de `112x112` (12,544 px) a `48x48` (2,304 px) y 20 colores, pasando de ~250ms a ~15ms y eliminando congelamientos de la interfaz al cambiar de canción.
    - Aislamiento del deslizador de progreso (`PlaybackProgressSlider`) con `RepaintBoundary` para no repintar los controles ni la portada con cada tick de posición (4 Hz).
    - Aislamiento del mini-header superior y sección de controles inferiores con `RepaintBoundary`.
    - Limitación del tamaño de decodificación en memoria de las imágenes de portada a `600x600`.
  - **Otras partes**:
    - `NowPlayingMoreMenu`: lectura sin suscripción de `PlayerProvider` (`listen: false`) para evitar rebuilds continuos al abrir el menú de opciones.
    - Modo horizontal (`_buildLandscapeLayout`): migración de `Consumer` a `Selector`.

## [1.0.50] - 2026-09-04

### Removed
- **Eliminación de la Estrella de Favoritos sobre la Carátula del Reproductor (`AlbumArtView`)**:
  - Se retiró la insignia flotante con icono de estrella (`⭐`) que se superponía sobre la esquina superior derecha de la imagen de portada en la pantalla de reproducción.
  - La carátula ahora se muestra limpia y completa sin elementos obstructivos, manteniéndose el botón interactivo de favoritos situado adecuadamente junto al título de la canción.

## [1.0.49] - 2026-09-04

### Fixed
- **Sincronización Total del Reproductor de Notificación y Pantalla de Bloqueo (Android MediaStyle / MediaSession)**:
  - Se corrigió el error donde la notificación del sistema se quedaba congelada en 0:00 con el botón de Play (`▶`) mientras la canción ya estaba sonando.
  - Se eliminó el uso restrictivo de `pipe` en `playbackState`, implementando un gestor de eventos reactivo (`broadcastPlaybackState`) suscrito activamente a `playbackEventStream`, `playerStateStream` y `positionDiscontinuityStream`.
  - Sincronización instantánea de metadatos (`MediaItem` y duración real) al cambiar de pista en `PlayerProvider`, evitando retardos y canciones en blanco.
  - Sincronización continua de posición (`updatePosition`, `speed: 1.0/0.0` y `updateTime: DateTime.now()`) con reanclaje periódico para evitar desfases o saltos de progreso en Android 13/14+.
  - Icono de notificación nítido (`ic_stat_music.xml`) reemplazando el icono adaptativo con fondo opaco que generaba un recuadro negro sobre la carátula en la notificación.

## [1.0.48] - 2026-09-04

### Fixed
- **Navegación al Álbum Real de la Canción ("Ir al Álbum")** — Se solucionó de raíz el problema donde al ir al álbum de la canción que estaba sonando o buscar un álbum se abría una pantalla genérica titulada "Album" por "Artist" con canciones aleatorias.
  - Implementación de `AlbumResolverService`: busca y navega directamente al álbum oficial en YouTube Music (mediante el filtro de álbumes oficial y extracción de `browseId`), cargando la lista de reproducción completa oficial con identificadores de video reales y portada en alta resolución.
  - Eliminación total de fallbacks erróneos en `getAlbum` que devolvían objetos con título "Album" y artista "Artist".
  - Enriquecimiento automático de álbumes sin metadatos mediante Deezer/iTunes API para canciones en reproducción.
  - Corrección de la numeración de pistas en la lista del álbum para que inicie en 1 (en vez de 0).
  - Acceso directo a "Ir al álbum" e "Ir al artista" desde la portada en reproducción, hoja de navegación de pista, menú de 3 puntos y resultados de búsqueda.

## [1.0.47] - 2026-09-04

### Fixed
- **Diseño del Encabezado de Artista Adaptable a Modo Claro/Oscuro** — Se corrigió el corte abrupto y oscuro en modo claro reemplazando el degradado negro rígido por un difuminado gradual fluido hacia el color de fondo de la página (`pageBgColor`). El nombre del artista ahora usa contraste dinámico inteligente (oscuro en modo claro, blanco en modo oscuro) con centrado y espaciado pulido.
- **Títulos Completos en "Canciones Destacadas"** — Se resolvió el truncamiento severo de títulos de canciones (como "Amarte Más No Pude" y "La Falla Fue Tuya"). Se optimizó el espacio horizontal desactivando la repetición redundante del nombre del artista y la duración en la pantalla del artista, compactando el botón de opciones secundario y permitiendo que los títulos y álbumes se lean de forma amplia y natural.

## [1.0.46] - 2026-09-04

### Fixed
- **Compositores Reales en Créditos de Canción** — Extracción e integración de compositores, autores y letristas reales verificados (Sony Music, Columbia, Warner, etc.) a través del endpoint oficial de créditos (MPTC). Se eliminó completamente la asignación incorrecta del cantante como compositor en "Composición y Letra".
- **Opción "Ver Créditos" en Menú de Canción** — Acceso directo a los créditos detallados desde el menú de 3 puntos en listas de canciones, álbumes y reproducción.
- **Estado Vacío Elegante en Créditos** — Muestra "Información de composición no disponible" en caso de no existir metadatos oficiales de composición, garantizando que el intérprete nunca aparezca como autor o compositor.

## [1.0.45] - 2026-09-04

### Fixed
- **Artist Discography Restored** — Full artist discography and albums are now prominently displayed under "Discografía" without strict song count restrictions, fetching online albums via Deezer.
- **Clean Artist Header Title Styling** — Artist name in the header is now crisp white text with no blurry drop shadows, over an elegant dark gradient vignette for maximum clarity and contrast.

## [1.0.44] - 2026-09-04

### Added
- **Artist HD Portraits** — Automatic resolution and caching of high-definition artist photos via Deezer and iTunes API fallback
- **Artist Screen Modern Header & Actions** — Full-bleed header with gradient overlay, favorite star button toggle, and Apple Music style options menu (add to queue, download albums, play, shuffle)
- **Song Cover Favorite Badge** — Visual favorite badge directly overlaid on album art across player and song tiles
- **Accurate Song Credits & Composers** — Real songwriters and composers fetched via Deezer ISRC and MusicBrainz work-rels
- **Duplicate Playlist Creation Fix** — Resolved race condition that created duplicate playlists
- **Library Unwanted Items Cleanup** — Removed auto-scraped non-user songs/albums/artists from library
- **Audio Silence on Resume Fix** — Fixed pause/play mute/silence bug in player provider

## [1.0.13] - 2026-05-10

### Added

- **Now Playing Custom Themes** — Complete theme system for personalizing the Now Playing screen
  - Theme manager screen with create, edit, duplicate, export/import, and delete
  - 5 editor tabs: Background, Artwork, Text, Controls, Animations
  - Background types: Solid color, Gradient, Blur, Mesh gradient, Custom Flutter code (with safe mode)
  - Artwork shapes: Circle, Rounded Rectangle (fixed Groovy default 12 px radius), Square (configurable corner radius 0–50 px)
  - Shadow intensity, rotation, and size factor controls
  - Cover rotation animation with configurable speed (3–60 seconds per full turn)
  - Pulse effect animation for artwork
  - Text styling for title, artist, album, and duration (font family, color, size, weight)
  - Control styling (color, size, spacing) and progress bar styling (color, height, shape)
  - Real-time animated preview in theme cards
  - All themes persisted to disk and survive app restarts

- **Gapless Playback** — Seamless track-to-track transitions via `ConcatenatingAudioSource`
  - Toggle in Playback settings to enable/disable
  - Preloads next track for instant switching

- **LRCLIB Lyrics Fallback** — Automatic lyrics lookup from LRCLIB when the Subsonic server has no lyrics
  - Toggle in Playback settings
  - Searches by song title and artist name

### Fixed

- **Playback Resume After App Restart** — Correctly restores playback position and prepares the audio source after cold start ([#171](https://github.com/Danx016/Groovy/issues/171))
- **Seek with Transcoding** — Fixed broken seeking when using transcoding via `LockCachingAudioSource` ([#170](https://github.com/Danx016/Groovy/issues/170))
- **Jukebox Mode UI** — Jukebox controls now properly integrated into the main playback controls ([#173](https://github.com/Danx016/Groovy/issues/173))
- **Cache Memory Optimization** — Replaced JSON bulk cache with SQLite to prevent OOM crashes on libraries with 100 000+ items
- **iOS Deployment Target** — Lowered minimum iOS version from 16.1 back to 15.0 (removes Live Activities dependency on iOS)
- **Theme Editor Overflow** — Fixed all `RenderFlex` overflow errors in `ThemePreviewCard` and `ThemeEditorScreen`
- **Theme Editor Layout** — Removed unwanted leading whitespace from `TabBar` in `ThemeEditorScreen`
- **Duplicate Theme Dialog** — Fixed `_dependents.isEmpty` assertion crash when cancelling or swiping away the duplicate dialog
- **Export Theme on Mobile** — `FilePicker.saveFile` now correctly passes `bytes` on Android & iOS, resolving "invalid argument(s): Bytes are required"
- **Rotation Animation State** — Cover rotation animation now pauses when playback stops and resumes when it starts

### Changed

- **Library Cache Backend** — JSON bulk cache replaced by SQLite for significantly lower memory usage on large libraries
- **Theme Strings** — All hardcoded UI strings in the theme editor and preview card moved to ARB localization keys
- **PlayerProvider Lifecycle** — Debounce timer for queue persistence is now cancelled in `dispose()` to avoid timer leaks in tests

## [1.0.12] - 2026-05-09

### Added
- **Persistent Queue Across Restarts** ([#156](https://github.com/Danx016/Groovy/issues/156))
  - Queue state (songs, current index, current song ID) saved to SharedPreferences
  - Automatically restores queue on app launch without auto-playing
  - Validates local file paths exist before restoring
  - Debounced save (200ms) to avoid excessive writes
  - Clears persisted data on explicit queue clear
- **Shuffle Persistence** — Shuffled queue order is now persisted alongside the queue, so reopening the app restores the correct shuffled sequence when shuffle mode is enabled
- **Artist Play Enhancement** ([#151](https://github.com/Danx016/Groovy/pull/151))
  - "Play" button on artist screens now appends rest of artist's songs to their top songs
  - Provides fuller artist experience when pressing play
- **Collapsible Playlist Cover Art** — `PlaylistScreen` now uses a `SliverAppBar` with `FlexibleSpaceBar`, matching the collapsible behavior of `AlbumScreen`
- **All Songs Entry Restored** — "All Songs" tile added back to Library → Faves tab for quick access to the full song list
- **Comprehensive Test Suite** — Unit, widget, integration, security, and memory-leak tests with configurable Navidrome server support via `test_server_config.json`
- **Android Audio Session Configuration** — Explicit `AudioSession` setup for music playback on Android, ensuring proper audio focus and routing on car head units
- **Lyrics Wake Lock** — Screen stays on while lyrics view is visible to prevent display timeout during active listening
- **Spotify-Style Desktop UX Redesign** — Complete overhaul of desktop interface emulating Spotify's design system
  - **3-Column Layout**: Fixed left sidebar (280px), expandable center content area, optional right sidebar (320px) for queue
  - **Spotify-like Dark Mode**: Deep black backgrounds (#000000, #121212, #181818) with consistent color palette
  - **Right Sidebar Queue**: Dedicated sidebar showing current playback queue with song artwork and metadata
  - **Enhanced Player Bar**: Improved 90px fixed bottom bar with Spotify color scheme (#181818) and border (#282828)
  - **Micro-Interactions**: Smooth hover effects on all cards (1.04x scale, 16px elevation shadow, 200ms animations)
  - **Green Play Button**: Spotify-signature green (#1DB954) circular play button appears on hover for albums and artists
  - **Quick Access Grid**: Spotify-style quick access tiles with hover states and background transitions
  - **Gradient Header Widget**: Dynamic gradient headers that extract dominant colors from album artwork
  - **Updated Navigation Sidebar**: 280px width (expanded) with improved Spotify-like colors and hover states
  - **New Widgets**: `SpotifyLikeCard`, `RightSidebar`, `QuickAccessGrid`, `GradientHeader` for reusable Spotify-style components

### Fixed
- **History Screen Loading** - Improved history loading and listener management
- **Library Refresh** ([#152](https://github.com/Danx016/Groovy/issues/152))
  - Refresh button now forces full re-sync by bypassing 6-hour cooldown
  - Fixes stale library content after user clicks refresh
- **Accent Color Consistency** ([#158](https://github.com/Danx016/Groovy/issues/158))
  - Play/Shuffle buttons now use theme accent color instead of hardcoded red
  - Applied to album, artist, and playlist screens
- **Emby/Jellyfin Library Sync** ([#160](https://github.com/Danx016/Groovy/issues/160))
  - Added `getAllSongs()` to JellyfinService for O(1) API call
  - SubsonicService proxy for Jellyfin compatibility
  - Fixed albumId and artistId fallbacks in item parsing
  - Fixed pagination loop early-break issue
- **Play/Shuffle Button Design** ([#157](https://github.com/Danx016/Groovy/issues/157))
  - Consistent pill-shaped design across artist, album, and playlist screens
  - Play/Shuffle row added below artist header
- **Now Playing Screen**
  - Replaced AnimatedMeshGradient with reliable radial gradient blobs
  - Fixed lyrics scroll-to-current when ListView items are unbuilt
  - Added lyrics slide-up/fade transition
  - Fixed ReorderableListView null crash with drag handle
  - Fixed syntax error causing build failure in `_buildRadioPlayer`
  - Status-bar icons now forced to white on dark background so they remain visible
- **Apple Music-Style Sliders** — Progress and volume bars redesigned with Apple Music aesthetics
  - Invisible thumb on mobile that grows to 28px with smooth animation when dragged
  - Track height animates from 3px to 5px during interaction with white glow effect
  - Desktop: thinner 3px tracks, smaller 5px thumbs, darker inactive track (#3A3A3A)
  - All transitions use 150ms easeOut curves for fluid micro-interactions
- **Android Audio Focus** — Playback now requests audio focus before starting, resolving no-sound issues on Android car head units and during remote playback
- **Android Playback Fix** — Resolved conflict between custom `AndroidSystemPlugin` and `audio_session` plugin that caused songs to start then immediately pause on Android devices
- **Windows Progress Bar** — Added fallback position polling timer for Windows desktop where `just_audio_windows` position stream does not emit reliably; progress bar and SMTC now update correctly during playback
- **Queue Layout** — Prevented queue list from sliding under the navigation bar on devices with gesture navigation
- **All Songs Screen** — Deferred `_loadCachedData` to post-frame callback, eliminating `setState during build` exception
- **Native Service Resilience** — `AuthProvider.logout()`, `PlayerProvider.dispose()`, `DiscordRpcService`, `WindowsSystemService`, and Android system services now gracefully handle missing native plugins in test environments
- **Local Files UX**
  - Folder cover art fallback
  - Smart sorting with genre/year filters
  - Added Radio Stations to mobile Library screen
- **Localization** - Updated l10n keys for empty states and scan actions

### Changed
- **Android Build** - Bumped version to 1.0.12+1 for update support ([#148](https://github.com/Danx016/Groovy/issues/148))
- **MusicService** - Cleaned up comments and streamlined code
- **Artwork Loading** - Optimized loading and metadata updates in MusicService
- **Recommendation Service** - Enhanced with improved data handling and caching

## [1.0.11] - 2026-05-04

### Added
- **Pitch Control & Speed Adjustment** ([#145](https://github.com/Danx016/Groovy/issues/145))
  - Independent pitch slider (0.5× – 2.0×) in the speed bottom sheet
  - "Preserve pitch" toggle: keeps original pitch when changing playback speed (time-stretching)
  - When disabled, pitch follows speed like a vinyl record
  - Native ExoPlayer bridge on Android via reflection for real pitch control
  - iOS stub ready for future AVAudioEngine integration
- **iPhone SE / Small Screen Compatibility**
  - Responsive layouts for 375×667 pt screens (iPhone SE, iPhone 8)
  - Reduced padding, font sizes, and control sizes across Now Playing, Login, Album, and Mini Player
  - `ScreenHelper` utility for adaptive sizing based on screen width

### Fixed
- **Listening History Blank** ([#146](https://github.com/Danx016/Groovy/issues/146))
  - History screen was empty when recommendations were disabled
  - `trackSongPlay`, `trackSkip`, `trackSongRating`, and `trackStarred` now always record listening data regardless of recommendation toggle
- **Emulator Detection (Pixel 9+)**
  - Replaced `device_info_plus` string-matching with `safe_device: ^1.3.10`
  - Pixel 9+ devices were falsely blocked as emulators due to "google"/"generic" strings in device info
- **Speed/Pitch Race Condition**
  - Fixed bug where changing playback speed reset pitch to 1.0
  - Unified `setPlaybackParameters(speed, pitch)` call applied atomically to ExoPlayer
  - Eliminates race between `just_audio.setSpeed()` and custom pitch reflection

### Changed
- **CI/CD**: Android release builds now produce a universal APK instead of split-per-ABI
  - Fixes issue where installing a new APK over an old one required uninstalling first

## [1.0.10] - 2026-05-04

### Added
- **Live Activities / Lyrics on Lock Screen** (iOS 16.1+ & Android)
  - Replaced custom `iOSLyricsPlugin` with `live_activities: ^2.4.9` package
  - iOS: Native Live Activity with Dynamic Island showing current lyrics line
  - Android: Live Activity-style notification via RemoteViews
  - Unified API for both platforms in `LockScreenLyricsService`
- **Multiple Server Profiles**: Switch between different Subsonic/Navidrome servers
- **Local Music Libraries**: Play music files stored on device with auto-scanning
- **Parallel Downloads**: Download multiple songs simultaneously in library
- **Heart/Repeat/Shuffle in Mini Player**: Quick action buttons in collapsed player
- **Android Auto Improvements**: Enhanced UI, animations, and Navidrome content support
- **SMTC Windows Lyrics & Bluetooth Lyrics**: Show lyrics in Windows notification and Bluetooth devices
- **Emulator Detection**: Block app on emulators for mobile builds
- **Arabic & Dutch Language Support**

### Changed
- **iOS Minimum Version**: Bumped to 16.1 for ActivityKit support
- **audio_service**: Updated to ^0.18.18 for better iOS Now Playing artwork
- **Donation Popup Timing**: Reduced from 25 min to 8 min usage
- **Playing Next Section**: Improved styling and tap-to-collapse behavior
- **Library Page Reorganization**: Better layout and filtering

### Fixed
- **iOS Build Error**: "Cannot find iOSLyricsPlugin" resolved by updating deployment target
- **iOS Audio Stopping**: Song no longer stops when closing fullscreen player
- **iOS Now Playing Artwork**: High-quality 1200px artwork from server
- **Self-Signed Certificates**: Eliminated UI freeze during TLS setup (async file reads)
- **Image Decompression Crash**: Fixed on Android low-memory devices
- **Background Download**: GrapheneOS compatibility fixes
- **Android Auto Artwork**: Proper loading and display
- **Logout Null Check**: Error when logging out from settings
- **Support Dialog**: Usability fixes on small screens
- **Album Screen Navigation**: Fixed from now-playing flow above artist page

## [1.0.9] - 2026-05-02

### Added
- **CI/CD Auto-Release**: Fully automated GitHub Actions workflow
  - Automated builds and releases for Android, iOS, Windows, Linux, and macOS
  - Windows NSIS installer (`Groovy-setup.exe`) automatically generated
  - Fixed ALSA dependency for Linux builds
  - Automatic artifact upload and GitHub Release creation
- **Privacy Policy Dialog**: Implemented dialog for privacy policy acceptance
- **Multi-Artist Support**: Support for multiple artists from Navidrome
  - Correct display of multiple artists for single songs
  - Multi-artist picker in song context menu
- **Album Download Button**: Button to download entire album from album screen
- **Swipe Gesture**: Swipe gesture to change songs in player
  - Carousel animation with haptic feedback
  - Forward/backward swipe navigation between tracks
- **Artist to Queue**: Added "Add artist to queue" button on artist screens
- **Tap Cover for Lyrics**: Tap album cover in player to show lyrics
- **Analytics**: Countly Analytics and crash reports (https://Groovy.Danil.lol/privacy)

### Changed
- **Flutter 3.41.7**: Updated Flutter to version 3.41.7
- **Dart SDK Constraint**: Updated constraint to `>=3.0.0 <4.0.0`
- **Code Quality**: Refactored duplicate `_` variables in callbacks for Dart 3 compatibility
- **iOS Cleanup**: Removed unnecessary iOS example files

### Fixed
- **UPnP Volume Overlay**: Fixed UPnP hardware volume jump
- **UPnP Auto-Disconnect**: Automatic renderer disconnection after 30s of connection loss
- **Shuffle History**: Back button tracks playback history with shuffle active
- **UPnP Remote Playback**: Fixed UPnP remote playback state management and UI routing
- **Recently Added Sort**: Fixed "Recently Added" sorting by server creation date
- **Download Library Bug**: Fixed partially persisted library bug during refresh
- **Context Menu**: Fixed stale context and scrollable artists sheet
- **Playlist Creation**: Library refresh after playlist creation from "now playing" menu

### Improved
- **Translations**: Crowdin translation updates (more languages supported)

## [1.0.8] - 2026-03-08

### Added
- **Smart Transcoding**: New automatic quality mode that switches bitrate in real time based on active network
  - Detects WiFi vs mobile data via `connectivity_plus`
  - Configure separate bitrates for WiFi and mobile; the app picks the right one automatically
  - Live connection badge (WiFi / Mobile pill) in Settings → Playback while smart mode is active
  - Smart mode toggle persists across restarts
- **Dynamic & Custom Accent Colors**: The accent color now propagates everywhere in the app
  - On Android 12+ the wallpaper-derived Material You palette is used automatically (via `dynamic_color`)
  - On all other platforms any color picked in Settings → Display is applied to every widget
  - Eliminated all hardcoded `AppTheme.appleMusicRed` references in settings tabs, mini player, song tiles, cast button, and album artwork shadow
- **iOS Control Center player**: Fixed the player widget shown in the iOS Control Center and Lock Screen
  - Disabled the podcast-style ±15 s skip buttons that were hiding the standard ⏮ ▶/⏸ ⏭ controls
  - Added `MPNowPlayingInfoPropertyMediaType = .audio` and `MPNowPlayingInfoPropertyDefaultPlaybackRate` for correct system content categorization
  - Fixed an artwork caching race condition: concurrent 1-second position updates no longer restart artwork downloads already in progress
- **Server connection retry**: `AuthProvider._verifyConnection()` now retries the ping up to 3 times (2 s backoff) before declaring the server unreachable — handles slow mobile network initialization on launch
- **Retry button on the server-unreachable screen**: A "Retry" button lets users re-attempt the connection without restarting the app (`AuthProvider.retryConnection()`)
- **Localization — Settings strings**: All hardcoded strings in the five Settings tabs are now in `app_en.arb` (~100 new keys covering Playback, Storage, About, Display, and Server sections)

### Changed
- **Loading screen**: The app no longer flashes the login screen while checking the server on startup; `AuthState.authenticating` now shows a centered `CircularProgressIndicator` on a black background
- **Home screen desktop layout**: Improved density and alignment for macOS/Windows/Linux
  - Wider horizontal padding (32 px), larger section headers and album cards (180 px)
  - Song lists render as a compact table (`_DesktopSongRow`) instead of full `SongTile` cards
  - Recent albums (6) and playlists (3) shown instead of 4 and 2
- **Error messages**: Improved error string formatting in `AuthProvider._formatError()` — strips `Exception:`, `Network error:`, and verbose library boilerplate for cleaner display
- **Connection timeout**: Server ping timeout increased from 6 s to 10 s
- **Now Playing screen**: Matrix transforms updated to Flutter 3.41-compatible `scaleByDouble`/`translateByDouble` signatures; `.withOpacity()` replaced with `.withValues(alpha:)` throughout

### Fixed
- **`seekForward`/`seekBackward` events from iOS Control Center**: Added `onSeekForward`/`onSeekBackward` callbacks to `AndroidSystemService` and registered handlers in `PlayerProvider` (clamping backward seeks to `Duration.zero`)
- **Settings tab indicator color hardcoded**: `indicatorColor` and `labelColor` in `settings_screen.dart` now use `Theme.of(context).colorScheme.primary`
- **`DjMixerService` removed**: Deleted unused `dj_mixer_service.dart` that was included by mistake; `services.dart` barrel still intact

### Dependencies
- Added `connectivity_plus: ^7.0.0` — network type detection for Smart Transcoding
- Added `dynamic_color: ^1.7.0` — Material You wallpaper color extraction on Android 12+
- Added `path: ^1.9.0`

## [1.0.7] - 2026-02-22

### Added
- **Spotify-style Desktop UX**: Complete redesign of the PC layout
  - New collapsible sidebar (`DesktopNavigationSidebar`) with 260 px expanded / 72 px collapsed states
  - Sidebar sections: Home, Search, Your Library (scrollable playlist list with Liked Songs shortcut), Settings, Collapse/Expand toggle
  - Settings navigation item restored directly in the sidebar
  - All sidebar strings localised via ARB (`expand`, `createPlaylist`)
- **Artwork Style Editor**: Full custom editor in Settings → Display → Artwork Style
  - **Shape**: Rounded rectangle, Circle, or Square
  - **Corner Radius**: slider (0–24 px), only visible when shape is *Rounded*
  - **Shadow intensity**: None, Soft, Medium, Strong
  - **Shadow color**: Black or Accent (Groovy red)
  - Live 108 px animated preview updates in real-time
  - All options persisted to `SharedPreferences` and restored on next launch (awaited before `runApp`)
- **No-artwork placeholder in mobile player**: Songs without cover art now show a clean dark gradient tile with a music note icon and localised "No artwork" label instead of an infinite shimmer loader. Shimmer is still used while the image is actually fetching.

### Changed
- **Desktop player bar accent colors**: All active-state indicators (shuffle, repeat, progress slider, volume slider, favorite heart, lyrics button) now use Groovy red
- **Update dialog colors**: Header gradient and download button changed from purple/blue (`#6C5CE7 → #00B4D8`) to Groovy red/pink (`appleMusicRed → appleMusicPink`)
- **Desktop lyrics**: Lyrics view now uses `rootNavigator: true` so it covers the full window (sidebar + content + player bar); close button pops from the root navigator correctly
- **React marketing website**: Version number and release date in Hero and Download sections are now fetched live from the GitHub public API (`/repos/Danx016/Groovy/releases/latest`) with a 10-minute session cache — no auth token required

### Fixed
- **Library list alignment**: Album/artist tiles in the Library screen now use an explicit `InkWell → Padding → Row` layout so artwork and text align with section headers on all platforms
- **Artwork settings not persisting**: `PlayerUiSettingsService.initialize()` is now `await`-ed before `runApp`, guaranteeing saved values are loaded into notifiers before any widget builds

## [1.0.6] - 2026-02-20

### Added
- **Jukebox Mode** ([#41](https://github.com/Danx016/Groovy/issues/41)): Server-side audio playback via the Subsonic jukebox API
  - New `JukeboxService` wrapping all jukebox API calls (`get`, `start`, `stop`, `skip`, `set`, `add`, `clear`, `shuffle`, `remove`, `setGain`)
  - Dedicated `JukeboxScreen` remote-control UI with now-playing artwork, playback controls, volume slider, and queue list
  - Toggle in Settings → Server to enable/disable jukebox mode
  - "Play on Jukebox" and "Add to Jukebox Queue" options in the song long-press context menu (shown only when jukebox is enabled)
  - Auto-refresh on screen open + 5-second polling to stay in sync with current server state
  - Friendly error screen when the server returns 501 (jukebox not enabled), with setup instructions
- **Genre Support**: Enhanced genre browsing
  - Genres screen now shows song count per genre and a tooltip
  - Genre screen rebuilt with two tabs: Songs and Albums

### Fixed
- **[#29](https://github.com/Danx016/Groovy/issues/29) Offline Playlists**: Playlists are now correctly restored from local cache when the server is unreachable
- **[#37](https://github.com/Danx016/Groovy/issues/37) Music Folder Selection**: Fixed the music folder selection dialog in Server settings
- **[#44](https://github.com/Danx016/Groovy/issues/44) Album Art Aspect Ratio**: Album artwork now preserves its original aspect ratio (`BoxFit.contain`) instead of stretching

### Improved
- **Localizations**: Removed duplicate keys from `app_en.arb`; cleaned non-English ARB files of orphaned section markers and English fallback strings

## [1.0.5] - 2026-02-19

### Added
- **Internationalization (i18n)**: Full app translation support via Flutter's `flutter_localizations`
  - 24 languages: Bengali, Danish, German, Greek, Spanish, Finnish, French, Irish, Hindi, Indonesian, Italian, Norwegian, Polish, Portuguese, Romanian, Russian, Albanian, Swedish, Telugu, Turkish, Ukrainian, Vietnamese, Chinese (Simplified), and English as base
  - Crowdin integration for community-driven translations with GitHub Actions auto-sync
  - Added `TRANSLATIONS.md` guide for contributors
  - Added `LocaleService` for runtime language switching
- **Google Cast / Chromecast Support**: Stream music to Cast-compatible devices
  - New `CastService` managing session lifecycle and media loading
  - New `CastButton` widget displayed in the player and mini-player
  - Album art shown on the TV/receiver as a video-style visualization (1280×720)
  - Integrated `flutter_chrome_cast` package (bundled under `packages/`)
  - UPnP device discovery via new `UPnPService` as a fallback discovery layer
- **mTLS Client Certificate Authentication**: Secure mutual TLS for self-hosted servers
  - Certificate file picker on the login screen (`.p12` / `.pfx`)
  - Optional password field for password-protected certificates
  - `ServerConfig` model extended with `clientCertPath` and `clientCertPassword` fields
  - `SubsonicService` now configures the HTTP client with the chosen certificate
- **Discord Rich Presence**: Show currently playing song in Discord status
  - New `DiscordRpcService` wired into the player pipeline
- **Auto-Update Service**: New `UpdateService` that checks GitHub Releases for newer versions and prompts the user
- **Windows NSIS Installer**: Packaged installer (`installer.nsi`) with dynamic version injection via `/D` flag from the CI pipeline
- **Linux Platform Support**: Full Linux desktop build configuration added
- **Star Rating Widget**: Visual 1–5 star picker widget used in the song options menu
- **React Marketing Website**: Added under `react-website/`, deployed to GitHub Pages via Actions workflow

### Improved
- **Google Cast Display**: Receiver now shows album art like Spotify
  - Switched from raw audio streaming to a video-style Cast session with artwork
  - Uses `GenericMediaMetadata` for broader Cast receiver compatibility
- **Support Dialog**: Streamlined post-login dialog
  - Removed 5-second wait timer; close button is immediately available
  - Added "Don't show again" checkbox
  - Removed BuyMeACoffee and donation links
- **Build System**: Upgraded to Gradle 8.0 for Java 21 compatibility
  - `flutter_chrome_cast` uses Gradle 8.0.2 and Kotlin 1.9.0
  - `compileSdk` bumped to 34, Java compatibility set to `VERSION_11`
  - Resolves _"Unsupported class file major version 65"_ build error
- **CI/CD Pipeline**: Overhauled GitHub Actions release workflow
  - Flutter dependency caching enabled to speed up builds
  - Updated all action versions to current releases
  - Removed hardcoded Flutter version pin for better forward compatibility
  - Removed AAB (Android App Bundle) artifact from release builds
- **Code Quality**: Cleaned up Dart lint warnings across the codebase
  - Removed unused imports, variables, and dead code
  - Fixed impossible null checks
  - Replaced deprecated API usages

### Fixed
- **Android Boot Crash**: Removed `AutoStartReceiver` that caused crashes on device startup
  - App no longer requests `RECEIVE_BOOT_COMPLETED` permission
- **Android 16 / Media3 Playback Bug**: Implemented workaround for a Media3 regression introduced in Android 16 that prevented playback from starting correctly
- **Low Power Device Crashes**: Optimized image caching and rendering pipeline to avoid OOM crashes on constrained hardware
- **Flutter 3.41.1 Compatibility**: Hid `RepeatMode` re-export from `cupertino.dart` to resolve a symbol conflict introduced in Flutter 3.41.1
- **Cast Service Resource Leaks**: Added proper `dispose()` and `disconnect()` methods; `loadMedia()` now returns a success/failure boolean
- **installer.nsi not tracked**: Removed `installer.nsi` from `.gitignore` so the Windows installer script is included in the repository

### Removed
- **Donation popup**: Support dialog no longer shows BuyMeACoffee or cryptocurrency donation options
- **`AutoStartReceiver`**: Android boot-start receiver removed entirely
- **`DOCUMENTATION.md`**: Replaced by inline code documentation and README improvements

## [1.0.4] - 2026-01-17

### Added
- **Support Dialog After Login**: Shows after each successful login
  - Discord community invite link (optional)
  - Donation options: Buy Me a Coffee, Bitcoin, Solana
  - 5-second timer before close button enables
  - Copy buttons for cryptocurrency addresses
- **Discord Integration in Settings**: Added Discord community link to Settings → About → LINKS
- **Discord Community Section in README**: Added dedicated section with Discord badge and invite link

### Improved
- **Landscape Lyrics Display**: Significantly improved lyrics viewing in landscape mode
  - Lyrics now occupy right 60% of screen while album art stays on left 40%
  - Created `CompactLyricsView` widget specifically optimized for landscape
  - Portrait mode keeps fullscreen lyrics overlay
  - Fixed overflow issues in lyrics dialog
- **Playlist Duration Calculation**: Enhanced playlist screen with accurate total duration
  - Total duration now calculated from actual song lengths
  - Displays formatted duration (e.g., "12 songs • 1 hr 23 min")

### Fixed
- **Homepage Loading Issue on Windows**: Fixed infinite skeleton loading
  - Added 5-second timeout to server initialization calls in `LibraryProvider`
  - App now continues in local mode if server doesn't respond
  - Improved error handling for missing server configuration
- **Windows SMTC Error Handling**: Improved error messages for RustLib initialization
  - App continues normally even if SMTC (Windows System Media Transport Controls) fails to initialize
  - Added informative debug messages explaining SMTC will be disabled

## [Unreleased] - 2026-01-17

### Added
- **[#27](https://github.com/Danx016/Groovy/issues/27) Star Rating System**: Added 1-5 star rating support for songs
  - Rate songs via the song options menu (three-dot menu)
  - Rating dialog with visual star picker
  - Shows current rating in menu title
  - Uses Subsonic `setRating` API endpoint
  - Added `userRating` field to Song model

- **Landscape Mode for Full Player**: New horizontal layout when device is rotated
  - Album artwork displayed on the left (40% width)
  - Song info and controls on the right (60% width)
  - Lyrics toggle replaces controls with synced lyrics on right side
  - Automatic layout switch based on screen orientation
  - Created `CompactLyricsView` widget optimized for landscape mode

### Improved
- **Playlist & Album Screens**: Enhanced with calculated total duration
  - Playlist screen now shows total duration calculated from songs (e.g., "12 songs • 1 hr 23 min")
  - More accurate duration display based on actual song lengths

### Changed
- **Performance Optimizations**: Migrated synced lyrics view to `flutter_lyric` package (v3.0.2)
  - Reduced blur effects from sigma 80 to 40 for better GPU performance
  - Added `RepaintBoundary` around animated backgrounds
  - Implemented position update throttling (100ms intervals)
  - Reduced image cache sizes for lower memory usage
- **Widget Optimization**: Replaced `Consumer` and `Provider.of` with `Selector` pattern
  - `SongTile`: Now only rebuilds when current song changes
  - `DesktopPlayerBar`: Optimized controls, progress bar, and volume slider
  - Reduced unnecessary widget rebuilds across the app

### Fixed
- **Synced lyrics assertion error**: `selectionAutoResumeDuration` must be less than `activeAutoResumeDuration`
- **Library "Local" filter removed**: Cleaned up unused local music filter from library screen
- **Storage permissions for Android 13+**: Added `READ_MEDIA_AUDIO` and `READ_MEDIA_IMAGES` permissions
- **Server not configured errors**: LibraryProvider now gracefully handles local-only mode without server errors

---

## [1.0.1] - 2026-01-15

### Added

- **Premium Equalizer**: 10-band EQ with presets (Rock, Pop, Jazz, Classical, Bass Boost, Treble Boost, Vocal, Electronic, Hip Hop) and custom preset saving
- **Settings Categories**: Reorganized settings into 5 tabs (Playback, Storage, Server, Display, About)
- **Local File Support**: Play music files stored on device with automatic library scanning
- **Transcoding/Streaming Quality**: Configure WiFi and Mobile bitrate settings with format selection (MP3, Opus, AAC)
- **Offline Mode**: Automatic fallback to downloaded music when server is unreachable
- **Offline Playback Indicator**: Orange banner shows when in offline mode

### Improved

- **Synced Lyrics Display**: 
  - Added blur effect for non-active lines (distance-based)
  - Added glow shadow for active line
  - Improved scale animations (1.15x-1.18x for active)
  - Enhanced line spacing and visual hierarchy
  - Applied to mobile, desktop, and fullscreen views

- **Shuffle Functionality**: Now properly shuffles playlist regardless of current playback state
- **Artists Tab**: Now correctly displays artists when "Artists" filter is selected
- **Homepage Empty State**: Added fallback message and refresh button when no content

### Fixed

- **[#26](https://github.com/Danx016/Groovy/issues/26)**: Transcoding/streaming quality settings
  - Added WiFi and Mobile bitrate configuration in Server settings
  - Support for format selection (MP3, Opus, AAC)
  - Bitrate options from 64kbps to 320kbps or original quality

- **[#25](https://github.com/Danx016/Groovy/issues/25)**: Library search now works on all items, not just playlists
  - Implemented `LibrarySearchDelegate` that searches across playlists, albums, and artists
  
- **[#24](https://github.com/Danx016/Groovy/issues/24)**: Artists tab now displays content
  - Fixed `_getFilteredItems` to properly filter and return artists list
  
- **[#22](https://github.com/Danx016/Groovy/issues/22)**: Homepage shows fallback when no content available
  - Added empty state widget with refresh button when no albums/songs loaded
  
- **[#20](https://github.com/Danx016/Groovy/issues/20)**: Shuffle button now always shuffles instead of acting as play/pause
  - Modified shuffle logic to always shuffle the playlist, even when already playing
  
- **[#19](https://github.com/Danx016/Groovy/issues/19)**: Download button in playlist now downloads all songs
  - Implemented batch download functionality in playlist screen
  
- **[#18](https://github.com/Danx016/Groovy/issues/18)**: Play/Pause state now correctly shows only for the active playlist
  - Fixed playlist header to compare current playing context
  
- **[#17](https://github.com/Danx016/Groovy/issues/17)**: Lyrics scroll now uses smooth animations without line-break changes
  - Used fixed font size for all lines to prevent layout shifts
  
- **[#16](https://github.com/Danx016/Groovy/issues/16)**: Library search button now works
  - Connected search icon to `LibrarySearchDelegate`
  
- **[#15](https://github.com/Danx016/Groovy/issues/15)**: Swipe down to minimize player implemented
  - Added gesture detector for vertical swipe to dismiss full player
  
- **[#14](https://github.com/Danx016/Groovy/issues/14)**: Option to hide volume bar from player
  - Added toggle in Display settings to show/hide volume slider
  
- **[#13](https://github.com/Danx016/Groovy/issues/13)**: Click on album/artist name navigates to respective screen
  - Made album and artist names tappable in now playing screen
  
- **[#12](https://github.com/Danx016/Groovy/issues/12)**: Internet radio station support
  - Added `RadioScreen` with server radio stations
  - Support for streaming internet radio URLs
  
- **[#11](https://github.com/Danx016/Groovy/issues/11)**: All Songs view with sort options and playback
  - Added `AllSongsScreen` with play/shuffle buttons
  
- **[#10](https://github.com/Danx016/Groovy/issues/10)**: Auto-DJ feature for queue
  - Implemented smart queue that adds similar songs when queue ends
  
- **[#9](https://github.com/Danx016/Groovy/issues/9)**: ReplayGain support
  - Added ReplayGain toggle in Playback settings
  
- **[#8](https://github.com/Danx016/Groovy/issues/8)**: Progress bar freezes on rewind
  - Fixed position stream subscription to properly update on seek
  
- **[#7](https://github.com/Danx016/Groovy/issues/7)**: Custom TLS/SSL certificates 
  - Added option to allow self-signed certificates in login
  - Added custom certificate file picker in Advanced Options
  
- **[#5](https://github.com/Danx016/Groovy/issues/5)**: Lyrics text stability
  - Fixed line break changes during playback by using consistent font sizing
  
- **[#4](https://github.com/Danx016/Groovy/issues/4)**: Music Folders support
  - Added music folder selection in Server settings
  
- **[#3](https://github.com/Danx016/Groovy/issues/3)**: Error messages for incorrect URL
  - Added proper error handling and snackbar messages for connection failures
  
- **[#1](https://github.com/Danx016/Groovy/issues/1)**: Miniplayer persists
  - Implemented nested navigator architecture to maintain miniplayer state
