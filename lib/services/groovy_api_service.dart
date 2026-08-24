import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/song.dart';

class GroovyUser {
  final int id;
  final String name;
  final String email;
  final String? avatarUrl;
  final String? createdAt;

  GroovyUser({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.createdAt,
  });

  factory GroovyUser.fromJson(Map<String, dynamic> json) {
    return GroovyUser(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? json['avatar_url'] as String?,
      createdAt: json['createdAt'] as String? ?? json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'avatarUrl': avatarUrl,
    'createdAt': createdAt,
  };
}

class AuthResponse {
  final bool success;
  final String? token;
  final GroovyUser? user;
  final String? error;

  AuthResponse({
    required this.success,
    this.token,
    this.user,
    this.error,
  });
}

class GroovyApiService {
  static final GroovyApiService _instance = GroovyApiService._internal();
  factory GroovyApiService() => _instance;
  GroovyApiService._internal();

  static const String defaultBaseUrl = 'http://157.137.233.119/api';
  String _baseUrl = defaultBaseUrl;

  String get baseUrl => _baseUrl;

  void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  Map<String, String> _headers([String? token]) {
    final map = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      map['Authorization'] = 'Bearer $token';
    }
    return map;
  }

  // ----------------------------------------------------
  // AUTH
  // ----------------------------------------------------

  Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
    String? avatarUrl,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/auth/register');
      final res = await http.post(
        uri,
        headers: _headers(),
        body: jsonEncode({
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
          if (avatarUrl != null) 'avatarUrl': avatarUrl,
        }),
      ).timeout(const Duration(seconds: 12));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300 && data['success'] == true) {
        return AuthResponse(
          success: true,
          token: data['token'] as String?,
          user: data['user'] != null ? GroovyUser.fromJson(data['user'] as Map<String, dynamic>) : null,
        );
      } else {
        return AuthResponse(
          success: false,
          error: data['error'] as String? ?? 'Error al registrar usuario (${res.statusCode})',
        );
      }
    } catch (e) {
      debugPrint('[GroovyApiService] register error: $e');
      return AuthResponse(
        success: false,
        error: 'No se pudo conectar con el servidor Groovy. Verifica tu conexión.',
      );
    }
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/auth/login');
      final res = await http.post(
        uri,
        headers: _headers(),
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'password': password,
        }),
      ).timeout(const Duration(seconds: 12));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300 && data['success'] == true) {
        return AuthResponse(
          success: true,
          token: data['token'] as String?,
          user: data['user'] != null ? GroovyUser.fromJson(data['user'] as Map<String, dynamic>) : null,
        );
      } else {
        return AuthResponse(
          success: false,
          error: data['error'] as String? ?? 'Correo o contraseña incorrectos.',
        );
      }
    } catch (e) {
      debugPrint('[GroovyApiService] login error: $e');
      return AuthResponse(
        success: false,
        error: 'No se pudo conectar con el servidor Groovy. Verifica tu conexión.',
      );
    }
  }

  Future<bool> checkEmailExists(String email) async {
    try {
      final uri = Uri.parse('$_baseUrl/auth/check-email');
      final res = await http.post(
        uri,
        headers: _headers(),
        body: jsonEncode({'email': email.trim().toLowerCase()}),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['exists'] == true;
      }
      // If endpoint returns 404 or specific status
      if (res.statusCode == 404) return false;
      return true; // Graceful fallback if endpoint is not separately implemented on older backends
    } catch (e) {
      debugPrint('[GroovyApiService] checkEmailExists: $e');
      return true; // Allow attempt
    }
  }

  Future<AuthResponse> resetPassword({
    required String email,
    required String newPassword,
    String? code,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/auth/reset-password');
      final res = await http.post(
        uri,
        headers: _headers(),
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'password': newPassword,
          'newPassword': newPassword,
          if (code != null) 'code': code,
        }),
      ).timeout(const Duration(seconds: 12));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300 && (data['success'] == true || data['message'] != null)) {
        return AuthResponse(
          success: true,
          token: data['token'] as String?,
          user: data['user'] != null ? GroovyUser.fromJson(data['user'] as Map<String, dynamic>) : null,
        );
      } else {
        return AuthResponse(
          success: false,
          error: data['error'] as String? ?? 'No se pudo restablecer la contraseña (${res.statusCode})',
        );
      }
    } catch (e) {
      debugPrint('[GroovyApiService] resetPassword error: $e');
      return AuthResponse(
        success: false,
        error: 'No se pudo conectar con el servidor Groovy.',
      );
    }
  }

  Future<GroovyUser?> getMe(String token) async {
    try {
      final uri = Uri.parse('$_baseUrl/auth/me');
      final res = await http.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['user'] != null) {
          return GroovyUser.fromJson(data['user'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('[GroovyApiService] getMe error: $e');
    }
    return null;
  }

  Future<AuthResponse> updateProfile({
    required String token,
    String? name,
    String? avatarUrl,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/auth/profile');
      final res = await http.put(
        uri,
        headers: _headers(token),
        body: jsonEncode({
          if (name != null) 'name': name.trim(),
          if (avatarUrl != null) 'avatarUrl': avatarUrl,
        }),
      ).timeout(const Duration(seconds: 12));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300 && data['success'] == true) {
        return AuthResponse(
          success: true,
          user: data['user'] != null ? GroovyUser.fromJson(data['user'] as Map<String, dynamic>) : null,
        );
      } else {
        return AuthResponse(
          success: false,
          error: data['error'] as String? ?? 'Error al actualizar perfil (${res.statusCode})',
        );
      }
    } catch (e) {
      debugPrint('[GroovyApiService] updateProfile error: $e');
      return AuthResponse(
        success: false,
        error: 'No se pudo conectar con el servidor Groovy.',
      );
    }
  }

  // ----------------------------------------------------
  // FAVORITES
  // ----------------------------------------------------

  Future<List<Song>> getFavorites(String token) async {
    try {
      final uri = Uri.parse('$_baseUrl/library/favorites');
      final res = await http.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (data['favorites'] as List<dynamic>?) ?? [];
        return list.map((item) {
          final m = item as Map<String, dynamic>;
          return Song(
            id: m['id']?.toString() ?? '',
            title: m['title']?.toString() ?? 'Sin título',
            artist: m['artist']?.toString(),
            album: m['album']?.toString(),
            coverArt: m['coverArt']?.toString(),
            duration: m['duration'] is int ? m['duration'] as int : int.tryParse(m['duration']?.toString() ?? '0') ?? 0,
            starred: true,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('[GroovyApiService] getFavorites error: $e');
    }
    return [];
  }

  Future<bool> addFavorite(String token, Song song) async {
    try {
      final uri = Uri.parse('$_baseUrl/library/favorites');
      final res = await http.post(
        uri,
        headers: _headers(token),
        body: jsonEncode({
          'songId': song.id,
          'title': song.title,
          'artist': song.artist ?? '',
          'album': song.album ?? '',
          'coverArt': song.coverArt ?? '',
          'duration': song.duration ?? 0,
        }),
      ).timeout(const Duration(seconds: 8));
      return res.statusCode == 201 || res.statusCode == 200;
    } catch (e) {
      debugPrint('[GroovyApiService] addFavorite error: $e');
      return false;
    }
  }

  Future<bool> removeFavorite(String token, String songId) async {
    try {
      final uri = Uri.parse('$_baseUrl/library/favorites/$songId');
      final res = await http.delete(uri, headers: _headers(token)).timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[GroovyApiService] removeFavorite error: $e');
      return false;
    }
  }

  // ----------------------------------------------------
  // PLAYLISTS
  // ----------------------------------------------------

  Future<List<Map<String, dynamic>>> getPlaylists(String token) async {
    try {
      final uri = Uri.parse('$_baseUrl/library/playlists');
      final res = await http.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['playlists'] ?? []);
      }
    } catch (e) {
      debugPrint('[GroovyApiService] getPlaylists error: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> createPlaylist(String token, String name, {String? description, String? coverArt}) async {
    try {
      final uri = Uri.parse('$_baseUrl/library/playlists');
      final res = await http.post(
        uri,
        headers: _headers(token),
        body: jsonEncode({
          'name': name,
          'description': description ?? '',
          'coverArt': coverArt ?? '',
        }),
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode == 201) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['playlist'] as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint('[GroovyApiService] createPlaylist error: $e');
    }
    return null;
  }

  Future<bool> addSongToPlaylist(String token, String playlistId, Song song) async {
    try {
      final uri = Uri.parse('$_baseUrl/library/playlists/$playlistId/songs');
      final res = await http.post(
        uri,
        headers: _headers(token),
        body: jsonEncode({
          'songId': song.id,
          'title': song.title,
          'artist': song.artist ?? '',
          'album': song.album ?? '',
          'coverArt': song.coverArt ?? '',
          'duration': song.duration ?? 0,
        }),
      ).timeout(const Duration(seconds: 8));
      return res.statusCode == 201;
    } catch (e) {
      debugPrint('[GroovyApiService] addSongToPlaylist error: $e');
      return false;
    }
  }

  // ----------------------------------------------------
  // HISTORY
  // ----------------------------------------------------

  Future<void> recordHistory(String token, Song song) async {
    try {
      final uri = Uri.parse('$_baseUrl/library/history');
      await http.post(
        uri,
        headers: _headers(token),
        body: jsonEncode({
          'songId': song.id,
          'title': song.title,
          'artist': song.artist ?? '',
          'album': song.album ?? '',
          'coverArt': song.coverArt ?? '',
          'duration': song.duration ?? 0,
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[GroovyApiService] recordHistory note: $e');
    }
  }

  Future<List<Song>> getHistory(String token, {int limit = 50}) async {
    try {
      final uri = Uri.parse('$_baseUrl/library/history?limit=$limit');
      final res = await http.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (data['history'] as List<dynamic>?) ?? [];
        return list.map((item) {
          final m = item as Map<String, dynamic>;
          return Song(
            id: m['id']?.toString() ?? '',
            title: m['title']?.toString() ?? 'Sin título',
            artist: m['artist']?.toString(),
            album: m['album']?.toString(),
            coverArt: m['coverArt']?.toString(),
            duration: m['duration'] is int
                ? m['duration'] as int
                : int.tryParse(m['duration']?.toString() ?? '0') ?? 0,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('[GroovyApiService] getHistory error: $e');
    }
    return [];
  }
}
