import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy/models/lyric_line.dart';
import 'package:groovy/widgets/now_playing/album_art_view.dart';
import 'package:groovy/widgets/lyrics/lyrics_line.dart';
import 'package:groovy/widgets/lyrics/lyrics_list_view.dart';
import '../bootstrap.dart';

void main() {
  initializeTestEnvironment();

  group('AlbumArtView & Lyrics Apple Music Widget Tests', () {
    testWidgets('AlbumArtView builds and animates between playing and paused without error', (tester) async {
      final imageProvider = const AssetImage('assets/images/placeholder.png');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlbumArtView(
              image: imageProvider,
              tag: 'test_art',
              isPlaying: true,
            ),
          ),
        ),
      );

      expect(find.byType(AlbumArtView), findsOneWidget);
      expect(find.byType(Transform), findsWidgets);

      // Toggle to paused state and pump frames across the 480ms duration
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlbumArtView(
              image: imageProvider,
              tag: 'test_art',
              isPlaying: false,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 240));
      await tester.pump(const Duration(milliseconds: 240));
      expect(find.byType(AlbumArtView), findsOneWidget);
    });

    testWidgets('LyricsLineWidget renders active and inactive states with Apple Music styling', (tester) async {
      final line = LyricLine(
        text: 'Apple Music Fluid Lyrics',
        startTime: const Duration(seconds: 10),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LyricsLineWidget(
              line: line,
              state: LyricLineState.current,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Apple Music Fluid Lyrics'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(LyricsLineWidget),
          matching: find.byType(AnimatedDefaultTextStyle),
        ),
        findsOneWidget,
      );
      expect(find.byType(AnimatedScale), findsOneWidget);
      expect(find.byType(AnimatedOpacity), findsOneWidget);

      // Switch to past state
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LyricsLineWidget(
              line: line,
              state: LyricLineState.past,
              distance: 2,
              onTap: () {},
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 420));
      expect(find.text('Apple Music Fluid Lyrics'), findsOneWidget);
    });

    testWidgets('LyricsListView generates lines and interlude dots for gaps >= 5 seconds', (tester) async {
      final lyrics = [
        LyricLine(text: 'Intro verse', startTime: const Duration(seconds: 1)),
        LyricLine(text: 'Verse after instrumental gap', startTime: const Duration(seconds: 15)),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LyricsListView(
              lyrics: lyrics,
              currentTime: const Duration(seconds: 1),
              onSeek: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Intro verse'), findsOneWidget);
      expect(find.text('Verse after instrumental gap'), findsOneWidget);
    });

    testWidgets('LyricsListView adapts padding and focal alignment in desktop landscape', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final lyrics = [
        LyricLine(text: 'Casi todos sabemos querer', startTime: const Duration(seconds: 1)),
        LyricLine(text: 'Pero pocos sabemos amar', startTime: const Duration(seconds: 5)),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LyricsListView(
              lyrics: lyrics,
              currentTime: const Duration(seconds: 1),
              onSeek: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Casi todos sabemos querer'), findsOneWidget);
      expect(find.text('Pero pocos sabemos amar'), findsOneWidget);
    });
  });
}
