import 'package:flutter_test/flutter_test.dart';
import 'package:groovy/services/google_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GoogleAuthService Credentials Validation', () {
    test('androidClientId matches Google Cloud Console credentials', () {
      expect(
        GoogleAuthService.androidClientId,
        '318948269972-hqqb1ctdq2ounraa32r4271sjvmfr9u2.apps.googleusercontent.com',
      );
    });

    test('webClientId is not empty and is valid Google client id', () {
      expect(GoogleAuthService.webClientId, isNotEmpty);
      expect(GoogleAuthService.webClientId, contains('.apps.googleusercontent.com'));
    });
  });
}
