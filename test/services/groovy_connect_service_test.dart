import 'package:flutter_test/flutter_test.dart';
import 'package:groovy/models/song.dart';
import 'package:groovy/services/groovy_connect_service.dart';

void main() {
  group('GroovyConnectService and GroovyRemoteDevice Tests', () {
    test('GroovyRemoteDevice serializes and deserializes properly', () {
      final song = Song(
        id: 'test_song_1',
        title: 'Song of the Wind',
        artist: 'Danilo',
        album: 'Acoustic Dreams',
        duration: 180,
      );

      final device = GroovyRemoteDevice(
        id: 'android_12345',
        name: 'Danilo Samsung Galaxy',
        platform: 'Android',
        model: 'Galaxy S23',
        host: '192.168.1.55',
        port: 42425,
        isLocalLan: true,
        currentSong: song,
        isPlaying: true,
        lastSeen: DateTime.now(),
      );

      final json = device.toJson();
      expect(json['id'], 'android_12345');
      expect(json['name'], 'Danilo Samsung Galaxy');
      expect(json['platform'], 'Android');
      expect(json['isPlaying'], true);
      expect(json['song']['title'], 'Song of the Wind');

      final fromJson = GroovyRemoteDevice.fromJson(json, host: '192.168.1.55', port: 42425);
      expect(fromJson.id, 'android_12345');
      expect(fromJson.name, 'Danilo Samsung Galaxy');
      expect(fromJson.currentSong?.title, 'Song of the Wind');
      expect(fromJson.isPlaying, true);
    });

    test('GroovyConnectService state transitions', () {
      final service = GroovyConnectService();
      expect(service.isConnected, isFalse);
      expect(service.connectedDevice, isNull);

      final testDev = GroovyRemoteDevice(
        id: 'win_1',
        name: 'Desktop PC',
        platform: 'Windows',
        model: 'PC',
        host: '127.0.0.1',
        port: 42425,
        lastSeen: DateTime.now(),
      );
      expect(testDev.name, 'Desktop PC');

      // Verify disconnect clears state safely
      service.disconnect();
      expect(service.isConnected, isFalse);
      expect(service.connectedDevice, isNull);
    });
  });
}
