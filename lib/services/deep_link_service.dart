import 'dart:async';
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:win32_registry/win32_registry.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../services/ytdlp_service.dart';
import '../utils/navigation_helper.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;
  PlayerProvider? _playerProvider;
  LibraryProvider? _libraryProvider;
  bool _initialized = false;

  void initialize({
    required PlayerProvider playerProvider,
    required LibraryProvider libraryProvider,
  }) {
    if (_initialized) return;
    _initialized = true;
    _playerProvider = playerProvider;
    _libraryProvider = libraryProvider;

    if (!kIsWeb && Platform.isWindows) {
      _registerWindowsProtocol();
    }

    // 1. Listen for incoming deep links while app is running (Warm start)
    _linkSub = _appLinks.uriLinkStream.listen(
      (uri) {
        debugPrint('[DeepLinkService] 🔗 Incoming URI stream: $uri');
        handleUri(uri);
      },
      onError: (err) {
        debugPrint('[DeepLinkService] ❌ Error in uriLinkStream: $err');
      },
    );

    // 2. Check for initial link if app was launched via link (Cold start)
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        debugPrint('[DeepLinkService] 🔗 Cold start initial URI: $uri');
        handleUri(uri);
      }
    }).catchError((err) {
      debugPrint('[DeepLinkService] ❌ Error reading initial link: $err');
    });
  }

  void dispose() {
    _linkSub?.cancel();
    _linkSub = null;
  }

  /// Extracts track ID from any supported format:
  /// - groovy://track/{id}
  /// - groovy://song/{id}
  /// - https://groovyapi.duckdns.org/track/{id}
  /// - https://groovy.app/track/{id}
  /// - https://youtu.be/{id}
  /// - https://www.youtube.com/watch?v={id}
  /// - https://music.youtube.com/watch?v={id}
  String? extractTrackId(Uri uri) {
    // 1. Custom scheme groovy://
    if (uri.scheme.toLowerCase() == 'groovy') {
      final host = uri.host.toLowerCase();
      if (host == 'track' || host == 'song') {
        if (uri.pathSegments.isNotEmpty) {
          return uri.pathSegments.first;
        }
        if (uri.queryParameters.containsKey('id')) {
          return uri.queryParameters['id'];
        }
      }
      if (uri.pathSegments.contains('track')) {
        final idx = uri.pathSegments.indexOf('track');
        if (idx + 1 < uri.pathSegments.length) {
          return uri.pathSegments[idx + 1];
        }
      }
      if (uri.pathSegments.contains('song')) {
        final idx = uri.pathSegments.indexOf('song');
        if (idx + 1 < uri.pathSegments.length) {
          return uri.pathSegments[idx + 1];
        }
      }
      // Direct ID: groovy://dQw4w9WgXcQ
      if (uri.host.length == 11 && RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(uri.host)) {
        return uri.host;
      }
      if (uri.path.isNotEmpty) {
        final clean = uri.path.replaceAll('/', '').trim();
        if (clean.length == 11 && RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(clean)) {
          return clean;
        }
      }
    }

    // 2. HTTP / HTTPS links
    final pathSegments = uri.pathSegments;
    if (pathSegments.contains('track')) {
      final idx = pathSegments.indexOf('track');
      if (idx + 1 < pathSegments.length) {
        return pathSegments[idx + 1];
      }
    }
    if (pathSegments.contains('song')) {
      final idx = pathSegments.indexOf('song');
      if (idx + 1 < pathSegments.length) {
        return pathSegments[idx + 1];
      }
    }

    // 3. YouTube & YouTube Music links
    if (uri.host.contains('youtu.be') && pathSegments.isNotEmpty) {
      return pathSegments.first;
    }
    if (uri.host.contains('youtube.com')) {
      return uri.queryParameters['v'];
    }

    return null;
  }

  /// Handles incoming URI and plays the track
  Future<void> handleUri(Uri uri) async {
    final trackId = extractTrackId(uri);
    if (trackId == null || trackId.isEmpty) {
      debugPrint('[DeepLinkService] ⚠️ Could not extract valid trackId from $uri');
      return;
    }
    await playTrackById(trackId);
  }

  /// Resolves track information and requests playback
  Future<void> playTrackById(String trackId) async {
    final cleanId = trackId.replaceFirst('ytmusic://', '').replaceFirst('yt_', '').trim();
    if (cleanId.isEmpty) return;

    final player = _playerProvider;
    final library = _libraryProvider;
    if (player == null) {
      debugPrint('[DeepLinkService] ⚠️ PlayerProvider not available yet');
      return;
    }

    debugPrint('[DeepLinkService] ▶ Resolving and playing track from deep link: $cleanId');

    // 1. Search in local library cache first
    Song? song;
    if (library != null) {
      final cachedMatches = library.cachedAllSongs.where(
        (s) => s.id == cleanId || s.id == 'yt_$cleanId',
      );
      if (cachedMatches.isNotEmpty) {
        song = cachedMatches.first;
      }
    }

    // 2. If not cached, fetch online metadata using YtDlpService
    if (song == null) {
      try {
        final videoInfo = await YtDlpService().getVideoInfo(cleanId);
        if (videoInfo != null) {
          song = Song(
            id: cleanId,
            title: videoInfo['title'] ?? 'Canción Compartida',
            artist: videoInfo['artist'] ?? 'Groovy',
            album: videoInfo['album'],
            duration: videoInfo['duration'],
            coverArt: cleanId,
          );
        }
      } catch (e) {
        debugPrint('[DeepLinkService] Metadata fetch note: $e');
      }
    }

    // Fallback song object if metadata couldn't be fetched
    song ??= Song(
      id: cleanId,
      title: 'Canción Compartida',
      artist: 'Groovy',
      coverArt: cleanId,
    );

    // 3. Start playback
    await player.playSong(song, forcePlay: true);

    // 4. Show friendly notification toast
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = NavigationHelper.navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Reproduciendo enlace: "${song!.title}"',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1DB954),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  /// Builds a universal web URL: https://groovyapi.duckdns.org/track/{id}
  static String buildShareUrl(Song song) {
    final cleanId = song.id.replaceFirst('ytmusic://', '').replaceFirst('yt_', '').trim();
    return 'https://groovyapi.duckdns.org/track/$cleanId';
  }

  /// Builds a native deep link URL: groovy://track/{id}
  static String buildGroovySchemeUrl(Song song) {
    final cleanId = song.id.replaceFirst('ytmusic://', '').replaceFirst('yt_', '').trim();
    return 'groovy://track/$cleanId';
  }

  /// Copies URL to clipboard and triggers the OS share sheet
  static Future<void> shareSong(BuildContext context, Song song) async {
    final shareUrl = buildShareUrl(song);
    final groovyUrl = buildGroovySchemeUrl(song);
    final title = song.title;
    final artist = song.artist ?? 'Groovy';

    final shareText = '🎵 Escucha "$title" de $artist en Groovy:\n$shareUrl\n(O abre en la app: $groovyUrl)';

    // Copy to clipboard
    await Clipboard.setData(ClipboardData(text: shareUrl));

    // Open system share sheet
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: shareText,
          subject: '$title - $artist',
        ),
      );
    } catch (e) {
      debugPrint('[DeepLinkService] Share sheet note: $e');
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.link_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Enlace copiado al portapapeles: $shareUrl',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Registers the "groovy://" protocol handler in Windows registry under HKCU
  void _registerWindowsProtocol() {
    try {
      final exePath = Platform.resolvedExecutable;
      final key = Registry.currentUser.createKey(r'Software\Classes\groovy');
      key.createValue(const RegistryValue.string('', 'URL:Groovy Protocol'));
      key.createValue(const RegistryValue.string('URL Protocol', ''));
      final shellKey = key.createKey(r'shell\open\command');
      shellKey.createValue(RegistryValue.string('', '"$exePath" "%1"'));
      debugPrint('[DeepLinkService] ✅ Windows protocol "groovy://" registered.');
    } catch (e) {
      debugPrint('[DeepLinkService] Windows protocol registration note: $e');
    }
  }
}
