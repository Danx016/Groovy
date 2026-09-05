import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to resolve and cache high-resolution artist images using
/// Deezer Artist Search API (with iTunes Search API fallback).
class ArtistImageService {
  static const String _prefsKey = 'artist_image_cache_v1';
  static final Map<String, String> _memoryCache = {};
  static bool _prefsLoaded = false;

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
    headers: {
      'User-Agent': 'GroovyMusicApp/1.0.0 (https://github.com/groovy)',
    },
  ));

  static final ArtistImageService _instance = ArtistImageService._internal();
  factory ArtistImageService() => _instance;
  ArtistImageService._internal();

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
            if (k is String && v is String && v.isNotEmpty) {
              _memoryCache[k] = v;
            }
          });
        }
      }
      _prefsLoaded = true;
    } catch (e) {
      debugPrint('[ArtistImageService] cache load error: $e');
      _prefsLoaded = true;
    }
  }

  /// Save memory cache to persistent SharedPreferences
  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, json.encode(_memoryCache));
    } catch (e) {
      debugPrint('[ArtistImageService] cache save error: $e');
    }
  }

  /// Normalize artist name for clean searching & caching
  String _normalize(String name) {
    return name
        .replaceAll(RegExp(r'^artist_|^local_artist_', caseSensitive: false), '')
        .replaceAll('_', ' ')
        .trim()
        .toLowerCase();
  }

  /// Extract primary artist if artist name contains collaboration markers
  String _extractPrimaryArtist(String name) {
    var clean = name
        .replaceAll(RegExp(r'^artist_|^local_artist_', caseSensitive: false), '')
        .replaceAll('_', ' ')
        .trim();

    // Split on common collaboration tokens: &, feat, ft., vs, con, y (surrounded by spaces)
    final splitRegex = RegExp(r'\s+(?:&|feat\.?|ft\.?|vs\.?|con|\/)\s+', caseSensitive: false);
    if (clean.contains(splitRegex)) {
      clean = clean.split(splitRegex).first.trim();
    }
    return clean;
  }

  /// Resolves the best available artist image URL.
  /// First checks local cache, then queries Deezer API, followed by iTunes fallback.
  Future<String?> getArtistImageUrl(
    String artistName, {
    String? fallbackCoverArt,
  }) async {
    if (artistName.trim().isEmpty) return fallbackCoverArt;

    await _ensureCacheLoaded();

    final key = _normalize(artistName);
    if (_memoryCache.containsKey(key) && _memoryCache[key]!.isNotEmpty) {
      return _memoryCache[key];
    }

    // Also check primary artist key
    final primaryName = _extractPrimaryArtist(artistName);
    final primaryKey = _normalize(primaryName);
    if (_memoryCache.containsKey(primaryKey) && _memoryCache[primaryKey]!.isNotEmpty) {
      return _memoryCache[primaryKey];
    }

    // 1. Query Deezer for the exact/original artist name
    String? resolvedUrl = await _queryDeezer(artistName.trim());

    // 2. If no result and primary name is different, query Deezer with primary name
    if (resolvedUrl == null && primaryName.toLowerCase() != artistName.trim().toLowerCase()) {
      resolvedUrl = await _queryDeezer(primaryName);
    }

    // 3. Fallback to iTunes song search to retrieve artist/track artwork
    resolvedUrl ??= await _queryItunes(primaryName);

    // 4. Use provided fallback cover art if still unresolved
    if (resolvedUrl == null && fallbackCoverArt != null && fallbackCoverArt.isNotEmpty) {
      resolvedUrl = fallbackCoverArt;
    }

    if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
      _memoryCache[key] = resolvedUrl;
      _memoryCache[primaryKey] = resolvedUrl;
      _saveCache();
      return resolvedUrl;
    }

    return null;
  }

  /// Query Deezer artist search API
  Future<String?> _queryDeezer(String query) async {
    try {
      final url = 'https://api.deezer.com/search/artist?q=${Uri.encodeComponent(query)}&limit=1';
      final response = await _dio.get(url);

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final list = data is Map ? data['data'] : null;
        if (list is List && list.isNotEmpty) {
          final first = list.first;
          if (first is Map) {
            final picXl = first['picture_xl'] as String?;
            final picBig = first['picture_big'] as String?;
            final picMed = first['picture_medium'] as String?;
            final pic = first['picture'] as String?;

            final candidate = picXl ?? picBig ?? picMed ?? pic;
            if (candidate != null &&
                candidate.isNotEmpty &&
                !candidate.contains('/artist//')) {
              return candidate;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[ArtistImageService] Deezer query error for "$query": $e');
    }
    return null;
  }

  /// Query iTunes search API for fallback artwork
  Future<String?> _queryItunes(String query) async {
    try {
      final url = 'https://itunes.apple.com/search?term=${Uri.encodeComponent(query)}&entity=song&limit=1';
      final response = await _dio.get(url);

      if (response.statusCode == 200 && response.data != null) {
        final raw = response.data;
        final data = raw is String ? json.decode(raw) : raw;
        if (data is Map && data['results'] is List && (data['results'] as List).isNotEmpty) {
          final first = (data['results'] as List).first;
          if (first is Map) {
            final art100 = first['artworkUrl100'] as String?;
            if (art100 != null && art100.isNotEmpty) {
              return art100.replaceAll('100x100bb', '600x600bb');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[ArtistImageService] iTunes query error for "$query": $e');
    }
    return null;
  }
}
