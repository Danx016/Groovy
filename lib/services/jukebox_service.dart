import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import 'youtube_service.dart';

class JukeboxStatus {
  final bool playing;
  final int currentIndex;
  final double gain;
  final Duration position;
  final List<Song> playlist;

  JukeboxStatus({
    required this.playing,
    required this.currentIndex,
    required this.gain,
    required this.position,
    required this.playlist,
  });

  static JukeboxStatus empty() => JukeboxStatus(
    playing: false,
    currentIndex: 0,
    gain: 1.0,
    position: Duration.zero,
    playlist: [],
  );

  Song? get currentSong => playlist.isNotEmpty && currentIndex < playlist.length
      ? playlist[currentIndex]
      : null;
}

class JukeboxService extends ChangeNotifier {
  static final JukeboxService _instance = JukeboxService._internal();
  factory JukeboxService() => _instance;
  JukeboxService._internal();

  static const _enabledKey = 'jukebox_mode_enabled';

  bool _enabled = false;
  JukeboxStatus _status = JukeboxStatus.empty();
  bool _isLoading = false;
  String? _error;
  bool _serverUnsupported = false;

  bool get enabled => _enabled;
  JukeboxStatus get status => _status;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get serverUnsupported => _serverUnsupported;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? false;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
    notifyListeners();
  }

  Future<void> refresh(YoutubeService musicService) async {
    if (!_enabled) return;
    _isLoading = true;
    notifyListeners();
    try {
      final data = await musicService.jukeboxGet();
      _status = _parseStatus(data);
      _error = null;
      _serverUnsupported = false;
    } catch (e) {
      debugPrint('Jukebox refresh error: $e');
      final msg = e.toString();
      if (msg.contains('501')) {
        _serverUnsupported = true;
        _error = null; 
      } else {
        _error = msg.replaceFirst('Exception: ', '');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> play(YoutubeService musicService) async {
    await _command(() => musicService.jukeboxStart(), musicService);
  }

  Future<void> pause(YoutubeService musicService) async {
    await _command(() => musicService.jukeboxStop(), musicService);
  }

  Future<void> skip(YoutubeService musicService, int index) async {
    await _command(() => musicService.jukeboxSkip(index), musicService);
  }

  Future<void> skipNext(YoutubeService musicService) async {
    final next = (_status.currentIndex + 1).clamp(
      0,
      (_status.playlist.length - 1).clamp(0, double.maxFinite.toInt()),
    );
    await skip(musicService, next);
  }

  Future<void> skipPrevious(YoutubeService musicService) async {
    final prev = (_status.currentIndex - 1).clamp(0, double.maxFinite.toInt());
    await skip(musicService, prev);
  }

  Future<void> setQueue(
    YoutubeService musicService,
    List<Song> songs, {
    int startIndex = 0,
  }) async {
    if (songs.isEmpty) return;
    _isLoading = true;
    notifyListeners();
    try {
      final ids = songs.map((s) => s.id).toList();
      await musicService.jukeboxSet(ids);
      await musicService.jukeboxSkip(startIndex);
      await musicService.jukeboxStart();
    } catch (e) {
      debugPrint('Jukebox setQueue error: $e');
    } finally {
      await refresh(musicService);
    }
  }

  Future<void> addToQueue(YoutubeService musicService, List<Song> songs) async {
    if (songs.isEmpty) return;
    final ids = songs.map((s) => s.id).toList();
    await _command(() => musicService.jukeboxAdd(ids), musicService);
  }

  Future<void> clearQueue(YoutubeService musicService) async {
    await _command(() => musicService.jukeboxClear(), musicService);
  }

  Future<void> shuffleQueue(YoutubeService musicService) async {
    await _command(() => musicService.jukeboxShuffle(), musicService);
  }

  Future<void> removeFromQueue(YoutubeService musicService, int index) async {
    await _command(() => musicService.jukeboxRemove(index), musicService);
  }

  Future<void> setGain(YoutubeService musicService, double gain) async {
    await _command(
      () => musicService.jukeboxSetGain(gain.clamp(0.0, 1.0)),
      musicService,
    );
  }

  Future<void> _command(
    Future<Map<String, dynamic>> Function() fn,
    YoutubeService musicService,
  ) async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await fn();
      _status = _parseStatus(data);
      _error = null;
      _serverUnsupported = false;
    } catch (e) {
      debugPrint('Jukebox command error: $e');
      final msg = e.toString();
      if (msg.contains('501')) {
        _serverUnsupported = true;
        _error = null;
      } else {
        _error = msg.replaceFirst('Exception: ', '');
      }
      await refresh(musicService);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  JukeboxStatus _parseStatus(Map<String, dynamic> data) {
    final playing = data['playing'] == true;
    final currentIndex = (data['currentIndex'] as int?) ?? 0;
    final gainRaw = data['gain'];
    final gain = gainRaw is num ? gainRaw.toDouble() : 1.0;
    final positionSecs = (data['position'] as int?) ?? 0;
    final position = Duration(seconds: positionSecs);

    final entriesRaw = data['entry'];
    final List<Song> playlist = [];
    if (entriesRaw is List) {
      for (final e in entriesRaw) {
        if (e is Map<String, dynamic>) {
          playlist.add(Song.fromJson(e));
        }
      }
    }

    return JukeboxStatus(
      playing: playing,
      currentIndex: currentIndex,
      gain: gain,
      position: position,
      playlist: playlist,
    );
  }
}
