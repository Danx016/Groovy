import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy/widgets/now_playing/animated_album_art_view.dart';
import 'package:groovy/widgets/now_playing/album_art_view.dart';
import 'package:groovy/services/player_ui_settings_service.dart';
import '../bootstrap.dart';

void main() {
  initializeTestEnvironment();

  group('AnimatedAlbumArtView Tests', () {
    testWidgets('AnimatedAlbumArtView renders correctly with isPlaying=true and dominantColor', (tester) async {
      const imageProvider = AssetImage('assets/images/placeholder.png');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedAlbumArtView(
              image: imageProvider,
              tag: 'art_playing',
              isPlaying: true,
              dominantColor: Color(0xFFFA233B),
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedAlbumArtView), findsOneWidget);
      expect(find.byType(Hero), findsOneWidget);
      expect(find.byType(Transform), findsWidgets);

      // Advance frames to ensure smooth animation ticks
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AnimatedAlbumArtView), findsOneWidget);
    });

    testWidgets('AnimatedAlbumArtView updates correctly when isPlaying toggles to false', (tester) async {
      const imageProvider = AssetImage('assets/images/placeholder.png');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedAlbumArtView(
              image: imageProvider,
              tag: 'art_toggle',
              isPlaying: true,
              dominantColor: Color(0xFF007AFF),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Pause playback
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedAlbumArtView(
              image: imageProvider,
              tag: 'art_toggle',
              isPlaying: false,
              dominantColor: Color(0xFF007AFF),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AnimatedAlbumArtView), findsOneWidget);
    });

    testWidgets('AlbumArtView renders directly with high-performance TweenAnimationBuilder', (tester) async {
      const imageProvider = AssetImage('assets/images/placeholder.png');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AlbumArtView(
              image: imageProvider,
              tag: 'album_art_view_test',
              isPlaying: true,
              dominantColor: Color(0xFFFF9500),
            ),
          ),
        ),
      );

      expect(find.byType(AlbumArtView), findsOneWidget);
      expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);
    });

    testWidgets('PlayerUiSettingsService toggles animated artwork properly', (tester) async {
      final settings = PlayerUiSettingsService();
      await settings.initialize();

      await settings.setAnimatedArtwork(false);
      expect(settings.getAnimatedArtwork(), isFalse);
      expect(settings.animatedArtworkNotifier.value, isFalse);

      await settings.setAnimatedArtwork(true);
      expect(settings.getAnimatedArtwork(), isTrue);
      expect(settings.animatedArtworkNotifier.value, isTrue);
    });
  });
}
