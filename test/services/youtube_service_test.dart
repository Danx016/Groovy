import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:groovy/services/youtube_service.dart';
import 'package:groovy/models/song.dart';

void main() {
  group('YoutubeService', () {
    late YoutubeService service;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      service = YoutubeService();
    });

    test('should initialize and be configured for YouTube', () {
      expect(service.isYoutube, isTrue);
      expect(service.isConfigured, isTrue);
    });

    test('should build cover art URL correctly for YouTube video ID', () {
      final url = service.getCoverArtUrl('dQw4w9WgXcQ', size: 300);
      expect(url, equals('https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg'));
    });

    test('should return original URL if already full HTTP URL', () {
      const input = 'https://lh3.googleusercontent.com/test=w120-h120';
      final url = service.getCoverArtUrl(input);
      expect(url, contains('https://lh3.googleusercontent.com/test'));
    });
    test('should return empty URL when coverArt is null', () {
      final url = service.getCoverArtUrl(null);
      expect(url, '');
    });

    test('scoreSongRelevance prioritizes exact match over cover or unrelated tracks', () {
      final originalSong = Song(
        id: '1',
        title: 'Starboy',
        artist: 'The Weeknd',
        album: 'Starboy',
        duration: 230,
      );

      final coverSong = Song(
        id: '2',
        title: 'Starboy (Acoustic Cover)',
        artist: 'Fan Singer',
        duration: 220,
      );

      final unrelatedSong = Song(
        id: '3',
        title: 'Random Track',
        artist: 'Other',
        album: 'Starboy Soundtrack',
        duration: 200,
      );

      final originalScore = service.scoreSongRelevance(originalSong, 'Starboy');
      final coverScore = service.scoreSongRelevance(coverSong, 'Starboy');
      final unrelatedScore = service.scoreSongRelevance(unrelatedSong, 'Starboy');

      expect(originalScore, greaterThan(coverScore));
      expect(originalScore, greaterThan(unrelatedScore));
    });

    test('scoreSongRelevance correctly handles artist + title combination queries', () {
      final targetSong = Song(
        id: '10',
        title: 'Yellow',
        artist: 'Coldplay',
        duration: 260,
      );

      final otherColdplaySong = Song(
        id: '11',
        title: 'Viva La Vida',
        artist: 'Coldplay',
        duration: 240,
      );

      final targetScore = service.scoreSongRelevance(targetSong, 'Coldplay Yellow');
      final otherScore = service.scoreSongRelevance(otherColdplaySong, 'Coldplay Yellow');

      expect(targetScore, greaterThan(otherScore));
    });
  });
}
