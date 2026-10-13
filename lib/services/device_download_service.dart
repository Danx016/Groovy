import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import '../models/song.dart';
import '../models/album.dart';
import 'offline_service.dart';
import 'audio_cache_service.dart';
import 'youtube_service.dart';

class DeviceDownloadService {
  static final DeviceDownloadService _instance = DeviceDownloadService._internal();
  factory DeviceDownloadService() => _instance;
  DeviceDownloadService._internal();

  static const MethodChannel _channel = MethodChannel('com.groovy.music/downloads');
  static const String _keySaveToDeviceDownloads = 'save_to_device_downloads';

  SharedPreferences? _prefs;
  bool _initialized = false;

  final ValueNotifier<bool> saveToDeviceDownloadsNotifier = ValueNotifier<bool>(false);

  bool get isDeviceDownloadEnabled => saveToDeviceDownloadsNotifier.value;
  bool get saveToDeviceDownloads => saveToDeviceDownloadsNotifier.value;

  Future<void> initialize() async {
    if (_initialized) return;
    _prefs ??= await SharedPreferences.getInstance();
    final enabled = _prefs?.getBool(_keySaveToDeviceDownloads) ?? false;
    saveToDeviceDownloadsNotifier.value = enabled;
    _initialized = true;
  }

  Future<void> setSaveToDeviceDownloads(bool value) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setBool(_keySaveToDeviceDownloads, value);
    saveToDeviceDownloadsNotifier.value = value;

