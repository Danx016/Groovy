import 'package:flutter_test/flutter_test.dart';
import 'package:groovy/services/lrclib_service.dart';

void main() {
  group('LrcLibService Title and Artist Cleaning', () {
    test('cleans official video fluff from YouTube titles', () {
      expect(
        LrcLibService.cleanTitle('Bohemian Rhapsody (Official Video)'),
        equals('Bohemian Rhapsody'),
      );
      expect(
        LrcLibService.cleanTitle('Numb [Official Music Video 4K]'),
        equals('Numb'),
      );
      expect(
        LrcLibService.cleanTitle('In the End (Official HD Video)'),
        equals('In the End'),
      );
      expect(
        LrcLibService.cleanTitle('Starboy ft. Daft Punk (Official Audio)'),
        equals('Starboy'),
      );
      expect(
        LrcLibService.cleanTitle('Queen - Another One Bites the Dust (Remastered 2011)'),
        equals('Another One Bites the Dust'),
      );
      expect(
        LrcLibService.cleanTitle('Shape of You [Official Lyric Video]'),
        equals('Shape of You'),
      );
      expect(
        LrcLibService.cleanTitle('Blinding Lights (Visualizer)'),
        equals('Blinding Lights'),
      );
      expect(
        LrcLibService.cleanTitle('Ramz - Barking (Audio)'),
        equals('Barking'),
      );
      expect(
        LrcLibService.cleanTitle('Eminem - Houdini (Official Video)'),
        equals('Houdini'),
      );
      expect(
        LrcLibService.cleanTitle('Kendrick Lamar - HUMBLE.'),
        equals('HUMBLE.'),
      );
      expect(
        LrcLibService.cleanTitle('MONACO (Video Oficial)'),
        equals('MONACO'),
      );
      expect(
        LrcLibService.cleanTitle('Columbia [En Vivo]'),
        equals('Columbia'),
      );
      expect(
        LrcLibService.cleanTitle('Luna (Audio Oficial)'),
        equals('Luna'),
      );
    });

    test('cleans artist names from YouTube Music channels', () {
      expect(
        LrcLibService.cleanArtist('The Weeknd - Topic'),
        equals('The Weeknd'),
      );
      expect(
        LrcLibService.cleanArtist('QueenVEVO'),
        equals('Queen'),
      );
      expect(
        LrcLibService.cleanArtist('Eminem ft. Rihanna'),
        equals('Eminem'),
      );
      expect(
        LrcLibService.cleanArtist('Diomedes Diaz Oficial'),
        equals('Diomedes Diaz'),
      );
      expect(
        LrcLibService.cleanArtist('Canal Oficial Bad Bunny'),
        equals('Canal Oficial Bad Bunny'),
      );
      expect(
        LrcLibService.cleanArtist('Bad Bunny Canal Oficial'),
        equals('Bad Bunny'),
      );
    });

    test('normalizes diacritics and casing for fuzzy matching', () {
      expect(
        LrcLibService.normalizeForMatching('Páginas De Oro'),
        equals(LrcLibService.normalizeForMatching('Paginas De Oro')),
      );
      expect(
        LrcLibService.normalizeForMatching('Diomedes Díaz'),
        equals(LrcLibService.normalizeForMatching('Diomedes Diaz')),
      );
    });

    test('extracts primary artist properly from collaboration strings', () {
      expect(
        LrcLibService.primaryArtist('Bad Bunny, Feid'),
        equals('Bad Bunny'),
      );
      expect(
        LrcLibService.primaryArtist('FloyyMenor & Cris Mj'),
        equals('FloyyMenor'),
      );
      expect(
        LrcLibService.primaryArtist('Eslabon Armado, Peso Pluma'),
        equals('Eslabon Armado'),
      );
    });

    test('searchLyrics finds synced lyrics for YouTube title formats', () async {
      final result = await LrcLibService().searchLyrics(
        artist: 'Music Zone',
        title: 'Ramz - Barking (Audio)',
      );

      expect(result, isNotNull);
      expect(result!['value'], isNotNull);
      expect(result['value'].toString().toLowerCase(), contains('barkin'));
      expect(result['structuredLyrics'], isNotNull);
    });

    test('searchLyrics finds synced lyrics for Diomedes Diaz Oficial - Paginas De Oro', () async {
      final result = await LrcLibService().searchLyrics(
        artist: 'Diomedes Diaz Oficial',
        title: 'Paginas De Oro',
        durationSeconds: 251,
      );

      expect(result, isNotNull);
      expect(result!['value'], isNotNull);
      expect(result['value'].toString().toLowerCase(), contains('página linda'));
    });
  });
}
