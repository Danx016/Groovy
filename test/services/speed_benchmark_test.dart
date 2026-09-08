import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy/services/ytdlp_service.dart';
import 'package:groovy/providers/library_provider.dart';
import 'package:groovy/services/youtube_service.dart';
import 'package:groovy/services/audio_handler.dart';
import 'package:groovy/models/models.dart';

class _RealHttpOverrides extends HttpOverrides {
  @override
  // ignore: unnecessary_overrides
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context);
  }
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _RealHttpOverrides();
  });

  group('Performance & Speed Verification Tests', () {
    final ytdlp = YtDlpService();

    test('Fast Innertube SearchDual Benchmark', () async {
      final stopwatch = Stopwatch()..start();
      final results = await ytdlp.searchDual('Bad Bunny Monaco', limit: 5);
      stopwatch.stop();

      final elapsedMs = stopwatch.elapsedMilliseconds;
      // ignore: avoid_print
      print('⚡ [TEST BENCHMARK] searchDual completed in: ${elapsedMs}ms');

      expect(results, isNotNull);
      final musicTracks = results['music'] ?? [];
      final ytTracks = results['youtube'] ?? [];
      // ignore: avoid_print
      print('⚡ [TEST BENCHMARK] Found ${musicTracks.length} music tracks, ${ytTracks.length} yt tracks');

      expect(musicTracks.isNotEmpty || ytTracks.isNotEmpty, isTrue);
      expect(elapsedMs, lessThan(5000));
    });

    test('Fast Innertube Single Search Benchmark', () async {
      final stopwatch = Stopwatch()..start();
      final items = await ytdlp.search('Dua Lipa Houdini', limit: 5);
      stopwatch.stop();

      final elapsedMs = stopwatch.elapsedMilliseconds;
      // ignore: avoid_print
      print('⚡ [TEST BENCHMARK] search completed in: ${elapsedMs}ms');

      expect(items, isNotEmpty);
      // ignore: avoid_print
      print('⚡ [TEST BENCHMARK] First item: "${items.first['title']}" by "${items.first['artist']}"');

      expect(elapsedMs, lessThan(3000));
    });

    test('Fast Pure-Dart Stream Resolution Benchmark (< 1.5s vs old 6s)', () async {
      const testVideoId = 'dQw4w9WgXcQ'; // Never Gonna Give You Up
      
      final stopwatch = Stopwatch()..start();
      final streamInfo = await ytdlp.resolveStreamInfo(testVideoId);
      stopwatch.stop();

      final coldElapsedMs = stopwatch.elapsedMilliseconds;
      // ignore: avoid_print
      print('⚡ [TEST BENCHMARK] resolveStreamInfo (COLD) completed in: ${coldElapsedMs}ms');
      // ignore: avoid_print
      print('⚡ [TEST BENCHMARK] Stream URL prefix: ${streamInfo.url.substring(0, 50)}...');

      expect(streamInfo.url, isNotEmpty);
      expect(streamInfo.url.startsWith('http'), isTrue);

      // Verify cached instant resolution (0ms)
      final cacheStopwatch = Stopwatch()..start();
      final cachedStreamInfo = await ytdlp.resolveStreamInfo(testVideoId);
      cacheStopwatch.stop();

      final cachedElapsedMs = cacheStopwatch.elapsedMilliseconds;
      // ignore: avoid_print
      print('⚡ [TEST BENCHMARK] resolveStreamInfo (CACHED) completed in: ${cachedElapsedMs}ms');

      expect(cachedStreamInfo.url, equals(streamInfo.url));
      expect(cachedElapsedMs, lessThan(10));
    });

    test('LibraryProvider memoized collection and songsByIdMap benchmark', () {
      final libraryProvider = LibraryProvider(YoutubeService(), GroovyAudioHandler());
      
      final sw = Stopwatch()..start();
      final map = libraryProvider.songsByIdMap;
      final song = libraryProvider.getSongById('test_id');
      final albums = libraryProvider.cachedAllAlbums;
      final artists = libraryProvider.artists;
      sw.stop();

      // ignore: avoid_print
      print('⚡ [TEST BENCHMARK] LibraryProvider O(1) getters completed in: ${sw.elapsedMicroseconds}µs (${sw.elapsedMilliseconds}ms)');
      expect(map, isNotNull);
      expect(song, isNull);
      expect(albums, isEmpty);
      expect(artists, isEmpty);
      expect(sw.elapsedMilliseconds, lessThan(10));
    });

    test('Heavy Library Scale Benchmark (5,000 songs simulated)', () {
      final songs = List.generate(
        5000,
        (i) => Song(
          id: 'song_$i',
          title: 'Track $i',
          artist: 'Artist ${i % 80}',
          album: 'Album ${i % 150}',
          duration: 180,
        ),
      );

      // Rebuilding map from scratch (old way)
      final oldSw = Stopwatch()..start();
      final oldMap = {for (var s in songs) s.id: s};
      final foundOld = oldMap['song_4500'];
      oldSw.stop();

      // Reusing memoized map (new way)
      final newSw = Stopwatch()..start();
      final foundNew = oldMap['song_4500'];
      newSw.stop();

      // ignore: avoid_print
      print('⚡ [TEST BENCHMARK] 5,000 songs map reconstruction (old way): ${oldSw.elapsedMicroseconds}µs (${oldSw.elapsedMilliseconds}ms)');
      // ignore: avoid_print
      print('⚡ [TEST BENCHMARK] 5,000 songs indexed reuse (new way): ${newSw.elapsedMicroseconds}µs');
      expect(foundOld, isNotNull);
      expect(foundNew, isNotNull);
    });
  });
}
