import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:async';
import 'package:window_manager/window_manager.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:safe_device/safe_device.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

import 'l10n/app_localizations.dart';
import 'models/server_config.dart';
import 'services/services.dart';
import 'services/audio_handler.dart';
import 'services/transcoding_service.dart';
import 'services/local_music_service.dart';
import 'services/analytics_service.dart';
import 'services/favorite_playlists_service.dart';
import 'services/recent_searches_service.dart';
import 'widgets/privacy_policy_dialog.dart';
import 'providers/providers.dart';
import 'screens/screens.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:permission_handler/permission_handler.dart';
import 'theme/theme.dart';
import 'utils/image_cache.dart';

// Global instance for analytics (to be shown after auth)

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

/// Shows the privacy policy dialog on first launch
Future<void> _showPrivacyPolicyIfNeeded() async {
  if (await PrivacyPolicyDialog.shouldShow()) {
    // Small delay to ensure UI is fully loaded
    await Future.delayed(const Duration(milliseconds: 300));
    if (navigatorKey.currentContext != null) {
      final result = await showDialog<bool>(
        context: navigatorKey.currentContext!,
        builder: (context) => const PrivacyPolicyDialog(),
        barrierDismissible: false,
      );

      // If user declined, exit the application
      if (result == false) {
        exit(0);
      } else {
        await PrivacyPolicyDialog.markAccepted();
      }
    }
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Checks if the app is running on an emulator/simulator
Future<bool> _isRunningOnEmulator() async {
  if (kDebugMode) return false;
  if (kIsWeb) return false;
  if (!Platform.isAndroid && !Platform.isIOS) return false;

  return !(await SafeDevice.isRealDevice);
}

/// Widget shown when app is running on emulator
class _EmulatorWarningScreen extends StatelessWidget {
  const _EmulatorWarningScreen();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context)!;
          return Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.block_rounded,
                      size: 80,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      l10n.emulatorDetected,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.emulatorNotAllowed,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    FilledButton.icon(
                      onPressed: () {
                        // Exit the app
                        exit(0);
                      },
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text('Exit App'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(200, 50),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final isEmulator = await _isRunningOnEmulator();
  if (isEmulator) {
    runApp(const _EmulatorWarningScreen());
    return;
  }

  if (!kIsWeb && Platform.isAndroid) {
    try {
      final modes = await FlutterDisplayMode.supported;
      DisplayMode? highestMode;
      for (final mode in modes) {
        if (highestMode == null || mode.refreshRate > highestMode.refreshRate) {
          highestMode = mode;
        }
      }
      if (highestMode != null) {
        await FlutterDisplayMode.setPreferredMode(highestMode);
      } else {
        await FlutterDisplayMode.setHighRefreshRate();
      }
    } catch (e) {
      debugPrint('Error enabling high refresh rate: $e');
    }
  }

  JustAudioMediaKit.ensureInitialized(linux: true, windows: false);

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions();
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  ImageCacheConfig.configure();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  final storageService = StorageService();
  final subsonicService = SubsonicService();
  final offlineService = OfflineService();
  final recommendationService = RecommendationService();
  final localMusicService = LocalMusicService();
  final castService = CastService();
  final localeService = LocaleService();
  final upnpService = UpnpService();
  final jukeboxService = JukeboxService();
  final themeService = ThemeService();

  BpmAnalyzerService().initialize().catchError((e) {
    debugPrint('Failed to initialize BPM analyzer: $e');
  });
  offlineService.initialize().catchError((e) {
    debugPrint('Failed to initialize offline service: $e');
  });
  recommendationService.initialize().catchError((e) {
    debugPrint('Failed to initialize recommendation service: $e');
  });
  localMusicService.initialize().catchError((e) {
    debugPrint('Failed to initialize local music service: $e');
  });
  localeService.loadSavedLocale().catchError((e) {
    debugPrint('Failed to load saved locale: $e');
  });
  await themeService.initialize().catchError((e) {
    debugPrint('Failed to initialize theme service: $e');
  });
  jukeboxService.initialize().catchError((e) {
    debugPrint('Failed to initialize jukebox service: $e');
  });


  // Initialize favorite playlists service
  FavoritePlaylistsService().initialize().catchError((e) {
    debugPrint('Failed to initialize favorite playlists service: $e');
  });

  // Initialize recent searches service
  RecentSearchesService().initialize().catchError((e) {
    debugPrint('Failed to initialize recent searches service: $e');
  });

  // Initialize analytics service (privacy-first, anonymous)
  final analyticsService = AnalyticsService();
  analyticsService.initialize().catchError((e) {
    debugPrint('Failed to initialize analytics: $e');
  });

  // Analytics service is initialized and used via AnalyticsNavigatorObserver

  try {
    await PlayerUiSettingsService().initialize();
  } catch (e) {
    debugPrint('Failed to initialize player UI settings: $e');
  }

  // Request notification permissions on Android 13+ so the media lockscreen notification always displays
  if (!kIsWeb && Platform.isAndroid) {
    Permission.notification.request().catchError((_) => PermissionStatus.denied);
  }

  // Initialise the audio service BEFORE runApp so the background audio engine
  // is ready and fully decoupled from the Flutter widget lifecycle on iOS.
  final audioHandler = await initAudioService();

  // Create TranscodingService instance to share across providers
  final transcodingService = TranscodingService();

  // Create these providers eagerly (not lazily via `create:`) so their
  // Android Auto callbacks are registered on the audio handler as soon as the
  // engine starts. This matters for the headless cold start: when Android
  // Auto launches the app with no UI, no widget ever reads the providers, so
  // lazy construction would leave the browse tree and search unwired.
  final authProvider = AuthProvider(subsonicService, storageService);
  final playerProvider = PlayerProvider(
    subsonicService,
    storageService,
    castService,
    upnpService,
    audioHandler,
    jukeboxService,
    transcodingService,
  );
  final libraryProvider = LibraryProvider(subsonicService, audioHandler);
  libraryProvider.setLocalMusicService(localMusicService, mergeWithServer: true);
  libraryProvider.setMergeLocalLibrary(true);
  playerProvider.setLibraryProvider(libraryProvider);

  final Widget appWithProviders = MultiProvider(
    providers: [
      Provider<StorageService>.value(value: storageService),
      Provider<SubsonicService>.value(value: subsonicService),
      ChangeNotifierProvider<RecommendationService>.value(
        value: recommendationService,
      ),
      ChangeNotifierProvider<RecentSearchesService>.value(
        value: RecentSearchesService(),
      ),
      ChangeNotifierProvider<TranscodingService>.value(
        value: transcodingService,
      ),
      ChangeNotifierProvider<LocalMusicService>.value(value: localMusicService),
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ChangeNotifierProvider<CastService>.value(value: castService),
      ChangeNotifierProvider<LocaleService>.value(value: localeService),
      ChangeNotifierProvider<ThemeService>.value(value: themeService),
      ChangeNotifierProvider<UpnpService>.value(value: upnpService),
      ChangeNotifierProvider<JukeboxService>.value(value: jukeboxService),
      ChangeNotifierProvider<PlayerProvider>.value(value: playerProvider),
      ChangeNotifierProvider<LibraryProvider>.value(value: libraryProvider),
    ],
    child: const GroovyApp(),
  );

  runApp(appWithProviders);
}

class GroovyApp extends StatelessWidget {
  const GroovyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeService = Provider.of<LocaleService>(context);
    final themeService = Provider.of<ThemeService>(context);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final accent = themeService.accentColor.color;

        final ThemeData light;
        final ThemeData dark;

        if (lightDynamic != null && darkDynamic != null) {
          // Override dynamic color scheme with user-selected accent color
          final harmonisedLight = lightDynamic.harmonized().copyWith(
                primary: accent,
                secondary: accent.withAlpha(200),
              );
          final harmonisedDark = darkDynamic.harmonized().copyWith(
                primary: accent,
                secondary: accent.withAlpha(200),
              );
          light = AppTheme.lightThemeFromScheme(harmonisedLight);
          dark = AppTheme.darkThemeFromScheme(harmonisedDark);
        } else {
          light = AppTheme.lightThemeWith(accent);
          dark = AppTheme.darkThemeWith(accent);
        }

        return MaterialApp(
          title: 'Groovy',
          debugShowCheckedModeBanner: false,
          theme: light,
          darkTheme: dark,
          themeMode: themeService.themeMode,
          scrollBehavior: AppScrollBehavior(),
          navigatorKey: navigatorKey,
          locale: localeService.currentLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AuthWrapper(),
          navigatorObservers: [AnalyticsNavigatorObserver()],
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.state == AuthState.authenticating && authProvider.currentUser == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0C0D10),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF1DB954),
          ),
        ),
      );
    }

    if (!authProvider.isAuthenticated) {
      return const LoginScreen();
    }

    return const MainScreen();
  }
}
