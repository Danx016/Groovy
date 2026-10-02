import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import 'ytdlp_service.dart';

/// Lightweight HTTP media server running locally on Wi-Fi.
///
/// Smart TVs (Chromecast, Google TV, Samsung Tizen, LG webOS, DLNA/UPnP renderers)
/// CANNOT play `file:///` URLs from local devices and frequently fail or get 403 Forbidden
/// when connecting directly to Google Video / YouTube streaming URLs without specific headers.
///
/// This service:
/// 1. Serves local songs via HTTP with full Range request support (HTTP 206 Partial Content),
///    allowing Smart TVs to buffer, play, and seek downloaded/local tracks.
/// 2. Proxies YouTube audio streams over the local network using the required User-Agent
///    and CDN headers, eliminating 403 Forbidden errors and enabling smooth TV streaming.
class LocalMediaStreamService {
  static final LocalMediaStreamService _instance = LocalMediaStreamService._internal();
  factory LocalMediaStreamService() => _instance;
  LocalMediaStreamService._internal();

  HttpServer? _server;
  int _port = 0;
  String _localIp = '';
  bool _isStarting = false;

  int get port => _port;
  String get localIp => _localIp;
  bool get isRunning => _server != null;

  /// Ensures the local media server is running and local IP is detected.
  Future<void> ensureServerRunning() async {
    if (kIsWeb) return;
    if (_server != null) {
      if (_localIp.isEmpty || _localIp == '127.0.0.1') {
        await _detectLocalIp();
      }
      return;
    }

    if (_isStarting) {
      while (_isStarting) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return;
    }

    _isStarting = true;
    try {
      await _detectLocalIp();

      try {
        _server = await HttpServer.bind(InternetAddress.anyIPv4, 42432);
      } catch (_) {
        // Fallback to dynamic port if 42432 is in use
        _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      }

      _port = _server!.port;
      debugPrint('[LocalMediaServer] Started on http://$_localIp:$_port');

      _server!.listen(
        _handleRequest,
        onError: (e) {
          debugPrint('[LocalMediaServer] Server error: $e');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[LocalMediaServer] Failed to bind server: $e');
    } finally {
      _isStarting = false;
    }
  }

  /// Detects the physical local Wi-Fi / Ethernet IPv4 address of this device,
  /// skipping virtual adapters (WSL, Docker, Hyper-V, Tailscale, etc.).
  Future<void> _detectLocalIp() async {
    if (kIsWeb) return;
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      bool isVirtualAdapter(String name) {
        final lower = name.toLowerCase();
        return lower.contains('vethernet') ||
            lower.contains('wsl') ||
            lower.contains('virtual') ||
            lower.contains('vbox') ||
            lower.contains('vmware') ||
            lower.contains('docker') ||
            lower.contains('hyper-v') ||
            lower.contains('tailscale') ||
            lower.contains('zerotier') ||
            lower.contains('tap') ||
            lower.contains('tun');
      }

      // Priority 1: Physical Wi-Fi / WLAN interfaces
      for (final iface in interfaces) {
        if (isVirtualAdapter(iface.name)) continue;
        final name = iface.name.toLowerCase();
        if (name.contains('wlan') || name.contains('wi-fi') || name.contains('wl')) {
          for (final addr in iface.addresses) {
            if (!addr.isLoopback &&
                !addr.address.startsWith('127.') &&
                !addr.address.startsWith('169.254.')) {
              _localIp = addr.address;
              return;
            }
          }
        }
      }

      // Priority 2: Physical Ethernet / LAN interfaces
      for (final iface in interfaces) {
        if (isVirtualAdapter(iface.name)) continue;
        final name = iface.name.toLowerCase();
        if (name.contains('eth') || name.contains('ethernet') || name.contains('en')) {
          for (final addr in iface.addresses) {
            if (!addr.isLoopback &&
                !addr.address.startsWith('127.') &&
                !addr.address.startsWith('169.254.')) {
              _localIp = addr.address;
              return;
            }
          }
        }
      }

      // Priority 3: Non-virtual adapter with private IP
      for (final iface in interfaces) {
        if (isVirtualAdapter(iface.name)) continue;
        for (final addr in iface.addresses) {
          if (!addr.isLoopback &&
              !addr.address.startsWith('127.') &&
              (addr.address.startsWith('192.168.') || addr.address.startsWith('10.'))) {
            _localIp = addr.address;
            return;
          }
        }
      }

      // Fallback: Any non-loopback IPv4
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback &&
              !addr.address.startsWith('127.') &&
              !addr.address.startsWith('169.254.')) {
            _localIp = addr.address;
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('[LocalMediaServer] Error detecting IP: $e');
    }
    if (_localIp.isEmpty) {
      _localIp = '127.0.0.1';
    }
  }

  /// Request dispatcher
  Future<void> _handleRequest(HttpRequest req) async {
    final res = req.response;

    // Standard CORS headers so Cast web receivers and Smart TV browsers can read streams
    res.headers.set('Access-Control-Allow-Origin', '*');
    res.headers.set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
    res.headers.set('Access-Control-Allow-Headers', '*');
    res.headers.set('Access-Control-Expose-Headers', 'Content-Range, Accept-Ranges, Content-Length');

    if (req.method == 'OPTIONS') {
      res.statusCode = HttpStatus.ok;
      await res.close();
      return;
    }

    final path = req.uri.path;
    try {
      if (path == '/media/local') {
        await _handleLocalMedia(req, res);
      } else if (path == '/media/stream') {
        await _handleProxyStream(req, res);
      } else if (path == '/media/art') {
        await _handleLocalArt(req, res);
      } else if (path == '/media/health') {
        res.statusCode = HttpStatus.ok;
        res.write('OK');
        await res.close();
      } else {
        res.statusCode = HttpStatus.notFound;
        await res.close();
      }
    } catch (e) {
      debugPrint('[LocalMediaServer] Error handling $path: $e');
      try {
        res.statusCode = HttpStatus.internalServerError;
        await res.close();
      } catch (_) {}
    }
  }

  /// Serves local files with HTTP Range (206) support for TVs
  Future<void> _handleLocalMedia(HttpRequest req, HttpResponse res) async {
    final filePath = req.uri.queryParameters['path'];
    if (filePath == null || filePath.isEmpty) {
      res.statusCode = HttpStatus.badRequest;
      await res.close();
      return;
    }

    final file = File(filePath);
    if (!file.existsSync()) {
      res.statusCode = HttpStatus.notFound;
      await res.close();
      return;
    }

    final fileLength = await file.length();
    final mimeType = _mimeTypeFromPath(filePath);

    res.headers.set('Content-Type', mimeType);
    res.headers.set('Accept-Ranges', 'bytes');

    if (req.method == 'HEAD') {
      res.headers.set('Content-Length', fileLength.toString());
      res.statusCode = HttpStatus.ok;
      await res.close();
      return;
    }

    final rangeHeader = req.headers.value('range');
    if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
      final rangeMatch = RegExp(r'bytes=(\d*)-(\d*)').firstMatch(rangeHeader);
      if (rangeMatch != null) {
        final startStr = rangeMatch.group(1);
        final endStr = rangeMatch.group(2);

        int start = (startStr != null && startStr.isNotEmpty) ? int.parse(startStr) : 0;
        int end = (endStr != null && endStr.isNotEmpty) ? int.parse(endStr) : fileLength - 1;

        if (start >= fileLength) {
          res.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          res.headers.set('Content-Range', 'bytes */$fileLength');
          await res.close();
          return;
        }

        if (end >= fileLength) {
          end = fileLength - 1;
        }

        final chunkSize = end - start + 1;
        res.statusCode = HttpStatus.partialContent;
        res.headers.set('Content-Range', 'bytes $start-$end/$fileLength');
        res.headers.set('Content-Length', chunkSize.toString());

        await res.addStream(file.openRead(start, end + 1));
        await res.close();
        return;
      }
    }

    // Full file response
    res.statusCode = HttpStatus.ok;
    res.headers.set('Content-Length', fileLength.toString());
    await res.addStream(file.openRead());
    await res.close();
  }

