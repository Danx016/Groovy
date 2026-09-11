import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/song.dart';
import 'device_info_service.dart';
import 'groovy_api_service.dart';
import 'storage_service.dart';

/// Represents a remote Groovy instance available on the local network (LAN) or cloud.
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
  final double? volume;
  final DateTime lastSeen;

  GroovyRemoteDevice({
    required this.id,
    required this.name,
    required this.platform,
    required this.model,
    this.host = '',
    this.port = 42425,
    this.isLocalLan = false,
    this.currentSong,
    this.isPlaying = false,
    this.volume = 1.0,
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
    double? volume,
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
      volume: volume ?? this.volume,
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
    'volume': volume,
    'song': currentSong?.toJson(),
  };

  factory GroovyRemoteDevice.fromJson(Map<String, dynamic> json, {String? host, int? port}) {
    final resolvedHost = host ?? json['host']?.toString() ?? json['ip_address']?.toString() ?? '';
    final isLan = host != null && host.isNotEmpty;

    return GroovyRemoteDevice(
      id: json['device_key']?.toString() ?? json['device_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['device_name']?.toString() ?? json['name']?.toString() ?? 'Groovy Device',
      platform: json['platform']?.toString() ?? 'Dispositivo',
      model: json['device_model']?.toString() ?? json['model']?.toString() ?? '',
      host: resolvedHost,
      port: port ?? (json['port'] is int ? json['port'] : int.tryParse(json['port']?.toString() ?? '42425') ?? 42425),
      isLocalLan: isLan,
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

/// Hybrid P2P LAN + Cloud Groovy Connect Service.
/// Coordinates cross-device discovery, real-time synchronization, and remote playback
/// controls across Windows, Android, Mac, Linux, and Web anywhere (local Wi-Fi or over internet).
class GroovyConnectService extends ChangeNotifier {
  static final GroovyConnectService _instance = GroovyConnectService._internal();
  factory GroovyConnectService() => _instance;
  GroovyConnectService._internal();

  static const int _defaultUdpPort = 42424;
  static const int _defaultHttpPort = 42425;

  HttpServer? _httpServer;
  RawDatagramSocket? _udpSocket;
  int _actualHttpPort = _defaultHttpPort;

  String _localDeviceId = '';
  String _localDeviceName = '';
  String _localPlatform = '';
  String _localModel = '';
  String _localIp = '';
  String? _cachedAuthToken;

  final Map<String, GroovyRemoteDevice> _discoveredDevices = {};
  GroovyRemoteDevice? _connectedDevice;
  bool _isDiscovering = false;
  Timer? _discoveryTimer;
  Timer? _pruneTimer;
  Timer? _commandPollTimer;
  Timer? _statusSyncTimer;
  Timer? _presenceHeartbeatTimer;
  bool _isPollingCommands = false;
  bool _isSyncingStatus = false;

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
  String get localIp => _localIp;
  int get httpPort => _actualHttpPort;
  String? get cachedAuthToken => _cachedAuthToken;

  Future<void> _detectLocalIp() async {
    if (kIsWeb) return;
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        if (name.contains('wlan') || name.contains('wi-fi') || name.contains('eth') || name.contains('ethernet') || name.contains('en')) {
          for (final addr in iface.addresses) {
            if (!addr.isLoopback && !addr.address.startsWith('127.')) {
              _localIp = addr.address;
              return;
            }
          }
        }
      }
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('127.')) {
            _localIp = addr.address;
            return;
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _probeAndUpgradeLanDevice(String remoteDeviceId, String host, int port) async {
    if (kIsWeb || host.isEmpty || host == '127.0.0.1' || host == _localIp) return;
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(milliseconds: 350);
      final uri = Uri.parse('http://$host:$port/groovy/info');
      final request = await client.getUrl(uri).timeout(const Duration(milliseconds: 350));
      final response = await request.close().timeout(const Duration(milliseconds: 350));
      if (response.statusCode == HttpStatus.ok) {
        final existing = _discoveredDevices[remoteDeviceId];
        if (existing != null) {
          final upgraded = existing.copyWith(
            host: host,
            port: port,
            isLocalLan: true,
          );
          _discoveredDevices[remoteDeviceId] = upgraded;
          if (_connectedDevice?.id == remoteDeviceId) {
            _connectedDevice = upgraded;
          }
          notifyListeners();
        }
      }
    } catch (_) {
    } finally {
      client?.close(force: true);
    }
  }

  /// Initializes the service: local LAN P2P UDP + HTTP server, and cloud relay polling.
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

      final storedToken = await StorageService().getUserToken();
      if (storedToken != null && storedToken.isNotEmpty) {
        _cachedAuthToken = storedToken;
      }

      await _detectLocalIp();

      // 1. Start local network P2P services (Wi-Fi discovery without internet dependency)
      if (!kIsWeb) {
        await _startHttpServer();
        await _startUdpListener();
      }

      // 2. Start background cloud command polling loop
      _startCommandPollLoop();

      // 3. Start cloud presence heartbeat (every 2s)
      _startPresenceHeartbeat();

      // 4. Prune devices not seen in > 45 seconds
      _pruneTimer?.cancel();
      _pruneTimer = Timer.periodic(const Duration(seconds: 12), (_) => _pruneStaleDevices());

      debugPrint('[GroovyConnect] Hybrid P2P LAN + Cloud initialized for device: $_localDeviceId ($_localDeviceName) IP: $_localIp on HTTP: $_actualHttpPort');
    } catch (e) {
      debugPrint('[GroovyConnect] Init error: $e');
    }
  }

  /// Starts the embedded HTTP server for local LAN transfer and remote control.
  Future<void> _startHttpServer() async {
    if (kIsWeb) return;
    try {
      try {
        _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, _defaultHttpPort);
      } catch (_) {
        // Fallback to ephemeral port if 42425 is already bound
        _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      }
      _actualHttpPort = _httpServer!.port;

      _httpServer!.listen(_handleHttpRequest, onError: (e) {
        debugPrint('[GroovyConnect] HTTP server error: $e');
      });
    } catch (e) {
      debugPrint('[GroovyConnect] Could not bind HTTP server: $e');
    }
  }

  Future<void> _handleHttpRequest(HttpRequest req) async {
    req.response.headers.add('Access-Control-Allow-Origin', '*');
    req.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    req.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method == 'OPTIONS') {
      req.response.statusCode = HttpStatus.ok;
      await req.response.close();
      return;
    }

    final path = req.uri.path;
    try {
      if (path == '/groovy/info' || path == '/groovy/status') {
        final status = onProvidePlayerStatus?.call() ?? {};
        final payload = {
          'id': _localDeviceId,
          'name': _localDeviceName,
          'platform': _localPlatform,
          'model': _localModel,
          'port': _actualHttpPort,
          ...status,
        };
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode(payload));
        await req.response.close();
        return;
      }

      if (path == '/groovy/transfer' && req.method == 'POST') {
        final bodyStr = await utf8.decodeStream(req);
        final data = jsonDecode(bodyStr) as Map<String, dynamic>;

        final songData = data['song'] as Map<String, dynamic>?;
        final positionMs = (data['positionMs'] as num?)?.toInt() ?? 0;
        final isPlaying = data['isPlaying'] as bool? ?? true;
        final fromDevice = data['fromDevice']?.toString() ?? 'Dispositivo Groovy';

        if (songData != null && onTransferReceived != null) {
          var song = Song.fromJson(songData);
          if (song.isLocal && (song.path == null || !File(song.path!).existsSync())) {
            song = song.copyWith(isLocal: false);
          }

          List<Song>? queue;
          final queueData = data['queue'] as List<dynamic>?;
          if (queueData != null) {
            queue = queueData.map((s) {
              var qs = Song.fromJson(s as Map<String, dynamic>);
              if (qs.isLocal && (qs.path == null || !File(qs.path!).existsSync())) {
                qs = qs.copyWith(isLocal: false);
              }
              return qs;
            }).toList();
          }
          final queueIndex = (data['queueIndex'] as num?)?.toInt();

          await onTransferReceived!(song, positionMs, isPlaying, fromDevice, queue, queueIndex);
          req.response.headers.contentType = ContentType.json;
          req.response.write(jsonEncode({'success': true, 'message': 'Playback transferred'}));
          await req.response.close();
          return;
        }
      }

      if (path == '/groovy/control' && req.method == 'POST') {
        final bodyStr = await utf8.decodeStream(req);
        final data = jsonDecode(bodyStr) as Map<String, dynamic>;
        final action = data['action']?.toString() ?? '';
        final value = data['value'];

        if (onCommandReceived != null && action.isNotEmpty) {
          onCommandReceived!(action, value);
          req.response.headers.contentType = ContentType.json;
          req.response.write(jsonEncode({'success': true}));
          await req.response.close();
          return;
        }
      }

      req.response.statusCode = HttpStatus.notFound;
      req.response.write('Not found');
      await req.response.close();
    } catch (e) {
      debugPrint('[GroovyConnect] HTTP handle error: $e');
      try {
        req.response.statusCode = HttpStatus.internalServerError;
        req.response.write(jsonEncode({'error': e.toString()}));
        await req.response.close();
      } catch (_) {}
    }
  }

  /// Starts UDP socket to receive LAN discovery broadcasts on the local Wi-Fi.
  Future<void> _startUdpListener() async {
    if (kIsWeb) return;
    try {
      _udpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _defaultUdpPort,
        reuseAddress: true,
        reusePort: !Platform.isWindows,
      );
      _udpSocket!.broadcastEnabled = true;

      _udpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = _udpSocket!.receive();
          if (dg != null) {
            _handleUdpPacket(dg);
          }
        }
      });
      debugPrint('[GroovyConnect] UDP discovery socket bound on port $_defaultUdpPort');
    } catch (e) {
      debugPrint('[GroovyConnect] UDP bind warning: $e');
    }
  }

  void _handleUdpPacket(Datagram dg) {
    try {
      final msg = utf8.decode(dg.data);
      final json = jsonDecode(msg) as Map<String, dynamic>;
      final type = json['type'] as String?;
      final senderId = json['id'] as String?;

      if (senderId == _localDeviceId) return; // Ignore self

      final senderHost = dg.address.address;
      final senderPort = (json['port'] as num?)?.toInt() ?? _defaultHttpPort;

      if (type == 'GROOVY_DISCOVER') {
        // Send back an announcement packet directly to the sender
        final status = onProvidePlayerStatus?.call() ?? {};
        final reply = jsonEncode({
          'type': 'GROOVY_ANNOUNCE',
          'id': _localDeviceId,
          'name': _localDeviceName,
          'platform': _localPlatform,
          'model': _localModel,
          'port': _actualHttpPort,
          'isPlaying': status['isPlaying'] ?? false,
          'song': status['song'],
        });
        _udpSocket?.send(utf8.encode(reply), dg.address, dg.port);
      }

      if (type == 'GROOVY_ANNOUNCE' || type == 'GROOVY_DISCOVER') {
        final device = GroovyRemoteDevice.fromJson(json, host: senderHost, port: senderPort);
        _discoveredDevices[device.id] = device;
        notifyListeners();
      }
    } catch (_) {
      // Ignore malformed UDP packets
    }
  }

  /// Sends periodic presence heartbeat to cloud backend.
  void _startPresenceHeartbeat() {
    _presenceHeartbeatTimer?.cancel();
    _presenceHeartbeatTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _sendPresencePing();
    });
    // Send immediate ping
    _sendPresencePing();
  }

  Future<void> _sendPresencePing() async {
    try {
      final status = onProvidePlayerStatus?.call() ?? {};
      final songMap = status['song'] as Map<String, dynamic>?;
      Song? song;
      if (songMap != null) {
        try {
          song = Song.fromJson(songMap);
        } catch (_) {}
      }

      final posMs = (status['positionMs'] as num?)?.toInt() ?? 0;
      final vol = (status['volume'] as num?)?.toDouble();

      await GroovyApiService().reportPlaybackState(
        token: _cachedAuthToken ?? '',
        song: song ?? Song(id: '', title: ''),
        isPlaying: status['isPlaying'] == true,
        position: posMs ~/ 1000,
        positionMs: posMs,
        listenDeltaSeconds: 0,
        deviceId: _localDeviceId,
        volume: vol,
        localIp: _localIp,
        localPort: _actualHttpPort,
      );
    } catch (_) {}
  }

  /// Updates cached auth token to fetch user-specific devices and receive private commands.
  void updateAuthToken(String? token) {
    _cachedAuthToken = token;
    if (token != null && token.isNotEmpty) {
      discover(authToken: token);
    }
  }

  bool _isListeningCloudCommands = false;

  /// Starts the cloud command long-poll loop to receive actions from other devices in real-time over the server.
  void _startCommandPollLoop() {
    _commandPollTimer?.cancel();
    _isListeningCloudCommands = true;
    unawaited(_runCloudCommandLoop());
  }

  Future<void> _runCloudCommandLoop() async {
    while (_isListeningCloudCommands) {
      if (_localDeviceId.isNotEmpty) {
        await _pollCloudCommands();
      }
      if (!_isListeningCloudCommands) break;
      await Future.delayed(const Duration(milliseconds: 60));
    }
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
        try {
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

              // Run asynchronously without blocking the command polling loop
              unawaited(
                onTransferReceived!(song, positionMs, isPlaying, fromDevice, queue, queueIndex)
                    .catchError((e) {
                  debugPrint('[GroovyConnect] Error executing onTransferReceived: $e');
                }),
              );
            }
          } else if (action == 'control' || action == 'play' || action == 'pause' || action == 'skipNext' || action == 'skipPrevious' || action == 'seek' || action == 'volume' || action == 'togglePlayPause') {
            String controlAction = action;
            dynamic controlValue;
            if (payload is Map) {
              controlAction = payload['action']?.toString() ?? action;
              controlValue = payload['value'];
            } else if (payload is num) {
              controlValue = payload;
            }
            if (onCommandReceived != null && controlAction.isNotEmpty) {
              try {
                onCommandReceived!(controlAction, controlValue);
              } catch (e) {
                debugPrint('[GroovyConnect] Error executing onCommandReceived: $e');
              }
            }
          }
        } catch (cmdError) {
          debugPrint('[GroovyConnect] Error processing command: $cmdError');
        }
      }
    } catch (e) {
      // Ignore intermittent poll drops
    } finally {
      _isPollingCommands = false;
    }
  }

  /// Discovers other Groovy devices via local Wi-Fi UDP broadcast and Cloud API.
  Future<void> discover({String? authToken}) async {
    if (authToken != null) _cachedAuthToken = authToken;
    _isDiscovering = true;
    notifyListeners();

    // 1. Send UDP broadcast to local Wi-Fi network (P2P zero-latency discovery)
    if (!kIsWeb && _udpSocket != null) {
      try {
        final status = onProvidePlayerStatus?.call() ?? {};
        final discoverPacket = jsonEncode({
          'type': 'GROOVY_DISCOVER',
          'id': _localDeviceId,
          'name': _localDeviceName,
          'platform': _localPlatform,
          'model': _localModel,
          'port': _actualHttpPort,
          'isPlaying': status['isPlaying'] ?? false,
          'song': status['song'],
        });
        final bytes = utf8.encode(discoverPacket);

        // Broadcast to 255.255.255.255
        _udpSocket?.send(bytes, InternetAddress('255.255.255.255'), _defaultUdpPort);

        try {
          _udpSocket?.send(bytes, InternetAddress('239.255.255.250'), _defaultUdpPort);
        } catch (_) {}
      } catch (e) {
        debugPrint('[GroovyConnect] UDP discovery broadcast error: $e');
      }
    }

    // 2. Query Cloud API relay (for remote / 4G / outside network devices)
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

        // Do not discover self by ID
        if (remoteDeviceId == _localDeviceId) continue;

        final remoteDeviceName = item['device_name']?.toString() ?? item['device_model']?.toString() ?? 'Groovy Device';
        final remoteDevicePlatform = item['platform']?.toString() ?? 'Dispositivo';

        // Do not discover self by matching name & platform
        if (remoteDeviceName.trim().toLowerCase() == _localDeviceName.trim().toLowerCase() &&
            remoteDevicePlatform.trim().toLowerCase() == _localPlatform.trim().toLowerCase()) {
          continue;
        }

        // If we are currently connected to a device with the same name and platform,
        // ignore duplicate ghost entries that have a different deviceId
        if (_connectedDevice != null &&
            _connectedDevice!.id != remoteDeviceId &&
            _connectedDevice!.name.trim().toLowerCase() == remoteDeviceName.trim().toLowerCase() &&
            _connectedDevice!.platform.trim().toLowerCase() == remoteDevicePlatform.trim().toLowerCase()) {
          continue;
        }

        // Clean up any stale duplicate device entry with the same physical name and platform
        _discoveredDevices.removeWhere((id, dev) {
          if (id == remoteDeviceId) return false;
          if (_connectedDevice?.id == id) return false;
          return dev.name.trim().toLowerCase() == remoteDeviceName.trim().toLowerCase() &&
              dev.platform.trim().toLowerCase() == remoteDevicePlatform.trim().toLowerCase();
        });

        final isPlaying = item['is_playing'] == 1 || item['is_playing'] == true;

        Song? song;
        if (item['song_id'] != null && item['title'] != null && item['title'].toString().isNotEmpty) {
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

        final localIpCandidate = item['local_ip']?.toString() ?? item['localIp']?.toString() ?? item['ip_address']?.toString() ?? '';
        final localPortCandidate = (item['local_port'] as num?)?.toInt() ?? (item['localPort'] as num?)?.toInt() ?? (item['port'] as num?)?.toInt() ?? 42425;

        final existing = _discoveredDevices[remoteDeviceId];
        if (existing == null) {
          _discoveredDevices[remoteDeviceId] = GroovyRemoteDevice(
            id: remoteDeviceId,
            name: remoteDeviceName,
            platform: remoteDevicePlatform,
            model: item['device_model']?.toString() ?? '',
            host: localIpCandidate,
            port: localPortCandidate,
            isLocalLan: false,
            isPlaying: isPlaying,
            currentSong: song,
            lastSeen: DateTime.now(),
          );
        } else {
          _discoveredDevices[remoteDeviceId] = existing.copyWith(
            name: remoteDeviceName,
            platform: remoteDevicePlatform,
            isPlaying: isPlaying,
            currentSong: song,
            lastSeen: DateTime.now(),
          );
        }

        if (localIpCandidate.isNotEmpty && !kIsWeb) {
          _probeAndUpgradeLanDevice(remoteDeviceId, localIpCandidate, localPortCandidate);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[GroovyConnect] fetchCloudDevices error: $e');
    }
  }

  /// Removes devices that haven't sent a ping in over 60 seconds.
  /// Never prunes the active connected device while connected.
  void _pruneStaleDevices() {
    final now = DateTime.now();
    _discoveredDevices.removeWhere((id, dev) {
      if (_connectedDevice?.id == id) {
        // Never disconnect the active device unless completely silent for > 120s
        final isConnectedStale = now.difference(_connectedDevice!.lastSeen).inSeconds > 120;
        if (isConnectedStale) {
          _connectedDevice = null;
          _statusSyncTimer?.cancel();
          return true;
        }
        return false;
      }
      return now.difference(dev.lastSeen).inSeconds > 60;
    });
    notifyListeners();
  }

  /// Transfers current playback to a remote device over local Wi-Fi or Cloud.
  Future<bool> transferPlayback({
    required GroovyRemoteDevice device,
    required Song song,
    required Duration position,
    required bool isPlaying,
    List<Song>? queue,
    int? queueIndex,
  }) async {
    // Sanitize and trim queue to a reasonable window (current + 25 upcoming songs)
    // to keep the JSON payload lightweight (< 10KB) and prevent transfer timeouts
    List<Map<String, dynamic>>? conciseQueue;
    int? effectiveQueueIndex = queueIndex;
    if (queue != null && queue.isNotEmpty) {
      final qIndex = queueIndex ?? queue.indexWhere((s) => s.id == song.id);
      final startIndex = qIndex > 0 ? (qIndex - 2).clamp(0, queue.length - 1) : 0;
      final endIndex = (startIndex + 25).clamp(0, queue.length);
      final sub = queue.sublist(startIndex, endIndex);
      conciseQueue = sub.map((s) => s.toJson()).toList();
      effectiveQueueIndex = (qIndex - startIndex).clamp(0, sub.length - 1);
    }

    // Optimistically update connected device immediately for 0ms UI lag on controller
    final now = DateTime.now();
    final updated = device.copyWith(
      currentSong: song,
      isPlaying: isPlaying,
      lastSeen: now,
    );
    _connectedDevice = updated;
    _discoveredDevices[device.id] = updated;
    _startStatusSyncTimer();
    notifyListeners();

    // 1. If device is available on local LAN, send directly over HTTP for instant transfer
    if (device.isLocalLan && device.host.isNotEmpty) {
      unawaited(_sendLanTransfer(
        device.host,
        device.port,
        song,
        position.inMilliseconds,
        isPlaying,
        conciseQueue,
        effectiveQueueIndex,
      ));
    }

    // 2. Route playback transfer through Groovy Cloud Server asynchronously
    try {
      debugPrint('[GroovyConnect] Sending transfer to server for device ${device.name} (${device.id})');
      final success = await GroovyApiService().sendDeviceCommand(
        targetDeviceId: device.id,
        senderDeviceId: _localDeviceId,
        action: 'transfer',
        payload: {
          'song': song.copyWith(isLocal: false).toJson(),
          'positionMs': position.inMilliseconds,
          'isPlaying': isPlaying,
          'fromDevice': _localDeviceName,
          'queue': conciseQueue,
          'queueIndex': effectiveQueueIndex,
        },
        token: _cachedAuthToken,
      );

      if (success) {
        debugPrint('[GroovyConnect] Successfully transferred playback to ${device.name} via cloud server');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[GroovyConnect] Server transfer error: $e');
      return false;
    }
  }

  Future<bool> _sendLanTransfer(
    String host,
    int port,
    Song song,
    int positionMs,
    bool isPlaying,
    List<Map<String, dynamic>>? queue,
    int? queueIndex,
  ) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(milliseconds: 1000);
      final uri = Uri.parse('http://$host:$port/groovy/transfer');
      final request = await client.postUrl(uri).timeout(const Duration(milliseconds: 1000));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'song': song.copyWith(isLocal: false).toJson(),
        'positionMs': positionMs,
        'isPlaying': isPlaying,
        'fromDevice': _localDeviceName,
        'queue': queue,
        'queueIndex': queueIndex,
      }));
      final response = await request.close().timeout(const Duration(milliseconds: 1000));
      return response.statusCode == HttpStatus.ok;
    } catch (_) {
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  /// Connects to a target Groovy device without immediately transferring a song.
  Future<bool> connectToDevice(GroovyRemoteDevice device) async {
    _connectedDevice = device;
    _startStatusSyncTimer();
    notifyListeners();
    // Query remote device status immediately to ensure current track is visible
    _syncRemoteStatus();
    return true;
  }

  Future<bool> _sendLanControl(String host, int port, String action, dynamic value) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(milliseconds: 600);
      final uri = Uri.parse('http://$host:$port/groovy/control');
      final request = await client.postUrl(uri).timeout(const Duration(milliseconds: 600));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'action': action, 'value': value}));
      final response = await request.close().timeout(const Duration(milliseconds: 600));
      return response.statusCode == HttpStatus.ok;
    } catch (_) {
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  Future<Map<String, dynamic>?> _fetchLanStatus(String host, int port) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(milliseconds: 500);
      final uri = Uri.parse('http://$host:$port/groovy/status');
      final request = await client.getUrl(uri).timeout(const Duration(milliseconds: 500));
      final response = await request.close().timeout(const Duration(milliseconds: 500));
      if (response.statusCode == HttpStatus.ok) {
        final body = await utf8.decodeStream(response);
        return jsonDecode(body) as Map<String, dynamic>;
      }
    } catch (_) {
      return null;
    } finally {
      client?.close(force: true);
    }
    return null;
  }

  /// Sends remote playback commands (play, pause, togglePlayPause, skipNext, skipPrevious, seek, volume) via LAN or Cloud Server.
  Future<bool> sendControl(String action, [dynamic value]) async {
    if (_connectedDevice == null) return false;

    // Optimistically update connected device local state immediately (0ms UI latency)
    if (action == 'play') {
      _connectedDevice = _connectedDevice?.copyWith(isPlaying: true);
      notifyListeners();
    } else if (action == 'pause') {
      _connectedDevice = _connectedDevice?.copyWith(isPlaying: false);
      notifyListeners();
    } else if (action == 'volume' && value is num) {
      _connectedDevice = _connectedDevice?.copyWith(volume: value.toDouble().clamp(0.0, 1.0));
      notifyListeners();
    }

    // 1. If connected device is on local LAN, send immediately over HTTP for sub-5ms instantaneous response
    if (_connectedDevice!.isLocalLan && _connectedDevice!.host.isNotEmpty) {
      unawaited(_sendLanControl(_connectedDevice!.host, _connectedDevice!.port, action, value));
    }

    // 2. Route control command through the Groovy Cloud Relay Server asynchronously
    try {
      final success = await GroovyApiService().sendDeviceCommand(
        targetDeviceId: _connectedDevice!.id,
        senderDeviceId: _localDeviceId,
        action: action,
        payload: {
          'action': action,
          'value': value,
        },
        token: _cachedAuthToken,
      );

      if (success) {
        if (action != 'volume') {
          _syncRemoteStatus();
        }
      }
      return success;
    } catch (e) {
      debugPrint('[GroovyConnect] Cloud sendControl error: $e');
      return false;
    }
  }

  /// Sends a song to play on the connected device via LAN or cloud.
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
    final interval = (_connectedDevice?.isLocalLan == true)
        ? const Duration(milliseconds: 250)
        : const Duration(milliseconds: 450);
    _statusSyncTimer = Timer.periodic(interval, (_) {
      _syncRemoteStatus();
    });
  }

  /// Synchronizes playback status with remote device via LAN or cloud server telemetry in real-time.
  Future<void> _syncRemoteStatus() async {
    if (_connectedDevice == null) {
      _statusSyncTimer?.cancel();
      return;
    }
    if (_isSyncingStatus) return;
    _isSyncingStatus = true;

    try {
      // Prioritize high-frequency LAN status if target device is on local Wi-Fi
      if (_connectedDevice!.isLocalLan && _connectedDevice!.host.isNotEmpty) {
        final lanData = await _fetchLanStatus(_connectedDevice!.host, _connectedDevice!.port);
        if (lanData != null) {
          final isPlaying = lanData['isPlaying'] == true || lanData['isPlaying'] == 1;
          final positionMs = (lanData['positionMs'] as num?)?.toInt() ?? 0;
          final durationMs = (lanData['durationMs'] as num?)?.toInt() ?? 0;
          final durationSec = durationMs ~/ 1000;

          Song? song;
          final songData = lanData['song'] as Map<String, dynamic>?;
          if (songData != null && songData['id'] != null) {
            try {
              song = Song.fromJson(songData);
            } catch (_) {}
          }

          final now = DateTime.now();
          final remoteVol = (lanData['volume'] as num?)?.toDouble() ?? _connectedDevice?.volume ?? 1.0;
          final updated = _connectedDevice!.copyWith(
            currentSong: song ?? _connectedDevice!.currentSong,
            isPlaying: isPlaying,
            volume: remoteVol,
            lastSeen: now,
          );
          _connectedDevice = updated;
          _discoveredDevices[updated.id] = updated;
          notifyListeners();

          onRemoteStatusUpdated?.call(
            song: song,
            position: Duration(milliseconds: positionMs),
            duration: Duration(seconds: durationSec),
            isPlaying: isPlaying,
            volume: remoteVol,
          );
          return;
        }
      }

      if (_cachedAuthToken != null && _cachedAuthToken!.isNotEmpty) {
        try {
          final devicesList = await GroovyApiService().fetchUserDevices(token: _cachedAuthToken);
          final targetDev = devicesList.firstWhere(
            (d) =>
                d['device_key']?.toString() == _connectedDevice!.id ||
                d['device_id']?.toString() == _connectedDevice!.id,
            orElse: () => devicesList.firstWhere(
              (d) =>
                  d['platform']?.toString().trim().toLowerCase() == _connectedDevice!.platform.trim().toLowerCase() &&
                  (d['device_name']?.toString().trim().toLowerCase() == _connectedDevice!.name.trim().toLowerCase() ||
                   d['device_model']?.toString().trim().toLowerCase() == _connectedDevice!.name.trim().toLowerCase()),
              orElse: () => {},
            ),
          );

          if (targetDev.isNotEmpty) {
            final isPlaying = targetDev['is_playing'] == 1 || targetDev['is_playing'] == true;
            final positionSec = (targetDev['position'] as num?)?.toInt() ?? 0;
            final positionMs = (targetDev['positionMs'] as num?)?.toInt() ?? (positionSec * 1000);
            final durationSec = (targetDev['duration'] as num?)?.toInt() ?? 0;

            Song? song;
            if (targetDev['song_id'] != null && targetDev['title'] != null && targetDev['title'].toString().isNotEmpty) {
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

            final now = DateTime.now();
            final remoteVol = (targetDev['volume'] as num?)?.toDouble() ?? _connectedDevice?.volume ?? 1.0;
            final updated = _connectedDevice!.copyWith(
              currentSong: song ?? _connectedDevice!.currentSong,
              isPlaying: isPlaying,
              volume: remoteVol,
              lastSeen: now,
            );
            _connectedDevice = updated;
            _discoveredDevices[updated.id] = updated;
            notifyListeners();

            onRemoteStatusUpdated?.call(
              song: song,
              position: Duration(milliseconds: positionMs),
              duration: Duration(seconds: durationSec),
              isPlaying: isPlaying,
              volume: remoteVol,
            );
          }
        } catch (_) {
          // Ignore intermittent network drop
        }
      }
    } finally {
      _isSyncingStatus = false;
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
    _isListeningCloudCommands = false;
    _statusSyncTimer?.cancel();
    _commandPollTimer?.cancel();
    _presenceHeartbeatTimer?.cancel();
    _pruneTimer?.cancel();
    _discoveryTimer?.cancel();
    _httpServer?.close(force: true);
    _udpSocket?.close();
    super.dispose();
  }
}
