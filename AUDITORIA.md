# 📋 Auditoría Técnica y Arquitectura del Sistema - Groovy

Documento técnico detallado que describe la arquitectura completa, el funcionamiento interno, las tecnologías utilizadas, la integración de APIs de audio, el sistema de sincronización entre dispositivos (**Groovy Connect**) y la infraestructura de backend del proyecto **Groovy**.

---

## 📌 Tabla de Contenidos

1. [Resumen Ejecutivo y Ficha Técnica](#1-resumen-ejecutivo-y-ficha-técnica)
2. [Arquitectura General del Sistema](#2-arquitectura-general-del-sistema)
3. [Auditoría del Frontend (Flutter & Dart)](#3-auditoría-del-frontend-flutter--dart)
   - [¿Cómo funciona Flutter en Groovy?](#31-cómo-funciona-flutter-en-groovy)
   - [Gestión de Estado Reactiva (Provider)](#32-gestión-de-estado-reactiva-provider)
   - [Motor y Pipeline de Audio](#33-motor-y-pipeline-de-audio)
   - [Base de Datos Local y Caché Offline](#34-base-de-datos-local-y-caché-offline)
   - [Diseño y Componentes de la Interfaz (UI/UX)](#35-diseño-y-componentes-de-la-interfaz-uiux)
4. [Extracción y Streaming de Música](#4-extracción-y-streaming-de-música)
   - [Resolución de Pistas y Streams](#41-resolución-de-pistas-y-streams)
   - [Proxy de Audio Anti-403 (`_YoutubeStreamAudioSource`)](#42-proxy-de-audio-anti-403-_youtubestreamaudiosource)
   - [Letras Sincronizadas en Tiempo Real (LRCLIB)](#43-letras-sincronizadas-en-tiempo-real-lrclib)
5. [Groovy Connect: Conexión y Control Entre Dispositivos](#5-groovy-connect-conexión-y-control-entre-dispositivos)
   - [Descubrimiento en Red Local (LAN)](#51-descubrimiento-en-red-local-lan)
   - [Servidor HTTP Local de Comandos](#52-servidor-http-local-de-comandos)
   - [Transferencia de Sesión y Control Remoto](#53-transferencia-de-sesión-y-control-remoto)
   - [Respaldo en la Nube (Cloud Relay)](#54-respaldo-en-la-nube-cloud-relay)
6. [Auditoría del Backend (Node.js & MySQL)](#6-auditoría-del-backend-nodejs--mysql)
   - [Esquema de Base de Datos](#61-esquema-de-base-de-datos)
   - [Seguridad y Control de Acceso](#62-seguridad-y-control-de-acceso)
   - [Endpoints de la API](#63-endpoints-de-la-api)
7. [Cliente Web SPA (React & Vite)](#7-cliente-web-spa-react--vite)
8. [Diagnóstico Técnico: Fortalezas, Riesgos y Recomendaciones](#8-diagnóstico-técnico-fortalezas-riesgos-y-recomendaciones)

---

## 1. Resumen Ejecutivo y Ficha Técnica

* **Nombre del Proyecto:** Groovy
* **Versión:** 1.1.9
* **Propósito:** Reproductor y plataforma de streaming de música moderno, multiplataforma y sin anuncios, con una interfaz inspirada en la elegancia de *Apple Music*.
* **Plataformas Soportadas:** Android (APK + Android Auto), Windows, macOS, Linux, iOS y Web.
* **Stack Tecnológico:**
  * **Móvil y Escritorio:** Flutter SDK, Dart.
  * **Web Client:** React 18, Vite, Tailwind CSS.
  * **Servidor Backend:** Node.js, Express, MySQL 8.0, Docker, Nginx.
  * **Reproducción de Audio:** `just_audio`, `audio_service`, `libmpv` (`media_kit`).
  * **Extracción de Audio:** `youtube_explode_dart`, `yt-dlp`.
  * **Letras:** LRCLIB API.

---

## 2. Arquitectura General del Sistema

El ecosistema opera mediante una estructura desacoplada de 5 capas:

```
┌────────────────────────────────────────────────────────┐
│                   INTERFAZ DE USUARIO                  │
│       Flutter UI (Móvil / Desktop)  /  React (Web)     │
└───────────┬────────────────────────────────┬───────────┘
            │                                │
            ▼                                ▼
┌──────────────────────┐        ┌────────────────────────┐
│ GESTIÓN DE ESTADO    │        │ MOTOR DE AUDIO         │
│ Provider:            │◄──────►│ just_audio + libmpv    │
│ Player / Library     │        │ audio_service (BG/Auto)│
└───────────┬──────────┘        └────────────▲───────────┘
            │                                │
            ▼                                │
┌────────────────────────────────────────┐   │
│ STREAMING Y EXTRACCIÓN                 │   │
│ YoutubeService + Proxy Anti-403        ├───┘
│ yt-dlp + LRCLIB (Letras)               │
└───────────┬────────────────────────────┘
            │
    ┌───────┴────────────────────────┐
    ▼                                ▼
┌──────────────────────┐  ┌──────────────────────────────┐
│ GROOVY CONNECT       │  │ GROOVY CLOUD API             │
│ UDP Broadcast :42424 │  │ Node.js / Express :4000      │
│ HTTP Server   :42425 │  │ Base de datos MySQL          │
└──────────────────────┘  └──────────────────────────────┘
```

---

## 3. Auditoría del Frontend (Flutter & Dart)

### 3.1. ¿Cómo funciona Flutter en Groovy?
Flutter no utiliza los componentes de vista tradicionales del sistema operativo. En su lugar:
1. **Renderizado Directo:** Emplea su propio motor gráfico (Impeller / Skia) para dibujar en un lienzo de la GPU a 60 o 120 fotogramas por segundo.
2. **Árbol de Widgets:** Toda la interfaz está compuesta por widgets declarativos. Cuando el estado del reproductor cambia (por ejemplo, el milisegundo de la canción), solo se redibujan los widgets suscritos al cambio (como el slider de progreso).
3. **Plataforma Nativa:** Mediante Platform Channels y FFI (`dart:ffi`), se comunica con librerías en C/C++ (`libmpv`, `sqlite3`) y APIs del sistema operativo (pantalla de bloqueo, barra de tareas de Windows).

### 3.2. Gestión de Estado Reactiva (Provider)
Ubicado en `lib/providers/`:
* **`PlayerProvider` (`lib/providers/player_provider.dart`):**
  * Controla la canción activa (`Song? _currentSong`), la cola de reproducción (`List<Song> _queue`), el índice, modos de repetición y mezcla aleatoria inteligente con memoria histórica para evitar repetir pistas.
  * Integra servicios como `AutoDjService` (añade pistas similares cuando la cola termina) y `ReplayGainService` (normalización de sonoridad).
* **`LibraryProvider` (`lib/providers/library_provider.dart`):**
  * Administra listas de reproducción, favoritos y álbumes con persistencia doble (local en SQLite y remota en la nube).
* **`AuthProvider` (`lib/providers/auth_provider.dart`):**
  * Maneja el token JWT, autenticación con Google y sesiones de usuario con almacenamiento seguro en `flutter_secure_storage`.

### 3.3. Motor y Pipeline de Audio
* **Móviles (Android):** Se coordina con `audio_service` a través de un servicio Foreground en segundo plano. Esto previene que el sistema operativo mate el proceso cuando la pantalla se apaga, y mantiene actualizados los controles en la pantalla de bloqueo y en la consola de **Android Auto**.
* **Escritorio (Windows & Linux):** Utiliza `just_audio_media_kit` enlazado contra las librerías nativas de **`libmpv`** (`libmpv-2.dll`). Esto proporciona decodificación nativa acelerada por hardware, eliminando cortes o retrasos comunes en entornos de escritorio.

### 3.4. Base de Datos Local y Caché Offline
* **SQLite (`lib/services/library_database_service.dart`):** Gestiona la biblioteca local, cachés de búsquedas y metadatos.
* **`AudioCacheService`:** Descarga y almacena en disco los fragmentos de audio escuchados recientemente para permitir la reproducción inmediata de canciones frecuentes sin gastar datos.

### 3.5. Diseño y Componentes de la Interfaz (UI/UX)
* **Colores Adaptativos:** Con `palette_generator`, al reproducir una canción la app detecta los colores primarios de la carátula y tiñe dinámicamente el fondo con degradados suaves ([`blurred_gradient_background.dart`](lib/widgets/blurred_gradient_background.dart)).
* **Modo Escritorio:** Barra lateral de navegación completa y barra inferior dedicada con deslizador de volumen ([`desktop_player_bar.dart`](lib/widgets/desktop_player_bar.dart)).
* **Modo Móvil:** Mini-reproductor interactivo persistente ([`mini_player.dart`](lib/widgets/mini_player.dart)) y pantalla Now Playing expandible ([`now_playing_screen.dart`](lib/screens/now_playing_screen.dart)).

---

## 4. Extracción y Streaming de Música

### 4.1. Resolución de Pistas y Streams
Groovy no aloja pistas de audio piratas en sus servidores; en su lugar, resuelve y transmite audio en tiempo real:
* **`youtube_service.dart`:** Utiliza `youtube_explode_dart` para la búsqueda instantánea de canciones, álbumes y artistas.
* **`ytdlp_service.dart`:** Invoca el motor nativo `yt-dlp` como mecanismo de fallback resistente para extraer URLs de audio de alta fidelidad (Opus/WebM a 160kbps o AAC a 128kbps).

### 4.2. Proxy de Audio Anti-403 (`_YoutubeStreamAudioSource`)
* **Problema:** Los servidores de Google aplican protecciones anti-scraping. Si ExoPlayer solicita un stream directamente, recibe un error `HTTP 403 Forbidden` por incompatibilidad de cabeceras o IP.
* **Solución de Groovy:** Se implementa un proxy interno en Dart:
  ```dart
  class _YoutubeStreamAudioSource extends StreamAudioSource {
    @override
    Future<StreamAudioResponse> request([int? start, int? end]) async {
      final streamInfo = await _ytdlp.resolveStreamInfo(_videoId);
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(streamInfo.url));
      if (start != null) request.headers.add('Range', 'bytes=$start-${end ?? ""}');
      final response = await request.close();
      return StreamAudioResponse(range: ..., source: response, contentType: 'audio/webm');
    }
  }
  ```
  Esto garantiza que cada paquete de audio sea solicitado con cabeceras de navegación válidas antes de entregarlo al reproductor.

### 4.3. Letras Sincronizadas en Tiempo Real (LRCLIB)
* Integrado en `lib/services/lrclib_service.dart`.
* Se conecta a la API de **LRCLIB** (`https://lrclib.net/api/get`) enviando título, artista, álbum y duración.
* El archivo `lrc_ttml_parser.dart` procesa los tiempos milimétricos y el widget de letras anima la tipografía sincronizada con la pista estilo karaoke.

---

## 5. Groovy Connect: Conexión y Control Entre Dispositivos

Ubicado en [`lib/services/groovy_connect_service.dart`](lib/services/groovy_connect_service.dart), este módulo implementa un protocolo híbrido LAN + Nube:

```
[ Dispositivo Móvil ] ◄── UDP Broadcast (42424) ──► [ PC Windows ]
         │                                                 │
         │════════ HTTP Local Server (Puerto 42425) ═══════│
         ▼                                                 ▼
   ┌─────────────────────────────────────────────────────────────┐
   │             Servidor Nube / API (device_commands)           │
   └─────────────────────────────────────────────────────────────┘
```

### 5.1. Descubrimiento en Red Local (LAN)
* **UDP Broadcast (Puerto 42424):** Cada cliente transmite paquetes periódicos notificando su ID único, nombre, plataforma y modelo en la misma red Wi-Fi.

### 5.2. Servidor HTTP Local de Comandos (Puerto 42425)
* Cada dispositivo ejecuta en segundo plano un servidor `HttpServer`.
* **Rutas locales:**
  * `GET /groovy/info`: Retorna el estado del dispositivo (canción sonando, volumen, posición actual).
  * `POST /groovy/command`: Recibe acciones de control remoto en JSON (`{"action": "pause"}`, `{"action": "seek", "value": 45000}`).
  * `POST /groovy/transfer`: Transfiere la sesión activa completa.

### 5.3. Transferencia de Sesión y Control Remoto
Permite transferir una sesión entre tu móvil y tu ordenador con cero pérdida de continuidad:
* El dispositivo emisor envía el objeto de la canción, el milisegundo exacto y la lista completa en cola.
* El dispositivo receptor inicia la pista en ese segundo y el emisor detiene su reproducción local.

### 5.4. Respaldo en la Nube (Cloud Relay)
Si los dispositivos están en redes distintas (por ejemplo, el móvil con datos móviles 5G y el ordenador en casa), el sistema conmuta a la tabla `device_commands` del servidor central mediante peticiones periódicas de sondeo (*polling*).

---

## 6. Auditoría del Backend (Node.js & MySQL)

El backend en `groovy-backend/` está construido sobre **Express** y **MySQL 8.0**.

### 6.1. Esquema de Base de Datos (`database.js`)
Ejecuta migraciones automáticas al iniciar creando las siguientes 7 tablas:
1. **`users`**: Identificador, nombre, correo, hash de contraseña (`bcrypt`), avatar, rol y fecha de registro.
2. **`user_sessions`**: Registro de sesiones, IPs, navegadores y plataformas.
3. **`favorites`**: Pistas favoritas asociadas a cada usuario.
4. **`playlists`** y **`playlist_songs`**: Listas personalizadas con orden y posición de pistas.
5. **`playback_history`**: Historial de reproducción con métricas de tiempo escuchado.
6. **`user_live_playback`**: Estado en tiempo real de qué canción está escuchando cada dispositivo.
7. **`device_commands`**: Cola de órdenes remotas para el soporte de Groovy Connect a través de Internet.

### 6.2. Seguridad y Control de Acceso
* **Protección contra fuerza bruta:** `express-rate-limit` restringe a un máximo de 20 peticiones cada 15 minutos en `/api/auth/login` y `/api/auth/register`.
* **Límite general de API:** 400 peticiones por minuto para prevenir abusos.
* **Tokens JWT:** Firma criptográfica para validar la identidad de cada cliente en los encabezados `Authorization: Bearer <token>`.

### 6.3. Endpoints Principales
* `/api/auth`: Registro, inicio de sesión, OAuth de Google y reseteo de contraseñas.
* `/api/library`: CRUD de playlists y sincronización de favoritos.
* `/api/library/devices`: Registro de presencia y despacho de comandos remotos.
* `/api/telemetry`: Métricas anónimas de rendimiento y uso.
* `/api/admin`: Gestión administrativa de usuarios y estadísticas.

---

## 7. Cliente Web SPA (React & Vite)

Ubicado en `react-website/`:
* Aplicación web moderna compilada con **Vite** y maquetada con **Tailwind CSS**.
* Servida directamente por el backend de Express en producción (`express.static`).
* Ofrece una alternativa ligera accesible desde cualquier navegador web sin necesidad de instalar la aplicación nativa.

---

## 8. Diagnóstico Técnico: Fortalezas, Riesgos y Recomendaciones

### ✅ Puntos Fuertes
1. **Rendimiento Nativo de Audio:** La integración de `libmpv` en escritorio y `audio_service` en móvil garantiza reproducción sin interrupciones y con bajo consumo de memoria.
2. **Resistencia Anti-Bloqueos:** El proxy interno de streams en Dart resuelve con eficacia las restricciones HTTP 403.
3. **Sincronización P2P Ágil:** Groovy Connect logra una experiencia fluida sin depender necesariamente de servidores externos cuando los dispositivos están en la misma red.

### ⚠️ Riesgos Técnicos
1. **Falta de Autenticación en Servidor Local (LAN):** El servidor HTTP local en el puerto `42425` acepta comandos de cualquier IP de la red local sin solicitar un PIN de emparejamiento previo.
2. **Fragilidad de Extracción de Terceros:** Cambios en el algoritmo de YouTube pueden afectar la extracción de streams si la versión de `yt-dlp` o `youtube_explode_dart` queda desactualizada.
3. **Monolito en `PlayerProvider.dart`:** El archivo supera las 3,700 líneas y centraliza demasiadas tareas que deberían modularizarse.

### 💡 Recomendaciones de Mejora
1. **Emparejamiento Seguro para Groovy Connect:** Implementar un código PIN de 4 dígitos o token efímero HMAC antes de permitir que un dispositivo remoto controle la reproducción local.
2. **Auto-actualizador de `yt-dlp`:** Incorporar una rutina que descargue automáticamente la última versión del binario desde su repositorio oficial en caso de fallo recurrente de reproducción.
3. **Modularización del Estado:** Descomponer `PlayerProvider` en controladores especializados (`PlaybackEngine`, `QueueController`, `RemoteCastManager`).
