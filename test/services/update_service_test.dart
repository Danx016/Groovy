import 'package:flutter_test/flutter_test.dart';
import 'package:groovy/services/update_service.dart';

void main() {
  group('UpdateService.isNewer tests', () {
    test('identical versions should return false', () {
      expect(UpdateService.isNewer('1.0.72', '1.0.72'), isFalse);
      expect(UpdateService.isNewer('v1.0.72', '1.0.72'), isFalse);
      expect(UpdateService.isNewer('1.0.72', 'v1.0.72'), isFalse);
    });

    test('remote version matching current with build number should return false (the bug that caused infinite loop)', () {
      // Current running app has 1.0.72+63, GitHub release tag is 1.0.72 or v1.0.72
      expect(UpdateService.isNewer('1.0.72', '1.0.72+63'), isFalse);
      expect(UpdateService.isNewer('v1.0.72', '1.0.72+63'), isFalse);
      expect(UpdateService.isNewer('1.0.72', '1.0.72.63'), isFalse);
    });

    test('remote version strictly newer should return true', () {
      expect(UpdateService.isNewer('1.0.72', '1.0.65'), isTrue);
      expect(UpdateService.isNewer('1.0.72', '1.0.65+56'), isTrue);
      expect(UpdateService.isNewer('1.1.0', '1.0.72+63'), isTrue);
      expect(UpdateService.isNewer('2.0.0', '1.9.99'), isTrue);
    });

    test('current version newer than remote should return false', () {
      expect(UpdateService.isNewer('1.0.65', '1.0.72'), isFalse);
      expect(UpdateService.isNewer('1.0.72', '1.0.73'), isFalse);
      expect(UpdateService.isNewer('1.0.72', '1.0.73+70'), isFalse);
    });

    test('cleanVersion strips build numbers and v prefix', () {
      expect(UpdateService.cleanVersion('1.0.72+63'), '1.0.72');
      expect(UpdateService.cleanVersion('v1.0.72+63'), '1.0.72');
      expect(UpdateService.cleanVersion('v1.0.65'), '1.0.65');
    });

    test('formatDownloadError returns user-friendly messages instead of raw tech stack traces', () {
      expect(
        UpdateService.formatDownloadError('SocketException: OS Error: Network is unreachable, errno = 101'),
        contains('Se perdió la conexión a internet'),
      );
      expect(
        UpdateService.formatDownloadError('Failed host lookup: api.github.com'),
        contains('Se perdió la conexión a internet'),
      );
      expect(
        UpdateService.formatDownloadError('No space left on device'),
        contains('Espacio insuficiente'),
      );
    });
  });
}
