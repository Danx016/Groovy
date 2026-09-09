import 'package:flutter_test/flutter_test.dart';
import 'package:audio_service/audio_service.dart';
import 'package:groovy/services/audio_handler.dart';

void main() {
  group('Headphone & Media Button Controls', () {
    test('MediaAction enum check', () {
      expect(MediaAction.values.contains(MediaAction.skipToNext), isTrue);
      expect(MediaAction.values.contains(MediaAction.skipToPrevious), isTrue);
      expect(MediaAction.values.contains(MediaAction.play), isTrue);
      expect(MediaAction.values.contains(MediaAction.pause), isTrue);
      expect(MediaAction.values.contains(MediaAction.playPause), isTrue);
    });

    test('GroovyAudioHandler systemActions contains all essential media controls', () {
      final handler = GroovyAudioHandler();
      handler.updateRemotePlaybackState(playing: true, position: Duration.zero);

      final state = handler.playbackState.value;
      expect(state.systemActions.contains(MediaAction.play), isTrue);
      expect(state.systemActions.contains(MediaAction.pause), isTrue);
      expect(state.systemActions.contains(MediaAction.playPause), isTrue);
      expect(state.systemActions.contains(MediaAction.skipToNext), isTrue);
      expect(state.systemActions.contains(MediaAction.skipToPrevious), isTrue);
      expect(state.controls.contains(MediaControl.skipToNext), isTrue);
      expect(state.controls.contains(MediaControl.skipToPrevious), isTrue);
    });

    test('Single click toggles play/pause after debounce interval', () async {
      final handler = GroovyAudioHandler();
      int toggleCount = 0;
      int skipNextCount = 0;
      int skipPrevCount = 0;

      handler.onTogglePlayPause = () async {
        toggleCount++;
      };
      handler.onSkipNext = () async {
        skipNextCount++;
      };
      handler.onSkipPrevious = () async {
        skipPrevCount++;
      };

      await handler.click(MediaButton.media);
      expect(toggleCount, 0); // Not fired immediately (waiting to see if double click)

      await Future.delayed(const Duration(milliseconds: 380));
      expect(toggleCount, 1);
      expect(skipNextCount, 0);
      expect(skipPrevCount, 0);
    });

    test('Double click skips to next song', () async {
      final handler = GroovyAudioHandler();
      int toggleCount = 0;
      int skipNextCount = 0;
      int skipPrevCount = 0;

      handler.onTogglePlayPause = () async {
        toggleCount++;
      };
      handler.onSkipNext = () async {
        skipNextCount++;
      };
      handler.onSkipPrevious = () async {
        skipPrevCount++;
      };

      // Two clicks within debounce window
      await handler.click(MediaButton.media);
      await Future.delayed(const Duration(milliseconds: 100));
      await handler.click(MediaButton.media);

      await Future.delayed(const Duration(milliseconds: 380));
      expect(toggleCount, 0);
      expect(skipNextCount, 1);
      expect(skipPrevCount, 0);
    });

    test('Triple click skips to previous song immediately', () async {
      final handler = GroovyAudioHandler();
      int toggleCount = 0;
      int skipNextCount = 0;
      int skipPrevCount = 0;

      handler.onTogglePlayPause = () async {
        toggleCount++;
      };
      handler.onSkipNext = () async {
        skipNextCount++;
      };
      handler.onSkipPrevious = () async {
        skipPrevCount++;
      };

      // Three clicks within window
      await handler.click(MediaButton.media);
      await Future.delayed(const Duration(milliseconds: 50));
      await handler.click(MediaButton.media);
      await Future.delayed(const Duration(milliseconds: 50));
      await handler.click(MediaButton.media);

      // Triple click fires immediately without waiting
      expect(skipPrevCount, 1);
      expect(toggleCount, 0);
      expect(skipNextCount, 0);
    });

    test('Dedicated next and previous buttons trigger immediately', () async {
      final handler = GroovyAudioHandler();
      int skipNextCount = 0;
      int skipPrevCount = 0;

      handler.onSkipNext = () async {
        skipNextCount++;
      };
      handler.onSkipPrevious = () async {
        skipPrevCount++;
      };

      await handler.click(MediaButton.next);
      expect(skipNextCount, 1);

      await handler.click(MediaButton.previous);
      expect(skipPrevCount, 1);
    });
  });
}
