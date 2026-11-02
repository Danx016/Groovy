import 'package:flutter_test/flutter_test.dart';
import 'package:groovy/models/song.dart';
import 'package:groovy/models/album.dart';
import 'package:groovy/models/artist.dart';
import 'package:groovy/services/deep_link_service.dart';

void main() {
  group('DeepLinkService - Sharing & Parsing Tests', () {
    final service = DeepLinkService();

    test('buildShareUrl creates clean Spotify-style HTTPS URL with encoded title, artist, album & cover', () {
      final song = Song(
        id: 'dQw4w9WgXcQ',
        title: 'No Me Vuelvas A Ilusionar',
        artist: 'Los Betos',
        album: '30 Grandes Exitos Vol. 2',
        coverArt: 'https://images.example.com/cover.jpg',
      );

      final shareUrl = DeepLinkService.buildShareUrl(song);
      expect(
        shareUrl,
        'https://groovyapi.duckdns.org/track/dQw4w9WgXcQ?title=No+Me+Vuelvas+A+Ilusionar&artist=Los+Betos&album=30+Grandes+Exitos+Vol.+2&cover=https%3A%2F%2Fimages.example.com%2Fcover.jpg',
      );

      // Verify prefix stripping for yt_
      final songWithPrefix = Song(
        id: 'yt_dQw4w9WgXcQ',
        title: 'Song With Prefix',
        artist: 'Artist',
      );
      final cleanShareUrl = DeepLinkService.buildShareUrl(songWithPrefix);
      expect(
        cleanShareUrl,
        'https://groovyapi.duckdns.org/track/dQw4w9WgXcQ?title=Song+With+Prefix&artist=Artist',
      );
    });

    test('buildGroovySchemeUrl builds native URI correctly', () {
      final song = Song(
        id: 'dQw4w9WgXcQ',
        title: 'Track',
        artist: 'Artist',
      );
      expect(DeepLinkService.buildGroovySchemeUrl(song), 'groovy://track/dQw4w9WgXcQ');
    });

    test('buildAlbumShareUrl and extractAlbumId work for albums', () {
      final album = Album(
        id: 'alb_12345',
        name: '30 Grandes Exitos Vol. 2',
        artist: 'Los Betos',
        year: 2003,
        coverArt: 'https://images.example.com/album.jpg',
      );

      final albumUrl = DeepLinkService.buildAlbumShareUrl(album);
      expect(albumUrl, contains('https://groovyapi.duckdns.org/album/alb_12345?'));
      expect(albumUrl, contains('title=30+Grandes+Exitos+Vol.+2'));
      expect(albumUrl, contains('artist=Los+Betos'));
      expect(albumUrl, contains('year=2003'));

      final uri = Uri.parse(albumUrl);
      final extractedId = service.extractAlbumId(uri);
      expect(extractedId, 'alb_12345');

      final nativeUri = Uri.parse('groovy://album/alb_12345');
      expect(service.extractAlbumId(nativeUri), 'alb_12345');
    });

    test('buildArtistShareUrl and extractArtistId work for artists', () {
      final artist = Artist(
        id: 'art_9876',
        name: 'Los Betos',
        artistImageUrl: 'https://images.example.com/artist.jpg',
      );

      final artistUrl = DeepLinkService.buildArtistShareUrl(artist);
      expect(artistUrl, 'https://groovyapi.duckdns.org/artist/art_9876?name=Los+Betos&image=https%3A%2F%2Fimages.example.com%2Fartist.jpg');

      final uri = Uri.parse(artistUrl);
      final extractedId = service.extractArtistId(uri);
      expect(extractedId, 'art_9876');

      final nativeUri = Uri.parse('groovy://artist/art_9876');
      expect(service.extractArtistId(nativeUri), 'art_9876');
    });

    test('extractTrackId correctly handles duckdns universal links with query params', () {
      final uri = Uri.parse(
        'https://groovyapi.duckdns.org/track/dQw4w9WgXcQ?title=No+Me+Vuelvas+A+Ilusionar&artist=Los+Betos',
      );
      final trackId = service.extractTrackId(uri);
      expect(trackId, 'dQw4w9WgXcQ');
      expect(uri.queryParameters['title'], 'No Me Vuelvas A Ilusionar');
      expect(uri.queryParameters['artist'], 'Los Betos');
    });

    test('extractTrackId correctly handles native groovy://track/ links', () {
      final uri = Uri.parse('groovy://track/dQw4w9WgXcQ');
      expect(service.extractTrackId(uri), 'dQw4w9WgXcQ');
    });

    test('extractTrackId correctly handles YouTube links', () {
      final shortUri = Uri.parse('https://youtu.be/dQw4w9WgXcQ');
      expect(service.extractTrackId(shortUri), 'dQw4w9WgXcQ');

      final watchUri = Uri.parse('https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(service.extractTrackId(watchUri), 'dQw4w9WgXcQ');

      final musicUri = Uri.parse('https://music.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(service.extractTrackId(musicUri), 'dQw4w9WgXcQ');
    });
  });
}
