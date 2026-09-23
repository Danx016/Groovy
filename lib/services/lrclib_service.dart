import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'offline_service.dart';

/// Multi-source lyrics aggregator with expanded global repertoire,
/// persistent disk caching, and YouTube Closed Captions (CC) extraction.
///
/// Features:
/// 1. Instant Cache: Disk & RAM lookup (0ms offline playback).
/// 2. Primary: LRCLIB (Millions of synchronized line-by-line LRC tracks).
/// 3. Secondary: YouTube Closed Captions (Synchronized lyrics extracted directly from the video).
/// 4. Tertiary: Genius (The world's largest lyrics catalog with 25M+ songs).
/// 5. Quaternary: Lyrics.ovh plain text fallback.
class LrcLibService {
  static final LrcLibService _instance = LrcLibService._internal();
  factory LrcLibService() => _instance;
  LrcLibService._internal();

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://lrclib.net/api',
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 6),
      headers: {
        'User-Agent': 'Groovy/1.0 (https://github.com/Danx016/Groovy)',
      },
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  // In-memory cache: "artist|title" -> response map
  final Map<String, Map<String, dynamic>> _cache = {};

  static final List<RegExp> _noiseRegexes = [
    RegExp(r'\((?:official|music|video|audio|lyrics?|lyric video|visualizer|hd|4k|remastered|live|explicit|clip|video oficial|clip officiel|en vivo).*?\)', caseSensitive: false),
    RegExp(r'\[(?:official|music|video|audio|lyrics?|lyric video|visualizer|hd|4k|remastered|live|explicit|clip|video oficial|clip officiel|en vivo).*?\]', caseSensitive: false),
    RegExp(r'\((?:feat\.|ft\.|featuring).*?\)', caseSensitive: false),
    RegExp(r'\[(?:feat\.|ft\.|featuring).*?\]', caseSensitive: false),
    RegExp(r'(?:feat\.|ft\.|featuring).*$', caseSensitive: false),
    RegExp(r'\(prod\..*?\)', caseSensitive: false),
    RegExp(r'\[prod\..*?\]', caseSensitive: false),
    RegExp(r'\((?:letra|audio oficial).*?\)', caseSensitive: false),
    RegExp(r'\[(?:letra|audio oficial).*?\]', caseSensitive: false),
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

  /// Extracts primary artist (first artist before comma, &, or feat).
  static String primaryArtist(String rawArtist) {
    final cleaned = cleanArtist(rawArtist);
    final parts = cleaned.split(RegExp(r'[,&/]'));
    if (parts.isNotEmpty && parts.first.trim().isNotEmpty) {
      return parts.first.trim();
    }
    return cleaned;
  }

  /// Validates that a candidate result strictly matches the expected artist & title.
  static bool _isCandidateValid(
    String resultTitle,
    String? resultArtist,
    String expectedTitle,
    String? expectedArtist,
    int? resultDuration,
    int? expectedDuration,
  ) {
    final rTitle = cleanTitle(resultTitle).toLowerCase();
    final eTitle = cleanTitle(expectedTitle).toLowerCase();
    final rArtist = cleanArtist(resultArtist ?? '').toLowerCase();
    final eArtist = cleanArtist(expectedArtist ?? '').toLowerCase();

    final fullResult = '$rArtist $rTitle';
    final fullExpected = '$eArtist $eTitle';

    // 1. Title verification
    bool titleMatches = rTitle.contains(eTitle) || eTitle.contains(rTitle) || fullResult.contains(eTitle);
    if (!titleMatches) {
      final titleWords = eTitle
          .split(RegExp(r'[\s,&/+\-_]+'))
          .where((w) => w.length >= 2)
          .toList();

      if (titleWords.isNotEmpty) {
        int matchedWords = 0;
        for (final w in titleWords) {
          if (fullResult.contains(w)) {
            matchedWords++;
          }
        }
        titleMatches = matchedWords == titleWords.length || (matchedWords >= 1 && fullResult.contains(eTitle));
      }
    }

    if (!titleMatches && !fullExpected.contains(rTitle)) {
      return false;
    }

    // 2. Artist verification
    if (eArtist.isNotEmpty) {
      bool artistMatches = rArtist.contains(eArtist) ||
          eArtist.contains(rArtist) ||
          fullResult.contains(eArtist);

      if (!artistMatches) {
        final words = eArtist
            .split(RegExp(r'[\s,&/+\-]+'))
            .where((w) => w.length >= 3)
            .toList();

        for (final word in words) {
          if (fullResult.contains(word)) {
            artistMatches = true;
            break;
          }
        }
      }

      if (!artistMatches) {
        return false;
      }
    }

    // 3. Duration verification if both are present (tolerance: up to 20s for music videos)
    if (expectedDuration != null && expectedDuration > 10 && resultDuration != null && resultDuration > 10) {
      final diff = (resultDuration - expectedDuration).abs();
      if (diff > 20) {
        return false;
      }
    }

    return true;
  }

  /// Extracts synchronized lyrics directly from YouTube Closed Captions (CC).
  Future<Map<String, dynamic>?> getYouTubeClosedCaptions(String videoId) async {
    final cleanId = videoId.replaceFirst('ytmusic://', '').replaceFirst('yt_', '').trim();
    if (!RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(cleanId)) return null;

    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.closedCaptions.getManifest(cleanId);
      if (manifest.tracks.isEmpty) return null;

      // Prefer Spanish, English, or non-auto-generated track
      ClosedCaptionTrackInfo? selectedTrack;
      for (final t in manifest.tracks) {
        final lang = t.language.code.toLowerCase();
        if (!t.isAutoGenerated && (lang.startsWith('es') || lang.startsWith('en'))) {
          selectedTrack = t;
          break;
        }
      }
      selectedTrack ??= manifest.tracks.firstWhere(
        (t) => !t.isAutoGenerated,
        orElse: () => manifest.tracks.first,
      );

      final track = await yt.videos.closedCaptions.get(selectedTrack);
      if (track.captions.isEmpty) return null;

      final lines = <Map<String, dynamic>>[];
      final lrcLines = <String>[];

      for (final c in track.captions) {
        var text = c.text.trim();
        text = text.replaceAll(RegExp(r'[♪♫♩♬]'), '').trim();
        if (text.isEmpty) continue;

        final startMs = c.offset.inMilliseconds;
        final minutes = c.offset.inMinutes;
        final seconds = c.offset.inSeconds % 60;
        final hundredths = (c.offset.inMilliseconds % 1000) ~/ 10;
        final timeTag = '[${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${hundredths.toString().padLeft(2, '0')}]';

        lines.add({
          'start': startMs,
          'value': text,
        });
        lrcLines.add('$timeTag $text');
      }

      if (lines.isEmpty) return null;

      final lrcString = lrcLines.join('\n');
      return {
        'value': lrcString,
        'syncedLyrics': lrcString,
        'structuredLyrics': [
          {
            'synced': true,
            'line': lines,
          },
        ],
      };
    } catch (e) {
      debugPrint('[YouTube CC] Closed captions extraction failed: $e');
      return null;
    } finally {
      yt.close();
    }
  }

  /// Searches for lyrics with multi-provider fallback, exact duration matching,
  /// disk persistence, and YouTube closed-captions backup.
  Future<Map<String, dynamic>?> searchLyrics({
    String? artist,
    required String title,
    int? durationSeconds,
    String? songId,
  }) async {
    if (title.trim().isEmpty) return null;

    final cleanedTitle = cleanTitle(title);
    final cleanedArtist = (artist != null && artist.isNotEmpty) ? cleanArtist(artist) : null;
    final durKey = durationSeconds != null && durationSeconds > 0 ? '|$durationSeconds' : '';
    final cacheKey = '${cleanedArtist?.toLowerCase() ?? ''}|${cleanedTitle.toLowerCase()}$durKey';

    // 1. In-memory cache
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }
    if (songId != null && _cache.containsKey(songId)) {
      return _cache[songId];
    }

    // 2. Persistent disk cache (OfflineService)
    if (songId != null) {
      try {
        final localData = await OfflineService().getLocalLyrics(songId);
        if (localData != null && localData.isNotEmpty) {
          _cache[cacheKey] = localData;
          _cache[songId] = localData;
          debugPrint('[Lyrics] ⚡ Instant disk cache hit for "$title" ($songId)');
          return localData;
        }
      } catch (_) {}
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

    void persistResult(Map<String, dynamic> res) {
      _cache[cacheKey] = res;
      if (songId != null) {
        _cache[songId] = res;
        OfflineService().saveLyrics(songId, res).catchError((_) {});
      }
    }

    // ==========================================
    // 1. SOURCE: LRCLIB (Exact match with duration)
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
        final queryParams = <String, dynamic>{
          'artist_name': pair.key,
          'track_name': pair.value,
        };
        if (durationSeconds != null && durationSeconds > 0) {
          queryParams['duration'] = durationSeconds;
        }

        var response = await _dio.get(
          '/get',
          queryParameters: queryParams,
        );

        // If not found with duration, try without duration parameter as fallback
        if ((response.statusCode != 200 || response.data == null) && queryParams.containsKey('duration')) {
          try {
            response = await _dio.get(
              '/get',
              queryParameters: {
                'artist_name': pair.key,
                'track_name': pair.value,
              },
            );
          } catch (_) {}
        }

        if (response.statusCode == 200 && response.data != null && response.data is Map) {
          final resMap = response.data as Map<String, dynamic>;
          final rTrack = resMap['trackName'] as String? ?? '';
          final rArtist = resMap['artistName'] as String? ?? '';
          final rDur = (resMap['duration'] as num?)?.toInt();

          if (_isCandidateValid(rTrack, rArtist, pair.value, pair.key, rDur, durationSeconds)) {
            final result = _parseLrcLibResponse(resMap);
            if (result != null) {
              persistResult(result);
              debugPrint('[LRCLIB] Exact verified match found for "${pair.key} - ${pair.value}" (dur: $rDur s)');
              return result;
            }
          }
        }
      } catch (_) {}
    }

    // ==========================================
    // 2. SOURCE: LRCLIB (Search query with duration-scored candidate validation)
    // ==========================================
    final searchQueries = <String>[];
    if (extractedArtist != null && extractedTrack != null && extractedArtist.isNotEmpty && extractedTrack.isNotEmpty) {
      searchQueries.add('$extractedArtist $extractedTrack'.trim());
    }
    if (cleanedArtist != null && cleanedArtist.isNotEmpty && cleanedTitle.isNotEmpty) {
      searchQueries.add('$cleanedArtist $cleanedTitle'.trim());
      final pArtist = primaryArtist(cleanedArtist);
      if (pArtist != cleanedArtist && !searchQueries.contains('$pArtist $cleanedTitle')) {
        searchQueries.add('$pArtist $cleanedTitle'.trim());
      }
    }
    if (cleanedTitle.isNotEmpty && !searchQueries.contains(cleanedTitle)) {
      searchQueries.add(cleanedTitle);
    }

    Map<String, dynamic>? fallbackPlainCandidate;

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
            int? bestDiff;

            for (final item in list) {
              if (item is Map<String, dynamic>) {
                final rTrack = item['trackName'] as String? ?? '';
                final rArtist = item['artistName'] as String? ?? '';
                final rDur = (item['duration'] as num?)?.toInt();

                final isValidCleaned = _isCandidateValid(rTrack, rArtist, cleanedTitle, cleanedArtist, rDur, durationSeconds);
                final isValidExtracted = (extractedTrack != null && extractedTrack.isNotEmpty)
                    ? _isCandidateValid(rTrack, rArtist, extractedTrack, extractedArtist, rDur, durationSeconds)
                    : false;

                if (!isValidCleaned && !isValidExtracted) {
                  continue;
                }

                final synced = item['syncedLyrics'] as String?;
                final plain = item['plainLyrics'] as String?;
                if (synced != null && synced.trim().isNotEmpty) {
                  final diff = (durationSeconds != null && rDur != null)
                      ? (rDur - durationSeconds).abs()
                      : 0;

                  if (bestDiff == null || diff < bestDiff) {
                    bestMatch = item;
                    bestDiff = diff;
                    if (diff <= 3) break; // Great duration match found!
                  }
                } else if (plain != null && plain.trim().isNotEmpty) {
                  fallbackPlainCandidate ??= item;
                }
              }
            }

            if (bestMatch != null) {
              final result = _parseLrcLibResponse(bestMatch);
              if (result != null) {
                persistResult(result);
                debugPrint('[LRCLIB] Best query candidate matched for "$query" (diff: ${bestDiff ?? 0} s)');
                return result;
              }
            }
          }
        }
      } catch (_) {}
    }

    // ==========================================
    // 3. SOURCE: YouTube Closed Captions (Direct Video Subtitles Sync)
    // ==========================================
    if (songId != null) {
      final cleanVideoId = songId.replaceFirst('ytmusic://', '').replaceFirst('yt_', '').trim();
      if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(cleanVideoId)) {
        try {
          final ccResult = await getYouTubeClosedCaptions(cleanVideoId);
          if (ccResult != null) {
            persistResult(ccResult);
            debugPrint('[YouTube CC] Synchronized captions found for "$cleanVideoId"');
            return ccResult;
          }
        } catch (_) {}
      }
    }

    // If plain lyrics were found on LRCLIB and no synced found yet, return plain
    if (fallbackPlainCandidate != null) {
      final plainRes = _parseLrcLibResponse(fallbackPlainCandidate);
      if (plainRes != null) {
        persistResult(plainRes);
        debugPrint('[LRCLIB] Plain lyrics matched for "$cleanedTitle"');
        return plainRes;
      }
    }

    // ==========================================
    // 4. SOURCE: Genius (25+ Million Songs Worldwide Repertoire)
    // ==========================================
    final geniusArtist = cleanedArtist ?? extractedArtist;
    final geniusTitle = cleanedTitle.isNotEmpty ? cleanedTitle : (extractedTrack ?? title);
    if (geniusTitle.isNotEmpty) {
      try {
        final geniusLyrics = await _fetchGeniusLyrics(geniusArtist, geniusTitle);
        if (geniusLyrics != null && geniusLyrics.isNotEmpty) {
          final res = {'value': geniusLyrics};
          persistResult(res);
          debugPrint('[Genius] High-repertoire lyrics matched for "$geniusArtist - $geniusTitle" (${geniusLyrics.length} chars)');
          return res;
        }
      } catch (e) {
        debugPrint('[Genius] Error: $e');
      }
    }

    // ==========================================
    // 5. SOURCE: Lyrics.ovh (Fallback)
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
            persistResult(res);
            debugPrint('[LyricsOVH] Fallback verified plain lyrics for "$cleanedArtist - $cleanedTitle"');
            return res;
          }
        }
      } catch (_) {}
    }

    return null;
  }

  /// Scrapes lyrics from Genius.com via public multi-search and page parsing.
  Future<String?> _fetchGeniusLyrics(String? artist, String title) async {
    final geniusDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    final cleanT = title.replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), '').trim();
    final cleanA = artist != null ? primaryArtist(artist) : '';
    final q = '$cleanA $cleanT'.trim();
    if (q.isEmpty) return null;

    final searchRes = await geniusDio.get(
      'https://genius.com/api/search/multi',
      queryParameters: {'q': q},
    );

    if (searchRes.statusCode != 200 || searchRes.data == null) return null;
    final data = searchRes.data is Map ? searchRes.data as Map<String, dynamic> : jsonDecode(searchRes.data.toString()) as Map<String, dynamic>;
    final sections = data['response']?['sections'] as List?;
    if (sections == null) return null;

    String? songUrl;
    for (final s in sections) {
      if (s['type'] == 'song') {
        final hits = s['hits'] as List?;
        if (hits != null && hits.isNotEmpty) {
          for (final h in hits) {
            final r = h['result'];
            final t = (r?['title'] as String? ?? '').toLowerCase();
            final a = (r?['artist_names'] as String? ?? '').toLowerCase();
            // Prefer original over translations
            if (!t.contains('translation') && !t.contains('traducci') && !a.contains('genius translations')) {
              songUrl = r['url'] as String?;
              break;
            }
          }
          songUrl ??= hits[0]['result']?['url'] as String?;
        }
      }
    }

    if (songUrl == null || !songUrl.startsWith('http')) return null;

    final pageRes = await geniusDio.get<String>(
      songUrl,
      options: Options(responseType: ResponseType.plain),
    );

    if (pageRes.statusCode != 200 || pageRes.data == null) return null;
    final pageHtml = pageRes.data!;

    final regex = RegExp(r'<div[^>]*data-lyrics-container="true"[^>]*>(.*?)</div>', dotAll: true);
    final matches = regex.allMatches(pageHtml);
    if (matches.isEmpty) return null;

    final sb = StringBuffer();
    for (final m in matches) {
      var text = m.group(1)!;
      text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
      text = text.replaceAll(RegExp(r'<[^>]*>'), '');
      sb.writeln(text);
    }

    var result = sb.toString().trim();
    result = result
        .replaceAll('&#x27;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ');

    final lines = result
        .split('\n')
        .where((l) => !RegExp(r'^\d+\s*Contributors', caseSensitive: false).hasMatch(l.trim()))
        .toList();

    if (lines.isNotEmpty && lines.first.toLowerCase().contains('translations')) {
      lines.removeAt(0);
    }

    final cleaned = lines.join('\n').trim();
    return cleaned.isNotEmpty ? cleaned : null;
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

  /// Converts an LRC string into structured lyrics format.
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