  /// Proxies online YouTube streams to the Smart TV with correct headers & range support
  Future<void> _handleProxyStream(HttpRequest req, HttpResponse res) async {
    final songId = req.uri.queryParameters['id'];
    if (songId == null || songId.isEmpty) {
      res.statusCode = HttpStatus.badRequest;
      await res.close();
      return;
    }

    final cleanId = songId.replaceFirst('ytmusic://', '').replaceFirst('yt_', '').trim();

    try {
      final info = await YtDlpService().resolveStreamInfo(cleanId);
      if (info.url.isEmpty) {
        res.statusCode = HttpStatus.notFound;
        await res.close();
        return;
      }

      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8)
        ..idleTimeout = const Duration(seconds: 15);

      final upstreamUri = Uri.parse(info.url);
      final upstreamReq = await client.openUrl(req.method, upstreamUri);

      // Pass required signature headers to YouTube CDN
      info.headers.forEach((k, v) {
        upstreamReq.headers.set(k, v);
      });

      // Forward TV's Range header to upstream CDN
      final rangeHeader = req.headers.value('range');
      if (rangeHeader != null) {
        upstreamReq.headers.set('range', rangeHeader);
      }

      final upstreamRes = await upstreamReq.close();

      res.statusCode = upstreamRes.statusCode;
      res.headers.set('Accept-Ranges', 'bytes');

      // Set TV-friendly audio mime type
      final ct = upstreamRes.headers.contentType?.toString() ??
          (info.ext.toLowerCase() == 'webm' ? 'audio/webm' : 'audio/mp4');
      res.headers.set('Content-Type', ct);

      final cl = upstreamRes.headers.value('content-length');
      if (cl != null) res.headers.set('Content-Length', cl);

      final cr = upstreamRes.headers.value('content-range');
      if (cr != null) res.headers.set('Content-Range', cr);

      await res.addStream(upstreamRes);
      await res.close();
      client.close();
    } catch (e) {
      debugPrint('[LocalMediaServer] Proxy error for $cleanId: $e');
      try {
        res.statusCode = HttpStatus.badGateway;
        await res.close();
      } catch (_) {}
    }
  }

  /// Serves local album artwork via HTTP for Smart TVs
  Future<void> _handleLocalArt(HttpRequest req, HttpResponse res) async {
    final artPath = req.uri.queryParameters['path'];
    if (artPath == null || artPath.isEmpty) {
      res.statusCode = HttpStatus.badRequest;
      await res.close();
      return;
    }

    final file = File(artPath);
    if (!file.existsSync()) {
      res.statusCode = HttpStatus.notFound;
      await res.close();
      return;
    }

    final lower = artPath.toLowerCase();
    String mime = 'image/jpeg';
    if (lower.endsWith('.png')) mime = 'image/png';
    if (lower.endsWith('.webp')) mime = 'image/webp';

    res.headers.set('Content-Type', mime);
    res.headers.set('Content-Length', (await file.length()).toString());
    res.statusCode = HttpStatus.ok;

    await res.addStream(file.openRead());
    await res.close();
  }

  /// Generates the HTTP URL to send to Google Cast or DLNA Smart TVs
  Future<String> getPlaybackUrlForTv(Song song) async {
    await ensureServerRunning();

    final ip = _localIp.isNotEmpty && _localIp != '127.0.0.1' ? _localIp : 'localhost';

    if (song.isLocal == true && song.path != null && song.path!.isNotEmpty) {
      return 'http://$ip:$_port/media/local?path=${Uri.encodeComponent(song.path!)}';
    }

    return 'http://$ip:$_port/media/stream?id=${Uri.encodeComponent(song.id)}';
  }

  /// Generates the cover art URL to send to Google Cast or DLNA Smart TVs
  String? getCoverArtUrlForTv(Song song) {
    if (song.coverArt == null || song.coverArt!.isEmpty) return null;

    final art = song.coverArt!;
    if (art.startsWith('http://') || art.startsWith('https://')) {
      return art;
    }

    if (song.isLocal == true && File(art).existsSync()) {
      final ip = _localIp.isNotEmpty && _localIp != '127.0.0.1' ? _localIp : 'localhost';
      return 'http://$ip:$_port/media/art?path=${Uri.encodeComponent(art)}';
    }

    return null;
  }

  /// Resolves standard MIME type for TVs
  String getMimeTypeForTv(Song song) {
    if (song.isLocal == true && song.path != null) {
      return _mimeTypeFromPath(song.path!);
    }
    // Remote audio streams proxied for Smart TVs use MP4/AAC container
    return 'audio/mp4';
  }

  static String _mimeTypeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.m4a') || lower.endsWith('.mp4') || lower.endsWith('.aac')) {
      return 'audio/mp4';
    }
    if (lower.endsWith('.flac')) return 'audio/flac';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.ogg') || lower.endsWith('.oga') || lower.endsWith('.opus')) {
      return 'audio/ogg';
    }
    return 'audio/mpeg';
  }
}
