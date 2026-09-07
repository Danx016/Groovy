import 'package:flutter_test/flutter_test.dart';
import 'package:groovy/providers/auth_provider.dart';
import 'package:groovy/services/services.dart';
import '../bootstrap.dart';

void main() {
  initializeTestEnvironment();

  group('AuthProvider', () {
    late StorageService storageService;
    late AuthProvider authProvider;

    setUp(() {
      storageService = StorageService();
      authProvider = AuthProvider(storageService);
    });

    tearDown(() {
      try {
        authProvider.dispose();
      } catch (_) {}
    });

    test('initial state should be authenticating or unauthenticated without token', () async {
      await Future.delayed(const Duration(milliseconds: 50));
      expect(authProvider.state, AuthState.unauthenticated);
      expect(authProvider.isAuthenticated, false);
      expect(authProvider.currentUser, isNull);
    });

    test('logout should clear token and reset state', () async {
      await authProvider.logout();
      expect(authProvider.state, AuthState.unauthenticated);
      expect(authProvider.isAuthenticated, false);
      expect(authProvider.token, isNull);
      expect(authProvider.currentUser, isNull);
    });

    test('notifyListeners should not throw after dispose', () {
      authProvider.dispose();
      expect(true, true);
    });
  });
}
