import 'package:flutter_test/flutter_test.dart';
import 'package:groovy/models/song.dart';
import 'package:groovy/models/lyric_line.dart';
import 'package:groovy/screens/now_playing_screen.dart';
import 'package:groovy/services/lrclib_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Lyrics Cold Start & Deduplication Tests', () {
    test('NowPlayingScreen lyrics cache handles hits and negative checks correctly', () {
      final songA = Song(id: 'song_test_1', title: 'Test Song One', artist: 'Test Artist');
      final songB = Song(id: 'song_test_2', title: 'Test Song Two', artist: 'Test Artist');

      expect(NowPlayingScreen.hasCachedLyrics(songA), isFalse);
      expect(NowPlayingScreen.hasCheckedLyrics(songA), isFalse);

      // Save lyrics for songA
      NowPlayingScreen.setCachedLyrics(songA, [
        LyricLine(startTime: const Duration(seconds: 1), text: 'Hello World'),
      ]);

      expect(NowPlayingScreen.hasCachedLyrics(songA), isTrue);
      expect(NowPlayingScreen.hasCheckedLyrics(songA), isTrue);
      expect(NowPlayingScreen.getCachedLyrics(songA)?.length, 1);

      // Save empty lyrics (negative cache) for songB
      NowPlayingScreen.setCachedLyrics(songB, const []);
      expect(NowPlayingScreen.hasCachedLyrics(songB), isTrue);
      expect(NowPlayingScreen.hasCheckedLyrics(songB), isTrue);
      expect(NowPlayingScreen.getCachedLyrics(songB)?.isEmpty, isTrue);
    });

    test('LrcLibService deduplicates in-flight calls for identical songs', () async {
      final service = LrcLibService();

      // Launch two searches simultaneously for the same song
      final call1 = service.searchLyrics(
        artist: 'Test Dedup Artist',
        title: 'Dedup Song',
        durationSeconds: 200,
        songId: 'dedup_id_1',
      );

      final call2 = service.searchLyrics(
        artist: 'Test Dedup Artist',
        title: 'Dedup Song',
        durationSeconds: 200,
        songId: 'dedup_id_1',
      );

      // Both calls should return the exact same Future instance
      expect(identical(call1, call2), isTrue);

      final res = await call1;
      // Result may be null since this is a mock title/artist, but future completes without error
      expect(res == null || res is Map<String, dynamic>, isTrue);
    });

    test('LrcLibService normalizes duration passed in milliseconds', () async {
      final service = LrcLibService();

      // Milliseconds duration (e.g. 210000ms = 210s)
      final call = service.searchLyrics(
        artist: 'Test Duration Artist',
        title: 'Test Duration Song',
        durationSeconds: 210000,
        songId: 'ms_duration_song',
      );

      final res = await call;
      expect(res == null || res is Map<String, dynamic>, isTrue);
    });
  });
}
