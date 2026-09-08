import 'package:flutter_test/flutter_test.dart';
import 'package:groovy/utils/album_sanitizer.dart';

void main() {
  group('AlbumSanitizer Tests', () {
    test('cleanTitle converts technical slug to human readable title', () {
      expect(AlbumSanitizer.cleanTitle('album_mi_mejor_momento'), 'Mi Mejor Momento');
      expect(AlbumSanitizer.cleanTitle('local_album_rock_classics'), 'Rock Classics');
      expect(AlbumSanitizer.cleanTitle('mi_mejor_momento'), 'Mi Mejor Momento');
      expect(AlbumSanitizer.cleanTitle('MI MEJOR MOMENTO'), 'Mi Mejor Momento');
      expect(AlbumSanitizer.cleanTitle('Abbey Road'), 'Abbey Road');
      expect(AlbumSanitizer.cleanTitle('dz_album_987654'), '987654');
    });

    test('cleanTitle filters out generic placeholders', () {
      expect(AlbumSanitizer.cleanTitle('album'), '');
      expect(AlbumSanitizer.cleanTitle('Álbum'), '');
      expect(AlbumSanitizer.cleanTitle('unknown album'), '');
      expect(AlbumSanitizer.cleanTitle('desconocido'), '');
      expect(AlbumSanitizer.cleanTitle(null), '');
      expect(AlbumSanitizer.cleanTitle('   '), '');
    });

    test('isPlaceholder and isPlaceholderOrSlug detection', () {
      expect(AlbumSanitizer.isPlaceholder('album'), isTrue);
      expect(AlbumSanitizer.isPlaceholder('Álbum'), isTrue);
      expect(AlbumSanitizer.isPlaceholder('Artista'), isTrue);
      expect(AlbumSanitizer.isPlaceholder('Unknown Artist'), isTrue);
      expect(AlbumSanitizer.isPlaceholder(null), isTrue);
      expect(AlbumSanitizer.isPlaceholder('Queen'), isFalse);

      expect(AlbumSanitizer.isPlaceholderOrSlug('album_mi_mejor_momento'), isTrue);
      expect(AlbumSanitizer.isPlaceholderOrSlug('local_album_123'), isTrue);
      expect(AlbumSanitizer.isPlaceholderOrSlug('MPREb_987'), isTrue);
      expect(AlbumSanitizer.isPlaceholderOrSlug('Mi Mejor Momento'), isFalse);
    });

    test('matches correctly pairs slugs and human titles', () {
      expect(
        AlbumSanitizer.matches('Mi Mejor Momento', 'album_mi_mejor_momento'),
        isTrue,
      );
      expect(
        AlbumSanitizer.matches('album_mi_mejor_momento', 'Mi Mejor Momento'),
        isTrue,
      );
      expect(
        AlbumSanitizer.matches('Rock Classics', 'local_album_rock_classics'),
        isTrue,
      );
      expect(
        AlbumSanitizer.matches('Different Album', 'album_mi_mejor_momento'),
        isFalse,
      );
    });

    test('cleanArtist returns clean artist or null for placeholders', () {
      expect(AlbumSanitizer.cleanArtist('Bad Bunny'), 'Bad Bunny');
      expect(AlbumSanitizer.cleanArtist('artista'), isNull);
      expect(AlbumSanitizer.cleanArtist('unknown artist'), isNull);
      expect(AlbumSanitizer.cleanArtist(null), isNull);
    });
  });
}
