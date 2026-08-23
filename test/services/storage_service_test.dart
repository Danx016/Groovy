import 'package:flutter_test/flutter_test.dart';
import 'package:groovy/services/storage_service.dart';
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
  });
}
