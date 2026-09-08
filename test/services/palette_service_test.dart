import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy/services/palette_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PaletteService Tests', () {
    test('defaultPalette contains 5 dark atmospheric tones', () {
      expect(PaletteService.defaultPalette.length, 5);
      expect(PaletteService.defaultPalette.first, const Color(0xFF16161E));
    });

    test('getCachedColors returns null when key not in cache', () {
      expect(PaletteService.getCachedColors('non_existent_key_12345'), isNull);
    });

    test('extractColors handles errors gracefully and returns defaultPalette', () async {
      // Dummy image provider that fails or cannot be decoded in headless test
      const dummyProvider = AssetImage('assets/non_existent.png');
      final colors = await PaletteService.extractColors(dummyProvider, 'error_test_song');
      
      expect(colors, isNotEmpty);
      expect(colors.length, 5);
      expect(colors, equals(PaletteService.defaultPalette));
    });

    test('getCachedColors returns cached result after extraction', () async {
      final cached = PaletteService.getCachedColors('error_test_song');
      expect(cached, isNotNull);
      expect(cached!.length, 5);
    });
  });
}
