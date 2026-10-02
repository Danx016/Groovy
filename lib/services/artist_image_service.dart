import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Service to resolve and cache high-resolution artist images using
/// Deezer Artist Search API (with iTunes Search API fallback).
class ArtistImageService {
  static const String _prefsKey = 'artist_image_cache_v1';
  static final Map<String, String> _memoryCache = {};
  static final Map<String, Future<String?>> _inFlight = {};
  static bool _prefsLoaded = false;

  static String removeAccents(String text) {
    return text
        .replaceAll(RegExp(r'[áàäâ]', caseSensitive: false), 'a')
        .replaceAll(RegExp(r'[éèëê]', caseSensitive: false), 'e')
        .replaceAll(RegExp(r'[íìïî]', caseSensitive: false), 'i')
        .replaceAll(RegExp(r'[óòöô]', caseSensitive: false), 'o')
        .replaceAll(RegExp(r'[úùüû]', caseSensitive: false), 'u');
  }

  /// Synchronous memory cache check
  static String? getCachedArtistImageUrl(String artistName) {
    if (artistName.trim().isEmpty) return null;
    final key = normalize(artistName);
    final cached = _memoryCache[key];
    if (cached != null && cached.isNotEmpty && !_isLikelyAlbumCover(cached)) {
      return cached;
    }
    final primaryKey = normalize(extractPrimaryArtist(artistName));
    if (primaryKey != key) {
      final primaryCached = _memoryCache[primaryKey];
      if (primaryCached != null && primaryCached.isNotEmpty && !_isLikelyAlbumCover(primaryCached)) {
        return primaryCached;
      }
    }
    return null;
  }

