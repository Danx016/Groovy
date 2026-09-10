import 'package:flutter_test/flutter_test.dart';
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
}
