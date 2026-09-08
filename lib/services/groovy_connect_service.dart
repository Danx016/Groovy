import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/song.dart';
import 'device_info_service.dart';
import 'groovy_api_service.dart';

/// Represents a remote Groovy instance available in the cloud.
class GroovyRemoteDevice {
  final String id;
  final String name;
  final String platform;
  final String model;
  final String host;
  final int port;
  final bool isLocalLan;
  final Song? currentSong;
  final bool isPlaying;
  final DateTime lastSeen;

  GroovyRemoteDevice({
    required this.id,
    required this.name,
    required this.platform,
    required this.model,
    this.host = '',
    this.port = 0,
    this.isLocalLan = false,
    this.currentSong,
    this.isPlaying = false,
    required this.lastSeen,
  });

  GroovyRemoteDevice copyWith({
    String? id,
    String? name,
    String? platform,
    String? model,
    String? host,
    int? port,
    bool? isLocalLan,
    Song? currentSong,
    bool? isPlaying,
    DateTime? lastSeen,
  }) {
    return GroovyRemoteDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      model: model ?? this.model,
      host: host ?? this.host,
      port: port ?? this.port,
      isLocalLan: isLocalLan ?? this.isLocalLan,
      currentSong: currentSong ?? this.currentSong,
      isPlaying: isPlaying ?? this.isPlaying,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'platform': platform,
    'model': model,
    'host': host,
    'port': port,
    'isLocalLan': isLocalLan,
    'isPlaying': isPlaying,
    'song': currentSong?.toJson(),
  };

  factory GroovyRemoteDevice.fromJson(Map<String, dynamic> json, {String? host, int? port}) {
    return GroovyRemoteDevice(
      id: json['device_key']?.toString() ?? json['device_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['device_name']?.toString() ?? json['name']?.toString() ?? 'Groovy Device',
      platform: json['platform']?.toString() ?? 'Dispositivo',
      model: json['device_model']?.toString() ?? json['model']?.toString() ?? '',
      host: host ?? json['ip_address']?.toString() ?? '',
      port: port ?? 0,
      isLocalLan: false,
      isPlaying: json['isPlaying'] == true || json['is_playing'] == 1 || json['is_playing'] == true,
      currentSong: json['song'] != null
          ? Song.fromJson(json['song'] as Map<String, dynamic>)
          : (json['song_id'] != null && json['title'] != null
              ? Song(
                  id: json['song_id'].toString(),
                  title: json['title'].toString(),
                  artist: json['artist']?.toString() ?? '',
                  album: json['album']?.toString(),
                  coverArt: json['cover_art']?.toString(),
                  duration: (json['duration'] as num?)?.toInt(),
                  isLocal: false,
                )
              : null),
      lastSeen: DateTime.now(),
    );
  }
}

/// 100% Cloud-Native Groovy Connect Service.
/// Coordinates cross-device discovery, real-time synchronization, and remote playback
/// controls across Windows, Android, Mac, Linux, and Web anywhere over the internet.
class GroovyConnectService extends ChangeNotifier {
  static final GroovyConnectService _instance = GroovyConnectService._internal();
  factory GroovyConnectService() => _instance;
  GroovyConnectService._internal();

  String _localDeviceId = '';
  String _localDeviceName = '';
  String _localPlatform = '';
  String _localModel = '';
  String? _cachedAuthToken;

  final Map<String, GroovyRemoteDevice> _discoveredDevices = {};
  GroovyRemoteDevice? _connectedDevice;
  bool _isDiscovering = false;
  Timer? _discoveryTimer;
  Timer? _pruneTimer;
  Timer? _commandPollTimer;
  Timer? _statusSyncTimer;
  bool _isPollingCommands = false;

  // Callbacks hooked to PlayerProvider
  Future<void> Function(
    Song song,
    int positionMs,
    bool isPlaying,
    String fromDevice,
    List<Song>? queue,
    int? queueIndex,
  )? onTransferReceived;

  void Function(String action, dynamic value)? onCommandReceived;
  Map<String, dynamic> Function()? onProvidePlayerStatus;

