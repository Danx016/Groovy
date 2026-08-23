import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
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

  VoidCallback? onPlay;
  VoidCallback? onPause;
  VoidCallback? onStop;
  VoidCallback? onSkipNext;
  VoidCallback? onSkipPrevious;
  Function(Duration position)? onSeekTo;

  Future<void> initialize() async {
    if (!kIsWeb && Platform.isWindows) {
      if (_isInitialized) return;

      try {
        _isInitialized = true;

        // Initialize local notifier for lyrics
        await localNotifier.setup(
          appName: 'Groovy',
          shortcutPolicy: ShortcutPolicy.requireNoCreate,
        );

        debugPrint(
            'WindowsSystemService initialized (Taskbar & Lyrics Notification)');
      } catch (e) {
        debugPrint('Error initializing WindowsSystemService: $e');
      }
    }
  }

  Future<void> updatePlaybackState({
    required Song? song,
    required bool isPlaying,
    required Duration position,
    required Duration duration,
    String? artworkUrl,
  }) async {
    if (!kIsWeb && Platform.isWindows && _isInitialized) {
      try {
        if (duration.inMilliseconds > 0) {
          WindowsTaskbar.setProgress(
            position.inMilliseconds,
            duration.inMilliseconds,
          );
          WindowsTaskbar.setProgressMode(
            isPlaying ? TaskbarProgressMode.normal : TaskbarProgressMode.paused,
          );
        } else {
          WindowsTaskbar.setProgressMode(TaskbarProgressMode.noProgress);
        }
      } catch (e) {
        debugPrint('Error updating Windows playback state: $e');
      }
    }
  }

  /// Update current song info for lyrics display
  Future<void> updateSongInfo(Song? song) async {
    if (!kIsWeb && Platform.isWindows) {
      _currentSong = song;
      // Clear lyrics when song changes
      await clearLyrics();
    }
  }

  /// Update lyrics line - shows as Windows notification
  Future<void> updateLyrics(String? lyricsLine) async {
    if (!kIsWeb && Platform.isWindows && _lyricsEnabled) {
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
    if (!kIsWeb && Platform.isWindows) {
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
    if (!kIsWeb && Platform.isWindows) {
      try {
        await clearLyrics();
        await WindowsTaskbar.setProgressMode(TaskbarProgressMode.noProgress);
      } catch (e) {
        debugPrint('WindowsSystemService dispose failed: $e');
      }
      _isInitialized = false;
    }
  }
}
