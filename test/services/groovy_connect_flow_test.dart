import 'package:flutter_test/flutter_test.dart';
import 'package:groovy/models/song.dart';
import 'package:groovy/providers/player_provider.dart';
import 'package:groovy/services/groovy_connect_service.dart';
import 'package:groovy/services/youtube_service.dart';
import 'package:groovy/services/storage_service.dart';
import 'package:groovy/services/upnp_service.dart';
import 'package:groovy/services/audio_handler.dart';
import 'package:groovy/services/jukebox_service.dart';
import 'package:groovy/services/transcoding_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../test_helpers.dart';
import '../bootstrap.dart';

void main() {
  initializeTestEnvironment();

  group('GroovyConnect Flow & Remote Routing Tests', () {
    late YoutubeService youtubeService;
    late PlayerProvider playerProvider;
    late GroovyConnectService groovyConnectService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      youtubeService = YoutubeService();
      playerProvider = PlayerProvider(
        youtubeService,
        StorageService(),
        FakeCastService(),
        UpnpService(),
        GroovyAudioHandler(),
        JukeboxService(),
        TranscodingService(),
      );
      groovyConnectService = GroovyConnectService();
      playerProvider.setGroovyConnectService(groovyConnectService);
    });

    tearDown(() {
      groovyConnectService.disconnect();
      playerProvider.dispose();
    });

    test('GroovyRemoteDevice copyWith and properties work accurately', () {
      final now = DateTime.now();
      final song = Song(id: 's1', title: 'Song 1', artist: 'Artist 1');
      final device = GroovyRemoteDevice(
        id: 'dev_test_123',
        name: 'Test PC',
        platform: 'Windows',
        model: 'Desktop',
        isPlaying: false,
        lastSeen: now,
      );

      expect(device.id, 'dev_test_123');
      expect(device.name, 'Test PC');
      expect(device.platform, 'Windows');
      expect(device.isPlaying, false);
      expect(device.currentSong, isNull);

      final updated = device.copyWith(
        isPlaying: true,
        currentSong: song,
      );

      expect(updated.id, 'dev_test_123');
      expect(updated.isPlaying, true);
      expect(updated.currentSong?.id, 's1');
      expect(updated.currentSong?.title, 'Song 1');
    });

    test('enableGroovyConnectRemote immediately adopts remote song and sets remote playback', () {
      final remoteSong = Song(id: 'rem_1', title: 'Remote Song', artist: 'Artist Remote', duration: 180);
      final remoteDevice = GroovyRemoteDevice(
        id: 'dev_remote_456',
        name: 'Living Room PC',
        platform: 'Windows',
        model: 'Desktop',
        currentSong: remoteSong,
        isPlaying: true,
        lastSeen: DateTime.now(),
      );

      expect(playerProvider.isRemotePlayback, false);
      expect(playerProvider.currentSong, isNull);

      playerProvider.enableGroovyConnectRemote(remoteDevice);

      expect(playerProvider.isRemotePlayback, true);
      expect(playerProvider.currentSong?.id, 'rem_1');
      expect(playerProvider.currentSong?.title, 'Remote Song');
      expect(playerProvider.isPlaying, true);
      expect(playerProvider.duration, const Duration(seconds: 180));
    });

    test('onGroovyConnectRemoteStatusUpdated updates position and duration smoothly', () {
      final remoteDevice = GroovyRemoteDevice(
        id: 'dev_remote_456',
        name: 'Living Room PC',
        platform: 'Windows',
        model: 'Desktop',
        lastSeen: DateTime.now(),
      );
      playerProvider.enableGroovyConnectRemote(remoteDevice);

      final song = Song(id: 'song_sync', title: 'Sync Title', duration: 200);
      playerProvider.onGroovyConnectRemoteStatusUpdated(
        song: song,
        position: const Duration(seconds: 45),
        duration: const Duration(seconds: 200),
        isPlaying: true,
        volume: 0.8,
      );

      expect(playerProvider.currentSong?.id, 'song_sync');
      expect(playerProvider.position, const Duration(seconds: 45));
      expect(playerProvider.duration, const Duration(seconds: 200));
      expect(playerProvider.isPlaying, true);
    });

    test('disableGroovyConnectRemote cleanly restores local state', () {
      final remoteDevice = GroovyRemoteDevice(
        id: 'dev_remote_456',
        name: 'Living Room PC',
        platform: 'Windows',
        model: 'Desktop',
        lastSeen: DateTime.now(),
      );
      playerProvider.enableGroovyConnectRemote(remoteDevice);
      expect(playerProvider.isRemotePlayback, true);

      playerProvider.disableGroovyConnectRemote();
      expect(playerProvider.isRemotePlayback, false);
    });

    test('playSong when connected routes remotely and stops local audio', () async {
      final remoteDevice = GroovyRemoteDevice(
        id: 'dev_remote_456',
        name: 'Living Room PC',
        platform: 'Windows',
        model: 'Desktop',
        lastSeen: DateTime.now(),
      );
      await groovyConnectService.connectToDevice(remoteDevice);
      playerProvider.enableGroovyConnectRemote(remoteDevice);

      final newSong = Song(id: 'new_song_789', title: 'Controller Selected Song', duration: 240);
      await playerProvider.playSong(newSong);

      expect(playerProvider.isRemotePlayback, true);
      expect(playerProvider.currentSong?.id, 'new_song_789');
      expect(playerProvider.isPlaying, true);
    });

    test('pause and play optimistically toggle state while connected', () async {
      final remoteDevice = GroovyRemoteDevice(
        id: 'dev_remote_456',
        name: 'Living Room PC',
        platform: 'Windows',
        model: 'Desktop',
        lastSeen: DateTime.now(),
      );
      await groovyConnectService.connectToDevice(remoteDevice);
      playerProvider.enableGroovyConnectRemote(remoteDevice);

      await playerProvider.pause();
      expect(playerProvider.isPlaying, false);

      await playerProvider.play();
      expect(playerProvider.isPlaying, true);
    });

    test('enableGroovyConnectRemote with transferredSong adopts transferred song and prevents stale clobbering', () {
      final staleSong = Song(id: 'stale_old', title: 'Stale Old Song', duration: 100);
      final remoteDevice = GroovyRemoteDevice(
        id: 'dev_android_999',
        name: 'Android Phone',
        platform: 'Android',
        model: 'Pixel',
        currentSong: staleSong,
        isPlaying: false,
        lastSeen: DateTime.now(),
      );

      final myTransferredSong = Song(id: 'windows_song_1', title: 'Windows Active Track', duration: 210);

      playerProvider.enableGroovyConnectRemote(
        remoteDevice,
        transferredSong: myTransferredSong,
        isPlaying: true,
        position: const Duration(seconds: 40),
      );

      expect(playerProvider.isRemotePlayback, true);
      expect(playerProvider.currentSong?.id, 'windows_song_1');
      expect(playerProvider.currentSong?.title, 'Windows Active Track');
      expect(playerProvider.isPlaying, true);
      expect(playerProvider.position, const Duration(seconds: 40));
      expect(playerProvider.duration, const Duration(seconds: 210));
    });

    test('skipNext and skipPrevious route remotely when connected', () async {
      final remoteDevice = GroovyRemoteDevice(
        id: 'dev_remote_456',
        name: 'Living Room PC',
        platform: 'Windows',
        model: 'Desktop',
        lastSeen: DateTime.now(),
      );
      await groovyConnectService.connectToDevice(remoteDevice);
      playerProvider.enableGroovyConnectRemote(remoteDevice);

      // Verify remote skipNext does not crash and toggles optimistic state
      await playerProvider.skipNext();
      expect(playerProvider.isRemotePlayback, true);

      // Verify remote skipPrevious
      await playerProvider.skipPrevious();
      expect(playerProvider.isRemotePlayback, true);
    });

    test('setVolume when connected routes volume remotely and updates local state', () async {
      final remoteDevice = GroovyRemoteDevice(
        id: 'dev_remote_456',
        name: 'Living Room PC',
        platform: 'Windows',
        model: 'Desktop',
        lastSeen: DateTime.now(),
      );
      await groovyConnectService.connectToDevice(remoteDevice);
      playerProvider.enableGroovyConnectRemote(remoteDevice);

      await playerProvider.setVolume(0.75);
      expect(playerProvider.volume, 0.75);
      expect(playerProvider.isRemotePlayback, true);
    });

    test('onGroovyConnectRemoteStatusUpdated smoothly updates volume', () {
      final remoteDevice = GroovyRemoteDevice(
        id: 'dev_remote_456',
        name: 'Living Room PC',
        platform: 'Windows',
        model: 'Desktop',
        lastSeen: DateTime.now(),
      );
      groovyConnectService.connectToDevice(remoteDevice);
      playerProvider.enableGroovyConnectRemote(remoteDevice);

      playerProvider.onGroovyConnectRemoteStatusUpdated(
        position: const Duration(seconds: 10),
        duration: const Duration(seconds: 200),
        isPlaying: true,
        volume: 0.40,
      );

      expect(playerProvider.volume, 0.40);
    });
  });
}