  void Function({
    Song? song,
    required Duration position,
    required Duration duration,
    required bool isPlaying,
    required double volume,
  })? onRemoteStatusUpdated;

  List<GroovyRemoteDevice> get discoveredDevices => _discoveredDevices.values.toList();
  GroovyRemoteDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _connectedDevice != null;
  bool get isDiscovering => _isDiscovering;
  String get localDeviceId => _localDeviceId;
  String get localDeviceName => _localDeviceName;
  String get localPlatform => _localPlatform;
  String get localModel => _localModel;
  int get httpPort => 0;

  /// Initializes the service, generating or loading the persistent device ID and starting cloud command listeners.
  Future<void> initialize() async {
    try {
      final info = await DeviceInfoService().getDeviceInfo();
      _localPlatform = info.platform;
      _localModel = info.deviceModel;
      _localDeviceName = info.deviceModel;

      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString('groovy_cloud_device_id_v2');
      if (id == null || id.isEmpty) {
        id = 'dev_${info.platform.toLowerCase()}_${const Uuid().v4().substring(0, 8)}';
        await prefs.setString('groovy_cloud_device_id_v2', id);
      }
      _localDeviceId = id;

      // Start background command polling loop (every 1.2 seconds)
      _startCommandPollLoop();

      // Prune devices not seen in > 60 seconds
      _pruneTimer?.cancel();
      _pruneTimer = Timer.periodic(const Duration(seconds: 15), (_) => _pruneStaleDevices());

      debugPrint('[GroovyConnect] 100% Cloud-Native initialized for device: $_localDeviceId ($_localDeviceName)');
    } catch (e) {
      debugPrint('[GroovyConnect] Init error: $e');
    }
  }

  /// Updates cached auth token to fetch user-specific devices and receive private commands.
  void updateAuthToken(String? token) {
    _cachedAuthToken = token;
    if (token != null && token.isNotEmpty) {
      discover(authToken: token);
    }
  }

