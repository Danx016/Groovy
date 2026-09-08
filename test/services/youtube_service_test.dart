import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:groovy/services/youtube_service.dart';

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
  });
}
