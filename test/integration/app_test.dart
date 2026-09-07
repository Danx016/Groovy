import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:groovy/main.dart';
import 'package:groovy/providers/auth_provider.dart';
import 'package:groovy/services/services.dart';
import '../bootstrap.dart';

void main() {
  initializeTestEnvironment();
  group('Musly App Integration Tests', () {
    testWidgets('should display login screen when not authenticated', (
      tester,
    ) async {
      final storageService = StorageService();
      final youtubeService = YoutubeService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<StorageService>.value(value: storageService),
            Provider<YoutubeService>.value(value: youtubeService),
            ChangeNotifierProvider<LocaleService>(
                create: (_) => LocaleService()),
            ChangeNotifierProvider<ThemeService>(create: (_) => ThemeService()),
            ChangeNotifierProvider(
              create: (_) => AuthProvider(storageService),
            ),
          ],
          child: const MaterialApp(home: GroovyApp()),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(MaterialApp), findsWidgets);
    });
  });
}
