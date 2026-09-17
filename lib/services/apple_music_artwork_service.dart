import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../utils/album_sanitizer.dart';

/// Resolved Apple Music metadata containing original HD studio artwork and catalog links.
class AppleMusicArtworkResult {
  final String artworkUrl;
  final String? albumName;
  final String? artistName;
  final String? trackName;
  final String? trackViewUrl;
  final String? collectionViewUrl;
  final int? collectionId;
  final String? motionVideoUrl;

  const AppleMusicArtworkResult({
    required this.artworkUrl,
    this.albumName,
    this.artistName,
    this.trackName,
    this.trackViewUrl,
    this.collectionViewUrl,
    this.collectionId,
    this.motionVideoUrl,
  });

  AppleMusicArtworkResult copyWith({
    String? artworkUrl,
    String? albumName,
    String? artistName,
    String? trackName,
    String? trackViewUrl,
    String? collectionViewUrl,
    int? collectionId,
    String? motionVideoUrl,
  }) =>
      AppleMusicArtworkResult(
        artworkUrl: artworkUrl ?? this.artworkUrl,
        albumName: albumName ?? this.albumName,
        artistName: artistName ?? this.artistName,
        trackName: trackName ?? this.trackName,
        trackViewUrl: trackViewUrl ?? this.trackViewUrl,
        collectionViewUrl: collectionViewUrl ?? this.collectionViewUrl,
        collectionId: collectionId ?? this.collectionId,
        motionVideoUrl: motionVideoUrl ?? this.motionVideoUrl,
      );

  Map<String, dynamic> toJson() => {
        'artworkUrl': artworkUrl,
        if (albumName != null) 'albumName': albumName,
        if (artistName != null) 'artistName': artistName,
        if (trackName != null) 'trackName': trackName,
        if (trackViewUrl != null) 'trackViewUrl': trackViewUrl,
        if (collectionViewUrl != null) 'collectionViewUrl': collectionViewUrl,
        if (collectionId != null) 'collectionId': collectionId,
        if (motionVideoUrl != null) 'motionVideoUrl': motionVideoUrl,
      };

  factory AppleMusicArtworkResult.fromJson(Map<String, dynamic> json) =>
      AppleMusicArtworkResult(
        artworkUrl: json['artworkUrl'] as String? ?? '',
        albumName: json['albumName'] as String?,
        artistName: json['artistName'] as String?,
        trackName: json['trackName'] as String?,
        trackViewUrl: json['trackViewUrl'] as String?,
        collectionViewUrl: json['collectionViewUrl'] as String?,
        collectionId: json['collectionId'] as int?,
        motionVideoUrl: json['motionVideoUrl'] as String?,
      );
}

