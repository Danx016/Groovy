import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:groovy/services/windows_system_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WindowsSystemService Headset Multi-Click Detection', () {
    late WindowsSystemService service;
    int togglePlayPauseCalls = 0;
    int skipNextCalls = 0;
    int skipPreviousCalls = 0;

    setUp(() {
      service = WindowsSystemService();
      togglePlayPauseCalls = 0;
      skipNextCalls = 0;
      skipPreviousCalls = 0;

      service.onTogglePlayPause = () {
        togglePlayPauseCalls++;
      };
      service.onSkipNext = () {
        skipNextCalls++;
      };
      service.onSkipPrevious = () {
        skipPreviousCalls++;
      };
    });

    test('Single click invokes onTogglePlayPause after debounce window', () async {
      service.handleMediaClickForTesting();

      expect(togglePlayPauseCalls, 0);
      expect(skipNextCalls, 0);
      expect(skipPreviousCalls, 0);

      // Wait for debounce window (320ms + margin)
      await Future.delayed(const Duration(milliseconds: 380));

      expect(togglePlayPauseCalls, 1);
      expect(skipNextCalls, 0);
      expect(skipPreviousCalls, 0);
    });

    test('Double click invokes onSkipNext and cancels togglePlayPause', () async {
      // First click
      service.handleMediaClickForTesting();

      // Second click arrives within 150ms (< 320ms)
      await Future.delayed(const Duration(milliseconds: 150));
      service.handleMediaClickForTesting();

      // Wait for debounce window to elapse for second click
      await Future.delayed(const Duration(milliseconds: 380));

      expect(togglePlayPauseCalls, 0, reason: 'Single click action must be superseded');
      expect(skipNextCalls, 1, reason: 'Double click must invoke onSkipNext');
      expect(skipPreviousCalls, 0);
    });

    test('Triple click invokes onSkipPrevious and cancels skipNext and togglePlayPause', () async {
      // First click
      service.handleMediaClickForTesting();

      // Second click at 100ms
      await Future.delayed(const Duration(milliseconds: 100));
      service.handleMediaClickForTesting();

      // Third click at 200ms
      await Future.delayed(const Duration(milliseconds: 100));
      service.handleMediaClickForTesting();

      // Wait for debounce window to elapse for third click
      await Future.delayed(const Duration(milliseconds: 380));

      expect(togglePlayPauseCalls, 0, reason: 'Single click action must be superseded');
      expect(skipNextCalls, 0, reason: 'Double click action must be superseded');
      expect(skipPreviousCalls, 1, reason: 'Triple click must invoke onSkipPrevious');
    });
  });

  group('WindowsSystemService Direct Media Key Event Handling', () {
    late WindowsSystemService service;
    int playCalls = 0;
    int pauseCalls = 0;
    int stopCalls = 0;
    int skipNextCalls = 0;
    int skipPreviousCalls = 0;
    int togglePlayPauseCalls = 0;

    setUp(() {
      service = WindowsSystemService();
      playCalls = 0;
      pauseCalls = 0;
      stopCalls = 0;
      skipNextCalls = 0;
      skipPreviousCalls = 0;
      togglePlayPauseCalls = 0;

      service.onPlay = () => playCalls++;
      service.onPause = () => pauseCalls++;
      service.onStop = () => stopCalls++;
      service.onSkipNext = () => skipNextCalls++;
      service.onSkipPrevious = () => skipPreviousCalls++;
      service.onTogglePlayPause = () => togglePlayPauseCalls++;
    });

    test('mediaPause key directly invokes onPause without delay or skipping', () {
      final event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.mediaPause,
        logicalKey: LogicalKeyboardKey.mediaPause,
        timeStamp: Duration.zero,
      );

      final handled = service.handleKeyEventForTesting(event);
      expect(handled, isTrue);
      expect(pauseCalls, 1);
      expect(skipNextCalls, 0, reason: 'Pausing should NEVER trigger skipNext');
      expect(togglePlayPauseCalls, 0);
    });

    test('mediaPlay key directly invokes onPlay', () {
      final event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.mediaPlay,
        logicalKey: LogicalKeyboardKey.mediaPlay,
        timeStamp: Duration.zero,
      );

      final handled = service.handleKeyEventForTesting(event);
      expect(handled, isTrue);
      expect(playCalls, 1);
      expect(skipNextCalls, 0);
    });

    test('mediaPlayPause key directly invokes onTogglePlayPause', () {
      final event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.mediaPlayPause,
        logicalKey: LogicalKeyboardKey.mediaPlayPause,
        timeStamp: Duration.zero,
      );

      final handled = service.handleKeyEventForTesting(event);
      expect(handled, isTrue);
      expect(togglePlayPauseCalls, 1);
      expect(skipNextCalls, 0);
    });

    test('mediaTrackNext key directly invokes onSkipNext', () {
      final event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.mediaTrackNext,
        logicalKey: LogicalKeyboardKey.mediaTrackNext,
        timeStamp: Duration.zero,
      );

      final handled = service.handleKeyEventForTesting(event);
      expect(handled, isTrue);
      expect(skipNextCalls, 1);
    });

    test('mediaTrackPrevious key directly invokes onSkipPrevious', () {
      final event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.mediaTrackPrevious,
        logicalKey: LogicalKeyboardKey.mediaTrackPrevious,
        timeStamp: Duration.zero,
      );

      final handled = service.handleKeyEventForTesting(event);
      expect(handled, isTrue);
      expect(skipPreviousCalls, 1);
    });

    test('mediaStop key directly invokes onStop', () {
      final event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.mediaStop,
        logicalKey: LogicalKeyboardKey.mediaStop,
        timeStamp: Duration.zero,
      );

      final handled = service.handleKeyEventForTesting(event);
      expect(handled, isTrue);
      expect(stopCalls, 1);
    });

    test('mediaFastForward and mediaSkipForward directly invoke onSkipNext', () async {
      final ffEvent = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.mediaFastForward,
        logicalKey: LogicalKeyboardKey.mediaFastForward,
        timeStamp: Duration.zero,
      );
      final handledFF = service.handleKeyEventForTesting(ffEvent);
      expect(handledFF, isTrue);
      expect(skipNextCalls, 1);

      await Future.delayed(const Duration(milliseconds: 220));

      final skipFwdEvent = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.mediaTrackNext,
        logicalKey: LogicalKeyboardKey.mediaSkipForward,
        timeStamp: Duration.zero,
      );
      final handledSkip = service.handleKeyEventForTesting(skipFwdEvent);
      expect(handledSkip, isTrue);
      expect(skipNextCalls, 2);
    });

    test('mediaRewind and mediaSkipBackward directly invoke onSkipPrevious', () async {
      final rwEvent = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.mediaRewind,
        logicalKey: LogicalKeyboardKey.mediaRewind,
        timeStamp: Duration.zero,
      );
      final handledRW = service.handleKeyEventForTesting(rwEvent);
      expect(handledRW, isTrue);
      expect(skipPreviousCalls, 1);

      await Future.delayed(const Duration(milliseconds: 220));

      final skipBackEvent = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.mediaTrackPrevious,
        logicalKey: LogicalKeyboardKey.mediaSkipBackward,
        timeStamp: Duration.zero,
      );
      final handledBack = service.handleKeyEventForTesting(skipBackEvent);
      expect(handledBack, isTrue);
      expect(skipPreviousCalls, 2);
    });

    test('unidentified logicalKey with physical mediaTrackNext and mediaTrackPrevious keys are handled', () async {
      final nextEvent = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.mediaTrackNext,
        logicalKey: LogicalKeyboardKey.unidentified,
        timeStamp: Duration.zero,
      );
      expect(service.handleKeyEventForTesting(nextEvent), isTrue);
      expect(skipNextCalls, 1);

      await Future.delayed(const Duration(milliseconds: 220));

      final prevEvent = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.mediaTrackPrevious,
        logicalKey: LogicalKeyboardKey.unidentified,
        timeStamp: Duration.zero,
      );
      expect(service.handleKeyEventForTesting(prevEvent), isTrue);
      expect(skipPreviousCalls, 1);
    });

    test('Rapid repeat keydown event within throttle window is throttled', () async {
      final event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.mediaPause,
        logicalKey: LogicalKeyboardKey.mediaPause,
        timeStamp: Duration.zero,
      );

      service.handleKeyEventForTesting(event);
      // Rapid duplicate event (key repeat)
      service.handleKeyEventForTesting(event);

      expect(pauseCalls, 1, reason: 'Duplicate rapid keydown within 200ms must be throttled');
      expect(skipNextCalls, 0);
    });
  });
}
