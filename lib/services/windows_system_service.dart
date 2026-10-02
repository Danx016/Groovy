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
  VoidCallback? onTogglePlayPause;
  Function(Duration position)? onSeekTo;

  // Multi-click state for single-button headset (same semantics as audio_handler.dart click())
  // 1 tap = play/pause, 2 taps = skip next, 3 taps = skip previous
  int _mediaClickCount = 0;
  int _clickGeneration = 0; // incremented on each click; used by the delayed closure to detect if a new click superseded it
  static const _multiClickWindow = Duration(milliseconds: 320);

  void _handleMediaClick() {
    _mediaClickCount++;
    final gen = ++_clickGeneration; // capture generation before the delay

    // Schedule the action after the multi-click window expires.
    // The closure checks if the generation is still current to detect whether
    // another click arrived during the wait and should supersede this one.
    Future.delayed(_multiClickWindow, () {
      if (gen != _clickGeneration) return; // another click arrived — let it fire instead
      final count = _mediaClickCount;
      _mediaClickCount = 0;
      if (count == 1) {
        if (onTogglePlayPause != null) {
          onTogglePlayPause!.call();
        } else if (_isPlaying) {
          onPause?.call();
        } else {
          onPlay?.call();
        }
      } else if (count == 2) {
        onSkipNext?.call();
      } else if (count >= 3) {
        onSkipPrevious?.call();
      }
    });
  }

  static const MethodChannel _mediaChannel =
      MethodChannel('com.groovy.music/windows_media_keys');

  DateTime? _lastKeyActionTime;
  String? _lastAction;
  static const _keyThrottleDuration = Duration(milliseconds: 200);

  bool _isActionThrottled(String action) {
    final now = DateTime.now();
    if (_lastAction == action &&
        _lastKeyActionTime != null &&
        now.difference(_lastKeyActionTime!) < _keyThrottleDuration) {
      return true;
    }
    _lastAction = action;
    _lastKeyActionTime = now;
    return false;
  }

  bool _isNextKey(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.mediaTrackNext ||
        event.logicalKey == LogicalKeyboardKey.mediaFastForward ||
        event.logicalKey == LogicalKeyboardKey.mediaSkipForward ||
        event.physicalKey == PhysicalKeyboardKey.mediaTrackNext ||
        event.physicalKey == PhysicalKeyboardKey.mediaFastForward;
  }

  bool _isPreviousKey(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.mediaTrackPrevious ||
        event.logicalKey == LogicalKeyboardKey.mediaRewind ||
        event.logicalKey == LogicalKeyboardKey.mediaSkipBackward ||
        event.physicalKey == PhysicalKeyboardKey.mediaTrackPrevious ||
        event.physicalKey == PhysicalKeyboardKey.mediaRewind;
  }

  bool _isPlayPauseKey(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.mediaPlayPause ||
        event.physicalKey == PhysicalKeyboardKey.mediaPlayPause;
  }

  bool _isPlayKey(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.mediaPlay ||
        event.physicalKey == PhysicalKeyboardKey.mediaPlay;
  }

  bool _isPauseKey(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.mediaPause ||
        event.physicalKey == PhysicalKeyboardKey.mediaPause;
  }

  bool _isStopKey(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.mediaStop ||
        event.physicalKey == PhysicalKeyboardKey.mediaStop;
  }

  @visibleForTesting
  void handleMediaClickForTesting() => _handleMediaClick();

  @visibleForTesting
  bool handleKeyEventForTesting(KeyEvent event) => _handleKeyEvent(event);

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    if (_isPlayPauseKey(event)) {
      if (_isActionThrottled('playPause')) return true;
      if (onTogglePlayPause != null) {
        onTogglePlayPause!.call();
      } else if (_isPlaying) {
        onPause?.call();
      } else {
        onPlay?.call();
      }
      return true;
    } else if (_isPlayKey(event)) {
      if (_isActionThrottled('play')) return true;
      onPlay?.call();
      return true;
    } else if (_isPauseKey(event)) {
      if (_isActionThrottled('pause')) return true;
      onPause?.call();
      return true;
    } else if (_isNextKey(event)) {
      if (_isActionThrottled('next')) return true;
      onSkipNext?.call();
      return true;
    } else if (_isPreviousKey(event)) {
      if (_isActionThrottled('previous')) return true;
      onSkipPrevious?.call();
      return true;
    } else if (_isStopKey(event)) {
      if (_isActionThrottled('stop')) return true;
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

      // 2. Windows native runner MethodChannel listener (WM_APPCOMMAND + global WM_HOTKEY)
      if (Platform.isWindows) {
        try {
          _mediaChannel.setMethodCallHandler((call) async {
            switch (call.method) {
              case 'skipNext':
                if (_isActionThrottled('next')) return;
                onSkipNext?.call();
                break;
              case 'skipPrevious':
                if (_isActionThrottled('previous')) return;
                onSkipPrevious?.call();
                break;
              case 'togglePlayPause':
                if (_isActionThrottled('playPause')) return;
                if (onTogglePlayPause != null) {
                  onTogglePlayPause!.call();
                } else if (_isPlaying) {
                  onPause?.call();
                } else {
                  onPlay?.call();
                }
                break;
              case 'play':
                if (_isActionThrottled('play')) return;
                onPlay?.call();
                break;
              case 'pause':
                if (_isActionThrottled('pause')) return;
                onPause?.call();
                break;
              case 'stop':
                if (_isActionThrottled('stop')) return;
                onStop?.call();
                break;
            }
          });
        } catch (e) {
          debugPrint('Error setting up native media keys MethodChannel: $e');
        }
      }

      // 3. Initialize local notifier for lyrics/notifications (optional, don't break media keys if it fails)
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
          '[Desktop] WindowsSystemService initialized (Taskbar, Media Keys & Lyrics Notifications)');
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
        debugPrint('[Desktop] Lyrics notification updated: $lyricsLine');
      } catch (e) {
        debugPrint('[Desktop] Failed to update lyrics notification: $e');
      }
    }
  }

  /// Clear lyrics notification
  Future<void> clearLyrics() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      try {
        await _lyricsNotification?.close();
        _lyricsNotification = null;
        debugPrint('[Desktop] Lyrics notification cleared');
      } catch (e) {
        debugPrint('[Desktop] Failed to clear lyrics notification: $e');
      }
    }
  }

  /// Enable/disable lyrics notifications
  Future<void> setLyricsEnabled(bool enabled) async {
    _lyricsEnabled = enabled;
    if (!enabled) {
      await clearLyrics();
    }
    debugPrint('[Desktop] Lyrics notifications enabled: $enabled');
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
