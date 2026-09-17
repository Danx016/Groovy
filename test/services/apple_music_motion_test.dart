import 'package:flutter_test/flutter_test.dart';
import 'package:groovy/services/apple_music_artwork_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppleMusicArtworkService Motion Artwork Tests', () {
    test('AppleMusicArtworkResult serializes and deserializes motionVideoUrl', () {
      final sample = AppleMusicArtworkResult(
        artworkUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music/v4/1400x1400bb.jpg',
        albumName: 'After Hours',
        artistName: 'The Weeknd',
        collectionViewUrl: 'https://music.apple.com/us/album/after-hours/1499378108',
        motionVideoUrl:
            'https://mvod.itunes.apple.com/itunes-assets/HLSMusic126/v4/0e/66/6b/P359476169_default.m3u8',
      );

      final json = sample.toJson();
      expect(json['motionVideoUrl'], contains('P359476169_default.m3u8'));

      final fromJson = AppleMusicArtworkResult.fromJson(json);
      expect(fromJson.motionVideoUrl, sample.motionVideoUrl);
      expect(fromJson.artworkUrl, sample.artworkUrl);
    });

    test('copyWith updates motionVideoUrl cleanly', () {
      const initial = AppleMusicArtworkResult(
        artworkUrl: 'https://mzstatic.com/art.jpg',
        albumName: 'Future Nostalgia',
      );
      expect(initial.motionVideoUrl, isNull);

      final updated = initial.copyWith(
        motionVideoUrl: 'https://mvod.itunes.apple.com/test.m3u8',
      );
      expect(updated.motionVideoUrl, 'https://mvod.itunes.apple.com/test.m3u8');
      expect(updated.albumName, 'Future Nostalgia');
      expect(updated.artworkUrl, 'https://mzstatic.com/art.jpg');
    });
  });
}
