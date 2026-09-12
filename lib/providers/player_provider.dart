import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;

import 'package:audio_session/audio_session.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/models.dart';
import '../services/youtube_service.dart';
import '../services/offline_service.dart';
import '../services/windows_system_service.dart';
import '../services/recommendation_service.dart';
import '../services/replay_gain_service.dart';
import '../services/auto_dj_service.dart';
import '../services/ytdlp_service.dart';
import '../services/lrclib_service.dart';
import '../services/palette_service.dart';
import '../services/audio_cache_service.dart';

import '../services/storage_service.dart';
import '../services/groovy_api_service.dart';
import '../services/cast_service.dart';
import '../services/upnp_service.dart';
import '../services/audio_handler.dart';

import '../services/transcoding_service.dart';
import '../services/groovy_connect_service.dart';
import '../providers/library_provider.dart';
import 'package:volume_controller/volume_controller.dart';

enum RepeatMode { off, all, one }

class PlayerProvider extends ChangeNotifier with WidgetsBindingObserver {
  final YoutubeService _youtubeService;
  late final StorageService _storageService;
  final GroovyAudioHandler _audioHandler;
  // Convenience getter — use this everywhere just_audio is accessed directly.
  AudioPlayer get _audioPlayer => _audioHandler.player;
  final OfflineService _offlineService = OfflineService();
  final WindowsSystemService _windowsService = WindowsSystemService();
  final ReplayGainService _replayGainService = ReplayGainService();
  final AutoDjService _autoDjService = AutoDjService();
  final AudioCacheService _audioCacheService = AudioCacheService();

  final CastService _castService;
  late final UpnpService _upnpService;

  LibraryProvider? _libraryProvider;
  RecommendationService? _recommendationService;

  List<Song> _queue = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _shuffleEnabled = false;
  bool _gaplessEnabled = true;
  final List<String> _shuffleHistory = [];
  RepeatMode _repeatMode = RepeatMode.off;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Song? _currentSong;
  String? _activeAudioSongId;
  double _volume = 1.0;

  /// True only while audio is actually being rendered on a remote device.
  /// Distinct from isConnected: if the user plays a radio station while a
  /// UPnP renderer is connected, the audio is still local, so this stays false.
  bool _isRenderingRemotely = false;
  Timer? _remotePositionTickerTimer;
  Duration _remoteAnchorPosition = Duration.zero;
  DateTime? _remoteAnchorTime;
  int _lastRemoteNotifiedSecond = -1;
  String? _optimisticRemoteSongId;
  DateTime? _optimisticRemoteSongUntil;
  DateTime? _optimisticRemotePlayPauseUntil;
  bool? _optimisticRemotePlayPauseState;
  DateTime? _lastRemoteSeekTime;
  DateTime? _lastRemoteVolumeChangeTime;
  double? _optimisticRemoteVolume;
  Timer? _remoteVolumeDebounceTimer;

  String? _resolvedArtworkUrl;

  RadioStation? _currentRadioStation;
  bool _isPlayingRadio = false;

  bool _hasPlayedOnce = false;

  SharedPreferences? _prefs;
  Timer? _persistDebounceTimer;
  Timer? _skipDebounceTimer;
  static const String _keyQueue = 'persistent_queue';
  static const String _keyQueueIndex = 'persistent_queue_index';
  static const String _keyQueueSongId = 'persistent_queue_song_id';
  static const String _keyQueuePosition = 'persistent_queue_position_ms';

  final bool _reactivatingSession = false;
  DateTime? _lastUserPauseTime;
  String? _lastCompletedSongId;

  /// Last playback error message, set when a song fails to load after all retries.
  /// Cleared automatically when a new song starts successfully.
  String? _lastPlaybackError;
  String? get lastPlaybackError => _lastPlaybackError;

