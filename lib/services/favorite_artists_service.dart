import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage favorite artists.
/// Stores favorite artist IDs and names locally using SharedPreferences.
class FavoriteArtistsService extends ChangeNotifier {
  static const String _prefsKey = 'favorite_artist_ids';

  final Set<String> _favoriteIds = {};
  bool _initialized = false;

  static final FavoriteArtistsService _instance =
      FavoriteArtistsService._internal();
  factory FavoriteArtistsService() => _instance;
  FavoriteArtistsService._internal();

  /// Initialize the service and load saved favorites
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIds = prefs.getStringList(_prefsKey);
      if (savedIds != null) {
        _favoriteIds.addAll(savedIds);
      }
      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[FavoriteArtistsService] init error: $e');
    }
  }

  /// Check if an artist is marked as favorite by ID or name
  bool isFavorite(String artistId, {String? artistName}) {
    if (_favoriteIds.contains(artistId)) return true;
    if (artistName != null && artistName.trim().isNotEmpty) {
      final normalizedName = artistName.trim().toLowerCase();
      if (_favoriteIds.contains(normalizedName)) return true;
      if (_favoriteIds.contains('artist_$normalizedName')) return true;
    }
    return false;
  }

  /// Toggle favorite status for an artist
  Future<bool> toggleFavorite(String artistId, {String? artistName}) async {
    await initialize();
    final isFav = isFavorite(artistId, artistName: artistName);
    final normalizedName = (artistName != null && artistName.trim().isNotEmpty)
        ? artistName.trim().toLowerCase()
        : null;

    if (isFav) {
      _favoriteIds.remove(artistId);
      if (normalizedName != null) {
        _favoriteIds.remove(normalizedName);
        _favoriteIds.remove('artist_$normalizedName');
      }
    } else {
      _favoriteIds.add(artistId);
      if (normalizedName != null) {
        _favoriteIds.add(normalizedName);
      }
    }

    await _saveFavorites();
    notifyListeners();
    return !isFav;
  }

  /// Add an artist to favorites
  Future<void> addFavorite(String artistId, {String? artistName}) async {
    await initialize();
    _favoriteIds.add(artistId);
    if (artistName != null && artistName.trim().isNotEmpty) {
      _favoriteIds.add(artistName.trim().toLowerCase());
    }
    await _saveFavorites();
    notifyListeners();
  }

  /// Remove an artist from favorites
  Future<void> removeFavorite(String artistId, {String? artistName}) async {
    await initialize();
    _favoriteIds.remove(artistId);
    if (artistName != null && artistName.trim().isNotEmpty) {
      final normalized = artistName.trim().toLowerCase();
      _favoriteIds.remove(normalized);
      _favoriteIds.remove('artist_$normalized');
    }
    await _saveFavorites();
    notifyListeners();
  }

  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, _favoriteIds.toList());
    } catch (e) {
      debugPrint('[FavoriteArtistsService] save error: $e');
    }
  }

  /// Get all favorite artist identifiers
  List<String> getFavoriteIds() {
    return List.unmodifiable(_favoriteIds);
  }

  /// Get the count of favorite artists
  int get favoriteCount => _favoriteIds.length;
}
