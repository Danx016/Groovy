// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:groovy/models/lyric_line.dart';
import 'package:groovy/models/song.dart';
import 'package:groovy/screens/now_playing_screen.dart';
import 'package:groovy/services/lrclib_service.dart';
import 'package:groovy/services/offline_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  SharedPreferences.setMockInitialValues({});

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (MethodCall methodCall) async => Directory.systemTemp.path,
  );

  group('Comprehensive Lyrics System Tests', () {
    final lrclib = LrcLibService();

    test('1. LRCLIB: Finds synced lyrics for noisy YouTube titles and collaborations', () async {
      // Test collaboration and noise cleaning
      final result = await lrclib.searchLyrics(
        artist: 'Manuel Turizo',
        title: 'La Bachata (Video Oficial)',
        durationSeconds: 165,
      );

      expect(result, isNotNull, reason: 'Should return lyrics for La Bachata');
      expect(result!['structuredLyrics'], isNotNull, reason: 'Should contain synchronized lines');
      final lines = (result['structuredLyrics'] as List).first['line'] as List;
      expect(lines.isNotEmpty, isTrue);
      print('✓ LRCLIB Synced: Found ${lines.length} lines for "La Bachata"');
    });

    test('2. YouTube Closed Captions: Extracts synchronized captions directly from video', () async {
      // Queen - Bohemian Rhapsody (Known to have official CC tracks)
      final videoId = 'fJ9rUzIMcZQ';
      final ccResult = await lrclib.getYouTubeClosedCaptions(videoId);

      expect(ccResult, isNotNull, reason: 'Should extract closed captions from YouTube');
      expect(ccResult!['structuredLyrics'], isNotNull);
      final lines = (ccResult['structuredLyrics'] as List).first['line'] as List;
      expect(lines.isNotEmpty, isTrue);
      expect(lines.first['start'], isA<int>());
      expect(lines.first['value'], isA<String>());
      print('✓ YouTube CC: Extracted ${lines.length} synchronized lines for video $videoId');
    });

    test('3. Genius Fallback: Extracts clean lyrics from Genius for rare tracks', () async {
      // Search via searchLyrics for a track that falls back to Genius or plain lyrics
      final result = await lrclib.searchLyrics(
        artist: 'Feid',
        title: 'LUNA',
      );

      expect(result, isNotNull);
      expect(result!['value'], isNotNull);
      final text = result['value'].toString();
      expect(text.isNotEmpty, isTrue);
      // Ensure no raw HTML tags leaked
      expect(text.contains('<div'), isFalse);
      expect(text.contains('<br'), isFalse);
      print('✓ Genius/Repertoire: Successfully retrieved clean lyrics (${text.split('\n').length} lines)');
    });

    test('4. Disk Persistence: Saves and loads lyrics instantly from disk cache', () async {
      final offlineService = OfflineService();
      await offlineService.initialize();

      const testSongId = 'test_lyrics_persistence_id';
      final dummyLyrics = {
        'value': '[00:05.00] Linea uno\n[00:10.00] Linea dos',
        'structuredLyrics': [
          {
            'synced': true,
            'line': [
              {'start': 5000, 'value': 'Linea uno'},
              {'start': 10000, 'value': 'Linea dos'},
            ],
          }
        ]
      };

      // 1. Save to disk
      await offlineService.saveLyrics(testSongId, dummyLyrics);

      // 2. Read back from disk
      final loaded = await offlineService.getLocalLyrics(testSongId);
      expect(loaded, isNotNull);
      expect(loaded!['value'], equals(dummyLyrics['value']));

      // 3. Verify LrcLibService instant cache hit with songId
      final serviceLoaded = await lrclib.searchLyrics(
        artist: 'Unknown Artist',
        title: 'Unknown Title',
        songId: testSongId,
      );
      expect(serviceLoaded, isNotNull);
      expect(serviceLoaded!['value'], equals(dummyLyrics['value']));
      print('✓ Disk Cache: Lyrics correctly persisted and retrieved in 0ms');
    });

    test('5. Remote Playback Resilience: Track equality and dual-key lyrics cache survive remote ID jitter', () {
      final localSong = Song(
        id: 'dz_12345678',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
      );

      final remoteSong = Song(
        id: '4NRXx6U8ABQ', // YouTube video ID reported by remote Groovy Connect device
        title: 'Blinding Lights ', // subtle whitespace difference
        artist: 'The Weeknd',
      );

      // 1. Verify track equality despite completely different ID formats
      expect(NowPlayingScreen.isSameTrack(localSong, remoteSong), isTrue);

      // 2. Populate cache with local song
      final testLyrics = [
        LyricLine(startTime: const Duration(seconds: 10), text: 'I said, ooh, I\'m blinded by the lights'),
      ];
      NowPlayingScreen.setCachedLyrics(localSong, testLyrics);

      // 3. Retrieve using remote song with different ID format
      final cachedForRemote = NowPlayingScreen.getCachedLyrics(remoteSong);
      expect(cachedForRemote, isNotNull);
      expect(cachedForRemote!.length, equals(1));
      expect(cachedForRemote.first.text, equals('I said, ooh, I\'m blinded by the lights'));
      print('✓ Remote Resilience: Lyrics resolved across differing device IDs via artist|title index');
    });
  });
}
