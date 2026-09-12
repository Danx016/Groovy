import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:groovy/services/audio_cache_service.dart';
import 'package:groovy/services/cache_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioCacheService Tests', () {
    late AudioCacheService cacheService;
    late CacheSettingsService settingsService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settingsService = CacheSettingsService();
      await settingsService.initialize();
      await settingsService.setMusicCacheEnabled(true);
      cacheService = AudioCacheService();
      await cacheService.clearCache();
    });

    tearDown(() async {
      await cacheService.clearCache();
    });

    test('formatSize formats byte sizes correctly', () {
      expect(cacheService.formatSize(0), '0 B');
      expect(cacheService.formatSize(512), '512.0 B');
      expect(cacheService.formatSize(1024), '1.0 KB');
      expect(cacheService.formatSize(1024 * 1024), '1.0 MB');
      expect(cacheService.formatSize(15 * 1024 * 1024), '15.0 MB');
    });

    test('getCachedSongFile returns null when song is not cached', () async {
      final file = await cacheService.getCachedSongFile('non_existent_id');
      expect(file, isNull);
    });

    test('getCachedSongFile returns null when music cache is disabled', () async {
      await settingsService.setMusicCacheEnabled(false);
      final file = await cacheService.getCachedSongFile('any_id');
      expect(file, isNull);
    });

    test('Stores and retrieves cached file when valid size exists', () async {
      // Mock saving a cached file into cache dir
      final dir = Directory('${Directory.systemTemp.path}/groovy_music_cache');
      if (!await dir.exists()) await dir.create(recursive: true);

      final dummyFile = File('${dir.path}/test_song_123.audio');
      // Create a dummy audio file >= 100 KB
      final bytes = List<int>.filled(120 * 1024, 0x41);
      await dummyFile.writeAsBytes(bytes);

      final cached = await cacheService.getCachedSongFile('test_song_123');
      expect(cached, isNotNull);
      expect(await cached!.exists(), isTrue);
      expect(await cached.length(), 120 * 1024);

      final totalSize = await cacheService.getCacheSizeBytes();
      expect(totalSize, greaterThanOrEqualTo(120 * 1024));

      // Clear cache
      await cacheService.clearCache();
      expect(await dummyFile.exists(), isFalse);
      expect(await cacheService.getCacheSizeBytes(), 0);
    });
  });
}
