import 'dart:io';
import 'package:flutter/foundation.dart';
import 'storage_service.dart';

class DiscordRpcService {
  final StorageService _storageService;

  bool _initialized = false;
  bool _enabled = true;

  DiscordRpcService(this._storageService);

  Future<void> initialize() async {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      try {
        _enabled = await _storageService.getDiscordRpcEnabled();
        _initialized = true;
      } catch (e) {
        debugPrint('Discord RPC initialization failed: $e');
      }
    }
  }

  void shutdown() {
    _initialized = false;
  }

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    try {
      await _storageService.saveDiscordRpcEnabled(enabled);
    } catch (_) {}
  }

  bool get enabled => _enabled;

  void updatePresence({
    required String state,
    required String details,
    String? largeImageKey,
    String? largeImageText,
    String? smallImageKey,
    String? smallImageText,
    int? startTime,
    int? endTime,
    String? button1Label,
    String? button1Url,
  }) {
    if (kIsWeb ||
        !(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return;
    }
    if (!_initialized || !_enabled) return;
  }

  void clearPresence() {
    if (kIsWeb ||
        !(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return;
    }
    if (!_initialized || !_enabled) return;
    debugPrint('Clearing Discord Presence');
  }
}