  /// Optional callback invoked (in addition to notifyListeners) when playback
  /// fails definitively — useful for showing a SnackBar from a widget.
  void Function(String message)? onPlaybackError;

  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }

  Timer? _sleepTimer;
  DateTime? _sleepTimerEnd;
  bool _sleepTimerEndCurrentSong = false;
  bool _sleepTimerFadeOut = false;
  int _sleepTimerFadeDurationSeconds = 30;
  Timer? _sleepTimerFadeTimer;
  Timer? _sleepTimerFadePeriodicTimer;

  Timer? _telemetryTimer;
  DateTime? _optimisticLocalPlayPauseTime;
  bool? _optimisticLocalPlayPauseState;

  void _startTelemetryHeartbeat() {
    _telemetryTimer?.cancel();
    final interval = (_groovyConnectService?.isConnected == true)
        ? const Duration(milliseconds: 350)
        : const Duration(milliseconds: 600);
    _telemetryTimer = Timer.periodic(interval, (_) {
      if (_isPlaying) {
        _sendTelemetryHeartbeat();
      }
    });
  }

  String? _cachedUserToken;

  void _sendTelemetryHeartbeat({bool? overridePlaying, Song? overrideSong}) {
    final song = overrideSong ?? _currentSong;
    if (song == null) return;
    final isPl = overridePlaying ?? _isPlaying;
    final posMs = _position.inMilliseconds;

    void sendWithToken(String token) {
      GroovyApiService().reportPlaybackState(
        token: token,
        song: song,
        isPlaying: isPl,
        position: _position.inSeconds,
        positionMs: posMs,
        listenDeltaSeconds: isPl ? 2 : 0,
        deviceId: _groovyConnectService?.localDeviceId,
        volume: _volume,
        localIp: _groovyConnectService?.localIp,
        localPort: _groovyConnectService?.httpPort,
      );
    }

    final token = _cachedUserToken ?? _groovyConnectService?.cachedAuthToken;
    if (token != null && token.isNotEmpty) {
      sendWithToken(token);
    } else {
      StorageService().getUserToken().then((tok) {
        if (tok != null && tok.isNotEmpty) {
          _cachedUserToken = tok;
          sendWithToken(tok);
        }
      }).catchError((_) {});
    }
  }

  void sendTelemetryHeartbeatNow({bool? overridePlaying, Song? overrideSong}) {
    _sendTelemetryHeartbeat(overridePlaying: overridePlaying, overrideSong: overrideSong);
  }

  final TranscodingService _transcodingService;

  double _playbackSpeed = 1.0;
  double _pitch = 1.0;
  bool _pitchCorrection = true;
  bool _hasRetriedCurrentPlay = false;
  int _playGeneration = 0;
  int _skipGeneration = 0; // incremented on every skip to cancel in-flight skips when user skips rapidly
  bool _isTransitioningSong = false;

  PlayerProvider(
    this._youtubeService,
    StorageService storageService,
    this._castService,
    this._upnpService,
    this._audioHandler,
    this._transcodingService,
  ) {
    _storageService = storageService;

    _castService.addListener(_onCastStateChanged);
    _upnpService.addListener(_onUpnpStateChanged);
    _upnpService.onRendererLost = _onUpnpRendererLost;
    _initializePlayer();
    try {
      _initializeAndroidAuto();
    } catch (_) {}
    try {
      _initializeSystemServices();
    } catch (_) {}
    _initializeAutoDj();
    _wireAudioHandlerCallbacks();



    _restoreQueueState();

    // Register app lifecycle observer to save state on iOS when app goes to background
    WidgetsBinding.instance.addObserver(this);
  }

  /// Handle app lifecycle changes - save queue state when going to background (important for iOS/Android)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      debugPrint(
          '[Player] App lifecycle state: $state - saving queue state immediately');
      _saveQueueStateImmediate();
    } else if (state == AppLifecycleState.resumed) {
      if (!_isRenderingRemotely && _audioPlayer.playing) {
        _position = _audioPlayer.position;
        _positionController.add(_position);
        notifyListeners();
      }
    }
  }

  /// Connect [GroovyAudioHandler] lock-screen commands back to this provider.
  /// On iOS these come via [audio_service] instead of [iOSSystemPlugin].
  void _wireAudioHandlerCallbacks() {
    _audioHandler.onPlay = play;
    _audioHandler.onPause = pause;
    _audioHandler.onStop = stop;
    _audioHandler.onSkipNext = skipNext;
    _audioHandler.onSkipPrevious = skipPrevious;
    _audioHandler.onSeekTo = seek;
    _audioHandler.onTogglePlayPause = togglePlayPause;
  }

  // ── Persistent Queue ───────────────────────────────────────────────────────

  void _saveQueueState() {
    _persistDebounceTimer?.cancel();
    _persistDebounceTimer = Timer(const Duration(milliseconds: 200), () async {
      await _saveQueueStateImmediate();
    });
  }

  Future<void> _saveQueueStateImmediate() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      if (_prefs == null) return;
      final queueJson = _queue.map((s) => s.toJson()).toList();
      await _prefs!.setString(_keyQueue, jsonEncode(queueJson));
      await _prefs!.setInt(_keyQueueIndex, _currentIndex);
      await _prefs!.setString(_keyQueueSongId, _currentSong?.id ?? '');
      await _prefs!.setInt(_keyQueuePosition, _position.inMilliseconds);
      debugPrint(
          'Queue state saved: index $_currentIndex, position $_position');
    } catch (e) {
      debugPrint('Error saving queue state: $e');
    }
  }

  Future<void> _restoreQueueState() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      if (_prefs == null) return;

      final queueRaw = _prefs!.getString(_keyQueue);
      if (queueRaw == null || queueRaw.isEmpty) return;

      final queueJson = jsonDecode(queueRaw) as List<dynamic>;
      if (queueJson.isEmpty) return;

      final restoredSongs = queueJson
          .map((j) => Song.fromJson(j as Map<String, dynamic>))
          .where((s) {
        // Validate local files still exist.
        if (s.isLocal && s.path != null) {
          return File(s.path!).existsSync();
        }
        return true;
      }).toList();

      if (restoredSongs.isEmpty) return;

      final savedIndex = _prefs!.getInt(_keyQueueIndex) ?? 0;
      final savedSongId = _prefs!.getString(_keyQueueSongId);
      final savedPositionMs = _prefs!.getInt(_keyQueuePosition) ?? 0;

      var targetIndex = savedIndex.clamp(0, restoredSongs.length - 1);
      if (savedSongId != null && savedSongId.isNotEmpty) {
        final idIndex = restoredSongs.indexWhere((s) => s.id == savedSongId);
        if (idIndex != -1) targetIndex = idIndex;
      }

      _queue = restoredSongs;
      _currentIndex = targetIndex;
      _currentSong = restoredSongs[targetIndex];
      _position = Duration(milliseconds: savedPositionMs);
      final songDurationSecs = restoredSongs[targetIndex].duration;
      if (songDurationSecs != null && songDurationSecs > 0) {
        _duration = Duration(seconds: songDurationSecs);
      }
      notifyListeners();
      debugPrint(
          'Restored persistent queue: ${restoredSongs.length} songs, index $targetIndex, position $_position');
      _prepareCurrentSong().catchError((e) {
        debugPrint('Error preparing restored song: $e');
      });
    } catch (e) {
      debugPrint('Error restoring queue state: $e');
    }
  }

  void _clearPersistedQueue() {
    _persistDebounceTimer?.cancel();
    try {
      SharedPreferences.getInstance().then((p) {
        p.remove(_keyQueue);
        p.remove(_keyQueueIndex);
        p.remove(_keyQueueSongId);
      });
    } catch (_) {}
  }

  GroovyConnectService? _groovyConnectService;

  void setGroovyConnectService(GroovyConnectService service) {
    _groovyConnectService?.removeListener(_onGroovyConnectChanged);
    _groovyConnectService = service;
    _groovyConnectService?.addListener(_onGroovyConnectChanged);
    _groovyConnectService?.onRemoteStatusUpdated = onGroovyConnectRemoteStatusUpdated;
    StorageService().getUserToken().then((token) {
      if (token != null && token.isNotEmpty) {
        _groovyConnectService?.updateAuthToken(token);
      }
    }).catchError((_) {});
  }

  void _onGroovyConnectChanged() {
    final isConnected = _groovyConnectService?.isConnected == true;
    _startTelemetryHeartbeat();
    if (isConnected) {
      if (_audioPlayer.playing) {
        _audioPlayer.stop();
      }
      _isRenderingRemotely = true;
      _remoteAnchorPosition = _position;
      _remoteAnchorTime = _isPlaying ? DateTime.now() : null;
      _manageRemotePositionTicker();
      _audioHandler.setRemotePlayback(isRemote: true);
      notifyListeners();
      _updateAllServices();
    } else if (_isRenderingRemotely && !_castService.isConnected && !_upnpService.isConnected) {
      _isRenderingRemotely = false;
      _remotePositionTickerTimer?.cancel();
      _remotePositionTickerTimer = null;
      _remoteAnchorTime = null;
      _audioHandler.setRemotePlayback(isRemote: false);
      notifyListeners();
      _updateAllServices();
    }
  }

  void enableGroovyConnectRemote(
    GroovyRemoteDevice device, {
    Song? transferredSong,
    bool? isPlaying,
    Duration? position,
  }) {
    try {
      _audioPlayer.pause();
      _audioPlayer.stop();
    } catch (_) {}
    _isRenderingRemotely = true;
    _lastRemoteSeekTime = null;

    if (transferredSong != null) {
      _currentSong = transferredSong;
      _isPlaying = isPlaying ?? true;
      _position = position ?? Duration.zero;
      _duration = transferredSong.duration != null
          ? Duration(seconds: transferredSong.duration!)
          : Duration.zero;
      _optimisticRemoteSongId = transferredSong.id;
      _optimisticRemoteSongUntil = DateTime.now().add(const Duration(milliseconds: 12000));
      _optimisticRemotePlayPauseState = _isPlaying;
      _optimisticRemotePlayPauseUntil = DateTime.now().add(const Duration(milliseconds: 3000));
      _refreshArtworkUrl().catchError((_) {});
    } else if (device.currentSong != null && (_currentSong == null || device.isPlaying)) {
      _currentSong = device.currentSong;
      _isPlaying = device.isPlaying;
      _duration = device.currentSong!.duration != null
          ? Duration(seconds: device.currentSong!.duration!)
          : Duration.zero;
      _refreshArtworkUrl().catchError((_) {});
    }

    _remoteAnchorPosition = _position;
    _remoteAnchorTime = _isPlaying ? DateTime.now() : null;
    _manageRemotePositionTicker();
    _audioHandler.setRemotePlayback(
      isRemote: true,
      volume: (_volume * 100).round(),
    );
    notifyListeners();
    _updateAllServices();
    _updateAndroidAuto();
  }

  void disableGroovyConnectRemote() {
    _isRenderingRemotely = false;
    _lastRemoteSeekTime = null;
    _lastRemoteVolumeChangeTime = null;
    _optimisticRemoteVolume = null;
    _remoteVolumeDebounceTimer?.cancel();
    _remoteVolumeDebounceTimer = null;
    _optimisticRemoteSongId = null;
    _optimisticRemoteSongUntil = null;
    _optimisticRemotePlayPauseState = null;
    _optimisticRemotePlayPauseUntil = null;
    _remotePositionTickerTimer?.cancel();
    _remotePositionTickerTimer = null;
    _remoteAnchorTime = null;
    _audioHandler.setRemotePlayback(isRemote: false);
    notifyListeners();
    _updateAllServices();
    _updateAndroidAuto();
  }

  void onGroovyConnectRemoteStatusUpdated({
    Song? song,
    required Duration position,
    required Duration duration,
    required bool isPlaying,
    required double volume,
  }) {
    final bool isRemote = _isRenderingRemotely || _groovyConnectService?.isConnected == true;
    if (!isRemote) return;

    // If we recently initiated an optimistic song change, ignore stale reports of the old song
    if (_optimisticRemoteSongUntil != null && DateTime.now().isBefore(_optimisticRemoteSongUntil!)) {
      if (song != null && song.id == _optimisticRemoteSongId) {
        // The remote device acknowledged the new song — clear optimistic window
        // whenever the remote confirms it is playing, or once position has moved, or loaded paused.
        final remoteActuallyPlaying = isPlaying;
        final remoteLoadedButPaused = !isPlaying &&
            DateTime.now().isAfter(_optimisticRemoteSongUntil!.subtract(const Duration(seconds: 4)));
        if (remoteActuallyPlaying || remoteLoadedButPaused) {
          _optimisticRemoteSongUntil = null;
          _optimisticRemoteSongId = null;
          _isLoading = false;
          _isPlaying = isPlaying;
          _remoteAnchorPosition = position;
          _remoteAnchorTime = isPlaying ? DateTime.now() : null;
          _position = position;
          _positionController.add(position);
        } else {
          // Remote is still buffering before starting playback; keep current optimistic state
          return;
        }
      } else {
        // Remote device is still transitioning; ignore stale song to prevent flickering/reverting
        return;
      }
    }

    bool changed = false;
    if (song != null && _currentSong?.id != song.id) {
      _currentSong = song;
      // Sync queue index if this song exists in our local queue
      final qIndex = _queue.indexWhere((s) => s.id == song.id);
      if (qIndex != -1) {
        _currentIndex = qIndex;
      }
      _refreshArtworkUrl().catchError((_) {});
      _audioHandler.updateNowPlaying(
        id: song.id,
        title: song.title,
        artist: song.artist,
        album: song.album,
        artworkUrl: _resolveArtworkUrl(),
        duration: duration,
      );
      // Only accept the remote position as the anchor if the device is actually playing.
      // If it just changed songs and reports position=0 while still loading, keep our
      // local dead-reckoning estimate rather than resetting back to 0:00.
      if (isPlaying || position.inMilliseconds > 0) {
        _remoteAnchorPosition = position;
        _remoteAnchorTime = isPlaying ? DateTime.now() : null;
        _position = position;
        _positionController.add(position);
      }
      changed = true;
    }

    if (duration > Duration.zero && _duration != duration) {
      _duration = duration;
      changed = true;
    }

    final bool isOptimisticActive = _optimisticRemoteSongUntil != null &&
        DateTime.now().isBefore(_optimisticRemoteSongUntil!);

    final bool isOptimisticPlayPauseActive = _optimisticRemotePlayPauseUntil != null &&
        DateTime.now().isBefore(_optimisticRemotePlayPauseUntil!);

    if (isOptimisticPlayPauseActive) {
      if (_optimisticRemotePlayPauseState == isPlaying) {
        _optimisticRemotePlayPauseUntil = null;
        _optimisticRemotePlayPauseState = null;
      }
    } else if (!isOptimisticActive) {
      if (_isPlaying != isPlaying) {
        _isPlaying = isPlaying;
        _remoteAnchorPosition = position;
        _remoteAnchorTime = isPlaying ? DateTime.now() : null;
        _position = position;
        _positionController.add(position);
        changed = true;
      }
    }

    // Reconcile extrapolated position with actual remote reported position
    final currentExtrapolated = _remoteAnchorTime != null && _isPlaying
        ? _remoteAnchorPosition + DateTime.now().difference(_remoteAnchorTime!)
        : _position;

    // Ignore remote reported positions for 4 seconds after an intentional seek on controller
    final bool isRecentSeek = _lastRemoteSeekTime != null &&
        DateTime.now().difference(_lastRemoteSeekTime!) < const Duration(seconds: 4);

    if (!isRecentSeek && !isOptimisticActive) {
      if (!_isPlaying) {
        _remoteAnchorPosition = position;
        _remoteAnchorTime = null;
        _position = position;
        _positionController.add(position);
        changed = true;
      } else {
        final diffMs = position.inMilliseconds - currentExtrapolated.inMilliseconds;
        // Use a larger threshold (-8000ms instead of -4000ms) to avoid treating
        // transient loading resets (positionMs=0 while buffering) as intentional seeks.
        if (diffMs < -8000) {
          // Significant backward seek on the remote device (>8s)
          _remoteAnchorPosition = position;
          _remoteAnchorTime = isPlaying ? DateTime.now() : null;
          _position = position;
          _positionController.add(position);
          changed = true;
        } else if (diffMs < -1500 && position.inMilliseconds <= 1500 && currentExtrapolated.inMilliseconds > 3000) {
          // Remote is reporting near-zero while we extrapolated past 3s: device is loading.
          // Do NOT reset — let dead-reckoning continue.
          // (no-op: skip the anchor update)
        } else if (diffMs > 150) {
          // Remote report is ahead; catch up immediately so playback & lyrics stay tightly 'en vivo'
          _remoteAnchorPosition = position;
          _remoteAnchorTime = isPlaying ? DateTime.now() : null;
          _position = position;
          _positionController.add(position);
          changed = true;
        }
        // Small lag (diffMs between -8000 and 0) is ignored so dead reckoning extrapolation continues smoothly without jumping backward
      }
    }

    final bool isRecentVolumeChange = _lastRemoteVolumeChangeTime != null &&
        DateTime.now().difference(_lastRemoteVolumeChangeTime!) < const Duration(seconds: 4);

    if (isRecentVolumeChange) {
      if (_optimisticRemoteVolume != null && (volume - _optimisticRemoteVolume!).abs() <= 0.05) {
        _lastRemoteVolumeChangeTime = null;
        _optimisticRemoteVolume = null;
      }
    } else {
      if ((_volume - volume).abs() > 0.05) {
        _volume = volume;
        _audioHandler.updateRemoteVolume((_volume * 100).round());
        changed = true;
      }
    }

    _manageRemotePositionTicker();

    if (changed) {
      _audioHandler.updateRemotePlaybackState(
        playing: _isPlaying,
        position: _position,
      );
      notifyListeners();
      _updateAllServices();
      _updateAndroidAuto();
    }
  }

  void _manageRemotePositionTicker() {
    final bool isRemote = _isRenderingRemotely || _groovyConnectService?.isConnected == true;
    if (isRemote && _isPlaying) {
      if (_remotePositionTickerTimer == null || !_remotePositionTickerTimer!.isActive) {
        _remotePositionTickerTimer?.cancel();
        _remotePositionTickerTimer = Timer.periodic(
          const Duration(milliseconds: 50),
          (_) => _tickRemotePosition(),
        );
      }
    } else {
      _remotePositionTickerTimer?.cancel();
      _remotePositionTickerTimer = null;
    }
  }

  void _tickRemotePosition() {
    final bool isRemote = _isRenderingRemotely || _groovyConnectService?.isConnected == true;
    if (!isRemote || !_isPlaying || _remoteAnchorTime == null) {
      _remotePositionTickerTimer?.cancel();
      _remotePositionTickerTimer = null;
      return;
    }

    final elapsed = DateTime.now().difference(_remoteAnchorTime!);
    var est = _remoteAnchorPosition + elapsed;
    if (_duration > Duration.zero && est > _duration) {
      est = _duration;
    }

    _position = est;
    _positionController.add(est);

    // Notify listeners every full second so widgets like DesktopPlayerBar text and slider update live
    if (est.inSeconds != _lastRemoteNotifiedSecond) {
      _lastRemoteNotifiedSecond = est.inSeconds;
      notifyListeners();
    }
  }

  void setLibraryProvider(LibraryProvider libraryProvider) {
    _libraryProvider?.removeListener(_onLibraryChanged);
    _libraryProvider = libraryProvider;
    _libraryProvider?.addListener(_onLibraryChanged);
  }

  void _onLibraryChanged() {
    if (_currentSong != null && _libraryProvider != null) {
      final libStarred = _libraryProvider!.isSongStarred(_currentSong!.id);
      if (_currentSong!.starred != libStarred) {
        _currentSong = _currentSong!.copyWith(starred: libStarred);
        notifyListeners();
      }
    }
  }

  void updateSongStarred(String songId, bool isStarred) {
    if (_currentSong != null && _currentSong!.id == songId) {
      if (_currentSong!.starred != isStarred) {
        _currentSong = _currentSong!.copyWith(starred: isStarred);
        notifyListeners();
      }
    }
  }

  void setRecommendationService(RecommendationService recommendationService) {
    _recommendationService = recommendationService;
    _autoDjService.setServices(_youtubeService, recommendationService);
  }

  AutoDjService get autoDjService => _autoDjService;


  Future<void> _initializeAutoDj() async {
    await _autoDjService.initialize();
    _autoDjService.setServices(_youtubeService, _recommendationService);
  }



  Future<void> _initializeSystemServices() async {
    await _windowsService.initialize();
    _windowsService.onPlay = play;
    _windowsService.onPause = pause;
    _windowsService.onStop = stop;
    _windowsService.onSkipNext = skipNext;
    _windowsService.onSkipPrevious = skipPrevious;
    _windowsService.onSeekTo = seek;
    _windowsService.onTogglePlayPause = togglePlayPause;
  }

  void _initializeAndroidAuto() {
    // Song-level browse data, search and playback for Android Auto are
    // served through the audio_service handler (see GroovyAudioHandler).
    _audioHandler.onGetAlbumSongs = _getAlbumSongsForAndroidAuto;
    _audioHandler.onGetArtistAlbums = _getArtistAlbumsForAndroidAuto;
    _audioHandler.onGetPlaylistSongs = _getPlaylistSongsForAndroidAuto;
    _audioHandler.onSearch = _searchForAndroidAuto;
    _audioHandler.onPlayFromMediaId = _playFromMediaId;
    _audioHandler.onPlayFromSearch = _playFromSearchForAndroidAuto;
    _audioHandler.onSetRemoteVolume = _onRemoteVolumeChange;
  }

  Future<List<Map<String, String>>> _getAlbumSongsForAndroidAuto(
    String albumId,
  ) async {
    if (_offlineService.isOfflineMode && _libraryProvider != null) {
      await _offlineService.initialize();
      final downloadedIds = _offlineService.getDownloadedSongIds().toSet();
      final offlineSongs = _libraryProvider!.cachedAllSongs
          .where((s) => s.albumId == albumId && downloadedIds.contains(s.id))
          .toList();
      if (offlineSongs.isNotEmpty) {
        return offlineSongs
            .map(
              (song) => {
                'id': song.id,
                'title': song.title,
                'artist': song.artist ?? '',
                'album': song.album ?? '',
                'artworkUrl': _offlineService.getLocalCoverArtPath(song.id) !=
                        null
                    ? Uri.file(_offlineService.getLocalCoverArtPath(song.id)!)
                        .toString()
                    : _youtubeService.getCoverArtUrl(song.coverArt, size: 300),
                'duration': (song.duration ?? 0).toString(),
              },
            )
            .toList();
      }
    }
    try {
      final songs = await _youtubeService.getAlbumSongs(albumId);
      return songs
          .map(
            (song) => {
              'id': song.id,
              'title': song.title,
              'artist': song.artist ?? '',
              'album': song.album ?? '',
              'artworkUrl': _youtubeService.getCoverArtUrl(
                song.coverArt,
                size: 300,
              ),
              'duration': (song.duration ?? 0).toString(),
            },
          )
          .toList();
    } catch (e) {
      debugPrint('Error getting album songs for Android Auto: $e');
      return [];
    }
  }

  Future<List<Map<String, String>>> _getArtistAlbumsForAndroidAuto(
    String artistId,
  ) async {
    if (_offlineService.isOfflineMode && _libraryProvider != null) {
      await _offlineService.initialize();
      final downloadedIds = _offlineService.getDownloadedSongIds().toSet();
      final albumIdsWithDownloads = _libraryProvider!.cachedAllSongs
          .where((s) => s.artistId == artistId && downloadedIds.contains(s.id))
          .map((s) => s.albumId)
          .whereType<String>()
          .toSet();
      final offlineAlbums = _libraryProvider!.cachedAllAlbums
          .where((a) => albumIdsWithDownloads.contains(a.id))
          .toList();
      if (offlineAlbums.isNotEmpty) {
        return offlineAlbums
            .map(
              (album) => {
                'id': album.id,
                'name': album.name,
                'artist': album.artist ?? '',
                'artworkUrl': _youtubeService.getCoverArtUrl(
                  album.coverArt,
                  size: 300,
                ),
              },
            )
            .toList();
      }
    }
    try {
      final albums = await _youtubeService.getArtistAlbums(artistId);
      return albums
          .map(
            (album) => {
              'id': album.id,
              'name': album.name,
              'artist': album.artist ?? '',
              'artworkUrl': _youtubeService.getCoverArtUrl(
                album.coverArt,
                size: 300,
              ),
            },
          )
          .toList();
    } catch (e) {
      debugPrint('Error getting artist albums for Android Auto: $e');
      return [];
    }
  }

  Future<List<Map<String, String>>> _getPlaylistSongsForAndroidAuto(
    String playlistId,
  ) async {
    if (_offlineService.isOfflineMode && _libraryProvider != null) {
      await _offlineService.initialize();
      final downloadedIds = _offlineService.getDownloadedSongIds().toSet();
      final cachedPlaylist = _libraryProvider!.playlists
          .where((p) => p.id == playlistId)
          .firstOrNull;
      if (cachedPlaylist?.songs != null && cachedPlaylist!.songs!.isNotEmpty) {
        final offlineSongs = cachedPlaylist.songs!
            .where((s) => downloadedIds.contains(s.id))
            .toList();
        if (offlineSongs.isNotEmpty) {
          return offlineSongs
              .map(
                (song) => {
                  'id': song.id,
                  'title': song.title,
                  'artist': song.artist ?? '',
                  'album': song.album ?? '',
                  'artworkUrl': _offlineService.getLocalCoverArtPath(song.id) !=
                          null
                      ? Uri.file(_offlineService.getLocalCoverArtPath(song.id)!)
                          .toString()
                      : _youtubeService.getCoverArtUrl(song.coverArt,
                          size: 300),
                  'duration': (song.duration ?? 0).toString(),
                },
              )
              .toList();
        }
      }
    }
    try {
      final playlist = await _youtubeService.getPlaylist(playlistId);
      final songs = playlist.songs ?? [];
      return songs
          .map(
            (song) => {
              'id': song.id,
              'title': song.title,
              'artist': song.artist ?? '',
              'album': song.album ?? '',
              'artworkUrl': _youtubeService.getCoverArtUrl(
                song.coverArt,
                size: 300,
              ),
              'duration': (song.duration ?? 0).toString(),
            },
          )
          .toList();
    } catch (e) {
      debugPrint('Error getting playlist songs for Android Auto: $e');
      return [];
    }
  }

  Future<List<Map<String, String>>> _searchForAndroidAuto(
    String query,
  ) async {
    debugPrint(
        'PlayerProvider: _searchForAndroidAuto called with query="$query"');
    debugPrint(
        'PlayerProvider: isOfflineMode=${_offlineService.isOfflineMode}, libraryProvider=$_libraryProvider');

    if (_offlineService.isOfflineMode && _libraryProvider != null) {
      await _offlineService.initialize();
      final downloadedIds = _offlineService.getDownloadedSongIds().toSet();
      final lowerQuery = query.toLowerCase();
      final offlineResults = _libraryProvider!.cachedAllSongs
          .where(
            (s) =>
                downloadedIds.contains(s.id) &&
                (s.title.toLowerCase().contains(lowerQuery) ||
                    (s.artist?.toLowerCase().contains(lowerQuery) ?? false) ||
                    (s.album?.toLowerCase().contains(lowerQuery) ?? false)),
          )
          .take(20)
          .toList();
      return offlineResults
          .map(
            (song) => {
              'id': song.id,
              'title': song.title,
              'artist': song.artist ?? '',
              'album': song.album ?? '',
              'artworkUrl': _offlineService.getLocalCoverArtPath(song.id) !=
                      null
                  ? Uri.file(_offlineService.getLocalCoverArtPath(song.id)!)
                      .toString()
                  : _youtubeService.getCoverArtUrl(song.coverArt, size: 300),
              'duration': (song.duration ?? 0).toString(),
            },
          )
          .toList();
    }

    // For YT Stream, also do a fast local-DB search on already-cached songs
    // before hitting the network, to make Auto browsing feel snappier.
    if (_youtubeService.isYoutube && _libraryProvider != null) {
      final lowerQuery = query.toLowerCase();
      final localHits = _libraryProvider!.cachedAllSongs
          .where(
            (s) =>
                s.title.toLowerCase().contains(lowerQuery) ||
                (s.artist?.toLowerCase().contains(lowerQuery) ?? false),
          )
          .take(20)
          .toList();
      if (localHits.isNotEmpty) {
        return localHits
            .map(
              (song) => {
                'id': song.id,
                'title': song.title,
                'artist': song.artist ?? '',
                'album': song.album ?? '',
                // YouTube songs store the thumbnail URL directly in coverArt
                'artworkUrl': song.coverArt ?? '',
                'duration': (song.duration ?? 0).toString(),
              },
            )
            .toList();
      }
    }

    try {
      debugPrint(
          'PlayerProvider: Calling youtubeService.search with query="$query"');
      final results = await _youtubeService.search(
        query,
        songCount: 20,
        albumCount: 0,
        artistCount: 0,
      );
      debugPrint(
          'PlayerProvider: Search returned ${results.songs.length} songs');
      return results.songs
          .map(
            (song) => {
              'id': song.id,
              'title': song.title,
              'artist': song.artist ?? '',
              'album': song.album ?? '',
              'artworkUrl': _youtubeService.isYoutube
                  ? (song.coverArt ?? '')
                  : _youtubeService.getCoverArtUrl(song.coverArt, size: 300),
              'duration': (song.duration ?? 0).toString(),
            },
          )
          .toList();
    } catch (e, stackTrace) {
      debugPrint('PlayerProvider: Android Auto search error: $e');
      debugPrint('PlayerProvider: Stack trace: $stackTrace');
      return [];
    }
  }

  Future<void> _playFromSearchForAndroidAuto(String query) async {
    debugPrint('Android Auto: playFromSearch called with query: "$query"');
    try {
      if (query.trim().isEmpty) {
        if (_currentSong != null) {
          await play();
          return;
        }
        // In YT Stream mode play from cached songs when no query is given.
        if (_youtubeService.isYoutube &&
            _libraryProvider != null &&
            _libraryProvider!.cachedAllSongs.isNotEmpty) {
          final songs = _libraryProvider!.cachedAllSongs;
          await playSong(songs.first, playlist: songs, startIndex: 0);
          return;
        }
        if (_libraryProvider != null &&
            _libraryProvider!.randomSongs.isNotEmpty) {
          final songs = _libraryProvider!.randomSongs;
          await playSong(songs.first, playlist: songs, startIndex: 0);
        }
        return;
      }

      final results = await _youtubeService.search(
        query,
        songCount: 20,
        albumCount: 0,
        artistCount: 0,
      );
      if (results.songs.isNotEmpty) {
        await playSong(
          results.songs.first,
          playlist: results.songs,
          startIndex: 0,
        );
      } else {
        debugPrint('Android Auto: no search results for "$query"');
      }
    } catch (e) {
      debugPrint('Android Auto: playFromSearch error: $e');
    }
  }

  Future<void> _playFromMediaId(String mediaId) async {
    debugPrint('Android Auto: playFromMediaId called with: $mediaId');

    // 1. Check the current queue first (works for all server types).
    final queueIndex = _queue.indexWhere((song) => song.id == mediaId);
    if (queueIndex != -1) {
      await skipToIndex(queueIndex);
      return;
    }

    // 2. Check the in-memory library
    if (_libraryProvider != null) {
      final allSongs = _youtubeService.isYoutube
          ? _libraryProvider!.cachedAllSongs
          : _libraryProvider!.randomSongs;
      final songIndex = allSongs.indexWhere((song) => song.id == mediaId);
      if (songIndex != -1) {
        await playSong(
          allSongs[songIndex],
          playlist: allSongs,
          startIndex: songIndex,
        );
        return;
      }
    }

    // 3. In YT Stream mode the mediaId IS the YouTube video ID – play it
    //    directly without a round-trip search.
    if (_youtubeService.isYoutube) {
      try {
        // Build a minimal Song object so playSong can resolve the stream.
        final tempSong = Song(
          id: mediaId,
          title: mediaId,
          artist: 'YouTube',
        );
        await playSong(tempSong);
        return;
      } catch (e) {
        debugPrint('Direct YouTube ID play error: $e');
      }
      return;
    }

    // 4. Fallback: search by ID.
    try {
      final searchResults = await _youtubeService.search(
        mediaId,
        songCount: 5,
      );
      if (searchResults.songs.isNotEmpty) {
        final song = searchResults.songs.firstWhere(
          (s) => s.id == mediaId,
          orElse: () => searchResults.songs.first,
        );
        await playSong(song);
        return;
      }

      debugPrint('Android Auto: Could not find song with id: $mediaId');
    } catch (e) {
      debugPrint('Android Auto: Error fetching song: $e');
    }
  }

  String? _resolveArtworkUrl() {
    if (_currentSong == null) return null;
    if (_currentSong!.coverArt == null) return null;
    if (_currentSong!.isLocal) {
      return Uri.file(_currentSong!.coverArt!).toString();
    }

    if (_resolvedArtworkUrl != null && _resolvedArtworkUrl!.isNotEmpty) {
      return _resolvedArtworkUrl;
    }

    final cover = _currentSong!.coverArt!;
    if (cover.startsWith('http://') || cover.startsWith('https://')) {
      return cover;
    }
    return _youtubeService.getCoverArtUrl(cover, size: 800);
  }

  Future<void> _refreshArtworkUrl() async {
    final song = _currentSong;
    if (song == null || song.coverArt == null) {
      _resolvedArtworkUrl = null;
      return;
    }
    if (song.isLocal) {
      _resolvedArtworkUrl = Uri.file(song.coverArt!).toString();
      if (_currentSong?.id == song.id) _updateAndroidAuto();
      return;
    }

    await _offlineService.initialize();

    final localPath = _offlineService.getLocalCoverArtPath(song.id);
    if (localPath != null) {
      _resolvedArtworkUrl = Uri.file(localPath).toString();
      if (_currentSong?.id == song.id) _updateAndroidAuto();
      return;
    }

    final coverArtId = song.coverArt!;
    final directUrl = (coverArtId.startsWith('http://') || coverArtId.startsWith('https://'))
        ? coverArtId
        : _youtubeService.getCoverArtUrl(coverArtId, size: 800);

    _resolvedArtworkUrl = directUrl;
    if (_currentSong?.id == song.id) _updateAndroidAuto();

    // Pre-warm background palette cache immediately in parallel so entering NowPlayingScreen has a 0ms instant cache hit
    final songId = song.id;
    if (PaletteService.getCachedColors(songId) == null) {
      final ImageProvider imgProvider = CachedNetworkImageProvider(directUrl);
      PaletteService.extractColors(imgProvider, songId).catchError((_) => <Color>[]);
    }

    // Cache the image file locally so Android notification / lock screen loads it instantly from disk!
    try {
      final file = await DefaultCacheManager().getSingleFile(directUrl);
      if (file.existsSync() && _currentSong?.id == song.id) {
        _resolvedArtworkUrl = Uri.file(file.path).toString();
        _updateAndroidAuto();
      }
    } catch (e) {
      debugPrint('[Artwork] Cache file download note: $e');
    }
  }

  void _updateAndroidAuto() {
    if (_currentSong == null) return;

    final artworkUrl = _resolveArtworkUrl();

    final effectiveDuration = _duration.inMilliseconds > 0
        ? _duration
        : Duration(seconds: _currentSong!.duration ?? 0);

    // Update the audio_service handler so lock screen / Control Center /
    // Android Auto Now Playing info stays accurate regardless of the UI
    // lifecycle.
    _audioHandler.updateNowPlaying(
      id: _currentSong!.id,
      title: _currentSong!.title,
      artist: _currentSong!.artist,
      album: _currentSong!.album,
      artworkUrl: artworkUrl,
      duration: effectiveDuration,
    );

    // While rendering on a remote target the local just_audio player is
    // paused, so push the real playback state to the media session manually.
    if (_isRenderingRemotely) {
      _audioHandler.updateRemotePlaybackState(
        playing: _isPlaying,
        position: _position,
      );
    }

    _updateAllServices();
  }

  void _updateAllServices() {
    if (_currentSong == null) return;

    final artworkUrl = _resolveArtworkUrl();

    final effectiveDuration = _duration.inMilliseconds > 0
        ? _duration
        : Duration(seconds: _currentSong!.duration ?? 0);

    _windowsService.updateSongInfo(_currentSong);
    _windowsService.updatePlaybackState(
      song: _currentSong!,
      artworkUrl: artworkUrl,
      duration: effectiveDuration,
      position: _position,
      isPlaying: _isPlaying,
    );

  }

  List<Song> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;

  /// True when audio is playing on a remote renderer (UPnP or Cast) rather
  /// than locally.  Used to suppress audio-focus and noisy-event handling that
  /// would incorrectly pause the remote device, and to route UI volume changes
  /// to the renderer instead of the Android system volume.
  bool get isRemotePlayback => _isRenderingRemotely || _groovyConnectService?.isConnected == true;
  bool get shuffleEnabled => _shuffleEnabled;
  bool get gaplessEnabled => _gaplessEnabled;
  RepeatMode get repeatMode => _repeatMode;
  Duration get position => _position;
  Duration get duration => _duration;
  Song? get currentSong => _currentSong;
  bool get hasNext =>
      _queue.isNotEmpty &&
      (_currentIndex < _queue.length - 1 ||
          _repeatMode == RepeatMode.all ||
          (_shuffleEnabled && _queue.length > 1));
  bool get hasPrevious =>
      _queue.isNotEmpty &&
      (_currentIndex > 0 ||
          _repeatMode == RepeatMode.all ||
          (_shuffleEnabled && _shuffleHistory.isNotEmpty));
  double get volume => _volume;

  RadioStation? get currentRadioStation => _currentRadioStation;
  bool get isPlayingRadio => _isPlayingRadio;

  void clearUpcomingQueue() {
    if (_queue.isEmpty || _currentIndex < 0) return;
    if (_currentIndex < _queue.length - 1) {
      _queue = _queue.sublist(0, _currentIndex + 1);
      _saveQueueState();
      notifyListeners();
    }
  }

  // Unified position stream: fed by the local audio player in normal mode, or
  // by UPnP/Cast polling in remote-playback mode.  The UI subscribes to this
  // instead of directly to _audioPlayer.positionStream so that the progress
  // bar animates correctly regardless of which playback path is active.
  final _positionController = StreamController<Duration>.broadcast();
  Stream<Duration> get positionStream => _positionController.stream;

  Stream<Duration> get bufferedPositionStream => _audioPlayer.bufferedPositionStream;
  Duration get bufferedPosition => _audioPlayer.bufferedPosition;
  bool get isBuffering =>
      _isLoading ||
      _audioPlayer.processingState == ProcessingState.buffering ||
      _audioPlayer.processingState == ProcessingState.loading;
  Stream<bool> get isBufferingStream => _audioPlayer.processingStateStream
      .map((s) => s == ProcessingState.buffering || s == ProcessingState.loading);

  // Subscriptions stored so they can be cancelled before dispose closes the
  // StreamController, preventing a late just_audio tick from calling add() on
  // a closed controller.
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<int?>? _currentIndexSub;

  ConcatenatingAudioSource? _concatenatingSource;

  // Fallback timer for Windows where positionStream may not emit reliably
  Timer? _windowsPositionTimer;
  Duration? _lastPolledPosition;

  // Preloading state: tracks the last preloaded song ID to avoid redundant work
  String? _lastPreloadedSongId;

  /// Checks if the currently playing song is nearing its end, and if so,
  /// triggers background preloading for the next song in the queue.
  void _checkAndPreloadNextSong(Duration position) {
    if (_queue.isEmpty || _currentSong == null || _isRenderingRemotely) return;
    final totalSeconds = _duration.inSeconds > 0
        ? _duration.inSeconds
        : (_currentSong?.duration ?? 0);
    if (totalSeconds <= 5) return;

    final secondsRemaining = totalSeconds - position.inSeconds;
    final progressRatio = position.inSeconds / totalSeconds;

    // Start preloading early (after 2 seconds of playback so initial buffering isn't contested)
    // or when nearing end of the song
    final shouldPreload = position.inSeconds >= 2 ||
        (secondsRemaining <= 25 && secondsRemaining > 0) ||
        (progressRatio >= 0.75 && position.inSeconds >= 5);

    if (!shouldPreload) return;

    final nextSong = _getNextSongToPreload();
    if (nextSong == null ||
        nextSong.id == _lastPreloadedSongId ||
        nextSong.id == _currentSong?.id) {
      return;
    }

    _lastPreloadedSongId = nextSong.id;
    _preloadSong(nextSong);
  }

  Song? _getNextSongToPreload() {
    if (_queue.isEmpty || _currentIndex < 0) return null;
    if (_repeatMode == RepeatMode.one) return _currentSong;
    if (_shuffleEnabled && _queue.length > 1) {
      for (int i = 0; i < _queue.length; i++) {
        if (i != _currentIndex) return _queue[i];
      }
    }
    if (_currentIndex < _queue.length - 1) {
      return _queue[_currentIndex + 1];
    }
    if (_repeatMode == RepeatMode.all && _queue.isNotEmpty) {
      return _queue[0];
    }
    return null;
  }

  Future<void> _preloadSong(Song nextSong) async {
    debugPrint(
      '[Player Preload] ⚡ Pre-buffering next song: "${nextSong.title}" (${nextSong.id})',
    );

    // 1. Preload audio stream into local disk cache for instant 0ms startup
    if (nextSong.isLocal != true) {
      unawaited(
        _audioCacheService.preloadSong(nextSong, _youtubeService).catchError((e) {
          debugPrint('[Player Preload] AudioCache preload error (harmless): $e');
          return null;
        }),
      );
      final cleanId = nextSong.id.replaceFirst('ytmusic://', '').replaceFirst('yt_', '');
      if (cleanId.length == 11) {
        YtDlpService().warmUpStreamCache(cleanId);
      }
    }

    // 2. Preload synced lyrics in cache
    if (nextSong.title.isNotEmpty) {
      LrcLibService()
          .searchLyrics(
            artist: nextSong.artist,
            title: nextSong.title,
            durationSeconds: nextSong.duration,
          )
          .catchError((_) => null);
    }

    // 3. Preload cover artwork into Flutter image cache
    if (nextSong.coverArt != null) {
      final coverUrl =
          _youtubeService.getCoverArtUrl(nextSong.coverArt, size: 300);
      if (coverUrl.isNotEmpty) {
        try {
          CachedNetworkImageProvider(coverUrl).resolve(ImageConfiguration.empty);
        } catch (_) {}
      }
    }

    // 4. Preload next YouTube radio tracks if near queue end
    if (_youtubeService.isYoutube &&
        _currentIndex >= _queue.length - 2 &&
        _currentSong != null) {
      _fetchAndQueueRadioTracks(_currentSong!).catchError((_) {});
    }
    if (_autoDjService.shouldAddSongs(_currentIndex + 1, _queue.length)) {
      _addAutoDjSongs().catchError((_) {});
    }
  }

  double get progress {
    if (_duration.inMilliseconds == 0) return 0;
    return _position.inMilliseconds / _duration.inMilliseconds;
  }

  double get playbackSpeed => _playbackSpeed;

  double get pitch => _pitch;

  bool get pitchCorrection => _pitchCorrection;

  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed.clamp(0.25, 4.0);

    final targetPitch = _pitchCorrection ? 1.0 : _playbackSpeed;
    _pitch = targetPitch.clamp(0.5, 2.0);

    final success = await _audioHandler.setPlaybackParameters(
      _playbackSpeed,
      _pitch,
    );
    if (!success) {
      // Fallback to just_audio native setSpeed when pitch plugin is unavailable.
      await _audioPlayer.setSpeed(_playbackSpeed);
    }

    notifyListeners();
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);

    final success = await _audioHandler.setPlaybackParameters(
      _playbackSpeed,
      _pitch,
    );
    if (!success) {
      await _audioPlayer.setSpeed(_playbackSpeed);
    }

    notifyListeners();
  }

  Future<void> togglePitchCorrection() async {
    _pitchCorrection = !_pitchCorrection;
    final targetPitch = _pitchCorrection ? 1.0 : _playbackSpeed;
    _pitch = targetPitch.clamp(0.5, 2.0);

    final success = await _audioHandler.setPlaybackParameters(
      _playbackSpeed,
      _pitch,
    );
    if (!success) {
      await _audioPlayer.setSpeed(_playbackSpeed);
    }

    notifyListeners();
  }

  bool get hasSleepTimer => _sleepTimer != null;
  bool get sleepTimerEndCurrentSong => _sleepTimerEndCurrentSong;
  bool get sleepTimerFadeOut => _sleepTimerFadeOut;
  int get sleepTimerFadeDurationSeconds => _sleepTimerFadeDurationSeconds;

  Duration? get sleepTimerRemaining {
    if (_sleepTimerEnd == null) return null;
    final remaining = _sleepTimerEnd!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void setSleepTimer(
    Duration duration, {
    bool endCurrentSong = false,
    bool fadeOut = false,
    int fadeDurationSeconds = 30,
  }) {
    _sleepTimer?.cancel();
    _sleepTimerFadeTimer?.cancel();
    _sleepTimerFadePeriodicTimer?.cancel();
    _sleepTimerFadePeriodicTimer = null;
    _sleepTimer = null;
    _sleepTimerEnd = null;
    _sleepTimerEndCurrentSong = endCurrentSong;
    _sleepTimerFadeOut = fadeOut;
    _sleepTimerFadeDurationSeconds = fadeDurationSeconds;

    if (duration > Duration.zero) {
      _sleepTimerEnd = DateTime.now().add(duration);

      if (fadeOut) {
        final fadeStart = duration - Duration(seconds: fadeDurationSeconds);
        if (fadeStart > Duration.zero) {
          _sleepTimerFadeTimer =
              Timer(fadeStart, () => _startFadeOut(fadeDurationSeconds));
        } else {
          _startFadeOut(fadeDurationSeconds);
        }
      }

      _sleepTimer = Timer(duration, () {
        if (endCurrentSong) {
          _sleepTimerEndCurrentSong = true;
          _sleepTimer = null;
          _sleepTimerEnd = null;
          notifyListeners();
        } else {
          _doSleepTimerStop();
        }
      });
    }
    notifyListeners();
  }

  void _startFadeOut([int fadeDurationSeconds = 30]) {
    _sleepTimerFadePeriodicTimer?.cancel();
    final steps = fadeDurationSeconds.clamp(5, 300);
    const stepDuration = Duration(seconds: 1);
    final originalVolume = _volume;
    int step = 0;
    _sleepTimerFadePeriodicTimer = Timer.periodic(stepDuration, (t) {
      step++;
      final newVolume = originalVolume * (1.0 - step / steps);
      _audioPlayer.setVolume(newVolume.clamp(0.0, 1.0));
      if (step >= steps) {
        t.cancel();
        _sleepTimerFadePeriodicTimer = null;
      }
    });
  }

  void _doSleepTimerStop() {
    _sleepTimerFadePeriodicTimer?.cancel();
    _sleepTimerFadePeriodicTimer = null;
    _audioPlayer.setVolume(_volume);
    pause();
    _sleepTimer = null;
    _sleepTimerEnd = null;
    _sleepTimerFadeOut = false;
    _sleepTimerFadeDurationSeconds = 30;
    _sleepTimerEndCurrentSong = false;
    notifyListeners();
  }

  Future<void> _cleanOldStreamCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final entities = cacheDir.listSync();
      final now = DateTime.now();
      for (final e in entities) {
        final name = e.uri.pathSegments.isNotEmpty ? e.uri.pathSegments.last : '';
        if (e is File && name.startsWith('groovy_stream_') && name.endsWith('.tmp')) {
          try {
            final stat = e.statSync();
            if (now.difference(stat.modified).inDays > 2) {
              e.deleteSync();
            }
          } catch (_) {}
        }
      }
      await _audioCacheService.cleanOldCacheFiles();
    } catch (_) {}
  }

  void _initializePlayer() {
    _configureAudioSession();

    _storageService.getVolume().then((savedVolume) {
      if (_isDisposed) return;
      _volume = savedVolume;
      _audioPlayer.setVolume(_volume);
      notifyListeners();
    });

    _storageService.getShuffleMode().then((saved) {
      if (_isDisposed) return;
      _shuffleEnabled = saved;
      notifyListeners();
    });

    // Resume any playlists that were queued for download but interrupted
    _offlineService.initialize().then((_) {
      if (_isDisposed) return;
      _offlineService.resumeIncompleteDownloads(_youtubeService);
    });

    _cleanOldStreamCache().catchError((_) {});
    _startTelemetryHeartbeat();

    _storageService.getRepeatMode().then((saved) {
      if (_isDisposed) return;
      _repeatMode =
          RepeatMode.values[saved.clamp(0, RepeatMode.values.length - 1)];
      notifyListeners();
    });

    _storageService.getGaplessPlayback().then((saved) {
      if (_isDisposed) return;
      _gaplessEnabled = saved;
      notifyListeners();
    });

    _playerStateSub = _audioPlayer.playerStateStream.listen(
      (state) {
        // In remote-playback mode the local player is stopped/paused; ignore
        // its state so it doesn't overwrite the UPnP/Cast-managed values.
        if (_isRenderingRemotely) return;

        final wasPlaying = _isPlaying;
        final bool isOptimisticLocalActive = _optimisticLocalPlayPauseTime != null &&
            DateTime.now().difference(_optimisticLocalPlayPauseTime!) < const Duration(milliseconds: 600);

        if (isOptimisticLocalActive) {
          if (state.playing == _optimisticLocalPlayPauseState) {
            _optimisticLocalPlayPauseTime = null;
            _optimisticLocalPlayPauseState = null;
          }
        } else {
          _isPlaying = state.playing;
        }

        if (state.playing || state.processingState == ProcessingState.ready) {
          _isLoading = false;
        }

        if (wasPlaying != _isPlaying && !_reactivatingSession) {
          debugPrint(
              '[Player] ${_isPlaying ? '▶ Playing' : '⏸ Paused'} — "${_currentSong?.title ?? 'unknown'}" (${state.processingState.name})');
          _sendTelemetryHeartbeat(overridePlaying: _isPlaying);

          // Start/stop desktop position polling timer (Windows and Linux both use just_audio_media_kit)
          if (_isPlaying && (Platform.isWindows || Platform.isLinux) && !_isRenderingRemotely) {
            _windowsPositionTimer?.cancel();
            _lastPolledPosition = null;
            Duration? lastSystemUpdate;
            _windowsPositionTimer = Timer.periodic(
              const Duration(milliseconds: 50),
              (_) {
                final pos = _audioPlayer.position;
                if (_lastPolledPosition == null ||
                    pos.inMilliseconds != _lastPolledPosition!.inMilliseconds) {
                  _lastPolledPosition = pos;
                  _position = pos;
                  _positionController.add(pos);
                  _checkAndPreloadNextSong(pos);
                  final effDur = _duration.inMilliseconds > 0
                      ? _duration
                      : (_currentSong?.duration != null ? Duration(seconds: _currentSong!.duration!) : Duration.zero);
                  if (!_isRenderingRemotely &&
                      _isPlaying &&
                      !_isTransitioningSong &&
                      effDur > const Duration(seconds: 5) &&
                      pos >= effDur - const Duration(milliseconds: 250)) {
                    if (_currentSong != null && _lastCompletedSongId != _currentSong!.id) {
                      _lastCompletedSongId = _currentSong!.id;
                      debugPrint('[Player Desktop] ✓ Position reached end of track: "${_currentSong?.title}" — advancing automatically');
                      _onSongComplete().catchError(
                          (e) => debugPrint('[Player] _onSongComplete error: $e'));
                    }
                  }
                  if (lastSystemUpdate == null ||
                      (pos.inMilliseconds - lastSystemUpdate!.inMilliseconds).abs() > 1000) {
                    lastSystemUpdate = pos;
                    _updateAllServices();
                  }
                }
              },
            );
          } else {
            _windowsPositionTimer?.cancel();
            _windowsPositionTimer = null;
            _lastPolledPosition = null;
          }
        }

        final bool userExplicitlyPaused = _lastUserPauseTime != null &&
            DateTime.now().difference(_lastUserPauseTime!) < const Duration(seconds: 3);

        final effDur = _duration.inMilliseconds > 0
            ? _duration
            : (_currentSong?.duration != null ? Duration(seconds: _currentSong!.duration!) : Duration.zero);

        final bool isNearTrackEnd = effDur > const Duration(seconds: 5) &&
            _position >= effDur - const Duration(milliseconds: 900);

        final bool naturalTrackEnd = (wasPlaying && !state.playing && isNearTrackEnd && !userExplicitlyPaused);

        if (state.processingState == ProcessingState.completed || naturalTrackEnd) {
          if (_currentSong != null && _lastCompletedSongId != _currentSong!.id) {
            _lastCompletedSongId = _currentSong!.id;
            debugPrint(
                '[Player] ✓ Song completed (${naturalTrackEnd ? 'natural end of stream' : 'state.completed'}): "${_currentSong?.title ?? 'unknown'}"');
            _onSongComplete().catchError(
                (e) => debugPrint('[Player] _onSongComplete error: $e'));
          }
        }

        if (state.processingState == ProcessingState.buffering && !wasPlaying) {
          debugPrint(
              '[Player] ⟳ Buffering: "${_currentSong?.title ?? 'unknown'}"');
        }

        if (wasPlaying != _isPlaying && !_reactivatingSession) {
          notifyListeners();
          _updateAndroidAuto();
        }
      },
      onError: (error) {
        debugPrint('[Player] State stream error (usually harmless): $error');
      },
    );

    Duration? lastSystemUpdate;
    _positionSub = _audioPlayer.createPositionStream(
      minPeriod: const Duration(milliseconds: 50),
      maxPeriod: const Duration(milliseconds: 80),
    ).listen(
      (position) {
        // In remote-playback mode the local player sits idle at position zero;
        // ignore its ticks so they don't overwrite the UPnP/Cast position.
        if (_isRenderingRemotely) return;

        _position = position;
        _positionController.add(position);
        _checkAndPreloadNextSong(position);

        final effDur = _duration.inMilliseconds > 0
            ? _duration
            : (_currentSong?.duration != null ? Duration(seconds: _currentSong!.duration!) : Duration.zero);
        if (!_isRenderingRemotely &&
            _isPlaying &&
            !_isTransitioningSong &&
            effDur > const Duration(seconds: 5) &&
            position >= effDur - const Duration(milliseconds: 250)) {
          if (_currentSong != null && _lastCompletedSongId != _currentSong!.id) {
            _lastCompletedSongId = _currentSong!.id;
            debugPrint('[Player Mobile] ✓ Position stream reached end of track: "${_currentSong?.title}" — advancing automatically');
            _onSongComplete().catchError(
                (e) => debugPrint('[Player] _onSongComplete error: $e'));
          }
        }

        if (lastSystemUpdate == null ||
            (position.inMilliseconds - lastSystemUpdate!.inMilliseconds).abs() > 1000) {
          lastSystemUpdate = position;
          _updateAllServices();
        }
      },
      onError: (error) {
        debugPrint('Position stream error (can be ignored): $error');
      },
    );

    _durationSub = _audioPlayer.durationStream.listen(
      (duration) {
        // In remote-playback mode the local player has no loaded track; ignore
        // its duration so it doesn't zero out the UPnP/Cast duration.
        if (_isRenderingRemotely) return;

        if (duration != null && duration > Duration.zero) {
          _duration = duration;
        } else if (_currentSong?.duration != null && _currentSong!.duration! > 0) {
          _duration = Duration(seconds: _currentSong!.duration!);
        } else {
          _duration = duration ?? Duration.zero;
        }
        notifyListeners();
        _updateAndroidAuto();
      },
      onError: (error) {
        debugPrint('Duration stream error (can be ignored): $error');
      },
    );

    _currentIndexSub = _audioPlayer.currentIndexStream.listen(
      (index) {
        if (index != null &&
            index != _currentIndex &&
            !_isRenderingRemotely &&
            _concatenatingSource != null) {
          _onCurrentIndexChanged(index).catchError((e) {
            debugPrint('[Player] _onCurrentIndexChanged error: $e');
          });
        }
      },
      onError: (error) {
        debugPrint('Current index stream error (can be ignored): $error');
      },
    );
  }

  StreamSubscription<void>? _becomingNoisySubscription;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSubscription;
  StreamSubscription<AudioDevicesChangedEvent>? _devicesChangedSubscription;
  bool _wasPlayingBeforeInterruption = false;

  /// Configures AudioSession for mobile and desktop, enabling automatic pause
  /// on headphone disconnect (becoming noisy), resume on headphone reconnect,
  /// audio interruption handling (calls/alarms), and headset media controls.
  Future<void> _configureAudioSession() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS)) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      debugPrint('[Player] AudioSession configured for music playback');

      // 1. Headphone disconnection ("Becoming Noisy"):
      // Automatically pause when wired/bluetooth headphones are unplugged or turned off
      await _becomingNoisySubscription?.cancel();
      _becomingNoisySubscription = session.becomingNoisyEventStream.listen((_) {
        debugPrint('[AudioSession] Headset disconnected (becoming noisy) -> pausing');
        if (_isPlaying) {
          pause();
        }
      });

      // 2. Audio Interruption (calls, navigation ducking):
      await _interruptionSubscription?.cancel();
      _interruptionSubscription = session.interruptionEventStream.listen((event) {
        debugPrint('[AudioSession] Interruption event: begin=${event.begin}, type=${event.type}');
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _audioPlayer.setVolume(_effectiveVolume * 0.3);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              if (_isPlaying) {
                _wasPlayingBeforeInterruption = true;
                pause();
              }
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _audioPlayer.setVolume(_effectiveVolume);
              break;
            case AudioInterruptionType.pause:
              if (_wasPlayingBeforeInterruption) {
                _wasPlayingBeforeInterruption = false;
                play();
              }
              break;
            case AudioInterruptionType.unknown:
              break;
          }
        }
      });

      // 3. Audio devices changed (headphones connected):
      // When headphones are plugged in or Bluetooth audio connects, prime session
      await _devicesChangedSubscription?.cancel();
      _devicesChangedSubscription = session.devicesChangedEventStream.listen((event) {
        debugPrint('[AudioSession] Audio devices changed. Added: ${event.devicesAdded.map((d) => d.name).toList()}');
        session.setActive(true).catchError((_) => false);
      });
    } catch (e) {
      debugPrint('[Player] AudioSession configuration failed: $e');
    }
  }

  final bool _audioFocusDenied = false;
  bool get audioFocusDenied => _audioFocusDenied;

  VoidCallback? onAudioFocusDenied;

  Future<void> _ensureAudioFocus(Future<void> Function() onGranted) async {
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
        final session = await AudioSession.instance;
        await session.setActive(true);
      }
    } catch (_) {}
    await onGranted();
  }

  Future<void> _onSongComplete() async {
    if (_isTransitioningSong) return;
    _isTransitioningSong = true;

    try {
      final completedSong = _currentSong;
      debugPrint('[Player] ✓ Song completed: "${completedSong?.title ?? 'unknown'}"');

      if (completedSong != null && completedSong.isLocal != true) {
        _youtubeService.scrobble(completedSong.id, submission: true).catchError((e) {
          _offlineService.queueScrobble(completedSong.id, submission: true);
        });
      }

      if (completedSong != null && _recommendationService != null) {
        _recommendationService!.trackSongPlay(
          completedSong,
          durationPlayed: _duration.inSeconds,
          completed: true,
        );
      }

      if (_sleepTimerEndCurrentSong) {
        _doSleepTimerStop();
        return;
      }

      if (_concatenatingSource != null) {
        await _handleEndOfQueue();
        return;
      }

      if (_repeatMode == RepeatMode.one) {
        await seek(Duration.zero);
        await play();
      } else if (_currentIndex < _queue.length - 1 ||
          _repeatMode == RepeatMode.all ||
          _shuffleEnabled) {
        if (_youtubeService.isYoutube && _currentIndex >= _queue.length - 2 && completedSong != null) {
          _fetchAndQueueRadioTracks(completedSong).catchError((_) {});
        }
        await _playNextSongAutomatic();
      } else if (_youtubeService.isYoutube && completedSong != null) {
        final moreSimilar = await _youtubeService.getSimilarSongs(completedSong.id, count: 20);
        final existingIds = _queue.map((s) => s.id).toSet();
        final toAdd = moreSimilar.where((s) => !existingIds.contains(s.id)).toList();
        if (toAdd.isNotEmpty) {
          _queue.addAll(toAdd);
          notifyListeners();
          _saveQueueState();
          await _playNextSongAutomatic();
        } else {
          await _handleEndOfQueue();
        }
      } else {
        await _handleEndOfQueue();
      }
    } finally {
      _isTransitioningSong = false;
    }
  }

  Future<void> _playNextSongAutomatic() async {
    if (_queue.isEmpty) {
      await _handleEndOfQueue();
      return;
    }

    int nextIndex = -1;

    if (_shuffleEnabled && _queue.length > 1) {
      _shuffleHistory.add(_currentSong?.id ?? '');
      if (_shuffleHistory.length > 50) _shuffleHistory.removeAt(0);
      int next;
      do {
        next = Random().nextInt(_queue.length);
      } while (next == _currentIndex);
      nextIndex = next;
    } else if (_currentIndex < _queue.length - 1) {
      nextIndex = _currentIndex + 1;
    } else if (_repeatMode == RepeatMode.all && _queue.isNotEmpty) {
      nextIndex = 0;
    }

    if (nextIndex >= 0 && nextIndex < _queue.length) {
      final nextSong = _queue[nextIndex];
      _currentIndex = nextIndex;
      _currentSong = nextSong;
      _position = Duration.zero;
      _duration = nextSong.duration != null ? Duration(seconds: nextSong.duration!) : Duration.zero;
      _isLoading = true;
      _lastPlaybackError = null;
      notifyListeners();
      _refreshArtworkUrl().catchError((_) {});
      _updateAndroidAuto();

      if (_youtubeService.isYoutube && nextIndex >= _queue.length - 2) {
        _fetchAndQueueRadioTracks(nextSong).catchError((_) {});
      }

      // Reset previous playback away from completed to prevent duplicate completion events
      try {
        await _audioPlayer.stop();
      } catch (_) {}

      await playSong(nextSong, startIndex: nextIndex, forcePlay: true);
    } else {
      await _handleEndOfQueue();
    }
  }

  Future<void> _handleEndOfQueue() async {
    if (_autoDjService.isEnabled) {
      await _addAutoDjSongs();

      if (_currentIndex < _queue.length - 1) {
        await _playNextSongAutomatic();
        return;
      }
    }
    _isPlaying = false;
    _isLoading = false;
    notifyListeners();
  }

  /// Plays a single song immediately and automatically populates the queue with similar / radio songs in the background.
  Future<void> playSongWithRadio(Song song) async {
    await playSong(song);

    _fetchAndQueueRadioTracks(song).catchError((e) {
      debugPrint('[Player] _fetchAndQueueRadioTracks error: $e');
    });
  }

  Future<void> _fetchAndQueueRadioTracks(Song song) async {
    if (_currentSong?.id != song.id) return;
    try {
      final similar = await _youtubeService.getSimilarSongs(song.id, count: 25);
      if (similar.isNotEmpty && _currentSong?.id == song.id) {
        final existingIds = _queue.map((s) => s.id).toSet();
        final toAdd = similar.where((s) => !existingIds.contains(s.id)).toList();
        if (toAdd.isNotEmpty) {
          _queue.addAll(toAdd);
          notifyListeners();
          _saveQueueState();
          debugPrint('[Player] Radio queue populated with ${toAdd.length} similar songs for "${song.title}"');
        }
      }
    } catch (e) {
      debugPrint('[Player] _fetchAndQueueRadioTracks failed: $e');
    }
  }

  void _recordSongPlayback(Song song) {
    if (_recommendationService != null) {
      _recommendationService!.trackSongPlay(
        song,
        durationPlayed: 0,
        completed: false,
      );
    }

    _storageService.addSongToHistory(song).catchError((e) {
      debugPrint('[Player] Error adding song to history: $e');
    });

    _storageService.getUserToken().then((token) {
      if (token != null && token.isNotEmpty) {
        GroovyApiService().recordHistory(token, song);
      }
      GroovyApiService().reportPlaybackState(
        token: token ?? '',
        song: song,
        isPlaying: true,
        position: _position.inSeconds,
        listenDeltaSeconds: 0,
        deviceId: _groovyConnectService?.localDeviceId,
      );
      _startTelemetryHeartbeat();
    }).catchError((_) {});
  }

  Future<void> playSong(
    Song song, {
    List<Song>? playlist,
    int? startIndex,
    Duration? initialPosition,
    bool forcePlay = false,
  }) async {
    final currentGen = ++_playGeneration;

    if (!forcePlay && _activeAudioSongId == song.id && !_isPlayingRadio && initialPosition == null) {
      await togglePlayPause();
      return;
    }

    _isPlayingRadio = false;
    _currentRadioStation = null;

    // Groovy Connect mode: route playback directly to connected device (Spotify Connect style)
    if (_groovyConnectService?.isConnected == true) {
      final List<Song> targetPlaylist;
      final int targetIndex;
      if (playlist != null && playlist.isNotEmpty) {
        targetPlaylist = List.from(playlist);
        targetIndex = startIndex ?? targetPlaylist.indexWhere((s) => s.id == song.id);
      } else if (_queue.any((s) => s.id == song.id)) {
        targetPlaylist = List.from(_queue);
        targetIndex = startIndex ?? _queue.indexWhere((s) => s.id == song.id);
      } else {
        targetPlaylist = [song];
        targetIndex = 0;
      }

      final safeIndex = targetIndex >= 0 ? targetIndex : 0;
      _queue = targetPlaylist;
      _currentIndex = safeIndex;
      _currentSong = song;
      _position = initialPosition ?? Duration.zero;
      _duration = song.duration != null ? Duration(seconds: song.duration!) : Duration.zero;
      _remoteAnchorPosition = _position;
      _remoteAnchorTime = null;
      _optimisticRemoteSongId = song.id;
      _optimisticRemoteSongUntil = DateTime.now().add(const Duration(milliseconds: 12000));
      _isRenderingRemotely = true;
      _activeAudioSongId = song.id;
      _isPlaying = true;
      _isLoading = true;
      _audioHandler.setRemotePlayback(isRemote: true);
      if (_audioPlayer.playing) {
        await _audioPlayer.stop();
      }
      _manageRemotePositionTicker();
      notifyListeners();
      _updateAndroidAuto();
      _updateAllServices();
      _refreshArtworkUrl().catchError((_) {});
      unawaited(_groovyConnectService!.sendPlaySong(
        song,
        positionMs: initialPosition?.inMilliseconds ?? 0,
        queue: _queue,
        queueIndex: _currentIndex,
      ));
      return;
    }

    debugPrint(
        '[Player] ▶ playSong: "${song.title}" by ${song.artist ?? 'unknown'} (id=${song.id} local=${song.isLocal})');

    // Instantly update queue, currentIndex, currentSong and UI synchronously before any async operations
    if (playlist != null) {
      _queue = List.from(playlist);
      _currentIndex =
          startIndex ?? playlist.indexWhere((s) => s.id == song.id);
      if (_currentIndex == -1) _currentIndex = 0;
      _shuffleHistory.clear();
    } else if (_queue.isEmpty || !_queue.any((s) => s.id == song.id)) {
      _queue = [song];
      _currentIndex = 0;
      _shuffleHistory.clear();
    } else {
      _currentIndex = startIndex ?? _queue.indexWhere((s) => s.id == song.id);
    }

    _currentSong = song;
    _lastCompletedSongId = null;
    _lastPreloadedSongId = null;
    _resolvedArtworkUrl = null;
    _position = initialPosition ?? Duration.zero;
    if (song.duration != null && song.duration! > 0) {
      _duration = Duration(seconds: song.duration!);
    } else {
      _duration = Duration.zero;
    }
    _isPlaying = true;
    _isLoading = true;
    _lastPlaybackError = null; // clear previous error on new play attempt
    notifyListeners();
    _saveQueueState();

    // Immediately report live playback presence to backend
    _startTelemetryHeartbeat();
    _sendTelemetryHeartbeat(overridePlaying: true);

    // Immediately publish song info to lockscreen / notification widget
    _updateAndroidAuto();
    _refreshArtworkUrl().catchError((_) {});

    // Ensure any previously active audio or faulted stream is completely stopped and detached
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    if (currentGen != _playGeneration) return;

    try {
      // If song has a non-YouTube ID (e.g. from Deezer dz_...), resolve real YouTube ID early
      if (song.isLocal != true && (song.id.startsWith('dz_') || !RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(song.id.replaceFirst('ytmusic://', '').replaceFirst('yt_', '')))) {
        try {
          final resolvedYtId = await _youtubeService.resolveVideoIdForSong(song);
          if (resolvedYtId.isNotEmpty && RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(resolvedYtId)) {
            final updatedSong = song.copyWith(
              id: resolvedYtId,
              coverArt: (song.coverArt == null || song.coverArt!.isEmpty) ? resolvedYtId : song.coverArt,
            );
            final qIdx = _queue.indexWhere((s) => s.id == song.id);
            if (qIdx != -1) {
              _queue[qIdx] = updatedSong;
            }
            song = updatedSong;
            if (_currentSong?.id == song.id) {
              _currentSong = updatedSong;
            }
          }
        } catch (_) {}
      }
      if (currentGen != _playGeneration) return;

      if (_castService.isConnected) {
        if (_audioPlayer.playing) await _audioPlayer.stop();

        final playUrl = song.isLocal == true
            ? Uri.file(song.path!).toString()
            : await _youtubeService.resolveStreamUrlAsync(song);
        if (currentGen != _playGeneration) return;

        final coverUrl = song.isLocal == true && song.coverArt != null
            ? song.coverArt!
            : _youtubeService.getCoverArtUrl(song.coverArt ?? song.id);

        await _castService.loadMedia(
          url: playUrl,
          title: song.title,
          artist: song.artist ?? 'Unknown Artist',
          imageUrl: coverUrl,
          albumName: song.album,
          trackNumber: song.track,
          duration:
              song.duration != null ? Duration(seconds: song.duration!) : null,
          autoPlay: true,
        );
        if (currentGen != _playGeneration) return;
        _isRenderingRemotely = true;
        _activeAudioSongId = song.id;
        _isPlaying = true;
      } else if (_upnpService.isConnected) {
        _upnpWasPlaying = false;
        debugPrint(
          'UPnP: playSong() taking UPnP branch, isConnected=${_upnpService.isConnected}',
        );
        if (_audioPlayer.playing) await _audioPlayer.stop();

        final playUrl = song.isLocal == true && song.path != null
            ? Uri.file(song.path!).toString()
            : await _youtubeService.resolveStreamUrlAsync(song);
        if (currentGen != _playGeneration) return;

        try {
          final mimeType =
              song.contentType ?? UpnpService.mimeTypeFromSuffix(song.suffix);
          final success = await _upnpService.loadAndPlay(
            url: playUrl,
            title: song.title,
            artist: song.artist ?? 'Unknown Artist',
            album: song.album,
            albumArtUrl: song.coverArt != null
                ? _youtubeService.getCoverArtUrl(song.coverArt, size: 0)
                : null,
            durationSecs: song.duration,
            contentType: mimeType,
          );
          if (!success) {
            _upnpService.disconnect();
            debugPrint(
                'UPnP playback failed (retries exhausted), disconnected');
            return;
          }
        } catch (e) {
          _upnpService.disconnect();
          debugPrint('UPnP playback failed, disconnected: $e');
          rethrow;
        }
        if (currentGen != _playGeneration) return;
        _isRenderingRemotely = true;
        _activeAudioSongId = song.id;
        _isPlaying = true;
      } else {
        _isRenderingRemotely = false;

        final youtubeSource = song.isLocal != true
            ? await _youtubeService.getYoutubeAudioSource(song)
            : null;

        if (currentGen != _playGeneration) {
          debugPrint('[Player] Aborting superseded play request for "${song.title}"');
          return;
        }

        if (youtubeSource != null) {
          _concatenatingSource = null;
          await _audioPlayer.setAudioSource(youtubeSource, initialPosition: initialPosition ?? Duration.zero);
          if (currentGen != _playGeneration) return;
          await _applyReplayGain(song);
          await _ensureAudioFocus(() => _audioPlayer.play());
          _isPlaying = true;
          _isLoading = false;
          notifyListeners();
        } else if (_youtubeService.isYoutube) {
          _concatenatingSource = null;
          final String playUrl;
          if (song.isLocal == true && song.path != null) {
            playUrl = Uri.file(song.path!).toString();
          } else {
            final offlinePath = _offlineService.getLocalPath(song.id);
            if (offlinePath != null) {
              playUrl = 'file://$offlinePath';
            } else {
              playUrl = await _youtubeService.resolveStreamUrlAsync(song);
            }
          }
          if (currentGen != _playGeneration) return;
          await _audioPlayer.setUrl(playUrl, initialPosition: initialPosition ?? Duration.zero);
          if (currentGen != _playGeneration) return;
          await _applyReplayGain(song);
          await _ensureAudioFocus(() => _audioPlayer.play());
        } else if (_gaplessEnabled) {
          try {
            await _buildAndSetConcatenatingSource(
              initialIndex: _currentIndex,
              initialPosition: initialPosition ?? Duration.zero,
              playGeneration: currentGen,
            );
          } catch (e) {
            if (!_hasPlayedOnce) {
              debugPrint(
                'First playback failed (Android 16 Media3 issue), retrying: $e',
              );
              await Future.delayed(const Duration(milliseconds: 100));
              await _buildAndSetConcatenatingSource(
                initialIndex: _currentIndex,
                initialPosition: initialPosition ?? Duration.zero,
                playGeneration: currentGen,
              );
              _hasPlayedOnce = true;
            } else {
              rethrow;
            }
          }
          if (currentGen != _playGeneration) return;
          await _audioPlayer.seek(initialPosition ?? Duration.zero);
          await _applyReplayGain(song);
          await _ensureAudioFocus(() => _audioPlayer.play());
        } else {
          final String playUrl;
          if (song.isLocal == true && song.path != null) {
            playUrl = Uri.file(song.path!).toString();
          } else {
            final offlinePath = _offlineService.getLocalPath(song.id);
            if (offlinePath != null) {
              playUrl = 'file://$offlinePath';
            } else {
              final maxBitRate = _transcodingService.enabled
                  ? _transcodingService.currentBitRate
                  : null;
              final format = _transcodingService.enabled
                  ? _transcodingService.format
                  : null;
              playUrl = _youtubeService.getStreamUrl(song.id,
                  maxBitRate: maxBitRate, format: format);
            }
          }
          if (currentGen != _playGeneration) return;
          if (song.isLocal == true ||
              _offlineService.getLocalPath(song.id) != null ||
              (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS))) {
            await _audioPlayer.setUrl(playUrl, initialPosition: initialPosition ?? Duration.zero);
          } else {
            final cacheDir = await getTemporaryDirectory();
            final cacheFile = File(
              '${cacheDir.path}/groovy_stream_${song.id.hashCode}.tmp',
            );
            // ignore: experimental_member_use
            await _audioPlayer.setAudioSource(
              // ignore: experimental_member_use
              LockCachingAudioSource(
                Uri.parse(playUrl),
                cacheFile: cacheFile,
                tag: song.id,
              ),
              initialPosition: initialPosition ?? Duration.zero,
            );
          }
          if (currentGen != _playGeneration) return;
          await _applyReplayGain(song);
          await _ensureAudioFocus(() => _audioPlayer.play());
        }
      }

      if (currentGen != _playGeneration) return;

      if (song.isLocal != true) {
        if (_offlineService.isOfflineMode) {
          _offlineService.queueScrobble(song.id, submission: false);
        } else {
          _youtubeService.scrobble(song.id, submission: false).catchError((e) {
            _offlineService.queueScrobble(song.id, submission: false);
          });

          _offlineService
              .flushPendingScrobbles(_youtubeService)
              .catchError((e) {
            debugPrint('Scrobble flush failed: $e');
          });
        }
      }

      _recordSongPlayback(song);
      _activeAudioSongId = song.id;

      _hasRetriedCurrentPlay = false;
      _updateAndroidAuto();

      // Preload next track in background for instantaneous (0ms) transition
      if (_queue.isNotEmpty && _currentIndex + 1 < _queue.length) {
        final nextSong = _queue[_currentIndex + 1];
        if (nextSong.isLocal != true) {
          YtDlpService().warmUpStreamCache(nextSong.id);
          unawaited(_audioCacheService.preloadSong(nextSong, _youtubeService));
        }
      }
    } catch (e) {
      // If this playSong call has been superseded by a newer play request (e.g. user passed/returned tracks),
      // do NOT report error, do NOT retry, and do NOT stop the audio player.
      if (currentGen != _playGeneration) {
        debugPrint('[Player] Ignoring error for superseded play request "${song.title}": $e');
        return;
      }

      // Ignore normal audio cancellation/abort exceptions caused by user skipping tracks or stopping
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('abort') ||
          errorStr.contains('interrupted') ||
          errorStr.contains('cancelled') ||
          errorStr.contains('canceled') ||
          errorStr.contains('superseded')) {
        debugPrint('[Player] Ignoring audio abort/cancellation error for "${song.title}": $e');
        return;
      }

      debugPrint('[Player] ✗ Error playing song "${song.title}": $e');
      if (song.isLocal != true && !_hasRetriedCurrentPlay) {
        _hasRetriedCurrentPlay = true;
        YtDlpService().invalidateCache(song.id);
        debugPrint('[Player] Retrying playSong for "${song.title}" once with fresh cache...');
        await Future.delayed(const Duration(milliseconds: 500));
        if (currentGen != _playGeneration) return;
        await playSong(song, playlist: playlist, startIndex: startIndex);
        return;
      }
      _hasRetriedCurrentPlay = false;
      _isPlaying = false;
      _activeAudioSongId = null;
      _position = Duration.zero;
      // Expose the error to the UI so a SnackBar / toast can be shown.
      _lastPlaybackError = 'No se pudo reproducir "${song.title}". Verifica tu conexión a internet.';
      onPlaybackError?.call(_lastPlaybackError!);
      try {
        await _audioPlayer.stop();
      } catch (_) {}
      _updateAndroidAuto();

      // Graceful queue auto-recovery: if there are subsequent tracks in the queue,
      // advance automatically instead of getting stuck on an unplayable track.
      if (_queue.isNotEmpty && _currentIndex < _queue.length - 1) {
        debugPrint('[Player] Song "${song.title}" unplayable. Auto-skipping to next track...');
        Future.delayed(const Duration(milliseconds: 600), () {
          if (currentGen == _playGeneration && !_isPlaying) {
            skipNext();
          }
        });
      }
    } finally {
      if (currentGen == _playGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> playRadioStation(RadioStation station) async {
    if (_isPlayingRadio && _currentRadioStation?.id == station.id) {
      await togglePlayPause();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _currentSong = null;
      _queue = [];
      _currentIndex = -1;
      _isPlayingRadio = true;
      _isRenderingRemotely = false; // radio always plays locally
      _currentRadioStation = station;
      _position = Duration.zero;
      _duration = Duration.zero;

      try {
        await _audioPlayer.setUrl(station.streamUrl);
      } catch (e) {
        if (!_hasPlayedOnce) {
          debugPrint(
            'First radio playback failed (Android 16 Media3 issue), retrying: $e',
          );
          await Future.delayed(const Duration(milliseconds: 100));
          await _audioPlayer.setUrl(station.streamUrl);
          _hasPlayedOnce = true;
        } else {
          rethrow;
        }
      }

      await _audioPlayer.setVolume(_volume);

      await _ensureAudioFocus(() => _audioPlayer.play());

      _updateSystemServicesForRadio(station);
    } catch (e) {
      debugPrint('Error playing radio station: $e');
      _isPlaying = false;
      _isPlayingRadio = false;
      _currentRadioStation = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void stopRadio() {
    if (_isPlayingRadio) {
      _audioPlayer.stop();
      _isPlayingRadio = false;
      _currentRadioStation = null;
      _activeAudioSongId = null;
      _isPlaying = false;

      notifyListeners();
    }
  }



  void _updateSystemServicesForRadio(RadioStation station) {
    _windowsService.updatePlaybackState(
      song: null,
      isPlaying: true,
      position: Duration.zero,
      duration: Duration.zero,
      artworkUrl: null,
    );
  }

  Future<void> play() async {
    // 1. Instant optimistic UI toggle (0ms latency)
    _isPlaying = true;
    _optimisticLocalPlayPauseState = true;
    _optimisticLocalPlayPauseTime = DateTime.now();
    notifyListeners();
    _updateAndroidAuto();
    _startTelemetryHeartbeat();
    _sendTelemetryHeartbeat(overridePlaying: true);

    if (_groovyConnectService?.isConnected == true) {
      _isRenderingRemotely = true;
      _optimisticRemotePlayPauseState = true;
      _optimisticRemotePlayPauseUntil = DateTime.now().add(const Duration(milliseconds: 3000));
      _remoteAnchorPosition = _position;
      _remoteAnchorTime = DateTime.now();
      _manageRemotePositionTicker();
      unawaited(_groovyConnectService!.sendControl('play'));
      return;
    }
    if (_castService.isConnected) {
      await _castService.play();
    } else if (_upnpService.isConnected) {
      await _upnpService.play();
    } else {
      // If no song is selected yet but queue has songs (e.g. headphone play button pressed on app start), start first/saved queue song
      if (_currentSong == null && _queue.isNotEmpty) {
        final targetIndex = (_currentIndex >= 0 && _currentIndex < _queue.length) ? _currentIndex : 0;
        await playSong(_queue[targetIndex], playlist: _queue, startIndex: targetIndex);
        return;
      }

      // After app restart, or if playback stalled/disconnected while paused,
      // prepare the audio source if missing, idle, or completed.
      final state = _audioPlayer.playerState.processingState;
      if (_currentSong != null &&
          (_audioPlayer.audioSource == null ||
              state == ProcessingState.idle ||
              state == ProcessingState.completed)) {
        await _prepareCurrentSong();
      }
      await _ensureAudioFocus(() async {
        // Ensure volume is properly restored to effective volume before playing
        await _audioPlayer.setVolume(_effectiveVolume);
        await _audioPlayer.play();
      });
    }
  }

  Future<void> pause() async {
    // 1. Instant optimistic UI toggle (0ms latency)
    _isPlaying = false;
    _lastUserPauseTime = DateTime.now();
    _optimisticLocalPlayPauseState = false;
    _optimisticLocalPlayPauseTime = DateTime.now();
    notifyListeners();
    _updateAndroidAuto();
    _telemetryTimer?.cancel();
    _sendTelemetryHeartbeat(overridePlaying: false);

    if (_groovyConnectService?.isConnected == true) {
      _isRenderingRemotely = true;
      _optimisticRemotePlayPauseState = false;
      _optimisticRemotePlayPauseUntil = DateTime.now().add(const Duration(milliseconds: 3000));
      _remoteAnchorPosition = _position;
      _remoteAnchorTime = null;
      _manageRemotePositionTicker();
      unawaited(_groovyConnectService!.sendControl('pause'));
      return;
    }

    if (_castService.isConnected) {
      await _castService.pause();
    } else if (_upnpService.isConnected) {
      await _upnpService.pause();
    } else {
      // Instantly pause local audio without waiting for fade-out lag
      unawaited(_audioPlayer.pause());
      unawaited(_audioPlayer.setVolume(_effectiveVolume));
    }
  }

  Future<void> stop() async {
    if (_groovyConnectService?.isConnected == true) {
      _isRenderingRemotely = true;
      _isPlaying = false;
      notifyListeners();
      _updateAndroidAuto();
      unawaited(_groovyConnectService!.sendControl('pause'));
      return;
    }
    _telemetryTimer?.cancel();
    _sendTelemetryHeartbeat(overridePlaying: false);
    if (_castService.isConnected) {
      await _castService.stop();
    } else if (_upnpService.isConnected) {
      _upnpWasPlaying = false; // prevent poll from misreading the STOPPED state
      await _upnpService.stop();
    } else {
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(_effectiveVolume);
    }

    _isPlaying = false;
    _position = Duration.zero;
    notifyListeners();
    _updateAndroidAuto();
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      _isPlaying = false;
      notifyListeners();
      _updateAndroidAuto();
      await pause();
    } else {
      _isPlaying = true;
      notifyListeners();
      _updateAndroidAuto();
      await play();
    }
  }

  Future<void> seek(Duration position) async {
    _position = position;
    _positionController.add(position);
    notifyListeners();
    if (_groovyConnectService?.isConnected == true) {
      _isRenderingRemotely = true;
      _lastRemoteSeekTime = DateTime.now();
      _remoteAnchorPosition = position;
      _remoteAnchorTime = _isPlaying ? DateTime.now() : null;
      _updateAndroidAuto();
      unawaited(_groovyConnectService!.sendControl('seek', position.inMilliseconds));
      return;
    }
    if (_castService.isConnected) {
      await _castService.seek(position);
    } else if (_upnpService.isConnected) {
      await _upnpService.seek(position);
    } else {
      await _audioPlayer.seek(position);
    }
    _sendTelemetryHeartbeat();
    _updateAndroidAuto();
  }

  Future<void> seekToProgress(double progress) async {
    final position = Duration(
      milliseconds: (progress * _duration.inMilliseconds).round(),
    );
    await seek(position);
  }

  Future<void> skipNext() async {
    _hasRetriedCurrentPlay = false;
    _isTransitioningSong = false; // Bug 5 fix: manual skip wins over concurrent auto-transition
    final skipGen = ++_skipGeneration; // capture before any await

    if (_currentSong != null && _recommendationService != null) {
      final played = _position.inSeconds;
      final total = _duration.inSeconds;
      if (total > 0 && played < total * 0.8) {
        _recommendationService!.trackSkip(_currentSong!);
      } else if (played > 0) {
        _recommendationService!.trackSongPlay(
          _currentSong!,
          durationPlayed: played,
          completed: played >= total * 0.8,
        );
      }
    }

    if (_groovyConnectService?.isConnected == true) {
      _isRenderingRemotely = true;
      _lastRemoteSeekTime = DateTime.now();
      _position = Duration.zero;
      _remoteAnchorPosition = Duration.zero;
      _remoteAnchorTime = null;
      _isLoading = true;
      _positionController.add(Duration.zero);
      if (_queue.isNotEmpty && _currentIndex < _queue.length - 1) {
        _currentIndex++;
        _currentSong = _queue[_currentIndex];
        _duration = _currentSong!.duration != null ? Duration(seconds: _currentSong!.duration!) : Duration.zero;
        _optimisticRemoteSongId = _currentSong?.id;
        _optimisticRemoteSongUntil = DateTime.now().add(const Duration(milliseconds: 12000));
        _refreshArtworkUrl().catchError((_) {});
        _manageRemotePositionTicker();
        notifyListeners();
        unawaited(_groovyConnectService!.sendPlaySong(_currentSong!, queue: _queue, queueIndex: _currentIndex));
        return;
      } else if (_currentSong != null) {
        try {
          final moreSimilar = await _youtubeService.getSimilarSongs(_currentSong!.id, count: 20);
          if (skipGen != _skipGeneration) return; // another skip came in
          final existingIds = _queue.map((s) => s.id).toSet();
          final toAdd = moreSimilar.where((s) => !existingIds.contains(s.id)).toList();
          if (toAdd.isNotEmpty) {
            _queue.addAll(toAdd);
            _currentIndex++;
            _currentSong = _queue[_currentIndex];
            _duration = _currentSong!.duration != null ? Duration(seconds: _currentSong!.duration!) : Duration.zero;
            _optimisticRemoteSongId = _currentSong?.id;
            _optimisticRemoteSongUntil = DateTime.now().add(const Duration(milliseconds: 12000));
            _refreshArtworkUrl().catchError((_) {});
            _manageRemotePositionTicker();
            notifyListeners();
            _saveQueueState();
            unawaited(_groovyConnectService!.sendPlaySong(_currentSong!, queue: _queue, queueIndex: _currentIndex));
            return;
          }
        } catch (_) {}
      }
      if (_repeatMode == RepeatMode.all && _queue.isNotEmpty) {
        _currentIndex = 0;
        _currentSong = _queue[0];
        _duration = _currentSong!.duration != null ? Duration(seconds: _currentSong!.duration!) : Duration.zero;
        _optimisticRemoteSongId = _currentSong?.id;
        _optimisticRemoteSongUntil = DateTime.now().add(const Duration(milliseconds: 12000));
        _refreshArtworkUrl().catchError((_) {});
        _manageRemotePositionTicker();
        notifyListeners();
        unawaited(_groovyConnectService!.sendPlaySong(_currentSong!, queue: _queue, queueIndex: 0));
        return;
      }
      _manageRemotePositionTicker();
      notifyListeners();
      unawaited(_groovyConnectService!.sendControl('skipNext'));
      return;
    }

    if (_autoDjService.shouldAddSongs(_currentIndex, _queue.length)) {
      await _addAutoDjSongs();
      if (skipGen != _skipGeneration) return; // another skip came in while fetching
    }

    if (_shuffleEnabled && _queue.length > 1) {
      _shuffleHistory.add(_currentSong?.id ?? '');
      if (_shuffleHistory.length > 50) _shuffleHistory.removeAt(0);
      int next;
      do {
        next = Random().nextInt(_queue.length);
      } while (next == _currentIndex);
      _currentIndex = next;
      _currentSong = _queue[next];
      _position = Duration.zero;
      _duration = _currentSong!.duration != null ? Duration(seconds: _currentSong!.duration!) : Duration.zero;
      _isLoading = true;
      _lastPlaybackError = null;
      notifyListeners();
      _refreshArtworkUrl().catchError((_) {});
      _updateAndroidAuto();

      _skipDebounceTimer?.cancel();
      _skipDebounceTimer = Timer(const Duration(milliseconds: 220), () {
        if (skipGen != _skipGeneration) return;
        skipToIndex(next, skipGen: skipGen);
      });
    } else if (_currentIndex < _queue.length - 1) {
      final nextIndex = _currentIndex + 1;
      _currentIndex = nextIndex;
      _currentSong = _queue[nextIndex];
      _position = Duration.zero;
      _duration = _currentSong!.duration != null ? Duration(seconds: _currentSong!.duration!) : Duration.zero;
      _isLoading = true;
      _lastPlaybackError = null;
      notifyListeners();
      _refreshArtworkUrl().catchError((_) {});
      _updateAndroidAuto();

      if (_youtubeService.isYoutube && nextIndex >= _queue.length - 2 && _currentSong != null) {
        _fetchAndQueueRadioTracks(_currentSong!).catchError((_) {});
      }
      _skipDebounceTimer?.cancel();
      _skipDebounceTimer = Timer(const Duration(milliseconds: 220), () {
        if (skipGen != _skipGeneration) return;
        skipToIndex(nextIndex, skipGen: skipGen);
      });
    } else if (_youtubeService.isYoutube && _currentSong != null) {
      final moreSimilar = await _youtubeService.getSimilarSongs(_currentSong!.id, count: 20);
      if (skipGen != _skipGeneration) return;
      final existingIds = _queue.map((s) => s.id).toSet();
      final toAdd = moreSimilar.where((s) => !existingIds.contains(s.id)).toList();
      if (toAdd.isNotEmpty) {
        _queue.addAll(toAdd);
        final nextIndex = _currentIndex + 1;
        _currentIndex = nextIndex;
        _currentSong = _queue[nextIndex];
        _position = Duration.zero;
        _duration = _currentSong!.duration != null ? Duration(seconds: _currentSong!.duration!) : Duration.zero;
        _isLoading = true;
        _lastPlaybackError = null;
        notifyListeners();
        _saveQueueState();
        _refreshArtworkUrl().catchError((_) {});
        _updateAndroidAuto();

        _skipDebounceTimer?.cancel();
        _skipDebounceTimer = Timer(const Duration(milliseconds: 220), () {
          if (skipGen != _skipGeneration) return;
          skipToIndex(nextIndex, skipGen: skipGen);
        });
      }
    } else if (_repeatMode == RepeatMode.all && _queue.isNotEmpty) {
      if (_queue.length == 1) {
        await seek(Duration.zero);
        await play();
      } else {
        _currentIndex = 0;
        _currentSong = _queue[0];
        _position = Duration.zero;
        _duration = _currentSong!.duration != null ? Duration(seconds: _currentSong!.duration!) : Duration.zero;
        _isLoading = true;
        _lastPlaybackError = null;
        notifyListeners();
        _refreshArtworkUrl().catchError((_) {});
        _updateAndroidAuto();

        _skipDebounceTimer?.cancel();
        _skipDebounceTimer = Timer(const Duration(milliseconds: 220), () {
          if (skipGen != _skipGeneration) return;
          skipToIndex(0, skipGen: skipGen);
        });
      }
    }
  }

  Future<void> _addAutoDjSongs() async {
    if (!_autoDjService.isEnabled) return;

    try {
      final songsToAdd = await _autoDjService.getSongsToQueue(
        currentSong: _currentSong,
        currentQueue: _queue,
        availableSongs: _libraryProvider?.cachedAllSongs,
      );

      if (songsToAdd.isNotEmpty) {
        _queue.addAll(songsToAdd);
        notifyListeners();
        _saveQueueState();
        debugPrint('Auto DJ added ${songsToAdd.length} songs to queue');
      }
    } catch (e) {
      debugPrint('Auto DJ error: $e');
    }
  }

  Future<void> skipPrevious() async {
    _hasRetriedCurrentPlay = false;
    _isTransitioningSong = false; // Bug 5 fix: manual skip wins over concurrent auto-transition
    final skipGen = ++_skipGeneration; // capture before any await

    if (_groovyConnectService?.isConnected == true) {
      _isRenderingRemotely = true;
      if (_position.inSeconds > 3) {
        await seek(Duration.zero);
        return;
      }
      _lastRemoteSeekTime = DateTime.now();
      _position = Duration.zero;
      _remoteAnchorPosition = Duration.zero;
      _remoteAnchorTime = null;
      _isLoading = true;
      _positionController.add(Duration.zero);
      if (_queue.isNotEmpty && _currentIndex > 0) {
        _currentIndex--;
        _currentSong = _queue[_currentIndex];
        _duration = _currentSong!.duration != null ? Duration(seconds: _currentSong!.duration!) : Duration.zero;
        _optimisticRemoteSongId = _currentSong?.id;
        _optimisticRemoteSongUntil = DateTime.now().add(const Duration(milliseconds: 12000));
        _refreshArtworkUrl().catchError((_) {});
        _manageRemotePositionTicker();
        notifyListeners();
        _skipDebounceTimer?.cancel();
        _skipDebounceTimer = Timer(const Duration(milliseconds: 220), () {
          unawaited(_groovyConnectService!.sendPlaySong(_currentSong!, queue: _queue, queueIndex: _currentIndex));
        });
        return;
      }
      _manageRemotePositionTicker();
      notifyListeners();
      unawaited(_groovyConnectService!.sendControl('skipPrevious'));
      return;
    }
    if (_position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    if (_queue.isEmpty) return;

    if (_shuffleEnabled && _shuffleHistory.isNotEmpty) {
      final prevId = _shuffleHistory.removeLast();
      final prev = _queue.indexWhere((s) => s.id == prevId);
      if (prev != -1) {
        _currentIndex = prev;
        _currentSong = _queue[prev];
        _position = Duration.zero;
        _duration = _currentSong!.duration != null ? Duration(seconds: _currentSong!.duration!) : Duration.zero;
        _isLoading = true;
        _lastPlaybackError = null;
        notifyListeners();
        _refreshArtworkUrl().catchError((_) {});
        _updateAndroidAuto();

        _skipDebounceTimer?.cancel();
        _skipDebounceTimer = Timer(const Duration(milliseconds: 220), () {
          if (skipGen != _skipGeneration) return;
          skipToIndex(prev, skipGen: skipGen);
        });
        return;
      }
    }
    if (_currentIndex > 0) {
      final prevIndex = _currentIndex - 1;
      _currentIndex = prevIndex;
      _currentSong = _queue[prevIndex];
      _position = Duration.zero;
      _duration = _currentSong!.duration != null ? Duration(seconds: _currentSong!.duration!) : Duration.zero;
      _isLoading = true;
      _lastPlaybackError = null;
      notifyListeners();
      _refreshArtworkUrl().catchError((_) {});
      _updateAndroidAuto();

      _skipDebounceTimer?.cancel();
      _skipDebounceTimer = Timer(const Duration(milliseconds: 220), () {
        if (skipGen != _skipGeneration) return;
        skipToIndex(prevIndex, skipGen: skipGen);
      });
    } else if (_repeatMode == RepeatMode.all && _queue.isNotEmpty) {
      if (_queue.length == 1) {
        await seek(Duration.zero);
        await play();
      } else {
        final lastIndex = _queue.length - 1;
        _currentIndex = lastIndex;
        _currentSong = _queue[lastIndex];
        _position = Duration.zero;
        _duration = _currentSong!.duration != null ? Duration(seconds: _currentSong!.duration!) : Duration.zero;
        _isLoading = true;
        _lastPlaybackError = null;
        notifyListeners();
        _refreshArtworkUrl().catchError((_) {});
        _updateAndroidAuto();

        _skipDebounceTimer?.cancel();
        _skipDebounceTimer = Timer(const Duration(milliseconds: 220), () {
          if (skipGen != _skipGeneration) return;
          skipToIndex(lastIndex, skipGen: skipGen);
        });
      }
    } else {
      await seek(Duration.zero);
    }
  }

  Future<void> skipToIndex(int index, {int? skipGen, bool forcePlay = true}) async {
    // If a skipGen was passed, abort if another skip superseded this one
    if (skipGen != null && skipGen != _skipGeneration) return;
    if (index >= 0 && index < _queue.length) {
      await playSong(_queue[index], startIndex: index, forcePlay: forcePlay);
    }
  }

  void toggleShuffle() {
    _shuffleEnabled = !_shuffleEnabled;
    _shuffleHistory.clear();
    if (_shuffleEnabled && _queue.length > 1 && _currentSong != null) {
      final currentSong = _currentSong!;
      _queue.shuffle();
      _queue.remove(currentSong);
      _queue.insert(0, currentSong);
      _currentIndex = 0;
      if (_concatenatingSource != null) {
        _buildAndSetConcatenatingSource(initialIndex: 0).catchError((e) {
          debugPrint('Error rebuilding concatenating source after shuffle: $e');
        });
      }
      _saveQueueState();
    }
    _storageService.saveShuffleMode(_shuffleEnabled);
    notifyListeners();
  }

  void toggleRepeat() {
    switch (_repeatMode) {
      case RepeatMode.off:
        _repeatMode = RepeatMode.all;
        _audioPlayer.setLoopMode(LoopMode.all);
        break;
      case RepeatMode.all:
        _repeatMode = RepeatMode.one;
        _audioPlayer.setLoopMode(LoopMode.one);
        break;
      case RepeatMode.one:
        _repeatMode = RepeatMode.off;
        _audioPlayer.setLoopMode(LoopMode.off);
        break;
    }
    _storageService.saveRepeatMode(_repeatMode.index);
    notifyListeners();
  }

  void toggleGaplessPlayback() {
    _gaplessEnabled = !_gaplessEnabled;
    _storageService.saveGaplessPlayback(_gaplessEnabled);
    notifyListeners();
  }

  void addToQueue(Song song) {
    _queue.add(song);
    notifyListeners();
  }

  Future<void> addToQueueNext(Song song) async {
    final insertIndex = _currentIndex + 1;
    if (insertIndex < _queue.length) {
      _queue.insert(insertIndex, song);
    } else {
      _queue.add(song);
    }
    if (_concatenatingSource != null) {
      try {
        final audioSource = await _buildAudioSourceForSong(song);
        if (insertIndex < _concatenatingSource!.length) {
          _concatenatingSource!.insert(insertIndex, audioSource);
        } else {
          _concatenatingSource!.add(audioSource);
        }
      } catch (e) {
        debugPrint('Error adding to concatenating source: $e');
      }
    }
    notifyListeners();
  }

  Future<void> addAllToQueue(Iterable<Song> songs) async {
    final newSongs = songs.toList();
    _queue.addAll(newSongs);
    if (_concatenatingSource != null) {
      for (final song in newSongs) {
        try {
          final source = await _buildAudioSourceForSong(song);
          _concatenatingSource!.add(source);
        } catch (e) {
          debugPrint('Error adding to concatenating source: $e');
        }
      }
    }
    notifyListeners();
  }

  void removeFromQueue(int index) {
    if (index >= 0 && index < _queue.length) {
      _queue.removeAt(index);
      if (_concatenatingSource != null &&
          index < _concatenatingSource!.length) {
        try {
          _concatenatingSource!.removeAt(index);
        } catch (e) {
          debugPrint('Error removing from concatenating source: $e');
        }
      }
      if (index < _currentIndex) {
        _currentIndex--;
      } else if (index == _currentIndex && _queue.isNotEmpty) {
        if (_currentIndex >= _queue.length) {
          _currentIndex = _queue.length - 1;
        }
        if (_queue.isNotEmpty) {
          playSong(
            _queue[_currentIndex],
            playlist: _queue,
            startIndex: _currentIndex,
          );
        }
      }
      _saveQueueState();
      notifyListeners();
    }
  }

  void clearQueue() {
    _queue.clear();
    _currentIndex = -1;
    _currentSong = null;
    _activeAudioSongId = null;
    _concatenatingSource = null;

    _clearPersistedQueue();
    _audioPlayer.stop();
    _isPlaying = false;
    _position = Duration.zero;
    notifyListeners();
    _updateAndroidAuto();
  }

  void moveQueueItem(int oldIndex, int newIndex) {
    if (oldIndex == newIndex ||
        oldIndex < 0 ||
        oldIndex >= _queue.length ||
        newIndex < 0 ||
        newIndex >= _queue.length) {
      return;
    }

    final song = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, song);

    if (_concatenatingSource != null) {
      try {
        _concatenatingSource!.move(oldIndex, newIndex);
      } catch (e) {
        debugPrint('Error moving in concatenating source: $e');
      }
    }

    if (oldIndex == _currentIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex -= 1;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex += 1;
    }

    notifyListeners();
    _saveQueueState();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    moveQueueItem(oldIndex, newIndex);
  }

  void _debounceRemoteVolumeSend(double targetVolume) {
    _remoteVolumeDebounceTimer?.cancel();
    _remoteVolumeDebounceTimer = Timer(const Duration(milliseconds: 75), () {
      if (_groovyConnectService?.isConnected == true) {
        unawaited(_groovyConnectService!.sendControl('volume', targetVolume));
      }
    });
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    notifyListeners();
    unawaited(_storageService.saveVolume(_volume));
    if (_groovyConnectService?.isConnected == true) {
      _isRenderingRemotely = true;
      _lastRemoteVolumeChangeTime = DateTime.now();
      _optimisticRemoteVolume = _volume;
      _audioHandler.updateRemoteVolume((_volume * 100).round());
      _debounceRemoteVolumeSend(_volume);
    } else if (_castService.isConnected) {
      await _castService.setVolume(_volume);
    } else if (_upnpService.isConnected) {
      await _upnpService.setVolume((_volume * 100).round());
    } else {
      await _applyReplayGain(_currentSong);
      if (!kIsWeb && Platform.isAndroid) {
        try {
          VolumeController.instance.setVolume(_volume);
        } catch (_) {}
      }
    }
  }

  bool _upnpVolumeWriteInProgress = false;

  void _onRemoteVolumeChange(int volume) {
    final normalized = (volume / 100.0).clamp(0.0, 1.0);
    if (_groovyConnectService?.isConnected == true) {
      setVolume(normalized);
    } else if (_castService.isConnected) {
      _castService.setVolume(normalized);
    } else if (_upnpService.isConnected) {
      if (_upnpVolumeWriteInProgress) return;
      _applyUpnpVolume(volume);
    }
  }

  Future<void> _applyUpnpVolume(int volume) async {
    _upnpVolumeWriteInProgress = true;
    _volume = (volume / 100.0).clamp(0.0, 1.0);
    notifyListeners();
    try {
      await _upnpService.setVolume(volume);
      final actual = await _upnpService.getVolume();
      if (actual >= 0) {
        _volume = actual / 100.0;
        _audioHandler.updateRemoteVolume(actual);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('UPnP setVolume error: $e');
    } finally {
      _upnpVolumeWriteInProgress = false;
    }
  }

  // ── Gapless playback helpers ───────────────────────────────────────────

  Future<AudioSource> _buildAudioSourceForSong(Song song) async {
    if (song.isLocal == true && song.path != null) {
      return AudioSource.uri(Uri.file(song.path!));
    }
    final offlinePath = _offlineService.getLocalPath(song.id);
    if (offlinePath != null) {
      return AudioSource.uri(Uri.file(offlinePath));
    }
    final ytSource = await _youtubeService.getYoutubeAudioSource(song);
    if (ytSource != null) return ytSource;

    // Try resolving actual direct stream URL asynchronously
    try {
      final playUrl = await _youtubeService.resolveStreamUrlAsync(song);
      if (playUrl.isNotEmpty && !playUrl.contains('youtube.com/watch')) {
        return AudioSource.uri(Uri.parse(playUrl), tag: song.id);
      }
    } catch (_) {}

    throw Exception('Could not resolve audio stream for "${song.title}"');
  }

  Future<void> _buildAndSetConcatenatingSource({
    required int initialIndex,
    Duration? initialPosition,
    int? playGeneration,
  }) async {
    final originalQueue = List<Song>.from(_queue);
    final selectedSongId = _currentSong?.id ??
        (initialIndex >= 0 && initialIndex < originalQueue.length
            ? originalQueue[initialIndex].id
            : null);
    final playableSongs = <Song>[];
    final children = <AudioSource>[];

    // One unavailable track must not prevent an album or playlist from
    // loading. Keep the selected track mandatory, but omit other tracks that
    // cannot resolve so the remaining queue can still play.
    final resolvedSources = await Future.wait(
      originalQueue.map((queuedSong) async {
        try {
          return await _buildAudioSourceForSong(queuedSong);
        } catch (error) {
          debugPrint(
            '[Player] Skipping unavailable queued track "${queuedSong.title}": $error',
          );
          if (queuedSong.id == selectedSongId) rethrow;
          return null;
        }
      }),
    );

    if (playGeneration != null && playGeneration != _playGeneration) return;

    for (var i = 0; i < resolvedSources.length; i++) {
      final source = resolvedSources[i];
      if (source != null) {
        playableSongs.add(originalQueue[i]);
        children.add(source);
      }
    }

    if (children.isEmpty) {
      throw StateError('No playable tracks remain in the queue');
    }

    if (playableSongs.length != originalQueue.length) {
      _queue = playableSongs;
      _currentIndex = selectedSongId == null
          ? (initialIndex < 0
              ? 0
              : (initialIndex >= _queue.length
                  ? _queue.length - 1
                  : initialIndex))
          : _queue.indexWhere((song) => song.id == selectedSongId);
      if (_currentIndex < 0) {
        throw StateError('Selected track was removed from the queue');
      }
      _currentSong = _queue[_currentIndex];
      _saveQueueState();
      notifyListeners();
    }

    if (playGeneration != null && playGeneration != _playGeneration) return;

    _concatenatingSource = ConcatenatingAudioSource(children: children);
    await _audioPlayer.setAudioSource(
      _concatenatingSource!,
      initialIndex: _currentIndex,
      initialPosition: initialPosition ?? Duration.zero,
      preload: true,
    );
  }

  Future<void> _prepareCurrentSong() async {
    if (_currentSong == null) return;
    try {
      final ytSource = _currentSong!.isLocal != true
          ? await _youtubeService.getYoutubeAudioSource(_currentSong!)
          : null;
      if (ytSource != null) {
        _concatenatingSource = null;
        await _audioPlayer.setAudioSource(ytSource);
        _activeAudioSongId = _currentSong?.id;
        if (_position.inMilliseconds > 0) {
          await _audioPlayer.seek(_position);
        }
        return;
      }
      if (_gaplessEnabled && _queue.isNotEmpty) {
        await _buildAndSetConcatenatingSource(initialIndex: _currentIndex);
      } else {
        final String playUrl;
        if (_currentSong!.isLocal == true && _currentSong!.path != null) {
          playUrl = Uri.file(_currentSong!.path!).toString();
        } else {
          final offlinePath = _offlineService.getLocalPath(_currentSong!.id);
          if (offlinePath != null) {
            playUrl = 'file://$offlinePath';
          } else {
            playUrl =
                await _youtubeService.resolveStreamUrlAsync(_currentSong!);
          }
        }
        if (playUrl.isEmpty || playUrl.contains('youtube.com/watch')) {
          throw Exception('No valid audio stream URL for "${_currentSong!.title}"');
        }
        if (_currentSong!.isLocal == true ||
            _offlineService.getLocalPath(_currentSong!.id) != null ||
            (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS))) {
          await _audioPlayer.setUrl(playUrl);
        } else {
          final cacheDir = await getTemporaryDirectory();
          final cacheFile = File(
            '${cacheDir.path}/groovy_stream_${_currentSong!.id.hashCode}.tmp',
          );
          // ignore: experimental_member_use
          await _audioPlayer.setAudioSource(
            // ignore: experimental_member_use
            LockCachingAudioSource(
              Uri.parse(playUrl),
              cacheFile: cacheFile,
              tag: _currentSong!.id,
            ),
          );
        }
      }
      // Seek to the restored position after the source is loaded
      if (_position.inMilliseconds > 0) {
        await _audioPlayer.seek(_position);
      }
    } catch (e) {
      debugPrint('Error preparing current song after restore: $e');
    }
  }

  Future<void> _onCurrentIndexChanged(int newIndex) async {
    if (newIndex < 0 || newIndex >= _queue.length) return;
    if (newIndex == _currentIndex) return;

    debugPrint(
        '[Player] ⏭ Track changed by index: $newIndex "${_queue[newIndex].title}"');

    // Sleep timer: end after current song
    if (_sleepTimerEndCurrentSong) {
      _doSleepTimerStop();
      return;
    }

    // Track completion of the previous song
    if (_currentSong != null) {
      if (_currentSong!.isLocal != true) {
        _youtubeService
            .scrobble(_currentSong!.id, submission: true)
            .catchError(
          (e) {
            _offlineService.queueScrobble(_currentSong!.id, submission: true);
          },
        );
      }
      if (_recommendationService != null) {
        _recommendationService!.trackSongPlay(
          _currentSong!,
          durationPlayed: _duration.inSeconds,
          completed: true,
        );
      }
    }

    // AutoDJ: add songs near end of queue
    if (_autoDjService.shouldAddSongs(newIndex, _queue.length)) {
      await _addAutoDjSongs();
    }

    _currentIndex = newIndex;
    _currentSong = _queue[_currentIndex];
    _activeAudioSongId = _currentSong?.id;
    _lastPreloadedSongId = null;
    _position = Duration.zero;
    _resolvedArtworkUrl = null;
    notifyListeners();
    _saveQueueState();

    if (_currentSong != null) {
      _recordSongPlayback(_currentSong!);
    }

    // Immediately publish song info to lockscreen / notification widget
    _updateAndroidAuto();

    await _refreshArtworkUrl();
    if (_currentSong != null) {
      await _applyReplayGain(_currentSong);
    }

    _updateAllServices();
    _updateAndroidAuto();
  }

  double get _effectiveVolume {
    final replayGainMultiplier = _replayGainService.calculateVolumeMultiplier(
      trackGain: _currentSong?.replayGainTrackGain,
      albumGain: _currentSong?.replayGainAlbumGain,
      trackPeak: _currentSong?.replayGainTrackPeak,
      albumPeak: _currentSong?.replayGainAlbumPeak,
    );
    return (_volume * replayGainMultiplier).clamp(0.0, 1.0);
  }

  Future<void> _applyReplayGain(Song? song) async {
    await _replayGainService.initialize();
    await _audioPlayer.setVolume(_effectiveVolume);
  }

  Future<void> refreshReplayGain() async {
    await _applyReplayGain(_currentSong);
    notifyListeners();
  }

  ReplayGainService get replayGainService => _replayGainService;

  Future<void> toggleFavorite() async {
    if (_currentSong == null) return;

    if (_libraryProvider != null) {
      final newStarred = await _libraryProvider!.toggleStarSong(_currentSong!);
      _currentSong = _currentSong!.copyWith(starred: newStarred);
      notifyListeners();
      return;
    }

    final isStarred = _currentSong!.starred == true;

    final newSong = _currentSong!.copyWith(starred: !isStarred);
    _currentSong = newSong;
    notifyListeners();

    try {
      if (isStarred) {
        await _youtubeService.unstar(id: newSong.id);
      } else {
        await _youtubeService.star(id: newSong.id);
      }
      _libraryProvider?.loadStarred();
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      _currentSong = _currentSong!.copyWith(starred: isStarred);
      notifyListeners();
    }
  }

  Future<void> toggleFavoriteForSong(Song song) async {
    if (_libraryProvider != null) {
      final newStarred = await _libraryProvider!.toggleStarSong(song);
      if (_currentSong?.id == song.id) {
        _currentSong = _currentSong!.copyWith(starred: newStarred);
        notifyListeners();
      }
      return;
    }

    final isStarred = song.starred == true;
    try {
      if (isStarred) {
        await _youtubeService.unstar(id: song.id);
      } else {
        await _youtubeService.star(id: song.id);
      }
      _libraryProvider?.loadStarred();

      if (_currentSong?.id == song.id) {
        _currentSong = _currentSong!.copyWith(starred: !isStarred);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error toggling favorite for song: $e');
    }
  }

  Future<void> setRating(String songId, int rating) async {
    if (_currentSong?.id != songId) return;

    final previousRating = _currentSong?.userRating;
    _currentSong = _currentSong?.copyWith(userRating: rating);
    notifyListeners();

    try {
      await _youtubeService.setRating(songId, rating);
    } catch (e) {
      _currentSong = _currentSong?.copyWith(userRating: previousRating);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> reactivateAudioSession() async {

    if (_currentSong != null) {
      _updateAllServices();
    }

    if (Platform.isIOS) {
      try {
        final session = await AudioSession.instance;
        await session.setActive(true);

        // Wait a bit for the audio session to stabilize
        await Future.delayed(const Duration(milliseconds: 100));

        // If there's a current song and audio is not playing, resume it
        // This handles the case where iOS pauses audio when dismissing the player
        if (_currentSong != null && !_audioPlayer.playing) {
          debugPrint(
              '[Player] iOS: Resuming playback after audio session reactivation (song: ${_currentSong!.title})');
          await _audioPlayer.play();
          _isPlaying = true;
          notifyListeners();
          _updateAllServices();
        }
      } catch (e) {
        debugPrint('[Player] iOS: Error reactivating audio session: $e');
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this); // single removal — was duplicated before
    _telemetryTimer?.cancel();
    _remoteVolumeDebounceTimer?.cancel();
    _sleepTimer?.cancel();
    _sleepTimerFadeTimer?.cancel();
    _sleepTimerFadePeriodicTimer?.cancel();
    // Save queue state immediately before cancelling the debounce timer
    _saveQueueStateImmediate();
    _persistDebounceTimer?.cancel();
    _skipDebounceTimer?.cancel();
    _windowsPositionTimer?.cancel();
    _remotePositionTickerTimer?.cancel();
    _castService.removeListener(_onCastStateChanged);
    _upnpService.removeListener(_onUpnpStateChanged);
    _groovyConnectService?.removeListener(_onGroovyConnectChanged);
    _libraryProvider?.removeListener(_onLibraryChanged); // Bug 4 fix: was missing, caused listener leak
    if (_upnpService.onRendererLost == _onUpnpRendererLost) {
      _upnpService.onRendererLost = null;
    }
    // Stop playback before disposing audio handler to prevent NPE on Android
    _audioPlayer.stop().catchError((_) {});

    // Dispose audio handler with error handling
    _audioHandler.customAction('dispose').catchError((e) {
      debugPrint('Error disposing audio handler: $e');
    });

    _becomingNoisySubscription?.cancel();
    _interruptionSubscription?.cancel();
    _devicesChangedSubscription?.cancel();

    try {
      _windowsService.dispose();
    } catch (_) {}

    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _currentIndexSub?.cancel();
    _positionController.close();
    super.dispose();
  }



  void _onCastStateChanged() {
    notifyListeners();
    if (_castService.isConnected) {
      _audioPlayer.pause();
      _audioHandler.setRemotePlayback(
        isRemote: true,
        volume: (_castService.mediaState.volume * 100).round().clamp(0, 100),
      );
      if (_currentSong != null) {
        // Bug 7 fix: do NOT null _currentSong before calling playSong — it caused playSong
        // to always think it's a new song and restart from 0. Use forcePlay:true instead.
        final song = _currentSong!;
        playSong(song, forcePlay: true);
      }
    } else {
      if (!_upnpService.isConnected && _groovyConnectService?.isConnected != true) {
        _isRenderingRemotely = false;
        _audioHandler.setRemotePlayback(isRemote: false);
        _isPlaying = false;
        notifyListeners();
        _updateAndroidAuto();
      }
    }
  }

  bool _upnpWasConnected = false;
  bool _upnpWasPlaying = false;
  // True when an A2DP audio-output device (car, speaker) is connected.
  // Control-only devices (Garmin watch, etc.) don't set this flag.
  final bool _isA2dpAudioActive = false;

  void _onUpnpStateChanged() {
    final connected = _upnpService.isConnected;

    if (connected && !_upnpWasConnected) {
      _upnpWasConnected = true;
      _upnpWasPlaying = false;
      if (_audioPlayer.playing) _audioPlayer.pause();
      final vol = _upnpService.volume;

      if (vol >= 0) _volume = vol / 100.0;
      _audioHandler.setRemotePlayback(
        isRemote: true,
        volume: vol >= 0 ? vol : 50,
      );
      if (_currentSong != null) {
        final song = _currentSong!;
        _currentSong = null;
        playSong(song);
      }
      return;
    }

    if (!connected && _upnpWasConnected) {
      _upnpWasConnected = false;
      _upnpWasPlaying = false;
      if (!_castService.isConnected && _groovyConnectService?.isConnected != true) {
        _isRenderingRemotely = false;
        _isPlaying = false;
        // Preserve _position and _duration so the UI shows where we were.
        _audioHandler.setRemotePlayback(isRemote: false);
        notifyListeners();
        _updateAndroidAuto();
      }
      return;
    }

    if (!connected) return;

    final pos = _upnpService.rendererPosition;
    final dur = _upnpService.rendererDuration;
    final playing = _upnpService.isRendererPlaying;
    final rendererState = _upnpService.rendererState;

    if (_upnpWasPlaying && rendererState == 'STOPPED') {
      // _upnpWasPlaying is reset to false in playSong() and stop() before
      // any Stop command is sent, so this only fires for a *natural* track
      // end.  We don't check duration > 0 here because many renderers
      // (including moode/upmpdcli) return 0:00:00 from GetPositionInfo once
      // the transport is stopped, which would cause the check to silently fail.
      debugPrint(
          'UPnP: Track ended (pos=${pos.inSeconds}s, dur=${dur.inSeconds}s) — advancing');
      _upnpWasPlaying = false;
      _onSongComplete()
          .catchError((e) => debugPrint('[Player] _onSongComplete error: $e'));
      return;
    }

    _upnpWasPlaying = playing;

    bool changed = false;

    if ((_position - pos).abs() > const Duration(milliseconds: 500)) {
      _position = pos;
      changed = true;
    }
    if (dur != Duration.zero && dur != _duration) {
      _duration = dur;
      changed = true;
    }
    if (playing != _isPlaying) {
      _isPlaying = playing;
      changed = true;
    }

    final vol = _upnpService.volume;
    if (vol >= 0 && !_upnpVolumeWriteInProgress) {
      final normalized = vol / 100.0;
      if ((_volume - normalized).abs() > 0.005) {
        _volume = normalized;
        changed = true;
        _audioHandler.updateRemoteVolume(vol);
      }
    }

    if (changed) {
      _positionController.add(_position);
      notifyListeners();
      _updateAndroidAuto();
    }
  }

  /// Called by [UpnpService] after 30 consecutive poll failures (~30 s).
  /// [_onUpnpStateChanged] has already switched us off remote playback and
  /// preserved [_position]. Load the song into the local player at the last
  /// known position, paused, so the user can resume wherever they want.
  /// Android routes audio to a connected A2DP device automatically.
  Future<void> _onUpnpRendererLost() async {
    final lastPosition = _position;
    final lastSong = _currentSong;

    debugPrint(
      'UPnP: renderer lost — A2DP audio active: $_isA2dpAudioActive, '
      'last position: ${lastPosition.inSeconds}s, song: "${lastSong?.title}"',
    );

    if (lastSong == null) return;

    final playUrl = lastSong.isLocal == true && lastSong.path != null
        ? Uri.file(lastSong.path!).toString()
        : _offlineService.getPlayableUrl(lastSong, _youtubeService);

    _isLoading = true;
    notifyListeners();

    try {
      await _audioPlayer.setUrl(playUrl);
      _position = lastPosition;
      await _audioPlayer.seek(lastPosition);
      // Leave paused — let the user consciously resume on their new output.
    } catch (e) {
      debugPrint('UPnP fallback: failed to reload local player: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
      _updateAndroidAuto();
    }
  }
}
