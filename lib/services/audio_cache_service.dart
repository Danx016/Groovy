import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';
import 'cache_settings_service.dart';
import 'offline_service.dart';
import 'youtube_service.dart';
import 'ytdlp_service.dart';

/// Service responsible for disk-caching streamed music (YouTube Music & other streams).
///
/// Ensures parity across Windows, Linux, macOS, and Android:
/// - Checks [CacheSettingsService.getMusicCacheEnabled].
/// - Stores fully buffered/streamed audio tracks in temporary cache directory.
/// - Pre-buffers subsequent tracks in background so they start instantly (0 ms latency).
/// - Serves cached tracks directly via [AudioSource.file] without network requests.
class AudioCacheService {
  static final AudioCacheService _instance = AudioCacheService._internal();
  factory AudioCacheService() => _instance;
  AudioCacheService._internal();

  final CacheSettingsService _cacheSettings = CacheSettingsService();
  final OfflineService _offlineService = OfflineService();
  final YtDlpService _ytdlp = YtDlpService();

  String? _cacheDirPath;
  final Map<String, Future<File?>> _inFlightPreloads = {};

  static const String _cacheSubdir = 'groovy_music_cache';
  static const int _minValidAudioSizeBytes = 100 * 1024; // 100 KB minimum
  static const int _maxCacheSizeBytes = 2 * 1024 * 1024 * 1024; // 2 GB soft limit

  Future<String> _ensureCacheDir() async {
    if (_cacheDirPath != null) return _cacheDirPath!;
    String tempPath;
    try {
      final tempDir = await getTemporaryDirectory();
      tempPath = tempDir.path;
    } catch (_) {
      tempPath = Directory.systemTemp.path;
    }
    final dir = Directory('$tempPath/$_cacheSubdir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDirPath = dir.path;
    return _cacheDirPath!;
  }

  String _filenameForSong(String songId) {
    final clean = songId
        .replaceFirst('ytmusic://', '')
        .replaceAll(RegExp(r'[^\w\-]'), '_');
    return '$clean.audio';
  }

  /// Returns the cached audio [File] if it exists on disk and is a valid size.
  /// Returns null if caching is disabled or the file is not yet cached.
  Future<File?> getCachedSongFile(String songId) async {
    try {
      if (!_cacheSettings.getMusicCacheEnabled()) return null;
      final dirPath = await _ensureCacheDir();
      final file = File('$dirPath/${_filenameForSong(songId)}');
      if (await file.exists()) {
        final length = await file.length();
        if (length >= _minValidAudioSizeBytes) {
          return file;
        } else {
          // Incomplete or corrupted file; remove it
          await file.delete().catchError((_) => file);
        }
      }
    } catch (e) {
      debugPrint('[AudioCache] Error checking cached song file: $e');
    }
    return null;
  }

  /// Synchronous quick check if a song file exists and is valid.
  File? getCachedSongFileSync(String songId) {
    try {
      if (!_cacheSettings.getMusicCacheEnabled()) return null;
      if (_cacheDirPath == null) return null;
      final file = File('$_cacheDirPath/${_filenameForSong(songId)}');
      if (file.existsSync() && file.lengthSync() >= _minValidAudioSizeBytes) {
        return file;
      }
    } catch (_) {}
    return null;
  }

  /// Preloads and caches the audio stream for [song] in the background.
  ///
  /// If already cached or downloaded in [OfflineService], returns immediately.
  /// Otherwise, resolves stream info via yt-dlp and downloads the audio stream
  /// directly into disk cache, enabling zero-latency playback when the song plays.
  Future<File?> preloadSong(Song song, YoutubeService youtubeService) async {
    if (!_cacheSettings.getMusicCacheEnabled()) return null;

    // Skip if already in user's permanent offline downloads
    if (_offlineService.getLocalPath(song.id) != null) return null;

    // Check if already in disk cache
    final existing = await getCachedSongFile(song.id);
    if (existing != null) {
      debugPrint('[AudioCache] ⚡ Song already cached on disk: "${song.title}" (${song.id})');
      return existing;
    }

    // Deduplicate concurrent preloads for the same track
    if (_inFlightPreloads.containsKey(song.id)) {
      return _inFlightPreloads[song.id]!;
    }

    final future = _doPreloadSong(song, youtubeService);
    _inFlightPreloads[song.id] = future;
    try {
      return await future;
    } finally {
      _inFlightPreloads.remove(song.id);
    }
  }

  Future<File?> _doPreloadSong(Song song, YoutubeService youtubeService) async {
    try {
      debugPrint('[AudioCache] ⬇️ Starting background audio cache for: "${song.title}" (${song.id})');
      final videoId = await youtubeService.resolveVideoIdForSong(song);
      if (videoId.isEmpty || !RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(videoId)) {
        debugPrint('[AudioCache] Cannot resolve video ID for "${song.title}"');
        return null;
      }

      final streamInfo = await _ytdlp.resolveStreamInfo(videoId);
      if (streamInfo.url.isEmpty) {
        debugPrint('[AudioCache] Stream URL empty for $videoId');
        return null;
      }

      final dirPath = await _ensureCacheDir();
      final targetFile = File('$dirPath/${_filenameForSong(song.id)}');
      final partFile = File('$dirPath/${_filenameForSong(song.id)}.part');

      if (await partFile.exists()) {
        await partFile.delete().catchError((_) => partFile);
      }

      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 12)
        ..idleTimeout = const Duration(seconds: 12);

      try {
        final req = await client.getUrl(Uri.parse(streamInfo.url));
        streamInfo.headers.forEach((k, v) {
          final lower = k.toLowerCase();
          if (lower != 'host' &&
              lower != 'content-length' &&
              lower != 'accept-encoding' &&
              lower != 'connection') {
            req.headers.set(k, v);
          }
        });
        if (!req.headers.toString().toLowerCase().contains('user-agent')) {
          req.headers.set(
            HttpHeaders.userAgentHeader,
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          );
        }
        req.headers.set(HttpHeaders.acceptHeader, '*/*');

        final resp = await req.close();
        if (resp.statusCode != 200 && resp.statusCode != 206) {
          await resp.drain<void>().catchError((_) {});
          debugPrint('[AudioCache] Preload HTTP ${resp.statusCode} for $videoId');
          return null;
        }

        final sink = partFile.openWrite();
        await resp.pipe(sink);

        final partLength = await partFile.length();
        if (partLength >= _minValidAudioSizeBytes) {
          if (await targetFile.exists()) {
            await targetFile.delete().catchError((_) => targetFile);
          }
          await partFile.rename(targetFile.path);
          debugPrint(
            '[AudioCache] ✅ Successfully cached "${song.title}" ($partLength bytes, ${(partLength / (1024 * 1024)).toStringAsFixed(2)} MB)',
          );
          return targetFile;
        } else {
          await partFile.delete().catchError((_) => partFile);
          return null;
        }
      } finally {
        client.close(force: true);
      }
    } catch (e) {
      debugPrint('[AudioCache] Preload failed for "${song.title}": $e');
      return null;
    }
  }

