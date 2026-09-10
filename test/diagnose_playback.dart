/// Diagnostic: tests multiple popular songs end-to-end through the proxy
/// Run with: flutter test test/diagnose_playback.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy/services/youtube_service.dart';
import 'package:groovy/services/ytdlp_service.dart';

class _RealHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context);
}

void main() {
  setUpAll(() => HttpOverrides.global = _RealHttpOverrides());

  final ytdlp = YtDlpService();
  final proxy = _DesktopAudioProxyServer.instance;

  tearDownAll(() {
    ytdlp.dispose();
    proxy.dispose();
  });

  // ── Test matrix: diverse genres, regions and client types ─────────────────
  final songs = <String, String>{
    'dQw4w9WgXcQ': 'Rick Astley – Never Gonna Give You Up',
    'kffacxfA7G4': 'Justin Bieber – Baby',
    '9bZkp7q19f0': 'PSY – Gangnam Style',
    'JGwWNGJdvx8': 'Ed Sheeran – Shape of You',
    'OPf0YbXqDm0': 'Mark Ronson – Uptown Funk',
    'CevxZvSJLk8': 'Katy Perry – Roar',
    'YQHsXMglC9A': 'Adele – Hello',
    'RgKAFK5djSk': 'Wiz Khalifa – See You Again',
    'lp-EO5I60KA': 'Daddy Yankee – Gasolina',
    'wHyLg6wKdm0': 'Carlos Vives – La Bicicleta',
    'LEHYryXUxbI': '??? – (video that gave 403)',
    'ZbZSe6N_BXs': 'Pharrell – Happy',
    'hTWKbfoikeg': 'Nirvana – Smells Like Teen Spirit',
    '7PCkvCPvDXk': 'Michael Jackson – Thriller',
    'SlPhMPnQ58k': 'Maluma – Hawái',
  };

  group('🎵 Diagnóstico de Reproducción por Canción', () {
    for (final entry in songs.entries) {
      final videoId = entry.key;
      final name = entry.value;

      test('[$videoId] $name', () async {
        print('\n──────────────────────────────────────────────');
        print('🎵 Probando: $name ($videoId)');

        // 1. Resolve stream info
        YtStreamInfo? info;
        String resolveError = '';
        try {
          info = await ytdlp.resolveStreamInfo(videoId).timeout(
              const Duration(seconds: 15));
          print('  ✅ URL resuelta (${info.url.substring(0, 60)}...)');
          print('  📋 Client param: ${_clientParam(info.url)}');
          print('  🧑 User-Agent: ${info.headers['User-Agent']?.substring(0, 40) ?? "none"}...');
        } catch (e) {
          resolveError = e.toString();
          print('  ❌ Error resolviendo: $e');
        }

        if (info == null) {
          print('  ⚠️ SKIP: No se pudo resolver URL');
          markTestSkipped('No stream URL: $resolveError');
          return;
        }

        // 2. Hit the URL directly (simulates what proxy does)
        await proxy.ensureStarted();
        final proxyUrl = await proxy.getProxyUrl(videoId);
        print('  🌐 Proxy URL: $proxyUrl');

        final client = HttpClient();
        try {
          final req = await client.getUrl(Uri.parse(proxyUrl));
          req.headers.set('Range', 'bytes=0-65535');
          final resp = await req.close().timeout(const Duration(seconds: 15));

          print('  📡 HTTP Status via proxy: ${resp.statusCode}');

          if (resp.statusCode == 206 || resp.statusCode == 200) {
            final bytes = <int>[];
            await for (final chunk in resp.timeout(const Duration(seconds: 10))) {
              bytes.addAll(chunk);
              if (bytes.length >= 65536) break;
            }
            print('  ✅ ÉXITO: ${bytes.length} bytes recibidos (${(bytes.length/1024).toStringAsFixed(1)} KB)');
            expect(resp.statusCode, anyOf([200, 206]));
            expect(bytes.length, greaterThan(1000));
          } else {
            print('  ❌ FALLO HTTP ${resp.statusCode}');
            await resp.drain<void>().catchError((_) {});
            fail('HTTP ${resp.statusCode} para $videoId');
          }
        } finally {
          client.close();
        }
      });
    }
  });
}

String _clientParam(String url) {
  if (url.contains('c=ANDROID')) return 'ANDROID';
  if (url.contains('c=TVHTML5')) return 'TV';
  if (url.contains('c=IOS')) return 'IOS';
  if (url.contains('c=WEB')) return 'WEB';
  return 'unknown';
}

// Expose internals for testing
extension _ProxyExpose on _DesktopAudioProxyServer {
  Future<void> ensureStarted() async {
    await _DesktopAudioProxyServer.instance.ensureStarted();
  }
  Future<String> getProxyUrl(String id) =>
      _DesktopAudioProxyServer.instance.getProxyUrl(id);
  void dispose() => _DesktopAudioProxyServer.instance.dispose();
}
