import 'package:flutter_test/flutter_test.dart';
import 'package:groovy/utils/song_title_utils.dart';
import 'package:groovy/models/song.dart';

void main() {
  group('SongTitleUtils', () {
    test('normalizes video, audio, lyric noise from titles', () {
      expect(
        SongTitleUtils.normalizeTitle('Moscow Mule (Video Oficial)'),
        equals('moscow mule'),
      );
      expect(
        SongTitleUtils.normalizeTitle('Moscow Mule (Official Audio)'),
        equals('moscow mule'),
      );
      expect(
        SongTitleUtils.normalizeTitle('Bad Bunny - Moscow Mule [Audio]'),
        equals('moscow mule'),
      );
      expect(
        SongTitleUtils.normalizeTitle('Tití Me Preguntó (Letra / Lyrics)'),
        equals('titi me pregunto'),
      );
      expect(
        SongTitleUtils.normalizeTitle('Tití Me Preguntó (360° Visualizer)'),
        equals('titi me pregunto'),
      );
    });

    test('areTitlesSame correctly detects versions of the same song', () {
      expect(
        SongTitleUtils.areTitlesSame(
          'Moscow Mule',
          'Moscow Mule (Video Oficial)',
        ),
        isTrue,
      );
      expect(
        SongTitleUtils.areTitlesSame(
          'Tití Me Preguntó',
          'Tití Me Preguntó (Official Audio)',
        ),
        isTrue,
      );
      expect(
        SongTitleUtils.areTitlesSame(
          'Moscow Mule',
          'Yonaguni',
        ),
        isFalse,
      );
      expect(
        SongTitleUtils.areTitlesSame(
          'Moscow Mule',
          'Me Porto Bonito',
        ),
        isFalse,
      );
    });

    test('deduplicates a list of songs with redundant title variations', () {
      final songs = [
        Song(id: '1', title: 'Moscow Mule (Official Video)', artist: 'Bad Bunny'),
        Song(id: '2', title: 'Moscow Mule (Audio)', artist: 'Bad Bunny'),
        Song(id: '3', title: 'Yonaguni', artist: 'Bad Bunny'),
        Song(id: '4', title: 'Moscow Mule [Lyrics]', artist: 'Bad Bunny'),
        Song(id: '5', title: 'Me Porto Bonito', artist: 'Bad Bunny'),
      ];

      final seenTitles = <String>{};
      final deduplicated = songs.where((s) {
        final norm = SongTitleUtils.normalizeTitle(s.title);
        return norm.isEmpty || seenTitles.add(norm);
      }).toList();

      expect(deduplicated.length, equals(3));
      expect(deduplicated[0].id, equals('1'));
      expect(deduplicated[1].id, equals('3'));
      expect(deduplicated[2].id, equals('5'));
    });
  });
}
