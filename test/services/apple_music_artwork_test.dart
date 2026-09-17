import 'package:flutter_test/flutter_test.dart';
import 'package:groovy/services/apple_music_artwork_service.dart';
import 'package:groovy/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppleMusicArtworkService Tests', () {
    test('cleanSongTitle removes YouTube markers and video metadata', () {
      expect(
        AppleMusicArtworkService.cleanSongTitle('Blinding Lights [Official Music Video]'),
        'Blinding Lights',
      );
      expect(
        AppleMusicArtworkService.cleanSongTitle('Starboy (Official Video) ft. Daft Punk'),
        'Starboy',
      );
      expect(
        AppleMusicArtworkService.cleanSongTitle('As It Was (Lyric Video)'),
        'As It Was',
      );
      expect(
        AppleMusicArtworkService.cleanSongTitle('Ella Baila Sola [Visualizer]'),
        'Ella Baila Sola',
      );
      expect(
        AppleMusicArtworkService.cleanSongTitle('In the End (Official Audio) [4K]'),
        'In the End',
      );
      expect(
        AppleMusicArtworkService.cleanSongTitle('Hotel California (Remastered 2013)'),
        'Hotel California',
      );
    });

    test('cleanArtistName removes YouTube channels and Topic suffixes', () {
      expect(
        AppleMusicArtworkService.cleanArtistName('The Weeknd - Topic'),
        'The Weeknd',
      );
      expect(
        AppleMusicArtworkService.cleanArtistName('ColdplayVEVO'),
        'Coldplay',
      );
      expect(
        AppleMusicArtworkService.cleanArtistName('artist_taylor_swift'),
        'taylor_swift',
      );
    });

    test('AppleMusicArtworkResult serialization works correctly', () {
      final result = AppleMusicArtworkResult(
        artworkUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music/v4/1400x1400bb.jpg',
        albumName: 'After Hours',
        artistName: 'The Weeknd',
        trackName: 'Blinding Lights',
        trackViewUrl: 'https://music.apple.com/us/album/blinding-lights/1499378108?i=1499378607',
        collectionViewUrl: 'https://music.apple.com/us/album/after-hours/1499378108',
        collectionId: 1499378108,
      );

      final json = result.toJson();
      expect(json['artworkUrl'], contains('1400x1400bb.jpg'));
      expect(json['albumName'], 'After Hours');
      expect(json['collectionId'], 1499378108);

      final fromJson = AppleMusicArtworkResult.fromJson(json);
      expect(fromJson.artworkUrl, result.artworkUrl);
      expect(fromJson.albumName, result.albumName);
      expect(fromJson.trackViewUrl, result.trackViewUrl);
      expect(fromJson.collectionId, result.collectionId);
    });

    test('resolveArtworkForSong returns null for local songs', () async {
      final localSong = Song(
        id: 'local_1',
        title: 'My Voice Note',
        isLocal: true,
        path: '/storage/music/note.mp3',
      );

      final result = await AppleMusicArtworkService().resolveArtworkForSong(localSong);
      expect(result, isNull);
    });
  });
}
