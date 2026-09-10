import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy/models/lyric_line.dart';
import 'package:groovy/widgets/lyrics/lyrics_list_view.dart';
import '../test_helpers.dart';

void main() {
  group('LyricsListView mounted & dispose safety', () {
    testWidgets('does not throw setState after dispose when stream emits', (tester) async {
      final controller = StreamController<Duration>.broadcast();
      final List<LyricLine> lyrics = [
        LyricLine(startTime: const Duration(seconds: 1), text: 'Line 1'),
        LyricLine(startTime: const Duration(seconds: 3), text: 'Line 2'),
        LyricLine(startTime: const Duration(seconds: 5), text: 'Line 3'),
      ];

      await tester.pumpWidget(
        createTestApp(
          child: LyricsListView(
            lyrics: lyrics,
            positionStream: controller.stream,
            onSeek: (_) {},
          ),
        ),
      );

      // Verify rendered
      expect(find.text('Line 1'), findsOneWidget);

      // Pump an update while mounted
      controller.add(const Duration(seconds: 2));
      await tester.pump();

      // Dispose widget by pumping empty container
      await tester.pumpWidget(
        createTestApp(
          child: const SizedBox.shrink(),
        ),
      );

      // Emit new positions AFTER widget is disposed
      expect(() {
        controller.add(const Duration(seconds: 4));
        controller.add(const Duration(seconds: 6));
      }, returnsNormally);

      await tester.pump(const Duration(milliseconds: 100));

      // Clean up
      await controller.close();
    });
  });
}
