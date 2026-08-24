import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

/// Multi-source lyrics aggregator and parser.
///
/// Integrates:
/// 1. LRCLIB (https://lrclib.net) - High precision synced LRC timestamps.
/// 2. Netease Cloud Music API - Massive database of timed lyrics (LRC).
/// 3. Kugou Music API - Synced lyrics.
/// 4. Lyrics.ovh - Plain lyrics fallback.
class LrcLibService {
  static final LrcLibService _instance = LrcLibService._internal();
  factory LrcLibService() => _instance;
  LrcLibService._internal();

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://lrclib.net/api',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {
        'User-Agent': 'Groovy/1.0 (https://github.com/Danx016/Groovy)',
      },
    ),
  );

  // In-memory cache: "artist|title" -> response map
  final Map<String, Map<String, dynamic>> _cache = {};

  static final List<RegExp> _noiseRegexes = [
    RegExp(r'\((?:official|music|video|audio|lyrics?|lyric video|visualizer|hd|4k|remastered|live|explicit|clip|video oficial|clip officiel).*?\)', caseSensitive: false),
    RegExp(r'\[(?:official|music|video|audio|lyrics?|lyric video|visualizer|hd|4k|remastered|live|explicit|clip|video oficial|clip officiel).*?\]', caseSensitive: false),
    RegExp(r'\((?:feat\.|ft\.|featuring).*?\)', caseSensitive: false),
    RegExp(r'\[(?:feat\.|ft\.|featuring).*?\]', caseSensitive: false),
    RegExp(r'(?:feat\.|ft\.|featuring).*$', caseSensitive: false),
    RegExp(r'\(prod\..*?\)', caseSensitive: false),
    RegExp(r'\[prod\..*?\]', caseSensitive: false),
  ];

  static final RegExp _multiSpaceRegex = RegExp(r'\s+');
  static final RegExp _topicRegex = RegExp(r'\s*-\s*Topic$', caseSensitive: false);
  static final RegExp _vevoRegex = RegExp(r'\s*VEVO$', caseSensitive: false);
  static final RegExp _officialRegex = RegExp(r'\s*Official$', caseSensitive: false);
  static final RegExp _featRegex = RegExp(r'(?:feat\.|ft\.|featuring).*$', caseSensitive: false);

  /// Cleans track titles by removing parentheses noise and tags.
  static String cleanTitle(String rawTitle) {
    var title = rawTitle;

    if (title.contains(' - ')) {
      final parts = title.split(' - ');
      if (parts.length >= 2) {
        title = parts.sublist(1).join(' - ');
      }
    }

    for (final reg in _noiseRegexes) {
      title = title.replaceAll(reg, ' ');
    }

    title = title
        .replaceAll('"', '')
        .replaceAll("'", '')
        .replaceAll(_multiSpaceRegex, ' ')
        .trim();

    return title.isNotEmpty ? title : rawTitle;
  }

  /// Cleans artist names.
  static String cleanArtist(String rawArtist) {
    var artist = rawArtist;
    artist = artist.replaceAll(_topicRegex, '');
    artist = artist.replaceAll(_vevoRegex, '');
    artist = artist.replaceAll(_officialRegex, '');
    artist = artist.replaceAll(_featRegex, '');
    return artist.trim().isNotEmpty ? artist.trim() : rawArtist;
  }

  /// Searches for lyrics with multi-provider fallback.
  Future<Map<String, dynamic>?> searchLyrics({
    String? artist,
    required String title,
    int? durationSeconds,
  }) async {
    if (title.trim().isEmpty) return null;

    final cleanedTitle = cleanTitle(title);
    final cleanedArtist = (artist != null && artist.isNotEmpty) ? cleanArtist(artist) : null;
    final cacheKey = '${cleanedArtist?.toLowerCase() ?? ''}|${cleanedTitle.toLowerCase()}';

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    // Extract potential artist and title candidates if title was "Artist - Track"
    String? extractedArtist;
    String? extractedTrack;
    if (title.contains(' - ')) {
      final parts = title.split(' - ');
      if (parts.length >= 2) {
        extractedArtist = cleanArtist(parts[0]);
        extractedTrack = cleanTitle(parts.sublist(1).join(' - '));
      }
    }

    // ==========================================
    // 1. SOURCE: LRCLIB (Exact match)
    // ==========================================
    final getPairs = <MapEntry<String, String>>[];
    if (extractedArtist != null && extractedTrack != null && extractedArtist.isNotEmpty && extractedTrack.isNotEmpty) {
      getPairs.add(MapEntry(extractedArtist, extractedTrack));
    }
    if (cleanedArtist != null && cleanedArtist.isNotEmpty && cleanedTitle.isNotEmpty) {
      getPairs.add(MapEntry(cleanedArtist, cleanedTitle));
    }

    for (final pair in getPairs) {
      try {
        final response = await _dio.get(
          '/get',
          queryParameters: {
            'artist_name': pair.key,
            'track_name': pair.value,
          },
        );

        if (response.statusCode == 200 && response.data != null && response.data is Map) {
          final result = _parseLrcLibResponse(response.data as Map<String, dynamic>);
          if (result != null) {
            _cache[cacheKey] = result;
            debugPrint('[LRCLIB] Exact match found for "${pair.key} - ${pair.value}"');
            return result;
          }
        }
      } catch (_) {}
    }

    // ==========================================
    // 2. SOURCE: LRCLIB (Search query)
    // ==========================================
    final searchQueries = <String>[];
    if (extractedArtist != null && extractedTrack != null && extractedArtist.isNotEmpty && extractedTrack.isNotEmpty) {
      searchQueries.add('$extractedArtist $extractedTrack'.trim());
    }
    if (cleanedArtist != null && cleanedArtist.isNotEmpty && cleanedTitle.isNotEmpty) {
      searchQueries.add('$cleanedArtist $cleanedTitle'.trim());
    }
    if (cleanedTitle.isNotEmpty && !searchQueries.contains(cleanedTitle)) {
      searchQueries.add(cleanedTitle);
    }
    final simpleRaw = title.replaceAll(RegExp(r'[\(\[\{].*?[\)\]\}]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (simpleRaw.isNotEmpty && !searchQueries.contains(simpleRaw)) {
      searchQueries.add(simpleRaw);
    }

    for (final query in searchQueries) {
      if (query.isEmpty) continue;
      try {
        final searchResp = await _dio.get(
          '/search',
          queryParameters: {'q': query},
        );

        if (searchResp.statusCode == 200 && searchResp.data is List) {
          final list = searchResp.data as List;
          if (list.isNotEmpty) {
            Map<String, dynamic>? bestMatch;
            for (final item in list) {
              if (item is Map<String, dynamic>) {
                final synced = item['syncedLyrics'] as String?;
                final plain = item['plainLyrics'] as String?;
                if (synced != null && synced.trim().isNotEmpty) {
                  bestMatch = item;
                  break;
                } else if (plain != null && plain.trim().isNotEmpty && bestMatch == null) {
                  bestMatch = item;
                }
              }
            }
            bestMatch ??= list.first as Map<String, dynamic>;

            final result = _parseLrcLibResponse(bestMatch);
            if (result != null) {
              _cache[cacheKey] = result;
              debugPrint('[LRCLIB] Search match found for query "$query"');
              return result;
            }
          }
        }
      } catch (_) {}
    }

    // ==========================================
    // 3. SOURCE: Netease Cloud Music (Synced LRC)
    // ==========================================
    try {
      final neteaseQuery = cleanedArtist != null ? '$cleanedArtist $cleanedTitle' : cleanedTitle;
      final neteaseClient = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
          headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
        ),
      );

      final searchRes = await neteaseClient.get(
        'https://music.163.com/api/search/get/web',
        queryParameters: {
          'csrf_token': '',
          'type': 1,
          'offset': 0,
          'total': 'true',
          'limit': 5,
          's': neteaseQuery,
        },
      );

      if (searchRes.statusCode == 200 && searchRes.data != null) {
        final data = searchRes.data is String ? jsonDecode(searchRes.data) : searchRes.data;
        final songs = data['result']?['songs'] as List?;
        if (songs != null && songs.isNotEmpty) {
          final songId = songs.first['id'];
          if (songId != null) {
            final lyricRes = await neteaseClient.get(
              'https://music.163.com/api/song/lyric',
              queryParameters: {
                'os': 'pc',
                'id': songId,
                'lv': -1,
                'kv': -1,
                'tv': -1,
              },
            );

            if (lyricRes.statusCode == 200 && lyricRes.data != null) {
              final lyricData = lyricRes.data is String ? jsonDecode(lyricRes.data) : lyricRes.data;
              final lrc = lyricData['lrc']?['lyric'] as String?;
              if (lrc != null && lrc.trim().isNotEmpty) {
                final structured = _buildStructuredLyrics(lrc);
                _cache[cacheKey] = structured;
                debugPrint('[Netease] Synced lyrics found for "$neteaseQuery"');
                return structured;
              }
            }
          }
        }
      }
    } catch (_) {}

    // ==========================================
    // 4. SOURCE: Kugou Music (Synced LRC)
    // ==========================================
    try {
      final kugouQuery = cleanedArtist != null ? '$cleanedArtist - $cleanedTitle' : cleanedTitle;
      final kugouClient = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
          headers: {'User-Agent': 'Mozilla/5.0'},
        ),
      );

      final kugouSearch = await kugouClient.get(
        'http://krcs.kugou.com/search',
        queryParameters: {
          'ver': 1,
          'man': 'yes',
          'client': 'mobi',
          'keyword': kugouQuery,
          'duration': (durationSeconds ?? 0) * 1000,
          'hash': '',
        },
      );

      if (kugouSearch.statusCode == 200 && kugouSearch.data != null) {
        final data = kugouSearch.data is String ? jsonDecode(kugouSearch.data) : kugouSearch.data;
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final first = candidates.first;
          final id = first['id'];
          final accesskey = first['accesskey'];

          if (id != null && accesskey != null) {
            final downloadRes = await kugouClient.get(
              'http://lyrics.kugou.com/download',
              queryParameters: {
                'ver': 1,
                'client': 'pc',
                'id': id,
                'accesskey': accesskey,
                'fmt': 'lrc',
                'charset': 'utf8',
              },
            );

            if (downloadRes.statusCode == 200 && downloadRes.data != null) {
              final dlData = downloadRes.data is String ? jsonDecode(downloadRes.data) : downloadRes.data;
              final b64Content = dlData['content'] as String?;
              if (b64Content != null && b64Content.isNotEmpty) {
                final decoded = utf8.decode(base64.decode(b64Content));
                if (decoded.trim().isNotEmpty) {
                  final structured = _buildStructuredLyrics(decoded);
                  _cache[cacheKey] = structured;
                  debugPrint('[Kugou] Synced lyrics found for "$kugouQuery"');
                  return structured;
                }
              }
            }
          }
        }
      }
    } catch (_) {}

    // ==========================================
    // 5. SOURCE: Lyrics.ovh (Plain text fallback)
    // ==========================================
    if (cleanedArtist != null && cleanedArtist.isNotEmpty && cleanedTitle.isNotEmpty) {
      try {
        final ovhResp = await Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 4),
          ),
        ).get(
          'https://api.lyrics.ovh/v1/${Uri.encodeComponent(cleanedArtist)}/${Uri.encodeComponent(cleanedTitle)}',
        );
        if (ovhResp.statusCode == 200 && ovhResp.data is Map) {
          final lyrics = ovhResp.data['lyrics'] as String?;
          if (lyrics != null && lyrics.trim().isNotEmpty) {
            final res = {'value': lyrics.trim()};
            _cache[cacheKey] = res;
            debugPrint('[LyricsOVH] Fallback plain lyrics found for "$cleanedArtist - $cleanedTitle"');
            return res;
          }
        }
      } catch (_) {}
    }

    return null;
  }

  Map<String, dynamic>? _parseLrcLibResponse(Map<String, dynamic> data) {
    final synced = data['syncedLyrics'] as String?;
    if (synced != null && synced.isNotEmpty) {
      return _buildStructuredLyrics(synced);
    }

    final plain = data['plainLyrics'] as String?;
    if (plain != null && plain.isNotEmpty) {
      return {'value': plain};
    }

    return null;
  }

  /// Converts an LRC string into the Subsonic structured-lyrics format.
  Map<String, dynamic> _buildStructuredLyrics(String lrcText) {
    final lines = <Map<String, dynamic>>[];
    for (final raw in LineSplitter.split(lrcText)) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      // Parse [mm:ss.xx] or [mm:ss.xxx] tags
      final match = RegExp(r'\[(\d+):(\d{2})\.(\d{2,3})\](.*)').firstMatch(line);
      if (match == null) continue;

      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final fracStr = match.group(3)!;
      final text = match.group(4)!.trim();
      if (text.isEmpty) continue;

      // Normalise fractional seconds to milliseconds
      final fracMs = fracStr.length == 2
          ? int.parse(fracStr) * 10
          : int.parse(fracStr);

      final startMs =
          (minutes * 60 + seconds) * 1000 + fracMs.clamp(0, 999);

      lines.add({
        'start': startMs,
        'value': text,
      });
    }

    if (lines.isEmpty) {
      return {'value': lrcText};
    }

    return {
      'value': lrcText,
      'structuredLyrics': [
        {
          'synced': true,
          'line': lines,
        },
      ],
    };
  }
}
