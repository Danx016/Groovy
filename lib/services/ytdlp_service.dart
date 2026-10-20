import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import '../utils/song_title_utils.dart';

List<Map<String, dynamic>> _decodeJsonList(String jsonStr) {
  final list = jsonDecode(jsonStr) as List<dynamic>;
  return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

Map<String, List<Map<String, dynamic>>> _decodeDualSearch(String jsonStr) {
  final data = jsonDecode(jsonStr) as Map<String, dynamic>;
  final musicRaw = (data['music'] as List<dynamic>? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  final ytRaw = (data['youtube'] as List<dynamic>? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  return {
    'music': musicRaw,
    'youtube': ytRaw,
  };
}

Map<String, dynamic> _decodeJsonMap(String jsonStr) {
  return jsonDecode(jsonStr) as Map<String, dynamic>;
}

/// Audio stream information returned by yt-dlp.
class YtStreamInfo {
  final String url;
  final Map<String, String> headers;
  final String ext;

  YtStreamInfo({
    required this.url,
    required this.headers,
    this.ext = 'mp4',
  });
}

/// Service that interacts with yt-dlp to extract high-quality audio streams and metadata.
///
/// Platforms:
/// - **Android**: Runs CPython 3.11 with `yt-dlp` embedded directly in the app via Chaquopy / MethodChannel.
/// - **Desktop (macOS / Windows / Linux)**: Spawns the host Python interpreter or `yt-dlp` CLI subprocess.
/// - **Fallback**: Uses `youtube_explode_dart` if native execution encounters an environment error.
class YtDlpService {
  static final YtDlpService _instance = YtDlpService._internal();
  factory YtDlpService() => _instance;
  YtDlpService._internal();

  static const MethodChannel _androidChannel = MethodChannel('com.groovy.music/ytdlp');

  yt.YoutubeExplode? _fallbackYt;

  // Stream Info cache: videoId -> YtStreamInfo
  final Map<String, YtStreamInfo> _streamInfoCache = {};
  final Map<String, DateTime> _streamCacheTime = {};
  final Map<String, Future<YtStreamInfo>> _inFlightResolutions = {};
  static const Duration _cacheTtl = Duration(hours: 5, minutes: 30);


  // Search Caches: query -> result
  final Map<String, Map<String, List<Map<String, dynamic>>>> _dualSearchCache = {};
  final Map<String, List<Map<String, dynamic>>> _searchCache = {};
  final Map<String, List<Map<String, dynamic>>> _albumsCache = {};
  final Map<String, List<Map<String, dynamic>>> _artistsCache = {};

  // Cached paths for detected binaries on desktop
  String? _detectedYtDlpPath;
  String? _detectedPythonPath;
  bool _detectionDone = false;

  yt.YoutubeExplode get _fallbackClient {
    _fallbackYt ??= yt.YoutubeExplode();
    return _fallbackYt!;
  }

  void dispose() {
    cancelCurrentExtraction();
    _fallbackYt?.close();
    _fallbackYt = null;
    _streamInfoCache.clear();
    _streamCacheTime.clear();
    _inFlightResolutions.clear();
  }

  yt.AudioStreamInfo _selectBestAudioStream(Iterable<yt.AudioStreamInfo> audioStreams, {bool preferTv = false}) {
    if (preferTv) {
      final tvStreams = audioStreams.where((s) => s.url.toString().contains('c=TVHTML5'));
      if (tvStreams.isNotEmpty) {
        final mp4Tv = tvStreams.where((s) =>
            s.container.name.toLowerCase() == 'mp4' ||
            s.container.name.toLowerCase() == 'm4a');
        if (mp4Tv.isNotEmpty) return mp4Tv.withHighestBitrate();
        return tvStreams.withHighestBitrate();
      }
      final nonMobileStreams = audioStreams.where((s) =>
          !s.url.toString().contains('c=ANDROID') &&
          !s.url.toString().contains('c=IOS'));
      if (nonMobileStreams.isNotEmpty) {
        final mp4NonMobile = nonMobileStreams.where((s) =>
            s.container.name.toLowerCase() == 'mp4' ||
            s.container.name.toLowerCase() == 'm4a');
        if (mp4NonMobile.isNotEmpty) return mp4NonMobile.withHighestBitrate();
        return nonMobileStreams.withHighestBitrate();
      }
    }
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      final mp4Streams = audioStreams.where((s) =>
          s.container.name.toLowerCase() == 'mp4' ||
          s.container.name.toLowerCase() == 'm4a');
      if (mp4Streams.isNotEmpty) {
        return mp4Streams.withHighestBitrate();
      }
    }
    return audioStreams.withHighestBitrate();
  }

  void invalidateCache(String videoId) {
    final cleanId = videoId.replaceFirst('ytmusic://', '').replaceFirst('yt_', '');
    _streamInfoCache.remove(cleanId);
    _streamCacheTime.remove(cleanId);
    _streamInfoCache.remove(videoId);
    _streamCacheTime.remove(videoId);
    _inFlightResolutions.remove(cleanId);
    _inFlightResolutions.remove(videoId);
  }

  /// Warms up the stream cache in the background without blocking the UI.
  /// Used by player and queue to make track changes instantaneous (0ms).
  void warmUpStreamCache(String songId) {
    final cleanId = songId.replaceFirst('ytmusic://', '').replaceFirst('yt_', '');
    if (!RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(cleanId)) return;
    if (_streamInfoCache.containsKey(cleanId)) return;
    if (_inFlightResolutions.length >= 2) return; // Prevent spawning multiple heavy background subprocesses
    unawaited(resolveStreamInfo(cleanId).catchError((_) => YtStreamInfo(url: '', headers: {})));
  }

  // ── Native Dart Innertube Helpers (Windows / Desktop / Fallback) ────────────

  static final HttpClient _innertubeHttpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10)
    ..idleTimeout = const Duration(seconds: 15)
    ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);

  static const Map<String, String> _innertubeHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Content-Type': 'application/json',
    'Origin': 'https://music.youtube.com',
    'Referer': 'https://music.youtube.com/',
  };

  static String _upgradeThumbnail(String? url) {
    if (url == null || url.isEmpty) return '';
    var upgraded = url;
    upgraded = upgraded.replaceAll(RegExp(r'=(w\d+-h\d+|s\d+)[^/]*'), '=w1200-h1200-c-l90-rj');
    upgraded = upgraded.replaceAll('/sddefault.jpg', '/hqdefault.jpg');
    upgraded = upgraded.replaceAll('/mqdefault.jpg', '/hqdefault.jpg');
    upgraded = upgraded.replaceAll('/default.jpg', '/hqdefault.jpg');
    return upgraded;
  }

  static dynamic _dig(dynamic obj, List<String> keys) {
    dynamic current = obj;
    for (final key in keys) {
      if (current is Map && current.containsKey(key)) {
        current = current[key];
      } else {
        return null;
      }
    }
    return current;
  }

  void _parseInnertubeMusicItems(List<dynamic> contents, List<Map<String, dynamic>> results, int limit) {
    for (final item in contents) {
      final r = item['musicResponsiveListItemRenderer'];
      if (r == null) continue;
      final flex = r['flexColumns'] as List<dynamic>? ?? [];
      if (flex.isEmpty) continue;

      final titleRuns = (flex[0]['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'] as List<dynamic>?) ?? [];
      final title = titleRuns.isNotEmpty ? (titleRuns[0]['text'] as String? ?? '') : '';

      final firstRun = titleRuns.isNotEmpty && titleRuns[0] is Map ? (titleRuns[0] as Map) : null;
      String? videoId;
      if (firstRun != null && firstRun['navigationEndpoint'] is Map) {
        final ep = firstRun['navigationEndpoint'] as Map;
        if (ep['watchEndpoint'] is Map) {
          videoId = ep['watchEndpoint']['videoId']?.toString();
        }
      }
      if (videoId == null || videoId.isEmpty) {
        final overlay = _dig(r, ['overlay', 'musicItemThumbnailOverlayRenderer', 'content', 'musicPlayButtonRenderer', 'playNavigationEndpoint', 'watchEndpoint']);
        if (overlay is Map) {
          videoId = overlay['videoId']?.toString();
        }
      }
      if (videoId == null || videoId.isEmpty) continue;

      // Avoid duplicate song IDs in the same search result
      if (results.any((x) => x['id'] == videoId)) continue;

      final infoRuns = flex.length > 1
          ? ((flex[1]['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'] as List<dynamic>?) ?? [])
          : <dynamic>[];

      final parts = <String>[];
      var curr = <String>[];
      for (final x in infoRuns) {
        final t = x['text'] as String? ?? '';
        if (t == ' • ') {
          if (curr.isNotEmpty) {
            parts.add(curr.join(''));
            curr = [];
          }
        } else {
          curr.add(t);
        }
      }
      if (curr.isNotEmpty) parts.add(curr.join(''));

      String artist = 'Unknown Artist';
      String? albumName;
      int durationSecs = 0;

      if (parts.length >= 3) {
        artist = parts[0];
        albumName = parts[1];
        final durSplit = parts[2].split(':');
        if (durSplit.length == 2) {
          durationSecs = (int.tryParse(durSplit[0]) ?? 0) * 60 + (int.tryParse(durSplit[1]) ?? 0);
        } else if (durSplit.length == 3) {
          durationSecs = (int.tryParse(durSplit[0]) ?? 0) * 3600 + (int.tryParse(durSplit[1]) ?? 0) * 60 + (int.tryParse(durSplit[2]) ?? 0);
        }
      } else if (parts.length == 2) {
        artist = parts[0];
        final durSplit = parts[1].split(':');
        if (durSplit.length == 2) {
          durationSecs = (int.tryParse(durSplit[0]) ?? 0) * 60 + (int.tryParse(durSplit[1]) ?? 0);
        } else if (durSplit.length == 3) {
          durationSecs = (int.tryParse(durSplit[0]) ?? 0) * 3600 + (int.tryParse(durSplit[1]) ?? 0) * 60 + (int.tryParse(durSplit[2]) ?? 0);
        }
      } else if (parts.isNotEmpty) {
        artist = parts[0];
      }

      final thumbs = (r['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] as List<dynamic>?) ?? [];
      final thumb = thumbs.isNotEmpty ? _upgradeThumbnail(thumbs.last['url'] as String?) : '';

      results.add({
        'id': videoId,
        'title': title,
        'artist': artist,
        'album': albumName,
        'duration': durationSecs,
        'thumbnailUrl': thumb,
        'coverArt': thumb.isNotEmpty ? thumb : videoId,
      });

      if (results.length >= limit) break;
    }
  }

  /// Queries official YouTube Music Innertube API (Songs filter) directly in pure Dart.
  Future<List<Map<String, dynamic>>> searchYtMusicInnertube(String query, {int limit = 100}) async {
    try {
      final req = await _innertubeHttpClient.postUrl(
        Uri.parse('https://music.youtube.com/youtubei/v1/search?prettyPrint=false&key=AIzaSyC9XL3ZjWddXya6X74dJoCTL-KLET5YdU'),
      );
      _innertubeHeaders.forEach((k, v) => req.headers.set(k, v));
      req.write(jsonEncode({
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20240918.01.00',
            'hl': 'es',
            'gl': 'US',
          }
        },
        'query': query,
        'params': 'EgWKAQIIAWoKEAUQAxAEEAkQBQ==',
      }));

      final resp = await req.close();
      if (resp.statusCode != 200) {
        await resp.drain<void>();
        return [];
      }
      final jsonStr = await resp.transform(utf8.decoder).join();
      final res = jsonDecode(jsonStr) as Map<String, dynamic>;
      final sections = res['contents']?['tabbedSearchResultsRenderer']?['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']?['contents'] as List<dynamic>? ?? [];
      final results = <Map<String, dynamic>>[];
      String? continuationToken;

      for (final sec in sections) {
        final cardShelf = sec['musicCardShelfRenderer'];
        if (cardShelf != null) {
          final cardTitleRuns = (cardShelf['title']?['runs'] as List<dynamic>?) ?? [];
          final cardTitle = cardTitleRuns.isNotEmpty ? (cardTitleRuns[0]['text'] as String? ?? '') : '';
          final cardContents = cardShelf['contents'] as List<dynamic>? ?? [];
          if (cardContents.isNotEmpty) {
            _parseInnertubeMusicItems(cardContents, results, limit);
          }
          final onTap = cardShelf['onTap'] ?? cardShelf['title']?['navigationEndpoint'];
          final watchEndpoint = onTap?['watchEndpoint'];
          final cardVid = watchEndpoint?['videoId']?.toString();
          if (cardVid != null && cardVid.isNotEmpty && !results.any((x) => x['id'] == cardVid)) {
            final thumbs = (cardShelf['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] as List<dynamic>?) ?? [];
            final thumb = thumbs.isNotEmpty ? _upgradeThumbnail(thumbs.last['url'] as String?) : '';
            final subtitleRuns = (cardShelf['subtitle']?['runs'] as List<dynamic>?) ?? [];
            final artist = subtitleRuns.isNotEmpty ? (subtitleRuns[0]['text'] as String? ?? 'Unknown Artist') : 'Unknown Artist';
            results.insert(0, {
              'id': cardVid,
              'title': cardTitle,
              'artist': artist,
              'album': null,
              'duration': 0,
              'thumbnailUrl': thumb,
              'coverArt': thumb.isNotEmpty ? thumb : cardVid,
            });
          }
        }

        final musicShelf = sec['musicShelfRenderer'];
        if (musicShelf == null) continue;
        final contents = musicShelf['contents'] as List<dynamic>? ?? [];
        _parseInnertubeMusicItems(contents, results, limit);

        final continuations = musicShelf['continuations'] as List<dynamic>? ?? [];
        if (continuations.isNotEmpty) {
          final nextData = continuations[0]['nextContinuationData'];
          if (nextData is Map) {
            continuationToken = nextData['continuation'] as String?;
          }
        }
      }

      // Fetch continuation pages only if the first page yielded very few songs (< 15)
      int pages = 0;
      while (results.length < 15 && continuationToken != null && pages < 1) {
        pages++;
        try {
          final contReq = await _innertubeHttpClient.postUrl(
            Uri.parse('https://music.youtube.com/youtubei/v1/search?continuation=$continuationToken&prettyPrint=false&key=AIzaSyC9XL3ZjWddXya6X74dJoCTL-KLET5YdU'),
          );
          _innertubeHeaders.forEach((k, v) => contReq.headers.set(k, v));
          contReq.write(jsonEncode({
            'context': {
              'client': {
                'clientName': 'WEB_REMIX',
                'clientVersion': '1.20240918.01.00',
                'hl': 'es',
                'gl': 'US',
              }
            },
          }));
          final contResp = await contReq.close();
          if (contResp.statusCode != 200) {
            await contResp.drain<void>();
            break;
          }
          final contJsonStr = await contResp.transform(utf8.decoder).join();
          final contRes = jsonDecode(contJsonStr) as Map<String, dynamic>;
          final shelfCont = contRes['continuationContents']?['musicShelfContinuation'];
          if (shelfCont == null) break;
          final contContents = shelfCont['contents'] as List<dynamic>? ?? [];
          _parseInnertubeMusicItems(contContents, results, limit);

          final nextConts = shelfCont['continuations'] as List<dynamic>? ?? [];
          if (nextConts.isNotEmpty) {
            final nextData = nextConts[0]['nextContinuationData'];
            continuationToken = nextData is Map ? nextData['continuation'] as String? : null;
          } else {
            continuationToken = null;
          }
        } catch (_) {
          break;
        }
      }

      return results;
    } catch (e) {
      debugPrint('[yt-dlp] searchYtMusicInnertube error: $e');
      return [];
    }
  }

  /// Queries official YouTube Innertube API (Video filter) directly in pure Dart.
  Future<List<Map<String, dynamic>>> searchYoutubeVideoInnertube(String query, {int limit = 25}) async {
    try {
      final req = await _innertubeHttpClient.postUrl(
        Uri.parse('https://www.youtube.com/youtubei/v1/search?prettyPrint=false&key=AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8'),
      );
      req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('Origin', 'https://www.youtube.com');
      req.headers.set('Referer', 'https://www.youtube.com/');
      req.write(jsonEncode({
        'context': {
          'client': {
            'clientName': 'WEB',
            'clientVersion': '2.20240918.01.00',
            'hl': 'es',
            'gl': 'US',
          }
        },
        'query': query,
        'params': 'EgIQAQ==',
      }));

      final resp = await req.close();
      if (resp.statusCode != 200) {
        await resp.drain<void>();
        return [];
      }
      final jsonStr = await resp.transform(utf8.decoder).join();
      final res = jsonDecode(jsonStr) as Map<String, dynamic>;
      final contents = res['contents']?['twoColumnSearchResultsRenderer']?['primaryContents']?['sectionListRenderer']?['contents'] as List<dynamic>? ?? [];
      final results = <Map<String, dynamic>>[];

      for (final sec in contents) {
        final itemSection = sec['itemSectionRenderer'];
        if (itemSection == null) continue;
        final items = itemSection['contents'] as List<dynamic>? ?? [];
        for (final it in items) {
          final r = it['videoRenderer'];
          if (r == null) continue;
          final vid = r['videoId'] as String?;
          if (vid == null || vid.isEmpty) continue;

          final titleRuns = (r['title']?['runs'] as List<dynamic>?) ?? [];
          final title = titleRuns.isNotEmpty ? (titleRuns[0]['text'] as String? ?? '') : '';

          final ownerRuns = (r['ownerText']?['runs'] as List<dynamic>?) ??
              (r['longBylineText']?['runs'] as List<dynamic>?) ??
              [];
          final artist = ownerRuns.isNotEmpty ? (ownerRuns[0]['text'] as String? ?? 'Unknown Artist') : 'Unknown Artist';

          final durStr = r['lengthText']?['simpleText'] as String? ?? '0:00';
          final durSplit = durStr.split(':');
          int durSecs = 0;
          if (durSplit.length == 2) {
            durSecs = (int.tryParse(durSplit[0]) ?? 0) * 60 + (int.tryParse(durSplit[1]) ?? 0);
          } else if (durSplit.length == 3) {
            durSecs = (int.tryParse(durSplit[0]) ?? 0) * 3600 + (int.tryParse(durSplit[1]) ?? 0) * 60 + (int.tryParse(durSplit[2]) ?? 0);
          }

          final thumbs = (r['thumbnail']?['thumbnails'] as List<dynamic>?) ?? [];
          final thumb = thumbs.isNotEmpty ? _upgradeThumbnail(thumbs.last['url'] as String?) : '';

          results.add({
            'id': vid,
            'title': title,
            'artist': artist,
            'album': null,
            'duration': durSecs,
            'thumbnailUrl': thumb,
            'coverArt': thumb.isNotEmpty ? thumb : vid,
          });

          if (results.length >= limit) break;
        }
        if (results.length >= limit) break;
      }
      return results;
    } catch (e) {
      debugPrint('[yt-dlp] searchYoutubeVideoInnertube error: $e');
      return [];
    }
  }

  /// Queries official YouTube Music Innertube API (Albums filter) directly in pure Dart.
  Future<List<Map<String, dynamic>>> searchYtAlbumsInnertube(String query, {int limit = 20}) async {
    final cleanQuery = query.trim().toLowerCase();
    if (_albumsCache.containsKey(cleanQuery)) {
      return _albumsCache[cleanQuery]!;
    }

    try {
      final req = await _innertubeHttpClient.postUrl(
        Uri.parse('https://music.youtube.com/youtubei/v1/search?prettyPrint=false&key=AIzaSyC9XL3ZjWddXya6X74dJoCTL-KLET5YdU'),
      );
      _innertubeHeaders.forEach((k, v) => req.headers.set(k, v));
      req.write(jsonEncode({
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20240918.01.00',
            'hl': 'es',
            'gl': 'US',
          }
        },
        'query': query,
        'params': 'EgWKAQIYAWoKEAUQAxAEEAkQBQ==',
      }));

      final resp = await req.close();
      if (resp.statusCode != 200) {
        await resp.drain<void>();
        return [];
      }
      final jsonStr = await resp.transform(utf8.decoder).join();
      final res = jsonDecode(jsonStr) as Map<String, dynamic>;
      final sections = res['contents']?['tabbedSearchResultsRenderer']?['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']?['contents'] as List<dynamic>? ?? [];
      final results = <Map<String, dynamic>>[];

      for (final sec in sections) {
        final musicShelf = sec['musicShelfRenderer'];
        if (musicShelf == null) continue;
        final contents = musicShelf['contents'] as List<dynamic>? ?? [];
        for (final it in contents) {
          final r = it['musicResponsiveListItemRenderer'];
          if (r == null) continue;
          final flex = r['flexColumns'] as List<dynamic>? ?? [];
          if (flex.isEmpty) continue;

          final tRuns = (flex[0]['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'] as List<dynamic>?) ?? [];
          final title = tRuns.isNotEmpty ? (tRuns[0]['text'] as String? ?? '') : '';

          final nav = r['navigationEndpoint'] ?? (tRuns.isNotEmpty ? tRuns[0]['navigationEndpoint'] : null);
          final browseId = nav?['browseEndpoint']?['browseId'] as String?;
          if (browseId == null || browseId.isEmpty) continue;

          final infoRuns = flex.length > 1
              ? ((flex[1]['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'] as List<dynamic>?) ?? [])
              : <dynamic>[];

          final parts = <String>[];
          var curr = <String>[];
          for (final x in infoRuns) {
            final t = x['text'] as String? ?? '';
            if (t == ' • ') {
              if (curr.isNotEmpty) {
                parts.add(curr.join(''));
                curr = [];
              }
            } else {
              curr.add(t);
            }
          }
          if (curr.isNotEmpty) parts.add(curr.join(''));

          String? artistName;
          int? year;

          for (final p in parts) {
            final yMatch = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(p);
            if (yMatch != null && year == null) {
              year = int.tryParse(yMatch.group(1)!);
            } else if (artistName == null) {
              final lower = p.toLowerCase();
              if (lower != 'álbum' && lower != 'album' && lower != 'ep' && lower != 'single' && lower != 'sencillo') {
                artistName = p;
              }
            }
          }

          final thumbs = (r['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] as List<dynamic>?) ?? [];
          final thumb = thumbs.isNotEmpty ? _upgradeThumbnail(thumbs.last['url'] as String?) : '';

          results.add({
            'id': browseId,
            'title': title,
            'artist': artistName,
            'year': year,
            'coverArt': thumb.isNotEmpty ? thumb : browseId,
            'thumbnailUrl': thumb,
          });

          if (results.length >= limit) break;
        }
        if (results.length >= limit) break;
      }
      if (cleanQuery.isNotEmpty && results.isNotEmpty) {
        if (_albumsCache.length > 50) _albumsCache.remove(_albumsCache.keys.first);
        _albumsCache[cleanQuery] = results;
      }
      return results;
    } catch (e) {
      debugPrint('[yt-dlp] searchYtAlbumsInnertube error: $e');
      return [];
    }
  }

  /// Queries official YouTube Music Innertube API (Artists filter) directly in pure Dart.
  Future<List<Map<String, dynamic>>> searchYtArtistsInnertube(String query, {int limit = 20}) async {
    final cleanQuery = query.trim().toLowerCase();
    if (_artistsCache.containsKey(cleanQuery)) {
      return _artistsCache[cleanQuery]!;
    }

    try {
      final req = await _innertubeHttpClient.postUrl(
        Uri.parse('https://music.youtube.com/youtubei/v1/search?prettyPrint=false&key=AIzaSyC9XL3ZjWddXya6X74dJoCTL-KLET5YdU'),
      );
      _innertubeHeaders.forEach((k, v) => req.headers.set(k, v));
      req.write(jsonEncode({
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20240918.01.00',
            'hl': 'es',
            'gl': 'US',
          }
        },
        'query': query,
        'params': 'EgWKAQIgAWoKEAUQAxAEEAkQBQ==',
      }));

      final resp = await req.close();
      if (resp.statusCode != 200) {
        await resp.drain<void>();
        return [];
      }
      final jsonStr = await resp.transform(utf8.decoder).join();
      final res = jsonDecode(jsonStr) as Map<String, dynamic>;
      final sections = res['contents']?['tabbedSearchResultsRenderer']?['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']?['contents'] as List<dynamic>? ?? [];
      final results = <Map<String, dynamic>>[];

      for (final sec in sections) {
        final musicShelf = sec['musicShelfRenderer'];
        if (musicShelf == null) continue;
        final contents = musicShelf['contents'] as List<dynamic>? ?? [];
        for (final it in contents) {
          final r = it['musicResponsiveListItemRenderer'];
          if (r == null) continue;
          final flex = r['flexColumns'] as List<dynamic>? ?? [];
          if (flex.isEmpty) continue;

          final tRuns = (flex[0]['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'] as List<dynamic>?) ?? [];
          final name = tRuns.isNotEmpty ? (tRuns[0]['text'] as String? ?? '') : '';

          final nav = r['navigationEndpoint'] ?? (tRuns.isNotEmpty ? tRuns[0]['navigationEndpoint'] : null);
          final browseId = nav?['browseEndpoint']?['browseId'] as String?;
          if (browseId == null || browseId.isEmpty || name.isEmpty) continue;

          final thumbs = (r['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] as List<dynamic>?) ?? [];
          final thumb = thumbs.isNotEmpty ? _upgradeThumbnail(thumbs.last['url'] as String?) : '';

          results.add({
            'id': browseId,
            'name': name,
            'coverArt': thumb.isNotEmpty ? thumb : browseId,
            'artistImageUrl': thumb,
          });

          if (results.length >= limit) break;
        }
        if (results.length >= limit) break;
      }
      if (cleanQuery.isNotEmpty && results.isNotEmpty) {
        if (_artistsCache.length > 50) _artistsCache.remove(_artistsCache.keys.first);
        _artistsCache[cleanQuery] = results;
      }
      return results;
    } catch (e) {
      debugPrint('[yt-dlp] searchYtArtistsInnertube error: $e');
      return [];
    }
  }

  // ── Binary Detection & Auto-Updater (Desktop) ──────────────────────────────

  bool _isUpdating = false;
  DateTime? _lastAutoRecoveryAttempt;

  bool get isUpdating => _isUpdating;
  String? get detectedYtDlpPath => _detectedYtDlpPath;

  /// Gets the version of the currently detected yt-dlp binary.
  Future<String?> getYtDlpVersion() async {
    if (kIsWeb) return null;
    await _detectBinaries();
    if (_detectedYtDlpPath != null) {
      try {
        final result = await Process.run(_detectedYtDlpPath!, ['--version']).timeout(
          const Duration(seconds: 4),
        );
        if (result.exitCode == 0) {
          return result.stdout.toString().trim();
        }
      } catch (_) {}
    }
    return null;
  }

  Completer<bool>? _ongoingUpdateCompleter;

  /// Proactively ensures that yt-dlp binary is available on desktop platforms.
  /// If not found, immediately starts background download without waiting for user action.
  Future<void> ensureBinaryAvailable() async {
    if (kIsWeb || Platform.isAndroid || Platform.isIOS) return;
    await _detectBinaries();
    if (_detectedYtDlpPath == null && _detectedPythonPath == null) {
      debugPrint('[yt-dlp] No binary found on startup. Starting initial download...');
      unawaited(updateYtDlp(force: true).catchError((e) {
        debugPrint('[yt-dlp] Initial binary download failed: $e');
        return false;
      }));
    }
  }

  void _triggerAutoRecovery() {
    if (kIsWeb || Platform.isAndroid || Platform.isIOS || _isUpdating) return;
    final now = DateTime.now();
    if (_lastAutoRecoveryAttempt != null && now.difference(_lastAutoRecoveryAttempt!) < const Duration(hours: 1)) {
      return; // Prevent spamming GitHub API if an unresolvable network issue occurs
    }
    _lastAutoRecoveryAttempt = now;
    debugPrint('[yt-dlp] Triggering background auto-recovery / update check...');
    updateYtDlp().catchError((err) {
      debugPrint('[yt-dlp] Auto-recovery update error: $err');
      return false;
    });
  }

  /// Checks and updates yt-dlp binary from official GitHub releases.
  /// Returns `true` if updated successfully, `false` otherwise.
  Future<bool> updateYtDlp({bool force = false}) async {
    if (kIsWeb) return false;
    if (Platform.isAndroid || Platform.isIOS) return false;
    if (_ongoingUpdateCompleter != null) {
      return _ongoingUpdateCompleter!.future;
    }

    final completer = Completer<bool>();
    _ongoingUpdateCompleter = completer;
    _isUpdating = true;
    try {
      final currentVersion = await getYtDlpVersion();
      debugPrint('[yt-dlp updater] Current local version: $currentVersion');

      String downloadUrl = '';
      String? latestTag;

      // 1. Try checking latest release on GitHub API (can be rate limited on clean IPs)
      try {
        final releaseUri = Uri.parse('https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest');
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
        final request = await client.getUrl(releaseUri);
        request.headers.add('User-Agent', 'GroovyMusicApp/1.0');
        request.headers.add('Accept', 'application/vnd.github.v3+json');
        final response = await request.close().timeout(const Duration(seconds: 8));

        if (response.statusCode == HttpStatus.ok) {
          final body = await utf8.decoder.bind(response).join();
          client.close();
          final releaseJson = jsonDecode(body) as Map<String, dynamic>;
          latestTag = (releaseJson['tag_name'] as String? ?? '').replaceFirst('v', '').trim();
          debugPrint('[yt-dlp updater] Latest GitHub version: $latestTag');

          if (!force && currentVersion != null && currentVersion == latestTag) {
            debugPrint('[yt-dlp updater] Already on the latest version ($currentVersion).');
            completer.complete(true);
            return true;
          }

          final assets = releaseJson['assets'] as List<dynamic>? ?? [];
          final targetAssetName = Platform.isWindows ? 'yt-dlp.exe' : (Platform.isMacOS ? 'yt-dlp_macos' : 'yt-dlp_linux');
          for (final asset in assets) {
            final name = asset['name'] as String? ?? '';
            if (name == (Platform.isWindows ? 'yt-dlp.exe' : 'yt-dlp') || name == targetAssetName) {
              downloadUrl = asset['browser_download_url'] as String? ?? '';
              break;
            }
          }
        } else {
          client.close();
          debugPrint('[yt-dlp updater] GitHub API returned HTTP ${response.statusCode}. Falling back to direct release download URL...');
        }
      } catch (e) {
        debugPrint('[yt-dlp updater] GitHub API check note: $e. Falling back to direct release download URL...');
      }

      // If GitHub API check was rate-limited or didn't find asset, use official direct download URLs
      if (downloadUrl.isEmpty) {
        downloadUrl = Platform.isWindows
            ? 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe'
            : (Platform.isMacOS
                ? 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos'
                : 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp');
      }

      debugPrint('[yt-dlp updater] Downloading from: $downloadUrl');

      // 3. Download to app support directory
      final appSupportDir = await getApplicationSupportDirectory();
      if (!await appSupportDir.exists()) {
        await appSupportDir.create(recursive: true);
      }
      final binaryName = Platform.isWindows ? 'yt-dlp.exe' : 'yt-dlp';
      final targetFile = File('${appSupportDir.path}/$binaryName');
      final tempFile = File('${appSupportDir.path}/$binaryName.tmp');

      final downloadClient = HttpClient()..connectionTimeout = const Duration(seconds: 15);
      final dlReq = await downloadClient.getUrl(Uri.parse(downloadUrl));
      dlReq.headers.add('User-Agent', 'GroovyMusicApp/1.0');
      final dlRes = await dlReq.close().timeout(const Duration(seconds: 120));

      if (dlRes.statusCode != HttpStatus.ok) {
        downloadClient.close();
        debugPrint('[yt-dlp updater] Download failed with status: ${dlRes.statusCode}');
        completer.complete(false);
        return false;
      }

      final sink = tempFile.openWrite();
      await dlRes.pipe(sink);
      downloadClient.close();

      final fileSize = await tempFile.length();
      if (fileSize < 5 * 1024 * 1024) {
        debugPrint('[yt-dlp updater] Downloaded file is too small ($fileSize bytes). Aborting.');
        if (await tempFile.exists()) await tempFile.delete();
        completer.complete(false);
        return false;
      }

      // 4. On Linux/macOS, chmod +x
      if (!Platform.isWindows) {
        try {
          await Process.run('chmod', ['+x', tempFile.path]);
        } catch (_) {}
      }

      // 5. Replace target binary
      if (await targetFile.exists()) {
        try {
          await targetFile.delete();
        } catch (_) {
          final oldBackup = File('${appSupportDir.path}/$binaryName.old');
          if (await oldBackup.exists()) await oldBackup.delete();
          await targetFile.rename(oldBackup.path);
        }
      }
      await tempFile.rename(targetFile.path);

      // Verify the new binary works
      final testResult = await Process.run(targetFile.path, ['--version']).timeout(
        const Duration(seconds: 5),
      );
      if (testResult.exitCode == 0) {
        _detectedYtDlpPath = targetFile.path;
        _detectionDone = true;
        debugPrint('[yt-dlp updater] ✅ Successfully updated/installed yt-dlp to v${testResult.stdout.toString().trim()} at ${targetFile.path}');
        completer.complete(true);
        return true;
      } else {
        debugPrint('[yt-dlp updater] ❌ New binary failed verification.');
        completer.complete(false);
        return false;
      }
    } catch (e, stack) {
      debugPrint('[yt-dlp updater] Error during update: $e\n$stack');
      completer.complete(false);
      return false;
    } finally {
      _isUpdating = false;
      _ongoingUpdateCompleter = null;
    }
  }

  Future<void> _detectBinaries() async {
    if (kIsWeb || _detectionDone || Platform.isAndroid || Platform.isIOS) return;
    _detectionDone = true;

    String? userBinaryPath;
    try {
      final appSupportDir = await getApplicationSupportDirectory();
      final binaryName = Platform.isWindows ? 'yt-dlp.exe' : 'yt-dlp';
      final file = File('${appSupportDir.path}/$binaryName');
      if (file.existsSync()) {
        userBinaryPath = file.path;
      }
    } catch (_) {}

    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final ytDlpCandidates = <String>[
      if (userBinaryPath != null) userBinaryPath,
      if (Platform.isWindows) ...[
        '$exeDir/yt-dlp.exe',
        '$exeDir/data/yt-dlp.exe',
        if (Platform.environment['ProgramFiles'] != null)
          '${Platform.environment['ProgramFiles']}\\Groovy\\yt-dlp.exe',
        if (Platform.environment['ProgramFiles(x86)'] != null)
          '${Platform.environment['ProgramFiles(x86)']}\\Groovy\\yt-dlp.exe',
        'C:\\Program Files\\Groovy\\yt-dlp.exe',
        'C:\\Program Files (x86)\\Groovy\\yt-dlp.exe',
        if (Platform.environment['LOCALAPPDATA'] != null)
          '${Platform.environment['LOCALAPPDATA']}\\Programs\\Groovy\\yt-dlp.exe',
        if (Platform.environment['APPDATA'] != null)
          '${Platform.environment['APPDATA']}\\Groovy\\yt-dlp.exe',
        if (Platform.environment['USERPROFILE'] != null)
          '${Platform.environment['USERPROFILE']}\\yt-dlp.exe',
        '$exeDir/../../../../yt-dlp.exe',
        '$exeDir/../../../yt-dlp.exe',
        '$exeDir/../../yt-dlp.exe',
        '$exeDir/../yt-dlp.exe',
        '${Directory.current.path}/yt-dlp.exe',
        '${Directory.current.path}/windows/yt-dlp.exe',
        '${Directory.current.parent.path}/yt-dlp.exe',
        'yt-dlp.exe',
      ],
      if (Platform.isLinux || Platform.isMacOS) ...[
        '$exeDir/yt-dlp',
        '${Directory.current.path}/yt-dlp',
        'yt-dlp',
      ],
      if (Platform.isMacOS) ...[
        '/opt/homebrew/bin/yt-dlp',
        '/usr/local/bin/yt-dlp',
        '/Library/Frameworks/Python.framework/Versions/3.14/bin/yt-dlp',
        '/Library/Frameworks/Python.framework/Versions/3.13/bin/yt-dlp',
        '/Library/Frameworks/Python.framework/Versions/3.12/bin/yt-dlp',
        '/Library/Frameworks/Python.framework/Versions/3.11/bin/yt-dlp',
      ],
      if (Platform.isLinux) ...[
        '/usr/bin/yt-dlp',
        '/usr/local/bin/yt-dlp',
        if (Platform.environment['HOME'] != null)
          '${Platform.environment['HOME']}/.local/bin/yt-dlp',
      ],
    ];

    for (final bin in ytDlpCandidates) {
      if (bin.contains('/') || bin.contains('\\')) {
        if (!File(bin).existsSync()) continue;
      }
      try {
        final result = await Process.run(bin, ['--version']).timeout(
          const Duration(seconds: 3),
        );
        if (result.exitCode == 0) {
          _detectedYtDlpPath = bin;
          debugPrint('[yt-dlp] Found yt-dlp binary at: $bin (v${result.stdout.toString().trim()})');
          break;
        }
      } catch (_) {}
    }

    final pythonCandidates = <String>[
      'python3',
      'python',
      if (Platform.isMacOS) ...[
        '/opt/homebrew/bin/python3',
        '/usr/local/bin/python3',
        '/usr/bin/python3',
        '/Library/Frameworks/Python.framework/Versions/3.14/bin/python3',
        '/Library/Frameworks/Python.framework/Versions/3.13/bin/python3',
        '/Library/Frameworks/Python.framework/Versions/3.12/bin/python3',
        '/Library/Frameworks/Python.framework/Versions/3.11/bin/python3',
      ],
      if (Platform.isLinux) ...[
        '/usr/bin/python3',
        '/usr/local/bin/python3',
      ],
      if (Platform.isWindows) ...[
        'python.exe',
        'python3.exe',
      ],
    ];

    for (final py in pythonCandidates) {
      try {
        final result = await Process.run(py, ['-c', 'import yt_dlp']).timeout(
          const Duration(seconds: 2),
        );
        if (result.exitCode == 0) {
          _detectedPythonPath = py;
          debugPrint('[yt-dlp] Found Python with yt_dlp module at: $py');
          break;
        }
      } catch (_) {}
    }
  }

  Process? _activeExtractionProcess;

  /// Immediately cancels and terminates any running background extraction subprocess.
  /// Called when skipping tracks so old yt-dlp instances do not hog CPU or cause UI freezing.
  void cancelCurrentExtraction() {
    if (_activeExtractionProcess != null) {
      _killProcess(_activeExtractionProcess);
      _activeExtractionProcess = null;
    }
  }

  void _killProcess(Process? process) {
    if (process == null) return;
    try {
      if (!kIsWeb && Platform.isWindows) {
        process.kill();
        Process.run('taskkill', ['/F', '/T', '/PID', '${process.pid}']).catchError((_) => ProcessResult(0, -1, '', ''));
      } else {
        process.kill(ProcessSignal.sigkill);
      }
    } catch (_) {
      try {
        process.kill();
      } catch (_) {}
    }
  }

  Future<ProcessResult?> _runProcessWithTimeout(
    String executable,
    List<String> args,
    Duration timeout,
  ) async {
    cancelCurrentExtraction();
    Process? process;
    try {
      process = await Process.start(executable, args);
      _activeExtractionProcess = process;
      final stdoutFuture = process.stdout.transform(utf8.decoder).join();
      final stderrFuture = process.stderr.transform(utf8.decoder).join();

      final exitCode = await process.exitCode.timeout(timeout);
      final stdout = await stdoutFuture;
      final stderr = await stderrFuture;

      if (_activeExtractionProcess == process) {
        _activeExtractionProcess = null;
      }
      return ProcessResult(process.pid, exitCode, stdout, stderr);
    } on TimeoutException {
      debugPrint('[yt-dlp] Process timed out ($timeout) for $executable. Killing PID ${process?.pid}...');
      _killProcess(process);
      if (_activeExtractionProcess == process) {
        _activeExtractionProcess = null;
      }
      return null;
    } catch (e) {
      debugPrint('[yt-dlp] Process error for $executable: $e');
      _killProcess(process);
      if (_activeExtractionProcess == process) {
        _activeExtractionProcess = null;
      }
      return null;
    }
  }

  Future<ProcessResult?> _runYtDlp(List<String> args, {Duration timeout = const Duration(seconds: 15)}) async {
    await _detectBinaries();

    // If binary not detected yet, but an initial download or update is in progress, wait for it!
    if (_detectedYtDlpPath == null && _detectedPythonPath == null && _ongoingUpdateCompleter != null) {
      debugPrint('[yt-dlp] Binary not ready yet; awaiting active download before running...');
      try {
        await _ongoingUpdateCompleter!.future.timeout(const Duration(seconds: 15));
      } catch (_) {}
      _detectionDone = false;
      await _detectBinaries();
    }

    if (_detectedYtDlpPath != null) {
      try {
        final result = await _runProcessWithTimeout(_detectedYtDlpPath!, args, timeout);
        if (result != null && result.exitCode == 0) return result;
      } catch (_) {}
    }

    if (_detectedPythonPath != null) {
      try {
        final result = await _runProcessWithTimeout(_detectedPythonPath!, ['-m', 'yt_dlp', ...args], timeout);
        if (result != null && result.exitCode == 0) return result;
      } catch (_) {}
    }

    return null;
  }

  // ── Stream URL Extraction ───────────────────────────────────────────────────

  /// Resolves the stream info (URL and matching HTTP headers) for [videoId].
  Future<YtStreamInfo> resolveStreamInfo(String videoId, {bool forceRefresh = false}) async {
    final cleanId = videoId.replaceFirst('ytmusic://', '').replaceFirst('yt_', '').trim();

    if (!forceRefresh) {
      final cached = _streamInfoCache[cleanId];
      if (cached != null && cached.url.isNotEmpty) {
        final age = DateTime.now().difference(_streamCacheTime[cleanId] ?? DateTime.now());
        if (age < _cacheTtl) {
          return cached;
        }
      }

      final inFlight = _inFlightResolutions[cleanId];
      if (inFlight != null) {
        return inFlight;
      }
    }

    final future = _doResolveStreamInfo(cleanId);
    _inFlightResolutions[cleanId] = future;
    try {
      return await future;
    } finally {
      _inFlightResolutions.remove(cleanId);
    }
  }

  Future<YtStreamInfo> _doResolveStreamInfo(String cleanId) async {
    // ── DESKTOP (Windows / macOS / Linux) ──────────────────────────────────
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final completer = Completer<YtStreamInfo>();

      // 1. FAST-PATH: Pure-Dart Innertube attempt (Android & iOS clients) - 1500ms fast race
      unawaited(() async {
        try {
          final manifest = await _fallbackClient.videos.streamsClient
              .getManifest(cleanId, ytClients: [
                yt.YoutubeApiClient.android,
                yt.YoutubeApiClient.ios,
                yt.YoutubeApiClient.tv,
              ])
              .timeout(const Duration(milliseconds: 1500));
          final audioOnly = manifest.audioOnly;
          if (audioOnly.isNotEmpty) {
            final best = _selectBestAudioStream(audioOnly, preferTv: true);
            final url = best.url.toString();
            if (url.isNotEmpty && !completer.isCompleted) {
              final isAndroid = url.contains('c=ANDROID');
              final isIos = url.contains('c=IOS');
              final userAgent = isAndroid
                  ? 'com.google.android.youtube/17.36.4 (Linux; U; Android 12; GB) gzip'
                  : isIos
                      ? 'com.google.ios.youtube/17.36.4 (iPhone14,3; U; CPU iOS 15_6 like Mac OS X)'
                      : 'Mozilla/5.0 (SMART-TV; LINUX; Tizen 6.0) AppleWebKit/538.1 (KHTML, like Gecko) Version/6.0 TV Safari/538.1';
              final info = YtStreamInfo(
                url: url,
                headers: {
                  'User-Agent': userAgent,
                  'Origin': 'https://www.youtube.com',
                  'Referer': 'https://www.youtube.com/',
                },
                ext: best.container.name,
              );
              _streamInfoCache[cleanId] = info;
              _streamCacheTime[cleanId] = DateTime.now();
              debugPrint('[yt-dlp/Desktop] ⚡ Resolved $cleanId via FastDart (fast path)');
              cancelCurrentExtraction();
              completer.complete(info);
              return;
            }
          }
        } catch (_) {}
      }());

      // 2. SUBPROCESS PATH: yt-dlp binary (runs concurrently from millisecond 0!)
      unawaited(() async {
        final targetUrl = cleanId.startsWith('http') ? cleanId : 'https://www.youtube.com/watch?v=$cleanId';
        try {
          final result = await _runYtDlp([
            '-j',
            '-f',
            'ba/b[acodec!=none]/bestaudio/best',
            '--no-playlist',
            '--extractor-args',
            'youtube:player_client=android,web;skip=translated_subs,comments,webpage,dash,hls,storyboards,thumbnails',
            '--no-warnings',
            '--no-check-certificates',
            targetUrl,
          ], timeout: const Duration(seconds: 8));

          if (result != null && result.exitCode == 0 && !completer.isCompleted) {
            final json = jsonDecode(result.stdout.toString().trim()) as Map<String, dynamic>;
            final url = json['url'] as String?;
            if (url != null && url.isNotEmpty) {
              final rawHeaders = json['http_headers'] as Map<String, dynamic>? ?? {};
              final headers = rawHeaders.map((k, v) => MapEntry(k.toString(), v.toString()));
              if (!headers.containsKey('User-Agent') || headers['User-Agent']!.isEmpty) {
                headers['User-Agent'] = 'com.google.android.youtube/17.36.4 (Linux; U; Android 12; GB) gzip';
              }
              final ext = json['ext'] as String? ?? 'mp4';
              final info = YtStreamInfo(url: url, headers: headers, ext: ext);
              _streamInfoCache[cleanId] = info;
              _streamCacheTime[cleanId] = DateTime.now();
              debugPrint('[yt-dlp/Desktop] ✅ Resolved $cleanId via subprocess in parallel');
              completer.complete(info);
              return;
            }
          }
        } catch (_) {}

        if (!completer.isCompleted) {
          _triggerAutoRecovery();
          try {
            final fallback = await _fallbackClient.videos.streamsClient.getManifest(cleanId).timeout(const Duration(seconds: 6));
            if (fallback.audioOnly.isNotEmpty && !completer.isCompleted) {
              final best = _selectBestAudioStream(fallback.audioOnly, preferTv: true);
              final url = best.url.toString();
              final isAndroid = url.contains('c=ANDROID');
              final isIos = url.contains('c=IOS');
              final userAgent = isAndroid
                  ? 'com.google.android.youtube/17.36.4 (Linux; U; Android 12; GB) gzip'
                  : isIos
                      ? 'com.google.ios.youtube/17.36.4 (iPhone14,3; U; CPU iOS 15_6 like Mac OS X)'
                      : 'Mozilla/5.0 (SMART-TV; LINUX; Tizen 6.0) AppleWebKit/538.1 (KHTML, like Gecko) Version/6.0 TV Safari/538.1';
              final info = YtStreamInfo(
                url: url,
                headers: {
                  'User-Agent': userAgent,
                  'Origin': 'https://www.youtube.com',
                  'Referer': 'https://www.youtube.com/',
                },
                ext: best.container.name,
              );
              completer.complete(info);
              return;
            }
          } catch (_) {}
          if (!completer.isCompleted) {
            completer.completeError(Exception('All Desktop stream extraction methods exhausted for $cleanId'));
          }
        }
      }());

      return completer.future;
    }

    // ── ANDROID: FastDart + Chaquopy in PARALLEL RACE (Zero dead wait!) ───
    if (!kIsWeb && Platform.isAndroid) {
      final completer = Completer<YtStreamInfo>();

      // 1. FAST-PATH: Pure-Dart Innertube attempt (3500ms timeout)
      unawaited(() async {
        try {
          final manifest = await _fallbackClient.videos.streamsClient
              .getManifest(cleanId, ytClients: [
                yt.YoutubeApiClient.android,
                yt.YoutubeApiClient.tv,
                yt.YoutubeApiClient.ios,
              ])
              .timeout(const Duration(milliseconds: 3500));
          final audioOnly = manifest.audioOnly;
          if (audioOnly.isNotEmpty) {
            final best = _selectBestAudioStream(audioOnly);
            final url = best.url.toString();
            if (url.isNotEmpty && !completer.isCompleted) {
              final isAndroid = url.contains('c=ANDROID');
              final isIos = url.contains('c=IOS');
              final userAgent = isAndroid
                  ? 'com.google.android.youtube/17.36.4 (Linux; U; Android 12; GB) gzip'
                  : isIos
                      ? 'com.google.ios.youtube/17.36.4 (iPhone14,3; U; CPU iOS 15_6 like Mac OS X)'
                      : 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36';
              final info = YtStreamInfo(
                url: url,
                headers: {
                  'User-Agent': userAgent,
                  'Origin': 'https://www.youtube.com',
                  'Referer': 'https://www.youtube.com/',
                },
                ext: best.container.name,
              );
              _streamInfoCache[cleanId] = info;
              _streamCacheTime[cleanId] = DateTime.now();
              debugPrint('[yt-dlp/Android] ⚡ Resolved $cleanId via FastDart');
              completer.complete(info);
              return;
            }
          }
        } catch (_) {}
      }());

      // 2. CHAQUOPY PYTHON: starts at millisecond 0 concurrently!
      unawaited(() async {
        try {
          final jsonStr = await _androidChannel
              .invokeMethod<String>('getStreamUrl', {'videoId': cleanId})
              .timeout(const Duration(seconds: 8));
          if (jsonStr != null && jsonStr.isNotEmpty && !completer.isCompleted) {
            final data = jsonDecode(jsonStr) as Map<String, dynamic>;
            final url = data['url'] as String? ?? '';
            if (url.isNotEmpty && url.startsWith('http')) {
              final rawHeaders = (data['headers'] ?? data['http_headers']) as Map<String, dynamic>? ?? {};
              final headers = rawHeaders.map((k, v) => MapEntry(k.toString(), v.toString()));
              final ext = data['ext'] as String? ?? 'mp4';
              final info = YtStreamInfo(url: url, headers: headers, ext: ext);
              _streamInfoCache[cleanId] = info;
              _streamCacheTime[cleanId] = DateTime.now();
              debugPrint('[yt-dlp/Android Python] ✅ Resolved $cleanId via Chaquopy');
              completer.complete(info);
              return;
            }
          }
        } catch (_) {}

        if (!completer.isCompleted) {
          try {
            final fallback = await _fallbackClient.videos.streamsClient
                .getManifest(cleanId)
                .timeout(const Duration(seconds: 6));
            if (fallback.audioOnly.isNotEmpty && !completer.isCompleted) {
              final best = _selectBestAudioStream(fallback.audioOnly);
              final url = best.url.toString();
              final isAndroid = url.contains('c=ANDROID');
              final isIos = url.contains('c=IOS');
              final userAgent = isAndroid
                  ? 'com.google.android.youtube/17.36.4 (Linux; U; Android 12; GB) gzip'
                  : isIos
                      ? 'com.google.ios.youtube/17.36.4 (iPhone14,3; U; CPU iOS 15_6 like Mac OS X)'
                      : 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36';
              final info = YtStreamInfo(
                url: url,
                headers: {
                  'User-Agent': userAgent,
                  'Origin': 'https://www.youtube.com',
                  'Referer': 'https://www.youtube.com/',
                },
                ext: best.container.name,
              );
              _streamInfoCache[cleanId] = info;
              _streamCacheTime[cleanId] = DateTime.now();
              completer.complete(info);
              return;
            }
          } catch (_) {}
          if (!completer.isCompleted) {
            completer.completeError(Exception('Failed to resolve Android stream for $cleanId'));
          }
        }
      }());

      return completer.future;
    }

    // Fallback: Pure-Dart Innertube via TV, iOS, and Android clients
    // (used when yt-dlp subprocess / Chaquopy not available)
    try {
      final manifest = await _fallbackClient.videos.streamsClient
          .getManifest(cleanId, ytClients: [
            yt.YoutubeApiClient.tv,
            yt.YoutubeApiClient.ios,
            yt.YoutubeApiClient.android,
          ])
          .timeout(const Duration(seconds: 12));
      final audioOnly = manifest.audioOnly;
      if (audioOnly.isNotEmpty) {
        final best = _selectBestAudioStream(audioOnly);
        final url = best.url.toString();
        if (url.isNotEmpty) {
          final isAndroid = url.contains('&c=ANDROID') || url.contains('c=ANDROID');
          final isTv = url.contains('&c=TVHTML5') || url.contains('c=TVHTML5');
          final isIos = url.contains('&c=IOS') || url.contains('c=IOS');
          final userAgent = isAndroid
              ? 'com.google.android.youtube/17.36.4 (Linux; U; Android 12; GB) gzip'
              : isIos
                  ? 'com.google.ios.youtube/17.36.4 (iPhone14,3; U; CPU iOS 15_6 like Mac OS X)'
                  : isTv
                      ? 'Mozilla/5.0 (SMART-TV; LINUX; Tizen 6.0) AppleWebKit/538.1 (KHTML, like Gecko) Version/6.0 TV Safari/538.1'
                      : 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
          final info = YtStreamInfo(
            url: url,
            headers: {
              'User-Agent': userAgent,
              'Origin': 'https://www.youtube.com',
              'Referer': 'https://www.youtube.com/',
            },
            ext: best.container.name,
          );
          _streamInfoCache[cleanId] = info;
          _streamCacheTime[cleanId] = DateTime.now();
          debugPrint('[yt-dlp/FastDart] Resolved $cleanId (${isAndroid ? "Android" : isIos ? "iOS" : isTv ? "TV" : "Web"} client UA) [fallback]');
          return info;
        }
      }
    } catch (e) {
      debugPrint('[yt-dlp/FastDart] Dart client fallback for $cleanId: $e');
    }


    // 3. Final Dart Innertube fallback chains (TV, iOS, Android, Web clients)
    final clientSets = [
      [yt.YoutubeApiClient.tv, yt.YoutubeApiClient.mediaConnect],
      [yt.YoutubeApiClient.ios, yt.YoutubeApiClient.android],
      null,
    ];

    for (final clientList in clientSets) {
      try {
        final manifest = await _fallbackClient.videos.streamsClient
            .getManifest(cleanId, ytClients: clientList)
            .timeout(const Duration(seconds: 10));
        final audioOnly = manifest.audioOnly;
        if (audioOnly.isNotEmpty) {
          final best = _selectBestAudioStream(audioOnly);
          final url = best.url.toString();
          final isAndroid = url.contains('&c=ANDROID') || url.contains('c=ANDROID');
          final isTv = url.contains('&c=TVHTML5') || url.contains('c=TVHTML5');
          final isIos = url.contains('&c=IOS') || url.contains('c=IOS');
          final userAgent = isAndroid
              ? 'com.google.android.youtube/17.36.4 (Linux; U; Android 12; GB) gzip'
              : isIos
                  ? 'com.google.ios.youtube/17.36.4 (iPhone14,3; U; CPU iOS 15_6 like Mac OS X)'
                  : isTv
                      ? 'Mozilla/5.0 (SMART-TV; LINUX; Tizen 6.0) AppleWebKit/538.1 (KHTML, like Gecko) Version/6.0 TV Safari/538.1'
                      : 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
          final info = YtStreamInfo(
            url: url,
            headers: {
              'User-Agent': userAgent,
              'Origin': 'https://www.youtube.com',
              'Referer': 'https://www.youtube.com/',
            },
            ext: best.container.name,
          );
          _streamInfoCache[cleanId] = info;
          _streamCacheTime[cleanId] = DateTime.now();
          debugPrint('[yt-dlp/Innertube] Fallback resolved $cleanId (${isAndroid ? "Android" : isIos ? "iOS" : isTv ? "TV" : "Web"} UA)');
          return info;
        }
      } catch (e) {
        debugPrint('[yt-dlp/Innertube] Pure-Dart fallback note for $cleanId: $e');
      }
    }

    throw Exception('No audio streams available for video $cleanId');
  }

  /// Extracts the direct audio stream URL for a given [videoId].
  Future<String> resolveStreamUrl(String videoId, {bool forceRefresh = false}) async {
    final info = await resolveStreamInfo(videoId, forceRefresh: forceRefresh);
    return info.url;
  }

  // ── Search & Discovery ──────────────────────────────────────────────────────

  /// Internal helper: search via youtube_explode_dart, works even when
  /// Innertube is blocked on server/VPS IPs (common on Linux deployments).
  Future<List<Map<String, dynamic>>> _searchYoutubeExplodeFallback(String query, {int limit = 100}) async {
    try {
      final searchResults = await _fallbackClient.search
          .search(query, filter: yt.TypeFilters.video)
          .timeout(const Duration(seconds: 10));
      return searchResults.take(limit).map((v) {
        final music = v.musicData.isNotEmpty ? v.musicData.first : null;
        String? thumb;
        try {
          thumb = v.thumbnails.highResUrl;
        } catch (_) {
          thumb = 'https://i.ytimg.com/vi/${v.id.value}/hqdefault.jpg';
        }
        return <String, dynamic>{
          'id': v.id.value,
          'title': music?.song ?? v.title,
          'artist': music?.artist ?? v.author,
          'album': music?.album,
          'duration': v.duration?.inSeconds,
          'coverArt': v.id.value,
          'thumbnailUrl': thumb,
        };
      }).toList();
    } catch (e) {
      debugPrint('[yt-dlp/ExplodeFallback] error: $e');
      return [];
    }
  }

  /// Dual search: returns a map with 'music' and 'youtube' lists of tracks.
  Future<Map<String, List<Map<String, dynamic>>>> searchDual(String query, {int limit = 100}) async {
    final cleanQuery = query.trim().toLowerCase();
    if (_dualSearchCache.containsKey(cleanQuery)) {
      return _dualSearchCache[cleanQuery]!;
    }

    // 1. FAST Innertube APIs in parallel (200-300ms pure HTTP REST) - Instant on all platforms!
    try {
      final ytLimit = limit < 30 ? limit : 30;
      final results = await Future.wait([
        searchYtMusicInnertube(query, limit: limit),
        searchYoutubeVideoInnertube(query, limit: ytLimit),
      ]).timeout(const Duration(seconds: 8));
      final musicTracks = results[0];
      final ytTracks = results[1];

      if (musicTracks.isNotEmpty || ytTracks.isNotEmpty) {
        final res = <String, List<Map<String, dynamic>>>{
          'music': musicTracks,
          'youtube': ytTracks,
        };
        debugPrint('[yt-dlp/Dual] Fast search "$query": ${musicTracks.length} music, ${ytTracks.length} youtube');
        if (cleanQuery.isNotEmpty) _dualSearchCache[cleanQuery] = res;
        return res;
      }
    } catch (e) {
      debugPrint('[yt-dlp/Dual] Fast search note: $e');
    }

    // 2. Android: Execute embedded Python interpreter with yt-dlp (Chaquopy) as fallback only
    if (Platform.isAndroid) {
      try {
        final jsonStr = await _androidChannel.invokeMethod<String>('searchDual', {
          'query': query,
          'limit': limit,
        });
        if (jsonStr != null && jsonStr.isNotEmpty) {
          final dualResult = await compute(_decodeDualSearch, jsonStr);
          debugPrint('[yt-dlp/Android Python] Dual search "$query": ${dualResult['music']?.length ?? 0} music, ${dualResult['youtube']?.length ?? 0} youtube');
          if (cleanQuery.isNotEmpty && ((dualResult['music']?.isNotEmpty ?? false) || (dualResult['youtube']?.isNotEmpty ?? false))) {
            _dualSearchCache[cleanQuery] = dualResult;
          }
          return dualResult;
        }
      } catch (e) {
        debugPrint('[yt-dlp/Android Python] searchDual error: $e');
      }
    }

    // 2b. Fallback to youtube_explode_dart if Innertube was blocked or empty
    try {
      final explodeTracks = await _searchYoutubeExplodeFallback(query, limit: limit).timeout(const Duration(seconds: 6));
      if (explodeTracks.isNotEmpty) {
        final res = <String, List<Map<String, dynamic>>>{
          'music': explodeTracks,
          'youtube': explodeTracks,
        };
        if (cleanQuery.isNotEmpty) _dualSearchCache[cleanQuery] = res;
        return res;
      }
    } catch (_) {}

    // 3. Fallback: Process execution or youtube_explode_dart only
    try {
      final results = await Future.wait([
        search('$query audio', limit: limit),
        search(query, limit: limit),
      ]);
      final res = {
        'music': results[0],
        'youtube': results[1],
      };
      if (cleanQuery.isNotEmpty) _dualSearchCache[cleanQuery] = res;
      return res;
    } catch (_) {
      final single = await search(query, limit: limit);
      final res = {
        'music': single,
        'youtube': single,
      };
      if (cleanQuery.isNotEmpty) _dualSearchCache[cleanQuery] = res;
      return res;
    }
  }

  /// Searches YouTube / YouTube Music for tracks matching [query].
  Future<List<Map<String, dynamic>>> search(String query, {int limit = 100}) async {
    final cleanQuery = query.trim().toLowerCase();
    if (_searchCache.containsKey(cleanQuery)) {
      return _searchCache[cleanQuery]!;
    }

    // 1. Fast Innertube API first (200-400ms) - Instant on all platforms!
    try {
      final musicItems = await searchYtMusicInnertube(query, limit: limit).timeout(const Duration(seconds: 10));
      if (musicItems.isNotEmpty) {
        debugPrint('[yt-dlp/Search] Fast Innertube "$query" returned ${musicItems.length} items');
        _searchCache[cleanQuery] = musicItems;
        return musicItems;
      }
      final ytItems = await searchYoutubeVideoInnertube(query, limit: limit).timeout(const Duration(seconds: 10));
      if (ytItems.isNotEmpty) {
        debugPrint('[yt-dlp/Innertube] Fast video search "$query" returned ${ytItems.length} items');
        _searchCache[cleanQuery] = ytItems;
        return ytItems;
      }
    } catch (e) {
      debugPrint('[yt-dlp/Innertube] Fast search note: $e');
    }

    // 2. Android: Execute embedded Python interpreter with yt-dlp (Chaquopy) as fallback only
    if (Platform.isAndroid) {
      try {
        final jsonStr = await _androidChannel.invokeMethod<String>('search', {
          'query': query,
          'limit': limit,
        });
        if (jsonStr != null && jsonStr.isNotEmpty) {
          final items = await compute(_decodeJsonList, jsonStr);
          if (items.isNotEmpty) {
            debugPrint('[yt-dlp/Android Python] Search "$query" returned ${items.length} items');
            _searchCache[cleanQuery] = items;
            return items;
          }
        }
      } catch (e) {
        debugPrint('[yt-dlp/Android Python] Search error: $e');
      }
    }

    // 2b. Fallback to youtube_explode_dart if Innertube empty
    try {
      final explodeItems = await _searchYoutubeExplodeFallback(query, limit: limit).timeout(const Duration(seconds: 5));
      if (explodeItems.isNotEmpty) {
        _searchCache[cleanQuery] = explodeItems;
        return explodeItems;
      }
    } catch (_) {}

    // 3. Desktop: Execute host Python / yt-dlp subprocess
    final searchParam = 'ytsearch$limit:$query';
    try {
      final result = await _runYtDlp([
        searchParam,
        '--dump-json',
        '--flat-playlist',
        '--no-warnings',
        '--no-check-certificates',
      ], timeout: const Duration(seconds: 15));

      if (result != null && result.exitCode == 0) {
        final lines = result.stdout.toString().trim().split('\n');
        final items = <Map<String, dynamic>>[];

        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          try {
            final json = jsonDecode(trimmed) as Map<String, dynamic>;
            final id = json['id'] as String? ?? json['url'] as String?;
            if (id == null || id.isEmpty) continue;

            final title = json['title'] as String? ?? 'Unknown Title';
            final uploader = json['uploader'] as String? ??
                json['channel'] as String? ??
                json['artist'] as String? ??
                'Unknown Artist';
            final durationSec = (json['duration'] is num)
                ? (json['duration'] as num).toInt()
                : null;
            final thumbnails = json['thumbnails'] as List<dynamic>?;
            String? thumbUrl;
            if (thumbnails != null && thumbnails.isNotEmpty) {
              final last = thumbnails.last;
              if (last is Map && last['url'] != null) {
                thumbUrl = last['url'].toString();
              }
            }

            items.add({
              'id': id,
              'title': title,
              'artist': uploader,
              'album': json['album'] as String?,
              'duration': durationSec,
              'coverArt': id,
              'thumbnailUrl': thumbUrl,
            });
          } catch (_) {}
        }

        if (items.isNotEmpty) {
          debugPrint('[yt-dlp/Desktop Python] Search "$query" returned ${items.length} items');
          return items;
        }
      }
    } catch (e) {
      debugPrint('[yt-dlp/Desktop Python] Search error: $e');
    }

    // 4. Fallback to youtube_explode_dart
    debugPrint('[yt-dlp] Falling back to youtube_explode_dart search');
    final searchResults = await _fallbackClient.search.search(
      query,
      filter: yt.TypeFilters.video,
    );

    return searchResults.take(limit).map((v) {
      final music = v.musicData.isNotEmpty ? v.musicData.first : null;
      return <String, dynamic>{
        'id': v.id.value,
        'title': music?.song ?? v.title,
        'artist': music?.artist ?? v.author,
        'album': music?.album,
        'duration': v.duration?.inSeconds,
        'coverArt': v.id.value,
        'thumbnailUrl': v.thumbnails.highResUrl,
      };
    }).toList();
  }

  // ── Playlist Retrieval ──────────────────────────────────────────────────────

  /// Extracts songs from a YouTube playlist.
  Future<List<Map<String, dynamic>>> getPlaylistVideos(String playlistId, {int limit = 100}) async {
    // 1. Android: Execute embedded Python interpreter with yt-dlp (Chaquopy)
    if (Platform.isAndroid) {
      try {
        final jsonStr = await _androidChannel.invokeMethod<String>('getPlaylist', {
          'playlistId': playlistId,
          'limit': limit,
        });
        if (jsonStr != null && jsonStr.isNotEmpty) {
          final items = await compute(_decodeJsonList, jsonStr);
          if (items.isNotEmpty) {
            return items;
          }
        }
      } catch (e) {
        debugPrint('[yt-dlp/Android Python] getPlaylist error: $e');
      }
    }

    // 2. Desktop: Execute host Python / yt-dlp subprocess
    final playlistUrl = playlistId.startsWith('http')
        ? playlistId
        : 'https://www.youtube.com/playlist?list=$playlistId';

    try {
      final result = await _runYtDlp([
        playlistUrl,
        '--dump-json',
        '--flat-playlist',
        '--no-warnings',
        '--no-check-certificates',
      ], timeout: const Duration(seconds: 20));

      if (result != null && result.exitCode == 0) {
        final lines = result.stdout.toString().trim().split('\n');
        final items = <Map<String, dynamic>>[];

        for (final line in lines.take(limit)) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          try {
            final json = jsonDecode(trimmed) as Map<String, dynamic>;
            final id = json['id'] as String? ?? json['url'] as String?;
            if (id == null || id.isEmpty) continue;

            final title = json['title'] as String? ?? 'Unknown Title';
            final uploader = json['uploader'] as String? ??
                json['channel'] as String? ??
                json['artist'] as String? ??
                'Unknown Artist';
            final durationSec = (json['duration'] is num)
                ? (json['duration'] as num).toInt()
                : null;

            items.add({
              'id': id,
              'title': title,
              'artist': uploader,
              'album': json['album'] as String?,
              'duration': durationSec,
              'coverArt': id,
            });
          } catch (_) {}
        }

        if (items.isNotEmpty) {
          return items;
        }
      }
    } catch (e) {
      debugPrint('[yt-dlp/Desktop Python] getPlaylist error: $e');
    }

    // 3. Fallback to youtube_explode_dart
    final videos = await _fallbackClient.playlists.getVideos(playlistId).take(limit).toList();
    return videos.map((v) {
      final music = v.musicData.isNotEmpty ? v.musicData.first : null;
      return <String, dynamic>{
        'id': v.id.value,
        'title': music?.song ?? v.title,
        'artist': music?.artist ?? v.author,
        'album': music?.album,
        'duration': v.duration?.inSeconds,
        'coverArt': v.id.value,
        'thumbnailUrl': v.thumbnails.highResUrl,
      };
    }).toList();
  }

  /// Queries official YouTube Music Innertube next endpoint directly in pure Dart (200-300ms).
  /// Returns radio / recommended tracks seeded by [videoId].
  Future<List<Map<String, dynamic>>> getRadioTracksInnertube(
    String videoId, {
    int limit = 50,
  }) async {
    final cleanId = videoId.replaceFirst('ytmusic://', '');
    try {
      final req = await _innertubeHttpClient.postUrl(
        Uri.parse(
          'https://music.youtube.com/youtubei/v1/next?prettyPrint=false&key=AIzaSyC9XL3ZjWddXya6X74dJoCTL-KLET5YdU',
        ),
      );
      _innertubeHeaders.forEach((k, v) => req.headers.set(k, v));

      req.write(jsonEncode({
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20240918.01.00',
            'hl': 'es',
            'gl': 'US',
          }
        },
        'enablePersistentPlaylistPanel': true,
        'isAudioOnly': true,
        'playlistId': 'RDAMVM$cleanId',
        'videoId': cleanId,
      }));

      final resp = await req.close().timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) {
        resp.drain<void>().catchError((_) {});
        return [];
      }

      final jsonStr = await resp.transform(utf8.decoder).join();
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      final results = <Map<String, dynamic>>[];
      final seenIds = <String>{cleanId};
      final seenTitles = <String>{};

      void findTracks(dynamic obj) {
        if (results.length >= limit) return;
        if (obj is Map<String, dynamic>) {
          if (obj.containsKey('playlistPanelVideoRenderer')) {
            final item = obj['playlistPanelVideoRenderer'] as Map<String, dynamic>;
            final vid = item['videoId'] as String?;
            if (vid != null && vid.isNotEmpty && !seenIds.contains(vid)) {
              seenIds.add(vid);

              final titleRuns = item['title']?['runs'] as List<dynamic>?;
              final title = (titleRuns != null && titleRuns.isNotEmpty)
                  ? titleRuns.first['text']?.toString() ?? 'Unknown Title'
                  : 'Unknown Title';

              final normTitle = SongTitleUtils.normalizeTitle(title);
              if (normTitle.isNotEmpty && seenTitles.contains(normTitle)) {
                return;
              }
              if (normTitle.isNotEmpty) {
                seenTitles.add(normTitle);
              }

              String artist = 'Unknown Artist';
              final shortByline = item['shortBylineText']?['runs'] as List<dynamic>?;
              if (shortByline != null && shortByline.isNotEmpty) {
                artist = shortByline.first['text']?.toString() ?? 'Unknown Artist';
              } else {
                final longByline = item['longBylineText']?['runs'] as List<dynamic>?;
                if (longByline != null && longByline.isNotEmpty) {
                  artist = longByline.first['text']?.toString() ?? 'Unknown Artist';
                }
              }

              int? durationSec;
              final lengthRuns = item['lengthText']?['runs'] as List<dynamic>?;
              if (lengthRuns != null && lengthRuns.isNotEmpty) {
                final lenStr = lengthRuns.first['text']?.toString();
                if (lenStr != null && lenStr.contains(':')) {
                  final parts = lenStr.split(':').map((p) => int.tryParse(p) ?? 0).toList();
                  if (parts.length == 2) {
                    durationSec = parts[0] * 60 + parts[1];
                  } else if (parts.length == 3) {
                    durationSec = parts[0] * 3600 + parts[1] * 60 + parts[2];
                  }
                }
              }

              String? thumbUrl;
              final thumbs = item['thumbnail']?['thumbnails'] as List<dynamic>?;
              if (thumbs != null && thumbs.isNotEmpty) {
                final last = thumbs.last;
                if (last is Map && last['url'] != null) {
                  thumbUrl = _upgradeThumbnail(last['url'].toString());
                }
              }

              results.add({
                'id': vid,
                'title': title,
                'artist': artist,
                'album': null,
                'duration': durationSec,
                'coverArt': vid,
                'thumbnailUrl': thumbUrl ?? 'https://i.ytimg.com/vi/$vid/hqdefault.jpg',
              });
            }
          } else {
            obj.forEach((k, v) => findTracks(v));
          }
        } else if (obj is List) {
          for (final it in obj) {
            findTracks(it);
          }
        }
      }

      findTracks(map);
      debugPrint('[yt-dlp/Innertube] getRadioTracksInnertube for $cleanId returned ${results.length} tracks');
      return results;
    } catch (e) {
      debugPrint('[yt-dlp/Innertube] getRadioTracksInnertube error: $e');
      return [];
    }
  }

  /// Fetches similar tracks / song radio using YouTube Music automatic radio playlist (RDAMVM / RD)
  Future<List<Map<String, dynamic>>> getRadioTracks(String videoId, {int limit = 50}) async {
    final cleanId = videoId.replaceFirst('ytmusic://', '');

    // 0. Ultra-fast Native Dart Innertube REST (200-300ms) - Instant on all platforms (Android & Windows)!
    try {
      final innertubeResults = await getRadioTracksInnertube(cleanId, limit: limit);
      if (innertubeResults.isNotEmpty) {
        return innertubeResults;
      }
    } catch (e) {
      debugPrint('[yt-dlp] getRadioTracksInnertube fast path fallback: $e');
    }

    final radioUrl = 'https://music.youtube.com/playlist?list=RDAMVM$cleanId';
    final fallbackRadioUrl = 'https://www.youtube.com/watch?v=$cleanId&list=RD$cleanId';

    // 1. Android: Chaquopy Python
    if (Platform.isAndroid) {
      try {
        final jsonStr = await _androidChannel.invokeMethod<String>('getPlaylist', {
          'playlistId': 'RDAMVM$videoId',
          'limit': limit,
        });
        if (jsonStr != null && jsonStr.isNotEmpty) {
          final items = await compute(_decodeJsonList, jsonStr);
          if (items.isNotEmpty) return items;
        }
      } catch (e) {
        debugPrint('[yt-dlp/Android Python] getRadioTracks RDAMVM error: $e');
      }

      // Try RD fallback on Android
      try {
        final jsonStr = await _androidChannel.invokeMethod<String>('getPlaylist', {
          'playlistId': fallbackRadioUrl,
          'limit': limit,
        });
        if (jsonStr != null && jsonStr.isNotEmpty) {
          final items = await compute(_decodeJsonList, jsonStr);
          if (items.isNotEmpty) return items;
        }
      } catch (_) {}
    }

    // 2. Desktop: Subprocess execution with yt-dlp
    final urlsToTry = [radioUrl, fallbackRadioUrl];
    for (final url in urlsToTry) {
      try {
        final result = await _runYtDlp([
          '--flat-playlist',
          '--dump-json',
          '--playlist-items',
          '1:$limit',
          '--no-warnings',
          '--no-check-certificates',
          url,
        ], timeout: const Duration(seconds: 15));

        if (result != null && result.exitCode == 0) {
          final lines = result.stdout.toString().trim().split('\n');
          final items = <Map<String, dynamic>>[];

          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.isEmpty) continue;
            try {
              final json = jsonDecode(trimmed) as Map<String, dynamic>;
              final id = json['id'] as String? ?? json['url'] as String?;
              if (id == null || id.isEmpty) continue;

              final title = json['title'] as String? ?? 'Unknown Title';
              final uploader = json['uploader'] as String? ??
                  json['channel'] as String? ??
                  json['artist'] as String? ??
                  'Unknown Artist';
              final durationSec = (json['duration'] is num)
                  ? (json['duration'] as num).toInt()
                  : null;
              final thumbnails = json['thumbnails'] as List<dynamic>?;
              String? thumbUrl;
              if (thumbnails != null && thumbnails.isNotEmpty) {
                final last = thumbnails.last;
                if (last is Map && last['url'] != null) {
                  thumbUrl = last['url'].toString();
                }
              }

              items.add({
                'id': id,
                'title': title,
                'artist': uploader,
                'album': json['album'] as String?,
                'duration': durationSec,
                'coverArt': id,
                'thumbnailUrl': thumbUrl,
              });
            } catch (_) {}
          }

          if (items.isNotEmpty) {
            return items;
          }
        }
      } catch (e) {
        debugPrint('[yt-dlp/Desktop Python] getRadioTracks error for $url: $e');
      }
    }

    return [];
  }

  // ── Video Metadata ──────────────────────────────────────────────────────────

  /// Fetches metadata for a single video.
  Future<Map<String, dynamic>?> getVideoInfo(String videoId) async {
    final cleanId = videoId.replaceFirst('ytmusic://', '');

    // 1. Android: Execute embedded Python interpreter with yt-dlp (Chaquopy)
    if (Platform.isAndroid) {
      try {
        final jsonStr = await _androidChannel.invokeMethod<String>('getVideoInfo', {
          'videoId': cleanId,
        });
        if (jsonStr != null && jsonStr.isNotEmpty) {
          final map = await compute(_decodeJsonMap, jsonStr);
          return map;
        }
      } catch (e) {
        debugPrint('[yt-dlp/Android Python] getVideoInfo error: $e');
      }
    }

    // 2. Desktop: Execute host Python / yt-dlp subprocess
    final targetUrl = cleanId.startsWith('http') ? cleanId : 'https://www.youtube.com/watch?v=$cleanId';

    try {
      final result = await _runYtDlp([
        '-j',
        '--no-warnings',
        '--no-check-certificates',
        targetUrl,
      ], timeout: const Duration(seconds: 10));

      if (result != null && result.exitCode == 0) {
        final json = jsonDecode(result.stdout.toString().trim()) as Map<String, dynamic>;
        final title = json['title'] as String? ?? 'Unknown Title';
        final artist = json['uploader'] as String? ?? json['channel'] as String? ?? 'Unknown Artist';
        final duration = (json['duration'] is num) ? (json['duration'] as num).toInt() : null;

        return {
          'id': cleanId,
          'title': title,
          'artist': artist,
          'album': json['album'] as String?,
          'duration': duration,
          'coverArt': cleanId,
        };
      }
    } catch (_) {}

    // 3. Fallback to youtube_explode_dart
    try {
      final video = await _fallbackClient.videos.get(cleanId);
      final music = video.musicData.isNotEmpty ? video.musicData.first : null;
      return {
        'id': video.id.value,
        'title': music?.song ?? video.title,
        'artist': music?.artist ?? video.author,
        'album': music?.album,
        'duration': video.duration?.inSeconds,
        'coverArt': video.id.value,
      };
    } catch (e) {
      debugPrint('[yt-dlp] getVideoInfo fallback error: $e');
      return null;
    }
  }
}
