import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/song.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefsInstance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  @visibleForTesting
  void clearCacheForTesting() {
    _prefsInstance = null;
  }

  static const String _lastPlayedKey = 'last_played';
  static const String _playbackHistoryKey = 'local_playback_history';
  static const String _queueKey = 'queue';
  static const String _queueIndexKey = 'queue_index';
  static const String _shuffleModeKey = 'shuffle_mode';
  static const String _repeatModeKey = 'repeat_mode';
  static const String _gaplessPlaybackKey = 'gapless_playback';
  static const String _lrcLibFallbackKey = 'lrclib_fallback';
  static const String _volumeKey = 'volume';

  Future<String?> _safeSecureRead(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } on PlatformException catch (e) {
      if (e.code == '-34018' || e.message?.contains('entitlement') == true) {
        final prefs = await _prefs;
        return prefs.getString('fallback_secure_$key');
      }
      return null;
    }
  }

  Future<void> _safeSecureWrite(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } on PlatformException catch (e) {
      if (e.code == '-34018' || e.message?.contains('entitlement') == true) {
        final prefs = await _prefs;
        await prefs.setString('fallback_secure_$key', value);
      }
    }
  }

  Future<void> _safeSecureDelete(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } on PlatformException catch (e) {
      if (e.code == '-34018' || e.message?.contains('entitlement') == true) {
        final prefs = await _prefs;
        await prefs.remove('fallback_secure_$key');
      }
    }
  }

  Future<void> _safeSecureDeleteAll() async {
    try {
      await _secureStorage.deleteAll();
    } on PlatformException catch (_) {
      // Ignored for fallback
    }
  }

  Future<void> init() async {
    _prefsInstance = await SharedPreferences.getInstance();
  }

  Future<SharedPreferences> get _prefs async {
    _prefsInstance ??= await SharedPreferences.getInstance();
    return _prefsInstance!;
  }

  Future<void> saveLastPlayed(String songId) async {
    final prefs = await _prefs;
    await prefs.setString(_lastPlayedKey, songId);
  }

  Future<String?> getLastPlayed() async {
    final prefs = await _prefs;
    return prefs.getString(_lastPlayedKey);
  }

  Future<void> addSongToHistory(Song song) async {
    try {
      final prefs = await _prefs;
      final historyJson = prefs.getString(_playbackHistoryKey);
      List<dynamic> list = [];
      if (historyJson != null && historyJson.isNotEmpty) {
        try {
          list = json.decode(historyJson) as List<dynamic>;
        } catch (_) {
          list = [];
        }
      }

      list.removeWhere((item) {
        if (item is Map<String, dynamic>) {
          return item['id']?.toString() == song.id;
        }
        return false;
      });

      list.insert(0, song.toJson());

      if (list.length > 200) {
        list = list.sublist(0, 200);
      }

      await prefs.setString(_playbackHistoryKey, json.encode(list));
    } catch (e) {
      debugPrint('[StorageService] addSongToHistory error: $e');
    }
  }

  Future<List<Song>> getPlaybackHistory() async {
    try {
      final prefs = await _prefs;
      final historyJson = prefs.getString(_playbackHistoryKey);
      if (historyJson == null || historyJson.isEmpty) return [];

      final list = json.decode(historyJson) as List<dynamic>;
      final songs = <Song>[];
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          try {
            songs.add(Song.fromJson(item));
          } catch (_) {}
        }
      }
      return songs;
    } catch (e) {
      debugPrint('[StorageService] getPlaybackHistory error: $e');
      return [];
    }
  }

  Future<void> clearPlaybackHistory() async {
    final prefs = await _prefs;
    await prefs.remove(_playbackHistoryKey);
  }

  Future<void> saveQueue(List<Map<String, dynamic>> queue) async {
    final prefs = await _prefs;
    await prefs.setString(_queueKey, json.encode(queue));
  }

  Future<List<Map<String, dynamic>>> getQueue() async {
    final prefs = await _prefs;
    final queueJson = prefs.getString(_queueKey);
    if (queueJson != null) {
      final list = json.decode(queueJson) as List;
      return list.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<void> saveQueueIndex(int index) async {
    final prefs = await _prefs;
    await prefs.setInt(_queueIndexKey, index);
  }

  Future<int> getQueueIndex() async {
    final prefs = await _prefs;
    return prefs.getInt(_queueIndexKey) ?? 0;
  }

  Future<void> saveShuffleMode(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(_shuffleModeKey, enabled);
  }

  Future<bool> getShuffleMode() async {
    final prefs = await _prefs;
    return prefs.getBool(_shuffleModeKey) ?? false;
  }

  Future<void> saveRepeatMode(int mode) async {
    final prefs = await _prefs;
    await prefs.setInt(_repeatModeKey, mode);
  }

  Future<int> getRepeatMode() async {
    final prefs = await _prefs;
    return prefs.getInt(_repeatModeKey) ?? 0;
  }

  Future<void> saveGaplessPlayback(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(_gaplessPlaybackKey, enabled);
  }

  Future<bool> getGaplessPlayback() async {
    final prefs = await _prefs;
    return prefs.getBool(_gaplessPlaybackKey) ?? true;
  }

  Future<void> saveLrcLibFallback(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(_lrcLibFallbackKey, enabled);
  }

  Future<bool> getLrcLibFallback() async {
    final prefs = await _prefs;
    return prefs.getBool(_lrcLibFallbackKey) ?? false;
  }

  Future<void> saveVolume(double volume) async {
    final prefs = await _prefs;
    await prefs.setDouble(_volumeKey, volume);
  }

  Future<double> getVolume() async {
    final prefs = await _prefs;
    return prefs.getDouble(_volumeKey) ?? 1.0;
  }






  Future<void> saveLastSelectedFamily(String family) async {
    final prefs = await _prefs;
    await prefs.setString('last_selected_server_family', family);
  }

  static const String _userTokenKey = 'groovy_user_token';
  static const String _userProfileKey = 'groovy_user_profile';

  Future<void> saveUserAuth({required String token, required Map<String, dynamic> userJson}) async {
    final prefs = await _prefs;
    await prefs.setString(_userTokenKey, token);
    await prefs.setString(_userProfileKey, jsonEncode(userJson));
    await _safeSecureWrite(_userTokenKey, token);
  }

  Future<void> saveUserProfile(Map<String, dynamic> userJson) async {
    final prefs = await _prefs;
    await prefs.setString(_userProfileKey, jsonEncode(userJson));
  }

  Future<String?> getUserToken() async {
    final secure = await _safeSecureRead(_userTokenKey);
    if (secure != null && secure.isNotEmpty) return secure;
    final prefs = await _prefs;
    return prefs.getString(_userTokenKey);
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    final prefs = await _prefs;
    final str = prefs.getString(_userProfileKey);
    if (str == null || str.isEmpty) return null;
    try {
      return jsonDecode(str) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearUserAuth() async {
    final prefs = await _prefs;
    await prefs.remove(_userTokenKey);
    await prefs.remove(_userProfileKey);
    await _safeSecureDelete(_userTokenKey);
  }

  Future<bool> getDiscordRpcEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool('discord_rpc_enabled') ?? true;
  }

  Future<void> saveDiscordRpcEnabled(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool('discord_rpc_enabled', enabled);
  }

  Future<void> clearAll() async {
    final prefs = await _prefs;
    await prefs.clear();
    await _safeSecureDeleteAll();
  }
}