  /// Starts the cloud command polling loop to receive actions from other devices.
  void _startCommandPollLoop() {
    _commandPollTimer?.cancel();
    _commandPollTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      _pollCloudCommands();
    });
  }

  /// Polls pending cloud commands targeting this device.
  Future<void> _pollCloudCommands() async {
    if (_localDeviceId.isEmpty || _isPollingCommands) return;
    _isPollingCommands = true;

    try {
      final commands = await GroovyApiService().getPendingCommands(
        deviceId: _localDeviceId,
        token: _cachedAuthToken,
      );

      for (final cmd in commands) {
        final action = cmd['action']?.toString() ?? '';
        final payload = cmd['payload'];

        debugPrint('[GroovyConnect] Cloud command received: $action');

        if (action == 'transfer' && payload is Map) {
          final songData = payload['song'] as Map<String, dynamic>?;
          final positionMs = (payload['positionMs'] as num?)?.toInt() ?? 0;
          final isPlaying = payload['isPlaying'] as bool? ?? true;
          final fromDevice = payload['fromDevice']?.toString() ?? 'Dispositivo Remoto';

          if (songData != null && onTransferReceived != null) {
            final song = Song.fromJson(songData).copyWith(isLocal: false);

            List<Song>? queue;
            final queueData = payload['queue'] as List<dynamic>?;
            if (queueData != null) {
              queue = queueData.map((s) {
                return Song.fromJson(s as Map<String, dynamic>).copyWith(isLocal: false);
              }).toList();
            }
            final queueIndex = (payload['queueIndex'] as num?)?.toInt();

            await onTransferReceived!(song, positionMs, isPlaying, fromDevice, queue, queueIndex);
          }
        } else if (action == 'control' && payload is Map) {
          final controlAction = payload['action']?.toString() ?? '';
          final controlValue = payload['value'];
          if (onCommandReceived != null && controlAction.isNotEmpty) {
            onCommandReceived!(controlAction, controlValue);
          }
        }
      }
    } catch (e) {
      // Ignore intermittent poll drops
    } finally {
      _isPollingCommands = false;
    }
  }

  /// Discovers other Groovy devices in the cloud associated with this user's account.
  Future<void> discover({String? authToken}) async {
    if (authToken != null) _cachedAuthToken = authToken;
    _isDiscovering = true;
    notifyListeners();

    try {
      await _fetchCloudDevices(_cachedAuthToken);
    } catch (e) {
      debugPrint('[GroovyConnect] Cloud discovery note: $e');
    }

    _discoveryTimer?.cancel();
    _discoveryTimer = Timer(const Duration(seconds: 3), () {
      _isDiscovering = false;
      notifyListeners();
    });
  }

  /// Fetches active cloud devices from the Groovy backend.
  Future<void> _fetchCloudDevices(String? token) async {
    try {
      final devicesList = await GroovyApiService().fetchUserDevices(token: token);

      for (final item in devicesList) {
        final remoteDeviceId = item['device_key']?.toString() ??
            item['device_id']?.toString() ??
            '${item['platform']}_${item['device_name']}';

        // Do not discover self
        if (remoteDeviceId == _localDeviceId) continue;

        final remoteDeviceName = item['device_name']?.toString() ?? item['device_model']?.toString() ?? 'Groovy Device';
        final remoteDevicePlatform = item['platform']?.toString() ?? 'Dispositivo';
        final isPlaying = item['is_playing'] == 1 || item['is_playing'] == true;

        Song? song;
        if (item['song_id'] != null && item['title'] != null) {
          song = Song(
            id: item['song_id'].toString(),
            title: item['title'].toString(),
            artist: item['artist']?.toString() ?? '',
            album: item['album']?.toString(),
            coverArt: item['cover_art']?.toString(),
            duration: (item['duration'] as num?)?.toInt(),
            isLocal: false,
          );
        }

        _discoveredDevices[remoteDeviceId] = GroovyRemoteDevice(
          id: remoteDeviceId,
          name: remoteDeviceName,
          platform: remoteDevicePlatform,
          model: item['device_model']?.toString() ?? '',
          host: item['ip_address']?.toString() ?? '',
          port: 0,
          isLocalLan: false,
          isPlaying: isPlaying,
          currentSong: song,
          lastSeen: DateTime.now(),
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[GroovyConnect] fetchCloudDevices error: $e');
    }
  }

  /// Removes devices that haven't sent a cloud ping in over 50 seconds.
  void _pruneStaleDevices() {
    final now = DateTime.now();
    _discoveredDevices.removeWhere((id, dev) {
      final isStale = now.difference(dev.lastSeen).inSeconds > 50;
      if (isStale && _connectedDevice?.id == id) {
        _connectedDevice = null;
        _statusSyncTimer?.cancel();
      }
      return isStale;
    });
    notifyListeners();
  }

  /// Transfers current playback to a remote device over the cloud.
  Future<bool> transferPlayback({
    required GroovyRemoteDevice device,
    required Song song,
    required Duration position,
    required bool isPlaying,
    List<Song>? queue,
    int? queueIndex,
  }) async {
    try {
      debugPrint('[GroovyConnect] Cloud transferring to ${device.name} (${device.id})');

      final success = await GroovyApiService().sendDeviceCommand(
        targetDeviceId: device.id,
        senderDeviceId: _localDeviceId,
        action: 'transfer',
        payload: {
          'song': song.copyWith(isLocal: false).toJson(),
          'positionMs': position.inMilliseconds,
          'isPlaying': isPlaying,
          'fromDevice': _localDeviceName,
          'queue': queue?.map((s) => s.copyWith(isLocal: false).toJson()).toList(),
          'queueIndex': queueIndex,
        },
        token: _cachedAuthToken,
      );

      if (success) {
        _connectedDevice = device.copyWith(
          currentSong: song,
          isPlaying: isPlaying,
          lastSeen: DateTime.now(),
        );
        _startStatusSyncTimer();
        notifyListeners();
        debugPrint('[GroovyConnect] Successfully transferred playback to ${device.name} via cloud');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[GroovyConnect] Transfer failed: $e');
      return false;
    }
  }

  /// Connects to a target Groovy device in the cloud without immediately transferring a song.
  Future<bool> connectToDevice(GroovyRemoteDevice device) async {
    _connectedDevice = device;
    _startStatusSyncTimer();
    notifyListeners();
    return true;
  }

  /// Sends remote playback commands (play, pause, togglePlayPause, skipNext, skipPrevious, seek, volume) via cloud.
  Future<bool> sendControl(String action, [dynamic value]) async {
    if (_connectedDevice == null) return false;

    try {
      final success = await GroovyApiService().sendDeviceCommand(
        targetDeviceId: _connectedDevice!.id,
        senderDeviceId: _localDeviceId,
        action: 'control',
        payload: {
          'action': action,
          'value': value,
        },
        token: _cachedAuthToken,
      );

      // Trigger status sync shortly after sending command to reflect state
      Future.delayed(const Duration(milliseconds: 350), () => _syncRemoteStatus());

      return success;
    } catch (e) {
      debugPrint('[GroovyConnect] Cloud sendControl error: $e');
      return false;
    }
  }

  /// Sends a song to play on the connected device via cloud.
  Future<bool> sendPlaySong(
    Song song, {
    int positionMs = 0,
    List<Song>? queue,
    int? queueIndex,
  }) async {
    if (_connectedDevice == null) return false;
    return transferPlayback(
      device: _connectedDevice!,
      song: song,
      position: Duration(milliseconds: positionMs),
      isPlaying: true,
      queue: queue,
      queueIndex: queueIndex,
    );
  }

  /// Starts status synchronization timer to reflect remote playback progress in the UI.
  void _startStatusSyncTimer() {
    _statusSyncTimer?.cancel();
    _statusSyncTimer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      _syncRemoteStatus();
    });
  }

  /// Synchronizes playback status with cloud telemetry from the target device.
  Future<void> _syncRemoteStatus() async {
    if (_connectedDevice == null) {
      _statusSyncTimer?.cancel();
      return;
    }

    try {
      final devicesList = await GroovyApiService().fetchUserDevices(token: _cachedAuthToken);
      final targetDev = devicesList.firstWhere(
        (d) =>
            d['device_key']?.toString() == _connectedDevice!.id ||
            d['device_id']?.toString() == _connectedDevice!.id,
        orElse: () => {},
      );

      if (targetDev.isNotEmpty) {
        final isPlaying = targetDev['is_playing'] == 1 || targetDev['is_playing'] == true;
        final positionSec = (targetDev['position'] as num?)?.toInt() ?? 0;
        final durationSec = (targetDev['duration'] as num?)?.toInt() ?? 0;

        Song? song;
        if (targetDev['song_id'] != null && targetDev['title'] != null) {
          song = Song(
            id: targetDev['song_id'].toString(),
            title: targetDev['title'].toString(),
            artist: targetDev['artist']?.toString() ?? '',
            album: targetDev['album']?.toString(),
            coverArt: targetDev['cover_art']?.toString(),
            duration: durationSec,
            isLocal: false,
          );
        }

        _connectedDevice = _connectedDevice!.copyWith(
          currentSong: song ?? _connectedDevice!.currentSong,
          isPlaying: isPlaying,
          lastSeen: DateTime.now(),
        );
        notifyListeners();

        onRemoteStatusUpdated?.call(
          song: song,
          position: Duration(seconds: positionSec),
          duration: Duration(seconds: durationSec),
          isPlaying: isPlaying,
          volume: 1.0,
        );
      }
    } catch (_) {
      // Ignore intermittent network drop
    }
  }

  /// Disconnects from the remote device.
  void disconnect() {
    _statusSyncTimer?.cancel();
    _connectedDevice = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _statusSyncTimer?.cancel();
    _commandPollTimer?.cancel();
    _pruneTimer?.cancel();
    _discoveryTimer?.cancel();
    super.dispose();
  }
}
