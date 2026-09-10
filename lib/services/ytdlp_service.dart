import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

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
  static const Duration _cacheTtl = Duration(hours: 5, minutes: 30);

  // Search Caches: query -> result
  final Map<String, Map<String, List<Map<String, dynamic>>>> _dualSearchCache = {};
  final Map<String, List<Map<String, dynamic>>> _searchCache = {};

  // Cached paths for detected binaries on desktop
  String? _detectedYtDlpPath;
  String? _detectedPythonPath;
  bool _detectionDone = false;

  yt.YoutubeExplode get _fallbackClient {
    _fallbackYt ??= yt.YoutubeExplode();
    return _fallbackYt!;
  }

  void dispose() {
    _fallbackYt?.close();
    _fallbackYt = null;
    _streamInfoCache.clear();
    _streamCacheTime.clear();
  }

  yt.AudioStreamInfo _selectBestAudioStream(Iterable<yt.AudioStreamInfo> audioStreams) {
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
  }

  // ── Native Dart Innertube Helpers (Windows / Desktop / Fallback) ────────────

  static final HttpClient _innertubeHttpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8)
    ..idleTimeout = const Duration(seconds: 15);

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
    upgraded = upgraded.replaceAll(RegExp(r'=(w\d+-h\d+|s\d+)[^/]*'), '=w1200-h1200-l90-rj');
    upgraded = upgraded.replaceAll('/mqdefault.jpg', '/sddefault.jpg');
    upgraded = upgraded.replaceAll('/default.jpg', '/sddefault.jpg');
    upgraded = upgraded.replaceAll('/hqdefault.jpg', '/sddefault.jpg');
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

  /// Queries official YouTube Music Innertube API (Songs filter) directly in pure Dart.
  Future<List<Map<String, dynamic>>> searchYtMusicInnertube(String query, {int limit = 25}) async {
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

      for (final sec in sections) {
        final musicShelf = sec['musicShelfRenderer'];
        if (musicShelf == null) continue;
        final contents = musicShelf['contents'] as List<dynamic>? ?? [];
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
        if (results.length >= limit) break;
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
      return results;
    } catch (e) {
      debugPrint('[yt-dlp] searchYtAlbumsInnertube error: $e');
      return [];
    }
  }

  /// Queries official YouTube Music Innertube API (Artists filter) directly in pure Dart.
  Future<List<Map<String, dynamic>>> searchYtArtistsInnertube(String query, {int limit = 20}) async {
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
      return results;
    } catch (e) {
      debugPrint('[yt-dlp] searchYtArtistsInnertube error: $e');
      return [];
    }
  }

  // ── Binary Detection (Desktop) ──────────────────────────────────────────────

  Future<void> _detectBinaries() async {
    if (kIsWeb || _detectionDone || Platform.isAndroid || Platform.isIOS) return;
    _detectionDone = true;

    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final ytDlpCandidates = <String>[
      if (Platform.isWindows) ...[
        '$exeDir/yt-dlp.exe',
        '${Directory.current.path}/yt-dlp.exe',
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
        '~/.local/bin/yt-dlp',
      ],
    ];

    for (final bin in ytDlpCandidates) {
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

  // ── Process Execution Helper (Desktop) ──────────────────────────────────────

  Future<ProcessResult?> _runYtDlp(List<String> args, {Duration timeout = const Duration(seconds: 20)}) async {
    await _detectBinaries();

    if (_detectedYtDlpPath != null) {
      try {
        final result = await Process.run(_detectedYtDlpPath!, args).timeout(timeout);
        if (result.exitCode == 0) return result;
      } catch (_) {}
    }

    if (_detectedPythonPath != null) {
      try {
        final result = await Process.run(_detectedPythonPath!, ['-m', 'yt_dlp', ...args]).timeout(timeout);
        if (result.exitCode == 0) return result;
      } catch (_) {}
    }

    return null;
  }

  // ── Stream URL Extraction ───────────────────────────────────────────────────

  /// Resolves the stream info (URL and matching HTTP headers) for [videoId].
  Future<YtStreamInfo> resolveStreamInfo(String videoId, {bool forceRefresh = false}) async {
    final cleanId = videoId.replaceFirst('ytmusic://', '');

    if (!forceRefresh) {
      final cached = _streamInfoCache[cleanId];
      if (cached != null) {
        final age = DateTime.now().difference(_streamCacheTime[cleanId] ?? DateTime.now());
        if (age < _cacheTtl) {
          return cached;
        }
      }
    }

    // 1. Android: Execute embedded Python interpreter with yt-dlp (Chaquopy)
    if (Platform.isAndroid) {
      try {
        final jsonStr = await _androidChannel
            .invokeMethod<String>('getStreamUrl', {'videoId': cleanId})
            .timeout(const Duration(seconds: 15));
        if (jsonStr != null && jsonStr.isNotEmpty) {
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          final url = data['url'] as String? ?? '';
          if (url.isNotEmpty) {
            final rawHeaders = data['headers'] as Map<String, dynamic>? ?? {};
            final headers = rawHeaders.map((k, v) => MapEntry(k.toString(), v.toString()));
            final ext = data['ext'] as String? ?? 'mp4';

            final info = YtStreamInfo(url: url, headers: headers, ext: ext);
            _streamInfoCache[cleanId] = info;
            _streamCacheTime[cleanId] = DateTime.now();
            debugPrint('[yt-dlp/Android Python] Resolved stream info via Chaquopy for $cleanId');
            return info;
          }
        }
      } catch (e) {
        debugPrint('[yt-dlp/Android Python] MethodChannel getStreamUrl error: $e');
      }
    }

    // 2. Desktop (Windows / macOS / Linux) with bundled/detected yt-dlp
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final targetUrl = cleanId.startsWith('http') ? cleanId : 'https://www.youtube.com/watch?v=$cleanId';
      try {
        final result = await _runYtDlp([
          '-j',
          '-f',
          'ba/b[acodec!=none]/best',
          '--extractor-args',
          // tv_embedded generates URLs without IP/UA restrictions — required for
          // mobile data where requesting IP may differ from extraction IP.
          'youtube:player_client=tv_embedded,ios,android,mweb',
          '--no-warnings',
          '--no-check-certificates',
          targetUrl,
        ], timeout: const Duration(seconds: 15));

        if (result != null && result.exitCode == 0) {
          final json = jsonDecode(result.stdout.toString().trim()) as Map<String, dynamic>;
          final url = json['url'] as String?;
          if (url != null && url.isNotEmpty) {
            final rawHeaders = json['http_headers'] as Map<String, dynamic>? ?? {};
            final headers = rawHeaders.map((k, v) => MapEntry(k.toString(), v.toString()));
            final ext = json['ext'] as String? ?? 'mp4';

            final info = YtStreamInfo(url: url, headers: headers, ext: ext);
            _streamInfoCache[cleanId] = info;
            _streamCacheTime[cleanId] = DateTime.now();
            debugPrint('[yt-dlp/Desktop] Resolved direct stream info for $cleanId');
            return info;
          }
        }
      } catch (e) {
        debugPrint('[yt-dlp/Desktop] Subprocess stream resolution error: $e');
      }
    }

    // 3. Fallback: Pure-Dart Innertube manifest resolution
    // Try TV clients first — they generate URLs without IP/UA restrictions, best for mobile data.
    final clientSets = [
      [yt.YoutubeApiClient.tv, yt.YoutubeApiClient.mediaConnect],
      [yt.YoutubeApiClient.ios, yt.YoutubeApiClient.android],
      null,
    ];

    for (final clientList in clientSets) {
      try {
        final manifest = await _fallbackClient.videos.streamsClient
            .getManifest(cleanId, ytClients: clientList)
            .timeout(const Duration(seconds: 10)); // longer for mobile data
        final audioOnly = manifest.audioOnly;
        if (audioOnly.isNotEmpty) {
          final best = _selectBestAudioStream(audioOnly);
          final url = best.url.toString();
          final info = YtStreamInfo(
            url: url,
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            },
            ext: best.container.name,
          );
          _streamInfoCache[cleanId] = info;
          _streamCacheTime[cleanId] = DateTime.now();
          debugPrint('[yt-dlp/Innertube] Fallback resolved stream info for $cleanId in pure Dart');
          return info;
        }
      } catch (e) {
        debugPrint('[yt-dlp/Innertube] Pure-Dart fallback failed for $cleanId: $e');
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
  Future<List<Map<String, dynamic>>> _searchYoutubeExplodeFallback(String query, {int limit = 20}) async {
    try {
      final searchResults = await _fallbackClient.search
          .search(query, filter: yt.TypeFilters.video)
          .timeout(const Duration(seconds: 10));
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
    } catch (e) {
      debugPrint('[yt-dlp/ExplodeFallback] error: $e');
      return [];
    }
  }

  /// Dual search: returns a map with 'music' and 'youtube' lists of tracks.
  Future<Map<String, List<Map<String, dynamic>>>> searchDual(String query, {int limit = 20}) async {
    final cleanQuery = query.trim().toLowerCase();
    if (_dualSearchCache.containsKey(cleanQuery)) {
      return _dualSearchCache[cleanQuery]!;
    }

    // 1. Android: Execute embedded Python interpreter with yt-dlp (Chaquopy)
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

    // 2. Desktop or Android fallback: Innertube + youtube_explode_dart in parallel
    try {
      final results = await Future.wait([
        searchYtMusicInnertube(query, limit: limit),
        searchYoutubeVideoInnertube(query, limit: limit),
        _searchYoutubeExplodeFallback(query, limit: limit),
      ]).timeout(const Duration(seconds: 12));
      final musicTracks = results[0];
      final ytTracks = results[1];
      final explodeTracks = results[2];

      // Prefer Innertube results; fall back to youtube_explode_dart if blocked
      final finalMusic = musicTracks.isNotEmpty ? musicTracks : explodeTracks;
      final finalYt = ytTracks.isNotEmpty ? ytTracks : explodeTracks;

      if (finalMusic.isNotEmpty || finalYt.isNotEmpty) {
        final res = <String, List<Map<String, dynamic>>>{
          'music': finalMusic,
          'youtube': finalYt,
        };
        debugPrint('[yt-dlp/Dual] search "$query": ${finalMusic.length} music, ${finalYt.length} youtube');
        if (cleanQuery.isNotEmpty) _dualSearchCache[cleanQuery] = res;
        return res;
      }
    } catch (e) {
      debugPrint('[yt-dlp/Dual] search error: $e');
    }

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
  Future<List<Map<String, dynamic>>> search(String query, {int limit = 25}) async {
    final cleanQuery = query.trim().toLowerCase();
    if (_searchCache.containsKey(cleanQuery)) {
      return _searchCache[cleanQuery]!;
    }

    // 1. Android: Execute embedded Python interpreter with yt-dlp (Chaquopy)
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

    // 2. Desktop (Windows / macOS / Linux) or Android fallback: Innertube + youtube_explode_dart in parallel
    try {
      final parallel = await Future.wait([
        searchYtMusicInnertube(query, limit: limit),
        _searchYoutubeExplodeFallback(query, limit: limit),
      ]).timeout(const Duration(seconds: 10));
      final musicItems = parallel[0];
      final explodeItems = parallel[1];
      final bestItems = musicItems.isNotEmpty ? musicItems : explodeItems;
      if (bestItems.isNotEmpty) {
        debugPrint('[yt-dlp/Search] "$query" returned ${bestItems.length} items (innertube=${musicItems.length}, explode=${explodeItems.length})');
        _searchCache[cleanQuery] = bestItems;
        return bestItems;
      }
      final ytItems = await searchYoutubeVideoInnertube(query, limit: limit).timeout(const Duration(seconds: 8));
      if (ytItems.isNotEmpty) {
        debugPrint('[yt-dlp/Innertube] Fast video search "$query" returned ${ytItems.length} items');
        _searchCache[cleanQuery] = ytItems;
        return ytItems;
      }
    } catch (e) {
      debugPrint('[yt-dlp/Innertube] Fast search error: $e');
    }

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

  /// Fetches similar tracks / song radio using YouTube Music automatic radio playlist (RDAMVM / RD)
  Future<List<Map<String, dynamic>>> getRadioTracks(String videoId, {int limit = 50}) async {
    final radioUrl = 'https://music.youtube.com/playlist?list=RDAMVM$videoId';
    final fallbackRadioUrl = 'https://www.youtube.com/watch?v=$videoId&list=RD$videoId';

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
