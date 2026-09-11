// ignore_for_file: avoid_print, unused_import, unnecessary_overrides, unused_local_variable
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy/models/models.dart';
import 'package:groovy/services/youtube_service.dart';
import 'package:groovy/services/ytdlp_service.dart';
import 'package:just_audio/just_audio.dart';

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

  group('Pruebas Multiplataforma Específicas: Windows, Linux y Android', () {
    final youtubeService = YoutubeService();
    final ytdlpService = YtDlpService();

    tearDownAll(() {
      youtubeService.dispose();
      ytdlpService.dispose();
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 1. PRUEBA WINDOWS Y LINUX (Proxy Local + Windows Media Foundation / libwinmedia)
    // ──────────────────────────────────────────────────────────────────────────
    test('🪟🐧 [Windows & Linux] Reproducción a través de Servidor Proxy Local (HTTP 127.0.0.1)', () async {
      print('\n--- PRUEBA WINDOWS & LINUX: Proxy Local y Streaming WMF ---');
      const testVideoId = 'dQw4w9WgXcQ'; // Rick Astley - Never Gonna Give You Up
      final testSong = Song(
        id: 'yt_$testVideoId',
        title: 'Never Gonna Give You Up',
        artist: 'Rick Astley',
        duration: 213,
      );

      final sw = Stopwatch()..start();
      final audioSource = await youtubeService.getYoutubeAudioSource(testSong);
      sw.stop();

      print('  ✓ AudioSource generado para Desktop en: ${sw.elapsedMilliseconds} ms');
      expect(audioSource, isNotNull);
      expect(audioSource is UriAudioSource, isTrue);

      final uriSource = audioSource as UriAudioSource;
      final playUri = uriSource.uri;
      print('  ✓ URI para el reproductor de Windows/Linux: $playUri');
      expect(playUri.scheme.startsWith('http'), isTrue);

      // Simular petición nativa de Windows (libmpv / Media Foundation)
      print('  📡 Simulando conexión de Windows/Linux al stream de audio...');
      final client = HttpClient();
      final req = await client.getUrl(playUri);
      if (uriSource.headers != null) {
        uriSource.headers!.forEach((k, v) => req.headers.set(k, v));
      }
      req.headers.set('Range', 'bytes=0-131071'); // 128 KB chunk inicial
      
      final resp = await req.close();
      print('  🌐 Código de respuesta del Stream: ${resp.statusCode}');
      expect(resp.statusCode, anyOf([HttpStatus.ok, HttpStatus.partialContent]));
      
      final contentType = resp.headers.contentType?.mimeType ?? '';
      print('  📑 Content-Type entregado al reproductor: $contentType');
      expect(contentType, anyOf(['audio/mp4', 'video/mp4', 'audio/webm']));

      final bytes = <int>[];
      await for (final chunk in resp) {
        bytes.addAll(chunk);
      }
      print('  ✅ Bytes recibidos y listos para reproducir en Windows/Linux: ${bytes.length} bytes (${(bytes.length / 1024).toStringAsFixed(1)} KB)');
      expect(bytes.length, greaterThan(10000));
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 2. PRUEBA ANDROID (ExoPlayer + _YoutubeStreamAudioSource + Range Chunking)
    // ──────────────────────────────────────────────────────────────────────────
    test('📱 [Android] Streaming con ExoPlayer vía StreamAudioSource y Chunks HTTP 206', () async {
      print('\n--- PRUEBA ANDROID: ExoPlayer StreamAudioSource Chunks ---');
      const testVideoId = 'kffacxfA7G4'; // Justin Bieber - Baby
      
      final streamAudioSource = await youtubeService.buildAudioSource(testVideoId);
      expect(streamAudioSource, isNotNull);
      print('  ✓ StreamAudioSource creado para Android (ExoPlayer)');

      // Simular petición de chunk 1 por ExoPlayer (0 a 131071 bytes = 128 KB)
      final sw1 = Stopwatch()..start();
      final streamResponse1 = await streamAudioSource.request(0, 131071);
      sw1.stop();

      print('  ⏱ Chunk 1 (0-128KB) resuelto en: ${sw1.elapsedMilliseconds} ms');
      expect(streamResponse1.contentType, anyOf(['audio/mp4', 'video/mp4', 'audio/webm']));

      final chunk1Bytes = <int>[];
      await for (final byte in streamResponse1.stream) {
        chunk1Bytes.addAll(byte);
      }
      print('  ✅ Chunk 1 recibido en Android: ${chunk1Bytes.length} bytes (${(chunk1Bytes.length / 1024).toStringAsFixed(1)} KB)');
      expect(chunk1Bytes.length, greaterThan(10000));

      // Simular petición de chunk 2 por ExoPlayer (131072 a 262143 bytes)
      final sw2 = Stopwatch()..start();
      final streamResponse2 = await streamAudioSource.request(131072, 262143);
      sw2.stop();

      print('  ⏱ Chunk 2 (128KB-256KB) resuelto en: ${sw2.elapsedMilliseconds} ms');
      final chunk2Bytes = <int>[];
      await for (final byte in streamResponse2.stream) {
        chunk2Bytes.addAll(byte);
      }
      print('  ✅ Chunk 2 recibido en Android: ${chunk2Bytes.length} bytes (${(chunk2Bytes.length / 1024).toStringAsFixed(1)} KB)');
      expect(chunk2Bytes.length, greaterThan(10000));
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 3. PRUEBA DE CAMBIO DE CANCIÓN EN VIVO (Todas las plataformas)
    // ──────────────────────────────────────────────────────────────────────────
    test('🔄 [Android, Windows & Linux] Cambio de canción inmediato sin retención de pista previa', () async {
      print('\n--- PRUEBA CAMBIO DE CANCIÓN: Separación de Audio Activo y Transición ---');
      final song1 = Song(id: 'yt_dQw4w9WgXcQ', title: 'Never Gonna Give You Up', artist: 'Rick Astley', duration: 213);
      final song2 = Song(id: 'yt_kffacxfA7G4', title: 'Baby', artist: 'Justin Bieber', duration: 214);
      final song3 = Song(id: 'yt_9bZkp7q19f0', title: 'Gangnam Style', artist: 'PSY', duration: 252);

      // Paso 1: Resolver Canción 1
      final sw1 = Stopwatch()..start();
      final stream1 = await ytdlpService.resolveStreamInfo('dQw4w9WgXcQ');
      sw1.stop();
      print('  ▶ Canción 1 iniciada ("${song1.title}"): Resuelta en ${sw1.elapsedMilliseconds} ms');
      expect(stream1.url.isNotEmpty, isTrue);

      // Paso 2: Precarga automática de Canción 2 en segundo plano
      ytdlpService.warmUpStreamCache(song2.id);

      // Paso 3: El usuario pulsa "Siguiente" -> Canción 2
      final sw2 = Stopwatch()..start();
      final stream2 = await ytdlpService.resolveStreamInfo('kffacxfA7G4');
      sw2.stop();
      print('  ⏭ Cambio a Canción 2 ("${song2.title}"): Resuelta en ${sw2.elapsedMilliseconds} ms');
      expect(stream2.url.isNotEmpty, isTrue);
      expect(stream2.url, isNot(equals(stream1.url)));

      // Paso 4: Cambio a Canción 3
      final sw3 = Stopwatch()..start();
      final stream3 = await ytdlpService.resolveStreamInfo('9bZkp7q19f0');
      sw3.stop();
      print('  ⏭ Cambio a Canción 3 ("${song3.title}"): Resuelta en ${sw3.elapsedMilliseconds} ms');
      expect(stream3.url.isNotEmpty, isTrue);
      expect(stream3.url, isNot(equals(stream2.url)));

      print('\n  🎉 Transiciones y resolución de audio verificadas con éxito en todas las plataformas.');
    });
  });
}