/// High-performance service that resolves official Apple Music original album
/// artwork in ultra-high resolution (1400x1400) using the public iTunes/Apple Music Storefront API.
///
/// Features:
/// - Robust cleaning of YouTube badges (`[Official Video]`, `(Visualizer)`, `ft. ...`).
/// - 2-tier caching: 0ms in-memory lookup + persistent SharedPreferences storage.
/// - In-flight deduplication to avoid redundant network queries.
/// - Extracts album and track URLs for Apple Music Motion Artwork discovery.
class AppleMusicArtworkService {
  static const String _prefsKey = 'apple_music_artwork_cache_v2';
  static final Map<String, AppleMusicArtworkResult> _memoryCache = {};
  static final Map<String, Future<AppleMusicArtworkResult?>> _inFlight = {};
  static bool _prefsLoaded = false;

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 6),
    headers: {
      'User-Agent': 'GroovyMusic/1.2 (Macintosh; Intel Mac OS X 10_15_7)',
    },
  ));

  static final AppleMusicArtworkService _instance =
      AppleMusicArtworkService._internal();
  factory AppleMusicArtworkService() => _instance;
  AppleMusicArtworkService._internal();

  /// Synchronous memory cache check
  static AppleMusicArtworkResult? getCachedArtwork(String title, String? artist) {
    final key = _makeKey(title, artist);
    return _memoryCache[key];
  }

  static String _makeKey(String title, String? artist) {
    final cleanT = cleanSongTitle(title).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final cleanA = (artist != null ? cleanArtistName(artist) : '')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '${cleanA}_$cleanT';
  }

  /// Ensure persistent cache is loaded into memory
  Future<void> _ensureCacheLoaded() async {
    if (_prefsLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = json.decode(raw);
        if (decoded is Map) {
          decoded.forEach((k, v) {
            if (k is String && v is Map) {
              final parsed = AppleMusicArtworkResult.fromJson(
                  Map<String, dynamic>.from(v));
              if (parsed.artworkUrl.isNotEmpty) {
                _memoryCache[k] = parsed;
              }
            }
          });
        }
      }
      _prefsLoaded = true;
    } catch (e) {
      debugPrint('[AppleMusicArtwork] Cache load error: $e');
      _prefsLoaded = true;
    }
  }

  /// Persist cache to disk
  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mapToSave = <String, dynamic>{};
      _memoryCache.forEach((k, v) {
        mapToSave[k] = v.toJson();
      });
      await prefs.setString(_prefsKey, json.encode(mapToSave));
    } catch (e) {
      debugPrint('[AppleMusicArtwork] Cache save error: $e');
    }
  }

  /// Removes YouTube-specific decorations, video markers, and parenthetical metadata.
  static String cleanSongTitle(String title) {
    var s = title.trim();
    if (s.isEmpty) return '';

    // Strip common YouTube tags in brackets or parenthesis
    s = s.replaceAll(
        RegExp(r'\[(official\s*(music\s*)?video|video\s*oficial|visualizer|lyric\s*video|letra|audio\s*oficial|official\s*audio|hd|4k|remastered|live)\]',
            caseSensitive: false),
        '');
    s = s.replaceAll(
        RegExp(r'\((official\s*(music\s*)?video|video\s*oficial|visualizer|lyric\s*video|letra|audio\s*oficial|official\s*audio|hd|4k|remastered(\s*\d+)?|live(\s*at\s*[^)]+)?)\)',
            caseSensitive: false),
        '');

    // Strip "ft." or "feat." if present in the title
    s = s.replaceAll(RegExp(r'\s+(feat\.|ft\.)\s+[^(\[]+', caseSensitive: false), ' ');

    // Normalize multiple spaces and hyphens
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.endsWith('-')) {
      s = s.substring(0, s.length - 1).trim();
    }
    return s;
  }

  /// Cleans artist name by removing YouTube channels / VEVO / Topic suffixes
  static String cleanArtistName(String artist) {
    var s = artist.trim();
    if (AlbumSanitizer.isPlaceholder(s)) return '';

    s = s.replaceAll(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'VEVO$', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'^artist_|^local_artist_', caseSensitive: false), '');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Resolves original Apple Music HD artwork for a song.
  Future<AppleMusicArtworkResult?> resolveArtworkForSong(Song song) async {
    if (song.isLocal) return null;
    return resolveArtwork(
      title: song.title,
      artist: song.artist,
      album: song.album,
    );
  }

  /// Resolves original Apple Music HD artwork with in-flight deduplication and caching.
  Future<AppleMusicArtworkResult?> resolveArtwork({
    required String title,
    String? artist,
    String? album,
  }) async {
    await _ensureCacheLoaded();

    final cleanT = cleanSongTitle(title);
    final cleanA = artist != null ? cleanArtistName(artist) : '';
    if (cleanT.isEmpty && cleanA.isEmpty) return null;

    final key = _makeKey(title, artist);

    // 1. Instant Cache Hit
    if (_memoryCache.containsKey(key)) {
      final cached = _memoryCache[key]!;
      // If motion video was not resolved yet but album URL exists, resolve it in background
      if (cached.motionVideoUrl == null &&
          cached.collectionViewUrl != null &&
          cached.collectionViewUrl!.isNotEmpty) {
        resolveMotionVideo(cached.collectionViewUrl!).then((motionUrl) {
          if (motionUrl != null && motionUrl.isNotEmpty) {
            _memoryCache[key] = cached.copyWith(motionVideoUrl: motionUrl);
            _saveCache();
          }
        }).catchError((_) {});
      }
      return cached;
    }

    // 2. In-flight request deduplication
    if (_inFlight.containsKey(key)) {
      return await _inFlight[key];
    }

    final future = _doResolveArtwork(cleanT, cleanA, album);
    _inFlight[key] = future;

    try {
      final result = await future;
      if (result != null && result.artworkUrl.isNotEmpty) {
        _memoryCache[key] = result;
        _saveCache();

        if (result.collectionViewUrl != null &&
            result.collectionViewUrl!.isNotEmpty &&
            result.motionVideoUrl == null) {
          resolveMotionVideo(result.collectionViewUrl!).then((motionUrl) {
            if (motionUrl != null && motionUrl.isNotEmpty) {
              _memoryCache[key] = result.copyWith(motionVideoUrl: motionUrl);
              _saveCache();
            }
          }).catchError((_) {});
        }
      }
      return result;
    } finally {
      _inFlight.remove(key);
    }
  }

  /// Network query to the official iTunes/Apple Music Storefront search API
  Future<AppleMusicArtworkResult?> _doResolveArtwork(
    String cleanTitle,
    String cleanArtist,
    String? album,
  ) async {
    try {
      // 1. Query by track + artist
      final query = cleanArtist.isNotEmpty
          ? '$cleanArtist $cleanTitle'
          : cleanTitle;

      final url =
          'https://itunes.apple.com/search?term=${Uri.encodeComponent(query)}&entity=song&limit=6';

      final response = await _dio.get(url);
      if (response.statusCode == 200 && response.data != null) {
        final raw = response.data;
        final data = raw is String ? json.decode(raw) : raw;
        if (data is Map &&
            data['results'] is List &&
            (data['results'] as List).isNotEmpty) {
          final results = data['results'] as List;

          for (final item in results) {
            if (item is Map) {
              final rawArtwork = item['artworkUrl100'] as String?;
              if (rawArtwork == null || rawArtwork.isEmpty) continue;

              final trackName = item['trackName'] as String? ?? '';
              final artistName = item['artistName'] as String? ?? '';
              final collectionName = item['collectionName'] as String?;
              final trackViewUrl = item['trackViewUrl'] as String?;
              final collectionViewUrl = item['collectionViewUrl'] as String?;
              final collectionId = item['collectionId'] as int?;

              // Fuzzy match track and artist to ensure relevance
              final match = _fuzzyMatch(
                queryTitle: cleanTitle,
                queryArtist: cleanArtist,
                candidateTitle: trackName,
                candidateArtist: artistName,
              );

              if (match) {
                // Upgrade resolution to 1400x1400 lossless quality
                final hdArtwork = _upgradeResolution(rawArtwork, 1400);

                return AppleMusicArtworkResult(
                  artworkUrl: hdArtwork,
                  albumName: collectionName,
                  artistName: artistName,
                  trackName: trackName,
                  trackViewUrl: trackViewUrl,
                  collectionViewUrl: collectionViewUrl,
                  collectionId: collectionId,
                );
              }
            }
          }

          // If no strict match but we have results and cleanArtist was provided,
          // pick the first result if artist loosely matches
          final first = results.first;
          if (first is Map) {
            final rawArtwork = first['artworkUrl100'] as String?;
            if (rawArtwork != null && rawArtwork.isNotEmpty) {
              return AppleMusicArtworkResult(
                artworkUrl: _upgradeResolution(rawArtwork, 1400),
                albumName: first['collectionName'] as String?,
                artistName: first['artistName'] as String?,
                trackName: first['trackName'] as String?,
                trackViewUrl: first['trackViewUrl'] as String?,
                collectionViewUrl: first['collectionViewUrl'] as String?,
                collectionId: first['collectionId'] as int?,
              );
            }
          }
        }
      }

      // 2. Fallback: query by album if provided
      if (album != null && album.isNotEmpty && !AlbumSanitizer.isPlaceholder(album)) {
        final albumQuery = cleanArtist.isNotEmpty ? '$cleanArtist $album' : album;
        final albumUrl =
            'https://itunes.apple.com/search?term=${Uri.encodeComponent(albumQuery)}&entity=album&limit=3';

        final albResponse = await _dio.get(albumUrl);
        if (albResponse.statusCode == 200 && albResponse.data != null) {
          final raw = albResponse.data;
          final data = raw is String ? json.decode(raw) : raw;
          if (data is Map &&
              data['results'] is List &&
              (data['results'] as List).isNotEmpty) {
            final first = (data['results'] as List).first;
            if (first is Map) {
              final rawArtwork = first['artworkUrl100'] as String?;
              if (rawArtwork != null && rawArtwork.isNotEmpty) {
                return AppleMusicArtworkResult(
                  artworkUrl: _upgradeResolution(rawArtwork, 1400),
                  albumName: first['collectionName'] as String?,
                  artistName: first['artistName'] as String?,
                  collectionViewUrl: first['collectionViewUrl'] as String?,
                  collectionId: first['collectionId'] as int?,
                );
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[AppleMusicArtwork] Resolve error for "$cleanTitle" by "$cleanArtist": $e');
    }
    return null;
  }

  /// Converts Apple Music artwork URLs (typically /100x100bb.jpg) into high resolution
  static String _upgradeResolution(String url, int size) {
    if (url.contains('100x100bb')) {
      return url.replaceAll('100x100bb', '${size}x${size}bb');
    }
    return url.replaceAll(RegExp(r'\d+x\d+bb'), '${size}x${size}bb');
  }

  /// Fuzzy match check between query and result candidates
  static bool _fuzzyMatch({
    required String queryTitle,
    required String queryArtist,
    required String candidateTitle,
    required String candidateArtist,
  }) {
    final qt = queryTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final ct = candidateTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    final titleMatch = qt.contains(ct) || ct.contains(qt);
    if (!titleMatch) return false;

    if (queryArtist.isNotEmpty) {
      final qa = queryArtist.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final ca = candidateArtist.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final artistMatch = qa.contains(ca) || ca.contains(qa);
      return artistMatch;
    }

    return true;
  }

  /// Extracts the official 1:1 square Apple Music motion video (.m3u8 stream)
  /// directly from the public album web page without requiring developer tokens.
  Future<String?> resolveMotionVideo(String albumUrl) async {
    try {
      final response = await _dio.get(
        albumUrl,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final body = response.data.toString();

        // 1. Look inside serialized-server-data JSON for motionDetailSquare
        final serverDataMatch = RegExp(
                r'<script\s+type="application/json"\s+id="serialized-server-data">([^<]+)</script>')
            .firstMatch(body);

        String? videoM3u8;

        if (serverDataMatch != null) {
          final jsonStr = serverDataMatch.group(1);
          if (jsonStr != null) {
            final squareMatch = RegExp(
                    r'"motionDetailSquare"\s*:\s*\{[^}]*"video"\s*:\s*"(https:[^"]+\.m3u8)"')
                .firstMatch(jsonStr);
            if (squareMatch != null) {
              videoM3u8 = squareMatch.group(1)?.replaceAll(r'\/', '/');
            }
          }
        }

        // 2. Fallback: match any motion master playlist on the page
        if (videoM3u8 == null) {
          final squarePattern = RegExp(
              r'https://mvod\.itunes\.apple\.com/itunes-assets/HLSMusic\d+/[^"]+P\d+_default\.m3u8');
          final m = squarePattern.firstMatch(body);
          if (m != null) {
            videoM3u8 = m.group(0);
          }
        }

        return videoM3u8;
      }
    } catch (e) {
      debugPrint('[AppleMusicArtwork] Motion video extraction note: $e');
    }
    return null;
  }
}