    if (value && !kIsWeb && Platform.isAndroid) {
      await requestStoragePermissions();
    }
  }

  Future<bool> requestStoragePermissions() async {
    if (kIsWeb || !Platform.isAndroid) return true;

    try {
      if (await Permission.audio.isGranted ||
          await Permission.storage.isGranted ||
          await Permission.manageExternalStorage.isGranted) {
        return true;
      }

      var status = await Permission.audio.request();
      if (status.isGranted) return true;

      status = await Permission.storage.request();
      if (status.isGranted) return true;

      status = await Permission.manageExternalStorage.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('[DeviceDownloadService] Error requesting storage permissions: $e');
      return false;
    }
  }

  String sanitizeFilename(String name) {
    return name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<String> getPublicDownloadsDirectory() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final path = await _channel.invokeMethod<String>('getDownloadsPath');
        if (path != null && path.isNotEmpty) return path;
      } catch (_) {}
      return '/storage/emulated/0/Download/Groovy';
    }

    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      try {
        final dir = await getDownloadsDirectory();
        if (dir != null) {
          return '${dir.path}${Platform.pathSeparator}Groovy';
        }
      } catch (_) {}

      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'] ?? '';
        if (userProfile.isNotEmpty) return '$userProfile\\Downloads\\Groovy';
      } else {
        final home = Platform.environment['HOME'] ?? '';
        if (home.isNotEmpty) return '$home/Downloads/Groovy';
      }
    }

    try {
      final docDir = await getApplicationDocumentsDirectory();
      return '${docDir.path}/Groovy';
    } catch (_) {
      return 'Downloads/Groovy';
    }
  }

  /// Guarda una canción como archivo de audio estándar en la carpeta Descargas del teléfono/sistema.
  Future<String?> saveSongToDevice(
    Song song, {
    File? cachedFile,
    String? subfolder,
  }) async {
    File? sourceFile = cachedFile;

    // 1. Localizar el archivo de audio si no fue proporcionado
    if (sourceFile == null || !await sourceFile.exists()) {
      final offlineService = OfflineService();
      final offlineSongPath = offlineService.getSongPath(song.id);
      final offFile = File(offlineSongPath);
      if (await offFile.exists() && await offFile.length() >= 65536) {
        sourceFile = offFile;
      }
    }

    if (sourceFile == null || !await sourceFile.exists()) {
      final cached = await AudioCacheService().getCachedSongFile(song.id);
      if (cached != null && await cached.exists() && await cached.length() >= 65536) {
        sourceFile = cached;
      }
    }

    if (sourceFile == null || !await sourceFile.exists()) {
      debugPrint('[DeviceDownloadService] Source audio file not found for "${song.title}"');
      return null;
    }

    // 2. Formatear nombre de archivo estándar: "Artista - Canción.mp3"
    final artistStr = (song.artist != null && song.artist!.trim().isNotEmpty)
        ? sanitizeFilename(song.artist!)
        : 'Desconocido';
    final titleStr = song.title.trim().isNotEmpty
        ? sanitizeFilename(song.title)
        : 'Canción';
    final fileName = '$artistStr - $titleStr.mp3';

    // Determinar subcarpeta si pertenece a un álbum
    String targetSubfolder = subfolder ?? 'Groovy';
    if (subfolder == null && song.album != null && song.album!.trim().isNotEmpty) {
      targetSubfolder = 'Groovy/${sanitizeFilename(song.album!)}';
    }

    // 3. Plataforma Android: usar canal nativo con MediaStore / Descargas públicas
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final saved = await _channel.invokeMethod<String>('saveToPublicDownloads', {
          'sourcePath': sourceFile.path,
          'fileName': fileName,
          'subfolder': targetSubfolder,
          'title': song.title,
          'artist': song.artist ?? '',
          'album': song.album ?? '',
        });
        debugPrint('[DeviceDownloadService] 📱 Saved song to Android Downloads: $saved');
        return saved;
      } catch (e) {
        debugPrint('[DeviceDownloadService] Native Android save failed: $e, trying fallback...');
      }
    }

    // 4. Fallback / Desktop / iOS
    try {
      final baseDir = await getPublicDownloadsDirectory();
      final folderParts = targetSubfolder.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty && s != 'Groovy').toList();
      String finalDirPath = baseDir;
      if (folderParts.isNotEmpty) {
        finalDirPath = '$baseDir${Platform.pathSeparator}${folderParts.join(Platform.pathSeparator)}';
      }

      final dir = Directory(finalDirPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final destPath = '$finalDirPath${Platform.pathSeparator}$fileName';
      final destFile = File(destPath);
      await sourceFile.copy(destFile.path);
      debugPrint('[DeviceDownloadService] 💾 Copied song to: $destPath');
      return destFile.path;
    } catch (e) {
      debugPrint('[DeviceDownloadService] Error saving song to device: $e');
      return null;
    }
  }

  /// Guarda todas las canciones de un álbum en la carpeta de Descargas del dispositivo
  /// organizadas bajo: Descargas/Groovy/[Nombre del Álbum]/
  Future<void> saveAlbumToDevice(
    Album album,
    List<Song> songs,
    YoutubeService youtubeService, {
    Function(int current, int total)? onProgress,
    Function(Song song, bool success)? onSongComplete,
  }) async {
    final offlineService = OfflineService();
    final albumSubfolder = 'Groovy/${sanitizeFilename(album.name)}';

    // 1. Descargar carátula del álbum en la carpeta del dispositivo si es posible
    if (album.coverArt != null && album.coverArt!.isNotEmpty) {
      try {
        final coverUrl = youtubeService.getCoverArtUrl(album.coverArt!, size: 800);
        if (coverUrl.isNotEmpty) {
          final baseDir = await getPublicDownloadsDirectory();
          final albumDir = Directory('$baseDir${Platform.pathSeparator}${sanitizeFilename(album.name)}');
          if (!await albumDir.exists()) {
            await albumDir.create(recursive: true);
          }
          final coverFile = File('${albumDir.path}${Platform.pathSeparator}cover.jpg');
          if (!await coverFile.exists()) {
            await Dio().download(coverUrl, coverFile.path);
          }
        }
      } catch (e) {
        debugPrint('[DeviceDownloadService] Could not save album cover: $e');
      }
    }

    // 2. Procesar cada canción del álbum
    for (int i = 0; i < songs.length; i++) {
      final song = songs[i];
      final songWithAlbum = song.copyWith(
        album: album.name,
        albumId: album.id,
        artist: (song.artist != null && song.artist!.isNotEmpty) ? song.artist : album.artist,
      );

      bool success = false;
      try {
        // Asegurarse de que esté descargada en caché offline
        if (!offlineService.isSongDownloaded(song.id)) {
          final downloaded = await offlineService.downloadSong(songWithAlbum, youtubeService);
          if (downloaded) {
            final path = await saveSongToDevice(songWithAlbum, subfolder: albumSubfolder);
            success = path != null;
          }
        } else {
          final path = await saveSongToDevice(songWithAlbum, subfolder: albumSubfolder);
          success = path != null;
        }
      } catch (e) {
        debugPrint('[DeviceDownloadService] Error processing song "${song.title}": $e');
      }

      onProgress?.call(i + 1, songs.length);
      onSongComplete?.call(song, success);
    }
  }

  /// Exporta todas las canciones que ya están descargadas en Groovy a la carpeta Descargas
  Future<int> exportAllOfflineSongs({
    Function(int current, int total)? onProgress,
  }) async {
    final offlineService = OfflineService();
    final songs = offlineService.getDownloadedSongs();
    if (songs.isEmpty) return 0;

    int exportedCount = 0;
    for (int i = 0; i < songs.length; i++) {
      final song = songs[i];
      try {
        final path = await saveSongToDevice(song);
        if (path != null) exportedCount++;
      } catch (e) {
        debugPrint('[DeviceDownloadService] Error exporting "${song.title}": $e');
      }
      onProgress?.call(i + 1, songs.length);
    }

    return exportedCount;
  }
}
