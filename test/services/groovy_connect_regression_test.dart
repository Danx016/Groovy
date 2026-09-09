import 'package:flutter_test/flutter_test.dart';
import 'package:groovy/models/song.dart';
import 'package:groovy/providers/player_provider.dart';
import 'package:groovy/services/groovy_connect_service.dart';
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

  group('Groovy Connect Jitter & Control Regression Tests', () {
    late YoutubeService youtubeService;
    late PlayerProvider playerProvider;
    late GroovyConnectService groovyConnectService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      youtubeService = YoutubeService();
      groovyConnectService = GroovyConnectService();

      playerProvider = PlayerProvider(
        youtubeService,
        StorageService(),
        FakeCastService(),
        UpnpService(),
        GroovyAudioHandler(),
        TranscodingService(),
      );

      playerProvider.setGroovyConnectService(groovyConnectService);
    });

    tearDown(() {
      groovyConnectService.disconnect();
      playerProvider.dispose();
    });

    test('Remote progress bar does NOT jump backward on delayed 1s telemetry packets while at 3s', () async {
      final remoteDev = GroovyRemoteDevice(
        id: 'dev_test_1',
        name: 'Remote Phone',
        platform: 'Android',
        model: 'Pixel 8',
        host: '192.168.1.100',
        port: 42425,
        lastSeen: DateTime.now(),
      );

      final song = Song(
        id: 'song_anti_jitter',
        title: 'Anti Jitter Anthem',
        duration: 240,
      );

      // Connect to remote device
      await groovyConnectService.connectToDevice(remoteDev);
      playerProvider.enableGroovyConnectRemote(remoteDev);

      // Initial status: starts at 1 second, playing
      playerProvider.onGroovyConnectRemoteStatusUpdated(
        song: song,
        position: const Duration(seconds: 1),
        duration: const Duration(seconds: 240),
        isPlaying: true,
        volume: 1.0,
      );

      expect(playerProvider.isPlaying, isTrue);
      expect(playerProvider.position.inSeconds, 1);

      // Simulate local extrapolation progressing to 3 seconds
      await Future.delayed(const Duration(milliseconds: 2100));
      final posAt3s = playerProvider.position;
      expect(posAt3s.inSeconds, greaterThanOrEqualTo(3),
          reason: 'Dead reckoning extrapolation should advance forward smoothly');

      // Now simulate arrival of a delayed/stale cloud telemetry packet reporting position: 1s
      playerProvider.onGroovyConnectRemoteStatusUpdated(
        song: song,
        position: const Duration(seconds: 1),
        duration: const Duration(seconds: 240),
        isPlaying: true,
        volume: 1.0,
      );

      // The anti-jitter filter MUST keep position at >= 3s, not pull it back to 1s!
      expect(playerProvider.position.inSeconds, greaterThanOrEqualTo(3),
          reason: 'Position must not jump back to 1s on stale telemetry packets');
    });

    test('Remote progress snaps on genuine backward seek (> 8 seconds difference)', () async {
      final remoteDev = GroovyRemoteDevice(
        id: 'dev_test_seek',
        name: 'Remote Phone',
        platform: 'Android',
        model: 'Pixel 8',
        host: '192.168.1.100',
        port: 42425,
        lastSeen: DateTime.now(),
      );

      final song = Song(
        id: 'song_long',
        title: 'Long Symphony',
        duration: 300,
      );

      await groovyConnectService.connectToDevice(remoteDev);
      playerProvider.enableGroovyConnectRemote(remoteDev);

      // Initially at 2 minutes (120s)
      playerProvider.onGroovyConnectRemoteStatusUpdated(
        song: song,
        position: const Duration(seconds: 120),
        duration: const Duration(seconds: 300),
        isPlaying: true,
        volume: 1.0,
      );
      expect(playerProvider.position.inSeconds, 120);

      // Genuine remote seek back to 10 seconds (difference is -110 seconds, far below -8s)
      playerProvider.onGroovyConnectRemoteStatusUpdated(
        song: song,
        position: const Duration(seconds: 10),
        duration: const Duration(seconds: 300),
        isPlaying: true,
        volume: 1.0,
      );

      expect(playerProvider.position.inSeconds, 10,
          reason: 'Genuine backward seeks on the remote device must be accepted');
    });

    test('Remote progress snaps on genuine forward jump (> 2.5 seconds)', () async {
      final remoteDev = GroovyRemoteDevice(
        id: 'dev_test_fwd',
        name: 'Remote Phone',
        platform: 'Android',
        model: 'Pixel 8',
        host: '192.168.1.100',
        port: 42425,
        lastSeen: DateTime.now(),
      );

      final song = Song(
        id: 'song_fwd',
        title: 'Fast Forward Song',
        duration: 300,
      );

      await groovyConnectService.connectToDevice(remoteDev);
      playerProvider.enableGroovyConnectRemote(remoteDev);

      // Initially at 10s
      playerProvider.onGroovyConnectRemoteStatusUpdated(
        song: song,
        position: const Duration(seconds: 10),
        duration: const Duration(seconds: 300),
        isPlaying: true,
        volume: 1.0,
      );

      // Jump forward to 40s
      playerProvider.onGroovyConnectRemoteStatusUpdated(
        song: song,
        position: const Duration(seconds: 40),
        duration: const Duration(seconds: 300),
        isPlaying: true,
        volume: 1.0,
      );

      expect(playerProvider.position.inSeconds, 40);
    });

    test('Remote pause and play update UI state instantaneously without freezing', () async {
      final remoteDev = GroovyRemoteDevice(
        id: 'dev_test_ctrl',
        name: 'Remote Tablet',
        platform: 'Android',
        model: 'Tab S9',
        // Deliberately unreachable IP to verify that timeout does NOT block the UI
        host: '192.0.2.1',
        port: 42425,
        isLocalLan: true,
        lastSeen: DateTime.now(),
      );

      await groovyConnectService.connectToDevice(remoteDev);
      playerProvider.enableGroovyConnectRemote(remoteDev);

      // Simulate it currently playing
      playerProvider.onGroovyConnectRemoteStatusUpdated(
        song: Song(id: 's1', title: 'Remote Beat'),
        position: const Duration(seconds: 15),
        duration: const Duration(seconds: 200),
        isPlaying: true,
        volume: 0.8,
      );
      expect(playerProvider.isPlaying, isTrue);

      final swPause = Stopwatch()..start();
      await playerProvider.pause();
      swPause.stop();

      // Pause must return within milliseconds and update isPlaying to false immediately!
      expect(playerProvider.isPlaying, isFalse, reason: 'Pause must update state to false immediately');
      expect(swPause.elapsedMilliseconds, lessThan(600), reason: 'Pause must not hang awaiting network response');

      final swPlay = Stopwatch()..start();
      await playerProvider.play();
      swPlay.stop();

      expect(playerProvider.isPlaying, isTrue, reason: 'Play must update state to true immediately');
      expect(swPlay.elapsedMilliseconds, lessThan(600), reason: 'Play must not hang awaiting network response');
    });

    test('Remote seek preserves controller position during 4-second grace cooldown', () async {
      final remoteDev = GroovyRemoteDevice(
        id: 'dev_test_grace',
        name: 'Remote Device',
        platform: 'Android',
        model: 'Pixel',
        host: '192.0.2.1',
        port: 42425,
        lastSeen: DateTime.now(),
      );

      await groovyConnectService.connectToDevice(remoteDev);
      playerProvider.enableGroovyConnectRemote(remoteDev);

      final song = Song(id: 's_grace', title: 'Grace Song', duration: 180);
      playerProvider.onGroovyConnectRemoteStatusUpdated(
        song: song,
        position: const Duration(seconds: 5),
        duration: const Duration(seconds: 180),
        isPlaying: true,
        volume: 1.0,
      );

      // User seeks to 75 seconds on controller
      await playerProvider.seek(const Duration(seconds: 75));
      expect(playerProvider.position.inSeconds, 75);

      // A stale packet arrives right after reporting the old 5s position
      playerProvider.onGroovyConnectRemoteStatusUpdated(
        song: song,
        position: const Duration(seconds: 5),
        duration: const Duration(seconds: 180),
        isPlaying: true,
        volume: 1.0,
      );

      // Position must remain at 75s (protected by seek grace period)
      expect(playerProvider.position.inSeconds, 75,
          reason: 'Controller seek must not be overwritten by stale pre-seek network packets');
    });

    test('sendControl optimistically updates connected device playback state', () async {
      final remoteDev = GroovyRemoteDevice(
        id: 'dev_optimistic',
        name: 'Speaker',
        platform: 'Linux',
        model: 'RPi',
        host: '192.0.2.1',
        port: 42425,
        isLocalLan: true,
        isPlaying: false,
        lastSeen: DateTime.now(),
      );

      await groovyConnectService.connectToDevice(remoteDev);
      expect(groovyConnectService.connectedDevice?.isPlaying, isFalse);

      // sendControl('play') should update connectedDevice.isPlaying to true
      groovyConnectService.sendControl('play');
      expect(groovyConnectService.connectedDevice?.isPlaying, isTrue);

      // sendControl('pause') should update connectedDevice.isPlaying to false
      groovyConnectService.sendControl('pause');
      expect(groovyConnectService.connectedDevice?.isPlaying, isFalse);
    });

    test('Remote volume set to maximum (1.0) does NOT snap back to middle (0.5) on stale remote packets', () async {
      final remoteDev = GroovyRemoteDevice(
        id: 'dev_volume_test',
        name: 'Remote Living Room',
        platform: 'Android',
        model: 'Pixel 7',
        lastSeen: DateTime.now(),
      );

      final song = Song(
        id: 'song_vol_1',
        title: 'Volume Test Track',
        duration: 200,
      );

      await groovyConnectService.connectToDevice(remoteDev);
      playerProvider.enableGroovyConnectRemote(remoteDev);

      // Initially remote reported volume was 0.5 (middle)
      playerProvider.onGroovyConnectRemoteStatusUpdated(
        song: song,
        position: const Duration(seconds: 10),
        duration: const Duration(seconds: 200),
        isPlaying: true,
        volume: 0.5,
      );
      expect(playerProvider.volume, 0.5);

      // User sets volume to maximum (1.0) on controller
      await playerProvider.setVolume(1.0);
      expect(playerProvider.volume, 1.0, reason: 'Local volume should immediately be 1.0');

      // A stale remote status report arrives right after with volume 0.5
      playerProvider.onGroovyConnectRemoteStatusUpdated(
        song: song,
        position: const Duration(seconds: 11),
        duration: const Duration(seconds: 200),
        isPlaying: true,
        volume: 0.5,
      );

      // Volume must remain at 1.0, NOT snap back to 0.5!
      expect(playerProvider.volume, 1.0,
          reason: 'Remote volume at maximum (1.0) must not snap back to middle (0.5) due to optimistic lock');
    });
  });
}
