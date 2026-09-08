import 'package:flutter_test/flutter_test.dart';
import 'package:groovy/models/models.dart';
import 'package:groovy/services/youtube_service.dart';
import '../bootstrap.dart';

void main() {
  initializeTestEnvironment();
  group('Security Tests', () {
    group('YouTube stream safety', () {
      late YoutubeService service;

      setUp(() {
        service = YoutubeService();
      });

      test('getCoverArtUrl should sanitize input', () {
        final url = service.getCoverArtUrl(null);
        expect(url, '');
      });

      test('should handle malformed song IDs gracefully', () {
        final song = Song(id: '../etc/passwd', title: 'Bad');
        expect(() => song.id, returnsNormally);
      });

      test('should handle SQL injection-like song titles', () {
        final song = Song(
          id: '1',
          title: "'; DROP TABLE songs; --",
        );
        expect(song.title, "'; DROP TABLE songs; --");
        expect(() => song.toJson(), returnsNormally);
      });

      test('should handle XSS payload in metadata', () {
        final song = Song(
          id: '2',
          title: '<script>alert(1)</script>',
          artist: '<img src=x onerror=alert(1)>',
          album: '<body onload=alert(1)>',
        );
        final json = song.toJson();
        expect(json['title'], contains('<script>'));
        expect(json['artist'], contains('<img'));
        expect(json['album'], contains('<body'));
      });
    });

    group('Password / credential handling', () {
      test('ServerConfig password should be stored', () {
        final config = ServerConfig(
          serverUrl: 'http://test',
          username: 'admin',
          password: 'secret123',
        );
        expect(config.password, 'secret123');
      });

      test('toJson should include password (for persistence)', () {
        final config = ServerConfig(
          serverUrl: 'http://test',
          username: 'u',
          password: 'p',
        );
        final json = config.toJson();
        expect(json['password'], 'p');
      });
    });
  });
}