  /// Calculates total size in bytes occupied by cached music files.
  Future<int> getCacheSizeBytes() async {
    try {
      final dirPath = await _ensureCacheDir();
      final dir = Directory(dirPath);
      if (!await dir.exists()) return 0;
      int total = 0;
      await for (final entity in dir.list(recursive: false, followLinks: false)) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Clears all cached audio files from disk.
  Future<void> clearCache() async {
    try {
      final dirPath = await _ensureCacheDir();
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: false, followLinks: false)) {
          if (entity is File) {
            await entity.delete().catchError((_) => entity);
          }
        }
      }
      debugPrint('[AudioCache] Music cache completely cleared.');
    } catch (e) {
      debugPrint('[AudioCache] Error clearing cache: $e');
    }
  }

  /// Automatic maintenance: trims cache files older than [maxAge] or if exceeding [maxBytes].
  Future<void> cleanOldCacheFiles({
    Duration maxAge = const Duration(days: 7),
    int maxBytes = _maxCacheSizeBytes,
  }) async {
    try {
      final dirPath = await _ensureCacheDir();
      final dir = Directory(dirPath);
      if (!await dir.exists()) return;

      final now = DateTime.now();
      final files = <File>[];
      int totalBytes = 0;

      await for (final entity in dir.list(recursive: false, followLinks: false)) {
        if (entity is File) {
          // Remove stray .part files from interrupted downloads older than 1 hour
          if (entity.path.endsWith('.part')) {
            final stat = await entity.stat();
            if (now.difference(stat.modified).inHours > 1) {
              await entity.delete().catchError((_) => entity);
            }
            continue;
          }

          final stat = await entity.stat();
          if (now.difference(stat.modified) > maxAge) {
            await entity.delete().catchError((_) => entity);
            continue;
          }

          files.add(entity);
          totalBytes += stat.size;
        }
      }

      // If over quota, delete oldest modified files until under 75% quota
      if (totalBytes > maxBytes) {
        files.sort((a, b) {
          final statA = a.statSync();
          final statB = b.statSync();
          return statA.modified.compareTo(statB.modified);
        });

        final target = (maxBytes * 0.75).round();
        for (final f in files) {
          if (totalBytes <= target) break;
          final sz = f.lengthSync();
          await f.delete().catchError((_) => f);
          totalBytes -= sz;
        }
      }
    } catch (e) {
      debugPrint('[AudioCache] Error during cache cleanup: $e');
    }
  }

  /// Formats byte counts into human-readable strings (e.g. "24.5 MB").
  String formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    int i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
