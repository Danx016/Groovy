import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:groovy/main.dart';
import 'package:groovy/providers/auth_provider.dart';
import 'package:groovy/services/locale_service.dart';
import 'package:groovy/services/theme_service.dart';
import 'package:groovy/services/subsonic_service.dart';
import 'package:groovy/services/storage_service.dart';

void main() {
  testWidgets('App should build', (WidgetTester tester) async {
    final subsonic = SubsonicService();
    final storage = StorageService();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LocaleService>(create: (_) => LocaleService()),
          ChangeNotifierProvider<ThemeService>(create: (_) => ThemeService()),
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => AuthProvider(subsonic, storage),
          ),
        ],
        child: const GroovyApp(),
      ),
    );
    expect(find.byType(GroovyApp), findsOneWidget);
  });
}