  static bool _isLikelyAlbumCover(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('/album/') ||
        lower.contains('i.ytimg.com/vi/') ||
        lower.contains('sddefault') ||
        lower.contains('hqdefault')) {
      return true;
    }
    return false;
  }

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
            if (k is String && v is String && v.isNotEmpty && !_isLikelyAlbumCover(v)) {
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
  static String normalize(String name) {
    final lower = name
        .replaceAll(RegExp(r'^artist_|^local_artist_', caseSensitive: false), '')
        .replaceAll('_', ' ')
        .trim()
        .toLowerCase();
    return removeAccents(lower);
  }

  String _normalize(String name) => normalize(name);

  /// Extract primary artist if artist name contains collaboration markers
  static String extractPrimaryArtist(String name) {
    var clean = name
        .replaceAll(RegExp(r'^artist_|^local_artist_', caseSensitive: false), '')
        .replaceAll('_', ' ')
        .trim();

    // Split on common collaboration tokens: &, feat, ft., vs, con, with, y, e, x, comma, slash
    final splitRegex = RegExp(
      r'(\s+(?:&|feat\.?|ft\.?|vs\.?|con|with|y|e|x|\/)\s+|,\s*)',
      caseSensitive: false,
    );
    if (clean.contains(splitRegex)) {
      clean = clean.split(splitRegex).first.trim();
    }
    return clean;
  }

  String _extractPrimaryArtist(String name) => extractPrimaryArtist(name);

  /// Resolves the best available artist image URL.
  /// First checks local cache, then queries Deezer API, followed by iTunes fallback.
  Future<String?> getArtistImageUrl(
    String artistName, {
    String? fallbackCoverArt,
  }) async {
    if (artistName.trim().isEmpty) return fallbackCoverArt;

    final key = _normalize(artistName);
    if (_memoryCache.containsKey(key) &&
        _memoryCache[key]!.isNotEmpty &&
        !_isLikelyAlbumCover(_memoryCache[key]!)) {
      return _memoryCache[key];
    }

    if (_inFlight.containsKey(key)) {
      return _inFlight[key];
    }

    final future = _resolveArtistImageInternal(artistName, key, fallbackCoverArt: fallbackCoverArt);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<String?> _resolveArtistImageInternal(
    String artistName,
    String key, {
    String? fallbackCoverArt,
  }) async {
    await _ensureCacheLoaded();

    if (_memoryCache.containsKey(key) &&
        _memoryCache[key]!.isNotEmpty &&
        !_isLikelyAlbumCover(_memoryCache[key]!)) {
      return _memoryCache[key];
    }

    // Also check primary artist key
    final primaryName = _extractPrimaryArtist(artistName);
    final primaryKey = _normalize(primaryName);
    if (_memoryCache.containsKey(primaryKey) &&
        _memoryCache[primaryKey]!.isNotEmpty &&
        !_isLikelyAlbumCover(_memoryCache[primaryKey]!)) {
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

    // Save strictly legitimate artist portraits, never fallback album covers
    if (resolvedUrl != null && resolvedUrl.isNotEmpty && !_isLikelyAlbumCover(resolvedUrl)) {
      _memoryCache[key] = resolvedUrl;
      _memoryCache[primaryKey] = resolvedUrl;
      _saveCache();
      return resolvedUrl;
    }

    // Transient fallback only if requested, but DO NOT pollute memory/persistent cache
    if (fallbackCoverArt != null && fallbackCoverArt.isNotEmpty) {
      return fallbackCoverArt;
    }

    return null;
  }

  /// Query Deezer artist search API with strict artist name verification
  Future<String?> _queryDeezer(String query) async {
    try {
      final unaccentedQuery = removeAccents(query);
      final url = 'https://api.deezer.com/search/artist?q=${Uri.encodeComponent(unaccentedQuery)}&limit=5';
      final response = await _dio.get(url);

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final list = data is Map ? data['data'] : null;
        if (list is List && list.isNotEmpty) {
          final cleanQuery = _normalize(query);
          for (final item in list) {
            if (item is Map) {
              final artistName = item['name'] as String?;
              if (artistName == null) continue;
              final cleanName = _normalize(artistName);
              // Ensure artist name matches query
              if (cleanName == cleanQuery ||
                  cleanName.startsWith(cleanQuery) ||
                  cleanQuery.startsWith(cleanName)) {
                final picXl = item['picture_xl'] as String?;
                final picBig = item['picture_big'] as String?;
                final picMed = item['picture_medium'] as String?;
                final pic = item['picture'] as String?;

                final candidate = picXl ?? picBig ?? picMed ?? pic;
                if (candidate != null &&
                    candidate.isNotEmpty &&
                    !candidate.contains('/artist//')) {
                  return candidate;
                }
              }
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
      final url = 'https://itunes.apple.com/search?term=${Uri.encodeComponent(query)}&entity=song&limit=5';
      final response = await _dio.get(url);

      if (response.statusCode == 200 && response.data != null) {
        final raw = response.data;
        final data = raw is String ? json.decode(raw) : raw;
        if (data is Map && data['results'] is List && (data['results'] as List).isNotEmpty) {
          final cleanQuery = _normalize(query);
          for (final item in (data['results'] as List)) {
            if (item is Map) {
              final artistName = item['artistName'] as String?;
              if (artistName != null) {
                final cleanName = _normalize(artistName);
                if (cleanName == cleanQuery ||
                    cleanName.startsWith(cleanQuery) ||
                    cleanQuery.startsWith(cleanName)) {
                  final art100 = item['artworkUrl100'] as String?;
                  if (art100 != null && art100.isNotEmpty) {
                    return art100.replaceAll('100x100bb', '600x600bb');
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[ArtistImageService] iTunes query error for "$query": $e');
    }
    return null;
  }

  /// Query Deezer to get full artist discography (albums)
  Future<List<Album>> getArtistAlbums(String artistName) async {
    final query = _extractPrimaryArtist(artistName);
    try {
      final url = 'https://api.deezer.com/search/album?q=${Uri.encodeComponent(query)}&limit=30';
      final response = await _dio.get(url);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final list = data is Map ? data['data'] : null;
        if (list is List && list.isNotEmpty) {
          final result = <Album>[];
          final seenTitles = <String>{};
          final cleanArtist = _normalize(artistName);
          final cleanQuery = _normalize(query);

          for (final item in list) {
            if (item is Map) {
              final artistObj = item['artist'];
              if (artistObj is Map) {
                final aName = (artistObj['name'] as String?);
                if (aName != null) {
                  final cleanAName = _normalize(aName);
                  if (cleanAName != cleanArtist &&
                      cleanAName != cleanQuery &&
                      !cleanAName.contains(cleanQuery) &&
                      !cleanQuery.contains(cleanAName)) {
                    continue; // Skip albums from unrelated artist
                  }
                }
              }

              final title = (item['title'] as String?)?.trim();
              if (title == null || title.isEmpty) continue;
              final lower = title.toLowerCase();
              if (seenTitles.contains(lower)) continue;
              seenTitles.add(lower);

              final id = item['id']?.toString() ?? title;
              final coverXl = item['cover_xl'] as String?;
              final coverBig = item['cover_big'] as String?;
              final coverMed = item['cover_medium'] as String?;
              final cover = coverXl ?? coverBig ?? coverMed;
              final nbTracks = item['nb_tracks'] as int?;

              result.add(
                Album(
                  id: 'dz_album_$id',
                  name: title,
                  artist: artistName,
                  coverArt: cover,
                  songCount: nbTracks,
                ),
              );
            }
          }
          return result;
        }
      }
    } catch (e) {
      debugPrint('[ArtistImageService] getArtistAlbums error: $e');
    }
    return [];
  }
}
