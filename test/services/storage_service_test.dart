import 'package:flutter_test/flutter_test.dart';
import 'package:groovy/services/storage_service.dart';
import 'package:groovy/models/song.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('StorageService', () {
    late StorageService storageService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storageService = StorageService();
      storageService.clearCacheForTesting();
    });

    test('saveShuffleMode saves value', () async {
      await storageService.saveShuffleMode(true);
      expect(await storageService.getShuffleMode(), true);
    });

    test('getShuffleMode returns false by default', () async {
      expect(await storageService.getShuffleMode(), false);
    });

    test('saveShuffleMode updates value', () async {
      await storageService.saveShuffleMode(true);
      expect(await storageService.getShuffleMode(), true);
      await storageService.saveShuffleMode(false);
      expect(await storageService.getShuffleMode(), false);
    });

    test('addSongToHistory saves song and moves duplicate to top', () async {
      final song1 = Song(id: 's1', title: 'Song 1', artist: 'Artist 1');
      final song2 = Song(id: 's2', title: 'Song 2', artist: 'Artist 2');

      await storageService.addSongToHistory(song1);
      await storageService.addSongToHistory(song2);

      var history = await storageService.getPlaybackHistory();
      expect(history.length, 2);
      expect(history[0].id, 's2');
      expect(history[1].id, 's1');

      // Re-add song1: it should become the first item without duplicating
      await storageService.addSongToHistory(song1);
      history = await storageService.getPlaybackHistory();
      expect(history.length, 2);
      expect(history[0].id, 's1');
      expect(history[1].id, 's2');
    });

    test('clearPlaybackHistory removes all recorded songs', () async {
      final song = Song(id: 's1', title: 'Song 1', artist: 'Artist 1');
      await storageService.addSongToHistory(song);
      expect((await storageService.getPlaybackHistory()).length, 1);

      await storageService.clearPlaybackHistory();
      expect((await storageService.getPlaybackHistory()).isEmpty, true);
    });
  });
}
