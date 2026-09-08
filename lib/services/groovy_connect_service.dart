import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import 'device_info_service.dart';
import 'groovy_api_service.dart';

/// Represents a remote Groovy instance available on the local network or cloud.
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
    required this.host,
    required this.port,
    this.isLocalLan = true,
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
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Groovy Device',
      platform: json['platform']?.toString() ?? 'Dispositivo',
      model: json['model']?.toString() ?? '',
      host: host ?? json['host']?.toString() ?? '127.0.0.1',
      port: port ?? (json['port'] is int ? json['port'] : int.tryParse(json['port']?.toString() ?? '42425') ?? 42425),
      isLocalLan: json['isLocalLan'] as bool? ?? true,
      isPlaying: json['isPlaying'] as bool? ?? false,
      currentSong: json['song'] != null ? Song.fromJson(json['song'] as Map<String, dynamic>) : null,
      lastSeen: DateTime.now(),
    );
  }
}

/// Service that coordinates device-to-device discovery, real-time synchronization,
/// and remote playback controls across Windows, Android, Mac, and Linux via Wi-Fi LAN P2P.
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

  final Map<String, GroovyRemoteDevice> _discoveredDevices = {};
  GroovyRemoteDevice? _connectedDevice;
  bool _isDiscovering = false;
  Timer? _discoveryTimer;
  Timer? _pruneTimer;
  Timer? _statusSyncTimer;

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
  int get httpPort => _actualHttpPort;

  /// Initializes the local server and UDP listener on app startup.
  Future<void> initialize() async {
    if (kIsWeb) return;

    try {
      final info = await DeviceInfoService().getDeviceInfo();
      _localPlatform = info.platform;
      _localModel = info.deviceModel;
      _localDeviceName = info.deviceModel;
      _localDeviceId = '${info.platform}_${info.deviceModel.hashCode.abs()}';

      await _startHttpServer();
      await _startUdpListener();

      _pruneTimer?.cancel();
      _pruneTimer = Timer.periodic(const Duration(seconds: 12), (_) => _pruneStaleDevices());

      debugPrint('[GroovyConnect] Service initialized on HTTP: $_actualHttpPort, Device: $_localDeviceName');
    } catch (e) {
      debugPrint('[GroovyConnect] Init error: $e');
    }
  }

  /// Starts the embedded HTTP server to handle incoming transfer, info, and control requests.
  Future<void> _startHttpServer() async {
    try {
      try {
        _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, _defaultHttpPort);
      } catch (_) {
        // Fallback to ephemeral port if 42425 is in use
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

          // If local file path doesn't exist on this receiving device, fall back to online streaming
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

  /// Starts UDP socket to receive LAN discovery broadcasts.
  Future<void> _startUdpListener() async {
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
        final reply = jsonEncode({
          'type': 'GROOVY_ANNOUNCE',
          'id': _localDeviceId,
          'name': _localDeviceName,
          'platform': _localPlatform,
          'model': _localModel,
          'port': _actualHttpPort,
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

  /// Triggers a network discovery scan for other Groovy devices (Subnet scan + LAN UDP + Cloud Heartbeat).
  Future<void> discover({String? authToken}) async {
    if (kIsWeb) return;
    _isDiscovering = true;
    notifyListeners();

    // 1. UDP Broadcast discovery (fastest when not blocked by router)
    try {
      if (_udpSocket != null) {
        final discoverPacket = jsonEncode({
          'type': 'GROOVY_DISCOVER',
          'id': _localDeviceId,
          'name': _localDeviceName,
          'platform': _localPlatform,
          'model': _localModel,
          'port': _actualHttpPort,
        });
        final bytes = utf8.encode(discoverPacket);

        // Broadcast to 255.255.255.255
        _udpSocket?.send(bytes, InternetAddress('255.255.255.255'), _defaultUdpPort);

        try {
          _udpSocket?.send(bytes, InternetAddress('239.255.255.250'), _defaultUdpPort);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[GroovyConnect] Discovery broadcast error: $e');
    }

    // 2. Active Subnet Scan (works even when routers block UDP broadcast / on Android)
    _scanSubnetForDevices().catchError((e) {
      debugPrint('[GroovyConnect] Subnet scan note: $e');
    });

    // 3. Cloud telemetry discovery
    try {
      await _fetchCloudDevices(authToken);
    } catch (e) {
      debugPrint('[GroovyConnect] Cloud discovery note: $e');
    }

    _discoveryTimer?.cancel();
    _discoveryTimer = Timer(const Duration(seconds: 4), () {
      _isDiscovering = false;
      notifyListeners();
    });
  }

  /// Scans local Wi-Fi subnet via direct HTTP unicast to bypass router UDP broadcast filtering.
  Future<void> _scanSubnetForDevices() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      final List<String> candidateSubnets = [];
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.')) {
            final parts = ip.split('.');
            if (parts.length == 4) {
              candidateSubnets.add('${parts[0]}.${parts[1]}.${parts[2]}');
            }
          }
        }
      }

      for (final subnet in candidateSubnets.toSet()) {
        final ips = List.generate(254, (i) => '$subnet.${i + 1}');
        for (int i = 0; i < ips.length; i += 32) {
          final chunk = ips.sublist(i, (i + 32).clamp(0, ips.length));
          await Future.wait(chunk.map((targetIp) async {
            try {
              final uri = Uri.parse('http://$targetIp:$_defaultHttpPort/groovy/info');
              final res = await http.get(uri).timeout(const Duration(milliseconds: 650));
              if (res.statusCode == 200) {
                final json = jsonDecode(res.body) as Map<String, dynamic>;
                final senderId = json['id'] as String?;
                if (senderId != null && senderId != _localDeviceId) {
                  final dev = GroovyRemoteDevice.fromJson(json, host: targetIp, port: _defaultHttpPort);
                  _discoveredDevices[dev.id] = dev;
                  notifyListeners();
                }
              }
            } catch (_) {}
          }));
        }
      }
    } catch (e) {
      debugPrint('[GroovyConnect] Subnet scan error: $e');
    }
  }

  /// Fetches active devices from Groovy Cloud backend telemetry.
  Future<void> _fetchCloudDevices(String? token) async {
    try {
      final baseUrl = GroovyApiService().baseUrl;
      final uri = Uri.parse('$baseUrl/telemetry/playback');
      final res = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data is Map && data['devices'] is List) ? data['devices'] as List : [];
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final devName = item['device_name']?.toString() ?? item['device_model']?.toString() ?? 'Groovy Device';
            final devPlatform = item['platform']?.toString() ?? 'Dispositivo';
            final devId = 'cloud_${item['user_id'] ?? item['ip_address']}_$devPlatform';

            if (devId != _localDeviceId && devName != _localDeviceName) {
              _discoveredDevices[devId] = GroovyRemoteDevice(
                id: devId,
                name: devName,
                platform: devPlatform,
                model: item['device_model']?.toString() ?? '',
                host: item['ip_address']?.toString() ?? '127.0.0.1',
                port: _defaultHttpPort,
                isLocalLan: false,
                isPlaying: item['is_playing'] == 1 || item['is_playing'] == true,
                lastSeen: DateTime.now(),
              );
            }
          }
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Removes devices that haven't responded in over 35 seconds.
  void _pruneStaleDevices() {
    final now = DateTime.now();
    _discoveredDevices.removeWhere((id, dev) {
      final isStale = now.difference(dev.lastSeen).inSeconds > 35;
      if (isStale && _connectedDevice?.id == id) {
        _connectedDevice = null;
        _statusSyncTimer?.cancel();
      }
      return isStale;
    });
    notifyListeners();
  }

  /// Transfers current playback to a target Groovy device and starts real-time synchronization.
  Future<bool> transferPlayback({
    required GroovyRemoteDevice device,
    required Song song,
    required Duration position,
    required bool isPlaying,
    List<Song>? queue,
    int? queueIndex,
  }) async {
    try {
      debugPrint('[GroovyConnect] Transferring to ${device.name} at ${device.host}:${device.port}');
      final uri = Uri.parse('http://${device.host}:${device.port}/groovy/transfer');

      final body = jsonEncode({
        'song': song.toJson(),
        'positionMs': position.inMilliseconds,
        'isPlaying': isPlaying,
        'fromDevice': _localDeviceName,
        'queue': queue?.map((s) => s.toJson()).toList(),
        'queueIndex': queueIndex,
      });

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _connectedDevice = device.copyWith(
          currentSong: song,
          isPlaying: isPlaying,
          lastSeen: DateTime.now(),
        );
        _startStatusSyncTimer();
        notifyListeners();
        debugPrint('[GroovyConnect] Playback successfully transferred to ${device.name}');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[GroovyConnect] Transfer failed to ${device.name}: $e');
      return false;
    }
  }

  /// Connects to a target Groovy device without requiring an active song
  /// (e.g. When user selects a device from the picker before playing).
  Future<bool> connectToDevice(GroovyRemoteDevice device) async {
    try {
      debugPrint('[GroovyConnect] Connecting to ${device.name} at ${device.host}:${device.port}');
      final uri = Uri.parse('http://${device.host}:${device.port}/groovy/info');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final songData = data['song'] as Map<String, dynamic>?;
        Song? currentSong;
        if (songData != null) {
          try {
            currentSong = Song.fromJson(songData);
          } catch (_) {}
        }

        _connectedDevice = device.copyWith(
          currentSong: currentSong,
          isPlaying: data['isPlaying'] as bool? ?? false,
          lastSeen: DateTime.now(),
        );
        _startStatusSyncTimer();
        notifyListeners();
        debugPrint('[GroovyConnect] Successfully connected to ${device.name}');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[GroovyConnect] Connection failed to ${device.name}: $e');
      return false;
    }
  }

  /// Starts periodic status polling to keep song, timeline position, play/pause and volume
  /// 100% in sync between both devices just like Spotify Connect.
  void _startStatusSyncTimer() {
    _statusSyncTimer?.cancel();
    _statusSyncTimer = Timer.periodic(const Duration(milliseconds: 850), (_) {
      _syncRemoteStatus();
    });
  }

  Future<void> _syncRemoteStatus() async {
    if (_connectedDevice == null) {
      _statusSyncTimer?.cancel();
      return;
    }

    try {
      final uri = Uri.parse('http://${_connectedDevice!.host}:${_connectedDevice!.port}/groovy/info');
      final response = await http.get(uri).timeout(const Duration(milliseconds: 800));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final isPlaying = data['isPlaying'] as bool? ?? false;
        final positionMs = (data['positionMs'] as num?)?.toInt() ?? 0;
        final durationMs = (data['durationMs'] as num?)?.toInt() ?? 0;
        final volume = (data['volume'] as num?)?.toDouble() ?? 1.0;
        final songData = data['song'] as Map<String, dynamic>?;

        Song? song;
        if (songData != null) {
          try {
            song = Song.fromJson(songData);
          } catch (_) {}
        }

        if (song != null) {
          _connectedDevice = _connectedDevice!.copyWith(
            currentSong: song,
            isPlaying: isPlaying,
            lastSeen: DateTime.now(),
          );
          notifyListeners();
        }

        onRemoteStatusUpdated?.call(
          song: song,
          position: Duration(milliseconds: positionMs),
          duration: Duration(milliseconds: durationMs),
          isPlaying: isPlaying,
          volume: volume,
        );
      }
    } catch (_) {
      // Ignore intermittent packet drops
    }
  }

  /// Sends remote playback commands (play, pause, togglePlayPause, skipNext, skipPrevious, seek, volume).
  Future<bool> sendControl(String action, [dynamic value]) async {
    if (_connectedDevice == null) return false;
    try {
      final uri = Uri.parse('http://${_connectedDevice!.host}:${_connectedDevice!.port}/groovy/control');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': action, 'value': value}),
      ).timeout(const Duration(seconds: 3));

      // Immediately poll status so UI reflects remote action instantly
      Future.delayed(const Duration(milliseconds: 100), () => _syncRemoteStatus());

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[GroovyConnect] Remote control error: $e');
      return false;
    }
  }

  /// Sends a song to play on the connected device.
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

  /// Disconnects from the remote device.
  void disconnect() {
    _statusSyncTimer?.cancel();
    _connectedDevice = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _statusSyncTimer?.cancel();
    _pruneTimer?.cancel();
    _discoveryTimer?.cancel();
    _httpServer?.close(force: true);
    _udpSocket?.close();
    super.dispose();
  }
}
