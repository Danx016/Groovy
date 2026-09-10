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

  group('Pruebas reales de descarga y streaming de audio', () {
    final youtubeService = YoutubeService();
    final ytdlp = YtDlpService();

    test('Verificar descarga real de bytes de audio (GoogleVideo / YouTube CDN)', () async {
      final songsToTest = [
        Song(id: 'dQw4w9WgXcQ', title: 'Never Gonna Give You Up', artist: 'Rick Astley'),
        Song(id: 'kffacxfA7G4', title: 'Baby', artist: 'Justin Bieber'),
        Song(id: '9bZkp7q19f0', title: 'Gangnam Style', artist: 'PSY'),
      ];

      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10)
        ..idleTimeout = const Duration(seconds: 10);

      for (int i = 0; i < songsToTest.length; i++) {
        final song = songsToTest[i];
        print('\n🎵 [PROBANDO CANCIÓN ${i + 1}/${songsToTest.length}]: "${song.title}" por ${song.artist} (ID: ${song.id})');
        
        final stopwatch = Stopwatch()..start();
        final streamInfo = await ytdlp.resolveStreamInfo(song.id);
        stopwatch.stop();

        print('   ⏱ Tiempo de resolución: ${stopwatch.elapsedMilliseconds} ms');
        print('   🔗 URL de stream obtenida: ${streamInfo.url.substring(0, streamInfo.url.length > 80 ? 80 : streamInfo.url.length)}...');
        print('   📦 Extensión de contenedor: ${streamInfo.ext}');

        expect(streamInfo.url, isNotEmpty);
        expect(streamInfo.url.startsWith('http'), isTrue);

        // Conectar a la CDN de audio real y descargar los primeros paquetes de música
        print('   📡 Conectando a CDN de audio y descargando paquetes de música...');
        final req = await client.getUrl(Uri.parse(streamInfo.url));
        streamInfo.headers.forEach((k, v) {
          req.headers.set(k, v);
        });
        req.headers.set('Range', 'bytes=0-131071'); // Pedir los primeros 128 KB de audio

        final resp = await req.close();
        print('   🌐 Código de respuesta HTTP: ${resp.statusCode} (OK / Partial Content)');
        print('   📑 Tipo de contenido (Content-Type): ${resp.headers.contentType?.mimeType ?? "audio/*"}');
        print('   📏 Content-Length recibido: ${resp.contentLength} bytes');

        expect(resp.statusCode == 200 || resp.statusCode == 206, isTrue);

        int totalBytesReceived = 0;
        await for (final chunk in resp) {
          totalBytesReceived += chunk.length;
        }

        print('   ✅ Bytes de música descargados con éxito: $totalBytesReceived bytes (~${(totalBytesReceived / 1024).toStringAsFixed(1)} KB)');
        expect(totalBytesReceived, greaterThan(10000));
      }

      client.close();
    });
  });
}
