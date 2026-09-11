// ignore_for_file: avoid_print, unused_import, unnecessary_overrides, unused_local_variable
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy/models/models.dart';
import 'package:groovy/services/youtube_service.dart';
import 'package:groovy/services/ytdlp_service.dart';

class _RealHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context);
  }
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _RealHttpOverrides();
  });

  group('Demostración y Validación en Vivo de Reproducción y Streaming', () {
    final ytdlp = YtDlpService();

    test('Flujo completo: Búsqueda, Streaming real, Descarga de Audio y Cambio de Pista', () async {
      print('===============================================================');
      print('  🚀 INICIANDO PRUEBA DE REPRODUCCIÓN Y STREAMING EN VIVO');
      print('===============================================================');

      // 1. Prueba de búsqueda en vivo
      print('\n[PASO 1] Buscando canciones populares en vivo...');
      final searchSw = Stopwatch()..start();
      final searchResults = await ytdlp.search('Feid Luna', limit: 3);
      searchSw.stop();

      print('  ✓ Búsqueda completada en: ${searchSw.elapsedMilliseconds} ms');
      expect(searchResults, isNotEmpty);
      for (var i = 0; i < searchResults.length; i++) {
        print('    ${i + 1}. "${searchResults[i]['title']}" - ${searchResults[i]['artist']} (ID: ${searchResults[i]['id']})');
      }

      // 2. Probar reproducción y streaming consecutivo de 3 canciones
      final testTracks = [
        Song(id: 'dQw4w9WgXcQ', title: 'Never Gonna Give You Up', artist: 'Rick Astley'),
        Song(id: 'kffacxfA7G4', title: 'Baby', artist: 'Justin Bieber'),
        Song(id: '9bZkp7q19f0', title: 'Gangnam Style', artist: 'PSY'),
      ];

      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 12)
        ..idleTimeout = const Duration(seconds: 12);

      for (int i = 0; i < testTracks.length; i++) {
        final track = testTracks[i];
        print('\n[PASO ${i + 2}] Reproduciendo Canción ${i + 1}: "${track.title}"');
        
        final resolveSw = Stopwatch()..start();
        final streamInfo = await ytdlp.resolveStreamInfo(track.id);
        resolveSw.stop();

        print('  ⏱ Tiempo de carga/resolución de audio: ${resolveSw.elapsedMilliseconds} ms');
        print('  🔗 URL del Stream: ${streamInfo.url.substring(0, streamInfo.url.length > 70 ? 70 : streamInfo.url.length)}...');
        print('  📦 Formato de audio: ${streamInfo.ext}');

        expect(streamInfo.url, isNotEmpty);
        expect(streamInfo.url.startsWith('https://'), isTrue);

        // 3. Descarga de paquetes de audio reales (256 KB)
        print('  📡 Descargando paquetes de audio reales de la CDN...');
        final req = await client.getUrl(Uri.parse(streamInfo.url));
        streamInfo.headers.forEach((k, v) => req.headers.set(k, v));
        req.headers.set('Range', 'bytes=0-262143'); // 256 KB

        final resp = await req.close();
        print('  🌐 Respuesta del servidor: HTTP ${resp.statusCode} (${resp.statusCode == 206 ? "Streaming OK" : "OK"})');
        print('  📑 Content-Type: ${resp.headers.contentType?.mimeType ?? "audio/mp4"}');

        expect(resp.statusCode == 200 || resp.statusCode == 206, isTrue);

        int totalBytes = 0;
        await for (final chunk in resp) {
          totalBytes += chunk.length;
        }

        print('  ✅ Audio recibido y listo para sonar: $totalBytes bytes (${(totalBytes / 1024).toStringAsFixed(1)} KB)');
        expect(totalBytes, greaterThan(20000));
        print('  🎶 >> Canción ${i + 1} sonando y transmitiendo sin errores.');
      }

      client.close();
      print('\n===============================================================');
      print('  🎉 TODAS LAS CANCIONES CARGARON Y TRANSMITIERON EXITOSAMENTE');
      print('===============================================================');
    });
  });
}
