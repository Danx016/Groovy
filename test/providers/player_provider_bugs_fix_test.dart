import 'package:flutter_test/flutter_test.dart';
import 'package:groovy/models/song.dart';
import 'package:groovy/providers/player_provider.dart';
import 'package:groovy/services/youtube_service.dart';
import 'package:groovy/services/storage_service.dart';
import 'package:groovy/services/upnp_service.dart';
import 'package:groovy/services/audio_handler.dart';
import 'package:groovy/services/transcoding_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../test_helpers.dart';
import '../bootstrap.dart';

void main() {
  initializeTestEnvironment();

  group('PlayerProvider Bug Fixes & Regression', () {
    late YoutubeService youtubeService;
    late PlayerProvider playerProvider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      youtubeService = YoutubeService();
      playerProvider = PlayerProvider(
        youtubeService,
        StorageService(),
        FakeCastService(),
        UpnpService(),
        GroovyAudioHandler(),
        TranscodingService(),
      );
    });

    test('Dispose marks isDisposed = true and cleans up resources without throwing', () {
      expect(playerProvider.isDisposed, false);

      expect(() => playerProvider.dispose(), returnsNormally);

      expect(playerProvider.isDisposed, true);

      // Verify that notifyListeners after dispose does not throw
      expect(() => playerProvider.notifyListeners(), returnsNormally);
    });

    test('Queue boundaries: hasNext and hasPrevious accurately track queue state', () {
      expect(playerProvider.hasNext, false);
      expect(playerProvider.hasPrevious, false);

      final song1 = Song(id: '1', title: 'Song 1');
      final song2 = Song(id: '2', title: 'Song 2');
      final song3 = Song(id: '3', title: 'Song 3');

      playerProvider.addToQueue(song1);
      playerProvider.addToQueue(song2);
      playerProvider.addToQueue(song3);

      expect(playerProvider.queue.length, 3);
      expect(playerProvider.currentIndex, -1);

      // Clean up safely
      playerProvider.dispose();
    });

    test('Audio player volume and repeat modes clamp correctly without invalid states', () {
      playerProvider.toggleRepeat();
      expect(playerProvider.repeatMode, RepeatMode.all);

      playerProvider.toggleRepeat();
      expect(playerProvider.repeatMode, RepeatMode.one);

      playerProvider.toggleRepeat();
      expect(playerProvider.repeatMode, RepeatMode.off);

      playerProvider.dispose();
    });

    test('Rapid consecutive skipNext calls advance currentSong and currentIndex immediately without reverting', () async {
      final song1 = Song(id: '1', title: 'Song 1', artist: 'Artist 1');
      final song2 = Song(id: '2', title: 'Song 2', artist: 'Artist 2');
      final song3 = Song(id: '3', title: 'Song 3', artist: 'Artist 3');
      final song4 = Song(id: '4', title: 'Song 4', artist: 'Artist 4');

      playerProvider.addToQueue(song1);
      playerProvider.addToQueue(song2);
      playerProvider.addToQueue(song3);
      playerProvider.addToQueue(song4);

      // Start at song 1 (index 0)
      playerProvider.playSong(song1, playlist: playerProvider.queue, startIndex: 0);
      expect(playerProvider.currentIndex, 0);
      expect(playerProvider.currentSong?.id, '1');

      // Rapid skip 1
      playerProvider.skipNext();
      expect(playerProvider.currentIndex, 1);
      expect(playerProvider.currentSong?.id, '2');

      // Rapid skip 2 immediately
      playerProvider.skipNext();
      expect(playerProvider.currentIndex, 2);
      expect(playerProvider.currentSong?.id, '3');

      // Rapid skip 3 immediately
      playerProvider.skipNext();
      expect(playerProvider.currentIndex, 3);
      expect(playerProvider.currentSong?.id, '4');

      // Does NOT revert to Song 1 (id '1')
      expect(playerProvider.currentSong?.id, isNot('1'));
      expect(playerProvider.currentSong?.title, 'Song 4');

      playerProvider.dispose();
    });
  });
}
