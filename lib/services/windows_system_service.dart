import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:windows_taskbar/windows_taskbar.dart';
import 'package:local_notifier/local_notifier.dart';
import '../models/song.dart';

class WindowsSystemService {
  static final WindowsSystemService _instance =
      WindowsSystemService._internal();
  factory WindowsSystemService() => _instance;
  WindowsSystemService._internal();

  bool _isInitialized = false;
  LocalNotification? _lyricsNotification;
  bool _lyricsEnabled = false;
  Song? _currentSong;
  bool _isPlaying = false;

  VoidCallback? onPlay;
  VoidCallback? onPause;
  VoidCallback? onStop;
  VoidCallback? onSkipNext;
  VoidCallback? onSkipPrevious;
  Function(Duration position)? onSeekTo;

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    if (event.logicalKey == LogicalKeyboardKey.mediaPlayPause) {
      if (_isPlaying) {
        onPause?.call();
      } else {
        onPlay?.call();
      }
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.mediaPlay) {
      onPlay?.call();
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.mediaPause) {
      onPause?.call();
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.mediaTrackNext) {
      onSkipNext?.call();
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.mediaTrackPrevious) {
      onSkipPrevious?.call();
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.mediaStop) {
      onStop?.call();
      return true;
    }
    return false;
  }

  Future<void> initialize() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      if (_isInitialized) return;

      // 1. Hardware keyboard / headphone media key listener on Windows
      try {
        HardwareKeyboard.instance.addHandler(_handleKeyEvent);
      } catch (e) {
        debugPrint('Error attaching hardware keyboard listener: $e');
      }

      // 2. Initialize local notifier for lyrics/notifications (optional, don't break media keys if it fails)
      try {
        await localNotifier.setup(
          appName: 'Groovy',
          shortcutPolicy: ShortcutPolicy.requireNoCreate,
        );
      } catch (e) {
        debugPrint('LocalNotifier setup skipped/failed: $e');
      }

      _isInitialized = true;
      debugPrint(
          'WindowsSystemService initialized (Taskbar, Media Keys & Lyrics Notification)');
    }
  }

  Future<void> updatePlaybackState({
    required Song? song,
    required bool isPlaying,
    required Duration position,
    required Duration duration,
    String? artworkUrl,
  }) async {
    _isPlaying = isPlaying;
    if (!kIsWeb && Platform.isWindows && _isInitialized) {
      try {
        // Clear taskbar progress bar so it never looks like a file download (matches Spotify behavior)
        if (Platform.isWindows) { await WindowsTaskbar.setProgressMode(TaskbarProgressMode.noProgress); }
      } catch (e) {
        debugPrint('Error updating Windows playback state: $e');
      }
    }
  }

  /// Update current song info for lyrics display
  Future<void> updateSongInfo(Song? song) async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      if (_currentSong?.id == song?.id) return;
      _currentSong = song;
      // Clear lyrics when song changes
      await clearLyrics();
    }
  }

  /// Update lyrics line - shows as Windows notification
  Future<void> updateLyrics(String? lyricsLine) async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux) && _lyricsEnabled) {
      if (lyricsLine == null || lyricsLine.isEmpty) {
        await clearLyrics();
        return;
      }

      try {
        // Close previous notification
        await _lyricsNotification?.close();

        // Create new notification with current lyrics line
        _lyricsNotification = LocalNotification(
          title: _currentSong?.title ?? 'Now Playing',
          body: lyricsLine,
          subtitle: _currentSong?.artist ?? 'Groovy',
          silent: true,
        );

        await _lyricsNotification?.show();
        debugPrint('[Windows] Lyrics notification updated: $lyricsLine');
      } catch (e) {
        debugPrint('[Windows] Failed to update lyrics notification: $e');
      }
    }
  }

  /// Clear lyrics notification
  Future<void> clearLyrics() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      try {
        await _lyricsNotification?.close();
        _lyricsNotification = null;
        debugPrint('[Windows] Lyrics notification cleared');
      } catch (e) {
        debugPrint('[Windows] Failed to clear lyrics notification: $e');
      }
    }
  }

  /// Enable/disable lyrics notifications
  Future<void> setLyricsEnabled(bool enabled) async {
    _lyricsEnabled = enabled;
    if (!enabled) {
      await clearLyrics();
    }
    debugPrint('[Windows] Lyrics notifications enabled: $enabled');
  }

  /// Get lyrics enabled state
  bool get lyricsEnabled => _lyricsEnabled;

  Future<void> dispose() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux) && _isInitialized) {
      HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
      try {
        await clearLyrics();
        if (Platform.isWindows) { await WindowsTaskbar.setProgressMode(TaskbarProgressMode.noProgress); }
      } catch (e) {
        debugPrint('WindowsSystemService dispose failed: $e');
      }
      _isInitialized = false;
    }
  }
}
