import 'dart:async';
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:win32_registry/win32_registry.dart';
import '../models/song.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../screens/album_screen.dart';
import '../screens/artist_screen.dart';
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

  /// Extracts album ID from:
  /// - groovy://album/{id}
  /// - https://groovyapi.duckdns.org/album/{id}
  String? extractAlbumId(Uri uri) {
    if (uri.scheme.toLowerCase() == 'groovy') {
      final host = uri.host.toLowerCase();
      if (host == 'album') {
        if (uri.pathSegments.isNotEmpty) {
          return uri.pathSegments.first;
        }
        if (uri.queryParameters.containsKey('id')) {
          return uri.queryParameters['id'];
        }
      }
      if (uri.pathSegments.contains('album')) {
        final idx = uri.pathSegments.indexOf('album');
        if (idx + 1 < uri.pathSegments.length) {
          return uri.pathSegments[idx + 1];
        }
      }
    }

    final pathSegments = uri.pathSegments;
    if (pathSegments.contains('album')) {
      final idx = pathSegments.indexOf('album');
      if (idx + 1 < pathSegments.length) {
        return pathSegments[idx + 1];
      }
    }
    return null;
  }

  /// Extracts artist ID from:
  /// - groovy://artist/{id}
  /// - https://groovyapi.duckdns.org/artist/{id}
  String? extractArtistId(Uri uri) {
    if (uri.scheme.toLowerCase() == 'groovy') {
      final host = uri.host.toLowerCase();
      if (host == 'artist') {
        if (uri.pathSegments.isNotEmpty) {
          return uri.pathSegments.first;
        }
        if (uri.queryParameters.containsKey('id')) {
          return uri.queryParameters['id'];
        }
      }
      if (uri.pathSegments.contains('artist')) {
        final idx = uri.pathSegments.indexOf('artist');
        if (idx + 1 < uri.pathSegments.length) {
          return uri.pathSegments[idx + 1];
        }
      }
    }

    final pathSegments = uri.pathSegments;
    if (pathSegments.contains('artist')) {
      final idx = pathSegments.indexOf('artist');
      if (idx + 1 < pathSegments.length) {
        return pathSegments[idx + 1];
      }
    }
    return null;
  }

  /// Handles incoming URI: dispatches to song, album, or artist
  Future<void> handleUri(Uri uri) async {
    // 1. Check if it's an album link
    final albumId = extractAlbumId(uri);
    if (albumId != null && albumId.isNotEmpty) {
      final title = uri.queryParameters['title'] ?? uri.queryParameters['name'];
      final artist = uri.queryParameters['artist'];
      final cover = uri.queryParameters['cover'] ?? uri.queryParameters['image'];
      final yearStr = uri.queryParameters['year'];
      final year = yearStr != null ? int.tryParse(yearStr) : null;
      await openAlbumById(albumId, title: title, artist: artist, cover: cover, year: year);
      return;
    }

    // 2. Check if it's an artist link
    final artistId = extractArtistId(uri);
    if (artistId != null && artistId.isNotEmpty) {
      final name = uri.queryParameters['name'] ?? uri.queryParameters['title'];
      final image = uri.queryParameters['image'] ?? uri.queryParameters['cover'];
      await openArtistById(artistId, name: name, image: image);
      return;
    }

    // 3. Otherwise treat as a song/track
    final trackId = extractTrackId(uri);
    if (trackId != null && trackId.isNotEmpty) {
      final title = uri.queryParameters['title'];
      final artist = uri.queryParameters['artist'];
      await playTrackById(trackId, title: title, artist: artist);
      return;
    }

    debugPrint('[DeepLinkService] ⚠️ Could not extract recognizable content from $uri');
  }

  /// Opens an album in AlbumScreen
  Future<void> openAlbumById(
    String albumId, {
    String? title,
    String? artist,
    String? cover,
    int? year,
  }) async {
    final cleanId = albumId.trim();
    if (cleanId.isEmpty) return;

    Album? album;
    final library = _libraryProvider;
    if (library != null) {
      final matches = library.cachedAllAlbums.where((a) => a.id == cleanId);
      if (matches.isNotEmpty) {
        album = matches.first;
      }
    }

    album ??= Album(
      id: cleanId,
      name: (title != null && title.isNotEmpty) ? title : 'Álbum',
      artist: artist,
      coverArt: cover,
      year: year,
    );

    debugPrint('[DeepLinkService] 💿 Opening album from deep link: ${album.name} ($cleanId)');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navState = NavigationHelper.navigatorKey.currentState;
      if (navState != null) {
        navState.push(
          MaterialPageRoute(
            builder: (_) => AlbumScreen(albumId: cleanId, album: album),
          ),
        );
      }
    });
  }

  /// Opens an artist in ArtistScreen
  Future<void> openArtistById(
    String artistId, {
    String? name,
    String? image,
  }) async {
    final cleanId = artistId.trim();
    if (cleanId.isEmpty) return;

    Artist? artist;
    final library = _libraryProvider;
    if (library != null) {
      final matches = library.artists.where(
        (a) => a.id == cleanId || (name != null && a.name.toLowerCase() == name.toLowerCase()),
      );
      if (matches.isNotEmpty) {
        artist = matches.first;
      }
    }

    artist ??= Artist(
      id: cleanId,
      name: (name != null && name.isNotEmpty) ? name : 'Artista',
      artistImageUrl: image,
    );

    debugPrint('[DeepLinkService] 🎤 Opening artist from deep link: ${artist.name} ($cleanId)');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navState = NavigationHelper.navigatorKey.currentState;
      if (navState != null) {
        navState.push(
          MaterialPageRoute(
            builder: (_) => ArtistScreen(artistId: cleanId, artist: artist),
          ),
        );
      }
    });
  }

  /// Resolves track information and requests playback
  Future<void> playTrackById(String trackId, {String? title, String? artist}) async {
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

    // 2. If title is passed via deep link parameters, instantiate immediately for instant playback
    if (song == null && title != null && title.isNotEmpty) {
      song = Song(
        id: cleanId,
        title: title,
        artist: (artist != null && artist.isNotEmpty) ? artist : 'Groovy',
        coverArt: cleanId,
      );
    }

    // 3. If not cached, fetch online metadata using YtDlpService
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

    // 4. Start playback
    await player.playSong(song, forcePlay: true);

    // 5. Show friendly notification toast
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
                    'Reproduciendo: "${song!.title}"',
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
    final params = <String, String>{};
    if (song.title.isNotEmpty) params['title'] = song.title;
    if (song.artist != null && song.artist!.isNotEmpty) params['artist'] = song.artist!;
    if (song.album != null && song.album!.isNotEmpty) params['album'] = song.album!;
    if (song.coverArt != null && song.coverArt!.startsWith('http')) {
      params['cover'] = song.coverArt!;
    }
    final query = Uri(queryParameters: params).query;
    return 'https://groovyapi.duckdns.org/track/$cleanId${query.isNotEmpty ? "?$query" : ""}';
  }

  /// Builds a native deep link URL: groovy://track/{id}
  static String buildGroovySchemeUrl(Song song) {
    final cleanId = song.id.replaceFirst('ytmusic://', '').replaceFirst('yt_', '').trim();
    return 'groovy://track/$cleanId';
  }

  /// Copies URL to clipboard and triggers the OS share sheet (Spotify style: single clean link)
  static Future<void> shareSong(BuildContext context, Song song) async {
    final shareUrl = buildShareUrl(song);
    final title = song.title;
    final artist = (song.artist != null && song.artist!.isNotEmpty) ? song.artist! : 'Groovy';

    // Spotify style: sending only the URL allows WhatsApp/Telegram to render the full rich preview card
    await Clipboard.setData(ClipboardData(text: shareUrl));

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: shareUrl,
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

  /// Builds an album web URL: https://groovyapi.duckdns.org/album/{id}
  static String buildAlbumShareUrl(Album album) {
    final cleanId = album.id.trim();
    final params = <String, String>{};
    if (album.name.isNotEmpty) params['title'] = album.name;
    if (album.artist != null && album.artist!.isNotEmpty) params['artist'] = album.artist!;
    if (album.year != null && album.year! > 0) params['year'] = album.year.toString();
    if (album.coverArt != null && album.coverArt!.startsWith('http')) {
      params['cover'] = album.coverArt!;
    }
    final query = Uri(queryParameters: params).query;
    return 'https://groovyapi.duckdns.org/album/$cleanId${query.isNotEmpty ? "?$query" : ""}';
  }

  /// Copies album URL to clipboard and triggers the OS share sheet (Spotify style)
  static Future<void> shareAlbum(BuildContext context, Album album) async {
    final shareUrl = buildAlbumShareUrl(album);
    final title = album.name;
    final artist = (album.artist != null && album.artist!.isNotEmpty) ? album.artist! : 'Groovy';

    await Clipboard.setData(ClipboardData(text: shareUrl));

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: shareUrl,
          subject: '$title - $artist',
        ),
      );
    } catch (e) {
      debugPrint('[DeepLinkService] Share album note: $e');
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.album_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Enlace del álbum copiado al portapapeles: $shareUrl',
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

  /// Builds an artist web URL: https://groovyapi.duckdns.org/artist/{id}
  static String buildArtistShareUrl(Artist artist, {String? imageUrl}) {
    final cleanId = artist.id.trim();
    final params = <String, String>{};
    if (artist.name.isNotEmpty) params['name'] = artist.name;
    final img = imageUrl ?? artist.artistImageUrl ?? artist.coverArt;
    if (img != null && img.startsWith('http')) {
      params['image'] = img;
    }
    final query = Uri(queryParameters: params).query;
    return 'https://groovyapi.duckdns.org/artist/$cleanId${query.isNotEmpty ? "?$query" : ""}';
  }

  /// Copies artist URL to clipboard and triggers the OS share sheet (Spotify style)
  static Future<void> shareArtist(BuildContext context, Artist artist, {String? imageUrl}) async {
    final shareUrl = buildArtistShareUrl(artist, imageUrl: imageUrl);

    await Clipboard.setData(ClipboardData(text: shareUrl));

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: shareUrl,
          subject: artist.name,
        ),
      );
    } catch (e) {
      debugPrint('[DeepLinkService] Share artist note: $e');
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.person_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Enlace del artista copiado al portapapeles: $shareUrl',
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
