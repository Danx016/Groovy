import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import 'device_info_service.dart';

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
  GroovyApiService._internal() {
    initDeviceInfo();
  }

  static const String defaultBaseUrl = 'https://groovyapi.duckdns.org/api';
  String _baseUrl = defaultBaseUrl;

  String get baseUrl => _baseUrl;

  void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  ClientDeviceInfo? _cachedDeviceInfo;

  void initDeviceInfo() {
    DeviceInfoService().getDeviceInfo().then((info) {
      _cachedDeviceInfo = info;
    }).catchError((_) {});
  }

  Future<ClientDeviceInfo> _getDeviceInfo() async {
    _cachedDeviceInfo ??= await DeviceInfoService().getDeviceInfo();
    return _cachedDeviceInfo!;
  }

  String get _clientPlatformName {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.linux:
        return 'Linux';
      default:
        return 'Flutter';
    }
  }

  Map<String, String> _headers([String? token]) {
    final dev = _cachedDeviceInfo;
    final platform = dev?.platform ?? _clientPlatformName;
    final map = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Client-Platform': platform,
      'X-Device-Model': dev?.deviceModel ?? '$_clientPlatformName Device',
      'X-OS-Version': dev?.osVersion ?? Platform.operatingSystemVersion,
      'X-App-Version': dev?.appVersion ?? '1.0.86',
      'User-Agent': dev?.userAgent ?? 'GroovyApp/1.0 ($platform; Flutter)',
    };
    if (token != null && token.isNotEmpty) {
      map['Authorization'] = 'Bearer $token';
    }
    return map;
  }

  // ----------------------------------------------------
  // TELEMETRY & LIVE PLAYBACK PRESENCE
  // ----------------------------------------------------

  Future<void> reportPlaybackState({
    required String token,
    required Song song,
    required bool isPlaying,
    int position = 0,
    int listenDeltaSeconds = 15,
    String? deviceId,
    double? volume,
    int? positionMs,
  }) async {
    try {
      String? effectiveDeviceId = deviceId;
      if (effectiveDeviceId == null || effectiveDeviceId.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          effectiveDeviceId = prefs.getString('groovy_cloud_device_id_v2');
        } catch (_) {}
      }

      final dev = await _getDeviceInfo();
      final uri = Uri.parse('$_baseUrl/telemetry/playback');
      await http.post(
        uri,
        headers: _headers(token),
        body: jsonEncode({
          if (effectiveDeviceId != null && effectiveDeviceId.isNotEmpty) 'deviceId': effectiveDeviceId,
          'songId': song.id,
          'title': song.title,
          'artist': song.artist ?? '',
          'album': song.album ?? '',
          'coverArt': song.coverArt ?? '',
          'duration': song.duration ?? 0,
          'position': position,
          if (positionMs != null) 'positionMs': positionMs,
          'isPlaying': isPlaying,
          if (volume != null) 'volume': volume,
          'platform': dev.platform,
          'deviceName': dev.deviceModel,
          'deviceModel': dev.deviceModel,
          'osVersion': dev.osVersion,
          'listenDeltaSeconds': listenDeltaSeconds,
        }),
      ).timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('[GroovyApiService] reportPlaybackState note: $e');
    }
  }

  /// Sends a remote control or playback transfer command to a target device via Groovy Cloud Relay.
  Future<bool> sendDeviceCommand({
    required String targetDeviceId,
    required String action,
    String? senderDeviceId,
    dynamic payload,
    String? token,
  }) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final uri = Uri.parse('$_baseUrl/telemetry/command');
        final res = await http.post(
          uri,
          headers: _headers(token),
          body: jsonEncode({
            'targetDeviceId': targetDeviceId,
            'senderDeviceId': senderDeviceId,
            'action': action,
            'payload': payload,
          }),
        ).timeout(const Duration(seconds: 3));
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final data = jsonDecode(res.body);
          if (data['success'] == true) return true;
        }
      } catch (e) {
        debugPrint('[GroovyApiService] sendDeviceCommand attempt $attempt error: $e');
        if (attempt == 0) await Future.delayed(const Duration(milliseconds: 80));
      }
    }
    return false;
  }

  /// Polls pending commands sent to this device from other Groovy instances across the internet.
  Future<List<Map<String, dynamic>>> getPendingCommands({
    required String deviceId,
    String? token,
  }) async {
    try {
      final dev = await _getDeviceInfo();
      final uri = Uri.parse('$_baseUrl/telemetry/command?deviceId=${Uri.encodeComponent(deviceId)}&platform=${Uri.encodeComponent(dev.platform)}&model=${Uri.encodeComponent(dev.deviceModel)}');
      final res = await http.get(
        uri,
        headers: _headers(token),
      ).timeout(const Duration(milliseconds: 2200));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['commands'] is List) {
          return (data['commands'] as List).cast<Map<String, dynamic>>();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Fetches active devices for the authenticated user from Groovy Cloud.
  Future<List<Map<String, dynamic>>> fetchUserDevices({String? token}) async {
    try {
      final uri = Uri.parse('$_baseUrl/telemetry/playback');
      final res = await http.get(
        uri,
        headers: _headers(token),
      ).timeout(const Duration(milliseconds: 2200));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['devices'] is List) {
          return (data['devices'] as List).cast<Map<String, dynamic>>();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[GroovyApiService] fetchUserDevices note: $e');
      return [];
    }
  }

  Future<void> pingSession(String token) async {
    try {
      String? deviceId;
      try {
        final prefs = await SharedPreferences.getInstance();
        deviceId = prefs.getString('groovy_cloud_device_id_v2');
      } catch (_) {}

      final dev = await _getDeviceInfo();
      final uri = Uri.parse('$_baseUrl/telemetry/ping');
      await http.post(
        uri,
        headers: _headers(token),
        body: jsonEncode({
          if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
          'platform': dev.platform,
          'deviceName': dev.deviceModel,
          'deviceModel': dev.deviceModel,
          'osVersion': dev.osVersion,
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[GroovyApiService] pingSession note: $e');
    }
  }

  Future<void> leaveSession(String token) async {
    try {
      String? deviceId;
      try {
        final prefs = await SharedPreferences.getInstance();
        deviceId = prefs.getString('groovy_cloud_device_id_v2');
      } catch (_) {}

      final dev = await _getDeviceInfo();
      final uri = Uri.parse('$_baseUrl/telemetry/leave');
      await http.post(
        uri,
        headers: _headers(token),
        body: jsonEncode({
          if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
          'platform': dev.platform,
          'deviceName': dev.deviceModel,
          'deviceModel': dev.deviceModel,
          'osVersion': dev.osVersion,
        }),
      ).timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('[GroovyApiService] leaveSession note: $e');
    }
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
      final dev = await _getDeviceInfo();
      final uri = Uri.parse('$_baseUrl/auth/register');
      final res = await http.post(
        uri,
        headers: _headers(),
        body: jsonEncode({
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
          if (avatarUrl != null) 'avatarUrl': avatarUrl,
          'platform': dev.platform,
          'deviceModel': dev.deviceModel,
          'osVersion': dev.osVersion,
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
      final dev = await _getDeviceInfo();
      final uri = Uri.parse('$_baseUrl/auth/login');
      final res = await http.post(
        uri,
        headers: _headers(),
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'password': password,
          'platform': dev.platform,
          'deviceModel': dev.deviceModel,
          'osVersion': dev.osVersion,
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

  Future<AuthResponse> loginWithGoogle({
    required String email,
    required String name,
    required String googleId,
    String? avatarUrl,
    String? idToken,
  }) async {
    try {
      final dev = await _getDeviceInfo();
      final uri = Uri.parse('$_baseUrl/auth/google');
      final res = await http.post(
        uri,
        headers: _headers(),
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'name': name.trim(),
          'googleId': googleId,
          if (avatarUrl != null) 'avatarUrl': avatarUrl,
          if (idToken != null) 'idToken': idToken,
          'platform': dev.platform,
          'deviceModel': dev.deviceModel,
          'osVersion': dev.osVersion,
        }),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return AuthResponse(
            success: true,
            token: data['token'] as String?,
            user: data['user'] != null
                ? GroovyUser.fromJson(data['user'] as Map<String, dynamic>)
                : null,
          );
        }
      }

      // If backend /auth/google doesn't exist yet (404), fall back to seamless login/register:
      final deterministicPassword = 'GAuth_${googleId}_${email.hashCode.abs()}';
      final loginAttempt = await login(email: email, password: deterministicPassword);
      if (loginAttempt.success) {
        return loginAttempt;
      }

      final registerAttempt = await register(
        name: name,
        email: email,
        password: deterministicPassword,
        avatarUrl: avatarUrl,
      );
      if (registerAttempt.success) {
        return registerAttempt;
      }

      // Local session fallback if backend is offline
      final fallbackUser = GroovyUser(
        id: googleId.hashCode.abs(),
        name: name,
        email: email,
        avatarUrl: avatarUrl,
        createdAt: DateTime.now().toIso8601String(),
      );
      return AuthResponse(
        success: true,
        token: 'local_gauth_${googleId}_${DateTime.now().millisecondsSinceEpoch}',
        user: fallbackUser,
      );
    } catch (e) {
      debugPrint('[GroovyApiService] loginWithGoogle note: $e');
      final fallbackUser = GroovyUser(
        id: googleId.hashCode.abs(),
        name: name,
        email: email,
        avatarUrl: avatarUrl,
        createdAt: DateTime.now().toIso8601String(),
      );
      return AuthResponse(
        success: true,
        token: 'local_gauth_${googleId}_${DateTime.now().millisecondsSinceEpoch}',
        user: fallbackUser,
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
        // If the server explicitly says exists is false, return false
        if (data.containsKey('exists')) {
          return data['exists'] == true;
        }
        return true;
      }
      
      // If endpoint returns 404 (endpoint not implemented on backend),
      // DO NOT block the user with 'usuario no encontrado'.
      // Allow the OTP recovery email flow to proceed.
      if (res.statusCode == 404) {
        debugPrint('[GroovyApiService] checkEmailExists: route /auth/check-email returned 404. Proceeding with recovery flow.');
        return true;
      }
      return true; // Graceful fallback
    } catch (e) {
      debugPrint('[GroovyApiService] checkEmailExists: $e');
      return true; // Allow attempt on network error
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

      if (res.statusCode == 404) {
        return AuthResponse(
          success: false,
          error: 'El servidor en la nube aún no tiene habilitada la ruta de cambio de contraseña (/api/auth/reset-password).',
        );
      }

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
          'platform': _clientPlatformName,
          'deviceName': '$_clientPlatformName App',
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
