/// Diagnóstico directo: prueba URLs de YouTube resueltas con el UA correcto
/// Run: dart run test\diagnose_songs.dart
import 'dart:io';
import 'dart:convert';

// IDs de canciones a probar
const songs = {
  'dQw4w9WgXcQ': 'Rick Astley – Never Gonna Give You Up',
  'kffacxfA7G4': 'Justin Bieber – Baby',
  '9bZkp7q19f0': 'PSY – Gangnam Style',
  'JGwWNGJdvx8': 'Ed Sheeran – Shape of You',
  'OPf0YbXqDm0': 'Mark Ronson – Uptown Funk',
  'YQHsXMglC9A': 'Adele – Hello',
  'RgKAFK5djSk': 'Wiz Khalifa – See You Again',
  'lp-EO5I60KA': 'Daddy Yankee – Gasolina',
  'wHyLg6wKdm0': 'Carlos Vives – La Bicicleta',
  'LEHYryXUxbI': '??? – Video con 403',
  'ZbZSe6N_BXs': 'Pharrell – Happy',
  'SlPhMPnQ58k': 'Maluma – Hawái',
  'X9ukSm5gmKk': 'Bad Bunny – Tití Me Preguntó',
  'uelHwf8o7_U': 'J Balvin – Reggaeton',
};

Future<void> main() async {
  final ytdlp = _detectYtDlp();
  if (ytdlp == null) {
    print('❌ yt-dlp no encontrado en PATH');
    exit(1);
  }
  print('✅ yt-dlp: $ytdlp\n');

  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10)
    ..idleTimeout = const Duration(seconds: 15);

  final passed = <String>[];
  final failed = <String>[];
  final skipped = <String>[];

  for (final entry in songs.entries) {
    final videoId = entry.key;
    final name = entry.value;
    print('──────────────────────────────────────────────');
    print('🎵 $name ($videoId)');

    // 1. Resolve via yt-dlp
    final sw = Stopwatch()..start();
    String url = '';
    String ua = '';
    String clientParam = '';
    try {
      final result = await Process.run(ytdlp, [
        '-j', '-f', 'ba/b[acodec!=none]/best',
        '--extractor-args', 'youtube:player_client=tv_embedded,ios,android',
        '--no-warnings', '--no-check-certificates',
        'https://www.youtube.com/watch?v=$videoId',
      ]).timeout(const Duration(seconds: 20));

      if (result.exitCode != 0) {
        final err = result.stderr.toString().trim();
        print('  ❌ yt-dlp error: ${err.split('\n').first}');
        skipped.add('$videoId ($name): yt-dlp error');
        continue;
      }

      final json = jsonDecode(result.stdout.toString().trim()) as Map<String, dynamic>;
      url = json['url'] as String? ?? '';
      final rawHeaders = json['http_headers'] as Map<String, dynamic>? ?? {};
      
      // Detect client from URL
      if (url.contains('c=ANDROID')) {
        clientParam = 'ANDROID';
        ua = 'com.google.android.youtube/17.36.4 (Linux; U; Android 12; GB) gzip';
      } else if (url.contains('c=TVHTML5')) {
        clientParam = 'TVHTML5';
        ua = 'Mozilla/5.0 (SMART-TV; LINUX; Tizen 6.0) AppleWebKit/538.1 (KHTML, like Gecko) Version/6.0 TV Safari/538.1';
      } else if (url.contains('c=IOS')) {
        clientParam = 'IOS';
        ua = 'com.google.ios.youtube/17.36.4 (iPhone14,3; U; CPU iOS 15_6 like Mac OS X)';
      } else {
        clientParam = rawHeaders['User-Agent']?.toString().contains('ANDROID') == true ? 'ANDROID-header' : 'WEB/other';
        ua = rawHeaders['User-Agent']?.toString() ?? 
             'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
      }

      sw.stop();
      print('  ✅ URL resuelta en ${sw.elapsedMilliseconds}ms | client=$clientParam');
    } catch (e) {
      print('  ❌ Error: $e');
      skipped.add('$videoId ($name): $e');
      continue;
    }

    // 2. Try to fetch first 64KB with correct UA
    try {
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set('User-Agent', ua);
      req.headers.set('Origin', 'https://www.youtube.com');
      req.headers.set('Referer', 'https://www.youtube.com/');
      req.headers.set('Accept', '*/*');
      req.headers.set('Range', 'bytes=0-65535');

      final resp = await req.close().timeout(const Duration(seconds: 15));
      print('  📡 HTTP Status: ${resp.statusCode} | Content-Type: ${resp.headers.contentType?.mimeType}');

      if (resp.statusCode == 206 || resp.statusCode == 200) {
        final bytes = <int>[];
        await for (final chunk in resp.timeout(const Duration(seconds: 10))) {
          bytes.addAll(chunk);
          if (bytes.length >= 65536) break;
        }
        print('  ✅ ÉXITO: ${bytes.length} bytes (${(bytes.length/1024).toStringAsFixed(1)} KB)');
        passed.add('$videoId ($name)');
      } else {
        await resp.drain<void>().catchError((_) {});
        print('  ❌ FALLO: HTTP ${resp.statusCode}');
        
        // Try with different UA as fallback diagnosis
        print('  🔄 Reintentando con Chrome Desktop UA...');
        final req2 = await client.getUrl(Uri.parse(url));
        req2.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36');
        req2.headers.set('Range', 'bytes=0-65535');
        final resp2 = await req2.close().timeout(const Duration(seconds: 10));
        print('  📡 Chrome UA Status: ${resp2.statusCode}');
        await resp2.drain<void>().catchError((_) {});
        
        failed.add('$videoId ($name): HTTP ${resp.statusCode}');
      }
    } catch (e) {
      print('  ❌ Fetch error: $e');
      failed.add('$videoId ($name): $e');
    }
  }

  client.close();

  print('\n══════════════════════════════════════════════');
  print('📊 RESULTADOS:');
  print('  ✅ OK  (${passed.length}): ${passed.join(", ")}');
  print('  ❌ FAIL(${failed.length}): ${failed.join(", ")}');
  print('  ⚠️ SKIP(${skipped.length}): ${skipped.join(", ")}');
}

String? _detectYtDlp() {
  for (final bin in ['yt-dlp.exe', 'yt-dlp']) {
    try {
      final r = Process.runSync(bin, ['--version']);
      if (r.exitCode == 0) return bin;
    } catch (_) {}
  }
  return null;
}
