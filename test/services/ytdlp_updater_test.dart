import 'package:flutter_test/flutter_test.dart';
import 'package:groovy/services/ytdlp_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('YtDlpService auto-updater unit tests', () {
    test('singleton instance initializes with valid default state', () {
      final service = YtDlpService();
      expect(service.isUpdating, isFalse);
    });

    test('getYtDlpVersion returns string or null without throwing', () async {
      final service = YtDlpService();
      final version = await service.getYtDlpVersion();
      // On Windows development machine with yt-dlp.exe in root, it should resolve the version
      if (version != null) {
        expect(version, isNotEmpty);
      }
    });
  });
}
