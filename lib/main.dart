import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:async';
import 'package:window_manager/window_manager.dart';
import 'package:media_kit/media_kit.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:safe_device/safe_device.dart';

import 'l10n/app_localizations.dart';
import 'services/services.dart';
import 'services/windows_title_bar_service.dart';
import 'services/audio_handler.dart';
import 'services/transcoding_service.dart';
import 'services/local_music_service.dart';
import 'services/analytics_service.dart';
import 'services/favorite_playlists_service.dart';
import 'services/recent_searches_service.dart';
import 'services/device_info_service.dart';
import 'models/models.dart';
import 'providers/providers.dart';
import 'screens/screens.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
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

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final isEmulator = await _isRunningOnEmulator();
  if (isEmulator) {
    runApp(const _EmulatorWarningScreen());
    return;
  }

  if (!kIsWeb && Platform.isAndroid) {
    DisplayModeService().initialize().catchError((e) {
      debugPrint('Error enabling high refresh rate: $e');
    });
  }

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    try {
      MediaKit.ensureInitialized();
      JustAudioMediaKit.title = 'Groovy';
      JustAudioMediaKit.prefetchPlaylist = false;
      JustAudioMediaKit.ensureInitialized(linux: true, windows: true);
    } catch (e) {
      debugPrint('MediaKit init error: $e');
    }
  }

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(800, 500),
      center: true,
      title: 'Groovy',
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setTitle('Groovy');
      await windowManager.show();
      await windowManager.focus();
      if (Platform.isWindows) {
        WindowsTitleBarService().initialize();
        WindowsTitleBarService().updateTheme(isDark: true);
      }
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
  final youtubeService = YoutubeService();
  final offlineService = OfflineService();
  final recommendationService = RecommendationService();
  final localMusicService = LocalMusicService();
  final castService = CastService();
  final localeService = LocaleService();
  final upnpService = UpnpService();
  final jukeboxService = JukeboxService();
  final themeService = ThemeService();

  DeviceInfoService().getDeviceInfo().catchError((e) {
    debugPrint('Failed to initialize device info: $e');
    return ClientDeviceInfo(
      platform: 'Unknown',
      deviceModel: 'Groovy Device',
      osVersion: 'Unknown',
      appVersion: '1.0.76',
      userAgent: 'GroovyApp/1.0',
    );
  });
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
  jukeboxService.initialize().catchError((e) {
    debugPrint('Failed to initialize jukebox service: $e');
  });
  FavoritePlaylistsService().initialize().catchError((e) {
    debugPrint('Failed to initialize favorite playlists service: $e');
  });
  RecentSearchesService().initialize().catchError((e) {
    debugPrint('Failed to initialize recent searches service: $e');
  });
  AnalyticsService().initialize().catchError((e) {
    debugPrint('Failed to initialize analytics: $e');
  });
  if (!kIsWeb && Platform.isAndroid) {
    Permission.notification.request().catchError((_) => PermissionStatus.denied);
  }
  if (!kIsWeb && Platform.isWindows) {
    WindowsSystemService().initialize().catchError((e) {
      debugPrint('Failed to initialize Windows system service: $e');
    });
  }

  // Parallel async initialization of core services to minimize startup time
  final initResults = await Future.wait([
    themeService.initialize().catchError((e) {
      debugPrint('Failed to initialize theme service: $e');
    }),
    PlayerUiSettingsService().initialize().catchError((e) {
      debugPrint('Failed to initialize player UI settings: $e');
    }),
    initAudioService(),
  ]);

  final audioHandler = initResults[2] as GroovyAudioHandler;

  // Create TranscodingService instance to share across providers
  final transcodingService = TranscodingService();

  // Create these providers eagerly (not lazily via `create:`) so their
  // Android Auto callbacks are registered on the audio handler as soon as the
  // engine starts. This matters for the headless cold start: when Android
  // Auto launches the app with no UI, no widget ever reads the providers, so
  // lazy construction would leave the browse tree and search unwired.
  final authProvider = AuthProvider(storageService);
  final playerProvider = PlayerProvider(
    youtubeService,
    storageService,
    castService,
    upnpService,
    audioHandler,
    jukeboxService,
    transcodingService,
  );
  final libraryProvider = LibraryProvider(youtubeService, audioHandler);
  libraryProvider.setLocalMusicService(localMusicService, mergeWithServer: true);
  libraryProvider.setMergeLocalLibrary(true);
  playerProvider.setLibraryProvider(libraryProvider);

  final groovyConnectService = GroovyConnectService();
  groovyConnectService.initialize().catchError((e) {
    debugPrint('Failed to initialize GroovyConnectService: $e');
  });
  playerProvider.setGroovyConnectService(groovyConnectService);

  authProvider.addListener(() {
    groovyConnectService.updateAuthToken(authProvider.token);
  });
  if (authProvider.token != null && authProvider.token!.isNotEmpty) {
    groovyConnectService.updateAuthToken(authProvider.token);
  }

  groovyConnectService.onTransferReceived = (
    Song song,
    int positionMs,
    bool isPlaying,
    String fromDevice,
    List<Song>? queue,
    int? queueIndex,
  ) async {
    debugPrint('[GroovyConnect] Playback transferred from $fromDevice: ${song.title} at ${positionMs}ms');
    groovyConnectService.disconnect();
    playerProvider.disableGroovyConnectRemote();
    await playerProvider.playSong(
      song,
      playlist: queue,
      startIndex: queueIndex,
      initialPosition: positionMs > 0 ? Duration(milliseconds: positionMs) : null,
    );
    if (!isPlaying) {
      await playerProvider.pause();
    }
  };

  groovyConnectService.onCommandReceived = (String action, dynamic value) {
    debugPrint('[GroovyConnect] Remote command received: $action ($value)');
    playerProvider.disableGroovyConnectRemote();
    switch (action) {
      case 'play':
        playerProvider.play();
        break;
      case 'pause':
        playerProvider.pause();
        break;
      case 'togglePlayPause':
        playerProvider.togglePlayPause();
        break;
      case 'skipNext':
        playerProvider.skipNext();
        break;
      case 'skipPrevious':
        playerProvider.skipPrevious();
        break;
      case 'seek':
        if (value is num) {
          playerProvider.seek(Duration(milliseconds: value.toInt()));
        }
        break;
      case 'volume':
        if (value is num) {
          playerProvider.setVolume(value.toDouble().clamp(0.0, 1.0));
        }
        break;
    }
  };

  groovyConnectService.onProvidePlayerStatus = () {
    return {
      'isPlaying': playerProvider.isPlaying,
      'song': playerProvider.currentSong?.toJson(),
      'positionMs': playerProvider.position.inMilliseconds,
      'durationMs': playerProvider.duration.inMilliseconds,
      'volume': playerProvider.volume,
    };
  };

  final Widget appWithProviders = MultiProvider(
    providers: [
      Provider<StorageService>.value(value: storageService),
      Provider<YoutubeService>.value(value: youtubeService),
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
      ChangeNotifierProvider<GroovyConnectService>.value(value: groovyConnectService),
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
          locale: localeService.currentLocale ?? const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          localeResolutionCallback: (locale, supportedLocales) {
            if (localeService.currentLocale != null) {
              return localeService.currentLocale;
            }
            if (locale != null) {
              for (var supportedLocale in supportedLocales) {
                if (supportedLocale.languageCode == locale.languageCode) {
                  return supportedLocale;
                }
              }
            }
            return const Locale('es');
          },
          home: const AuthWrapper(),
          navigatorObservers: [AnalyticsNavigatorObserver()],
          builder: (context, child) {
            if (!kIsWeb && Platform.isWindows) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              WindowsTitleBarService().updateTheme(
                isDark: isDark,
                customBackgroundColor:
                    isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
              );
            }
            return child ?? const SizedBox.shrink();
          },
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

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
