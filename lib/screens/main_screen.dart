import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/providers.dart';
import '../services/local_music_service.dart';
import '../services/recommendation_service.dart';
import '../services/theme_service.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import '../utils/navigation_helper.dart';
import '../widgets/widgets.dart';
import '../l10n/app_localizations.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'search_screen.dart';
import 'fantasy_screen.dart';

class PlayPauseIntent extends Intent {
  const PlayPauseIntent();
}

class MainScreen extends StatefulWidget {
  final bool isOfflineMode;

  const MainScreen({super.key, this.isOfflineMode = false});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int _searchTapCount = 0;
  DateTime _lastSearchTap = DateTime.fromMillisecondsSinceEpoch(0);
  final bool _showRightSidebar = true;

  final List<Widget> _screens = const [
    HomeScreen(),
    LibraryScreen(),
    SearchScreen(),
  ];

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    NavigationHelper.registerTabChangeCallback((index) {
      setState(() => _currentIndex = index);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final libraryProvider = Provider.of<LibraryProvider>(
        context,
        listen: false,
      );
      final playerProvider = Provider.of<PlayerProvider>(
        context,
        listen: false,
      );
      final recommendationService = Provider.of<RecommendationService>(
        context,
        listen: false,
      );

      playerProvider.setLibraryProvider(libraryProvider);
      playerProvider.setRecommendationService(recommendationService);

      playerProvider.onAudioFocusDenied = () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.audioFocusDenied),
          ),
        );
      };

      final localMusicService = Provider.of<LocalMusicService>(
        context,
        listen: false,
      );

      libraryProvider.setLocalMusicService(
        localMusicService,
        mergeWithServer: true,
      );
      libraryProvider.setMergeLocalLibrary(true);
      libraryProvider.setLocalOnlyMode(false);
      libraryProvider.setServerOfflineMode(widget.isOfflineMode);

      if (localMusicService.isEmpty && !localMusicService.isScanning) {
        localMusicService.scanForMusic();
      }

      libraryProvider.initialize();

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _checkForUpdate();
      });
    });
  }

  Future<void> _checkForUpdate() async {
    final release = await UpdateService.checkForUpdate();
    if (release == null || !mounted) return;
    _showUpdateDialog(release);
  }

  void _showUpdateDialog(ReleaseInfo release) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final changelog = UpdateService.stripMarkdown(release.body);
    final apkUrl = release.apkDownloadUrl;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return ValueListenableBuilder<bool>(
          valueListenable: UpdateService.isDownloadingNotifier,
          builder: (dialogCtx, isDownloading, _) {
            return ValueListenableBuilder<double>(
              valueListenable: UpdateService.downloadProgressNotifier,
              builder: (dialogCtx, progress, _) {
                return ValueListenableBuilder<String?>(
                  valueListenable: UpdateService.downloadErrorNotifier,
                  builder: (dialogCtx, errorMessage, _) {
                    return Dialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
                      elevation: 24,
                      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 580),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.06),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Sleek Top Header
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                              child: Column(
                                children: [
                                  // Glowing Icon Badge
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFFF334B), Color(0xFFE50914)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFE50914).withValues(alpha: 0.4),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      CupertinoIcons.sparkles,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    l10n.updateAvailable,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Hay una nueva versión de Groovy lista para ti',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 14),

                                  // Version Transition Pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : Colors.black.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'v${UpdateService.currentVersion}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white54 : Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 14,
                                          color: isDark ? Colors.white38 : Colors.black38,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'v${release.version}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1DB954),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Changelog Section
                            Flexible(
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 20),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.black.withValues(alpha: 0.3)
                                      : const Color(0xFFF4F4F5),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: Text(
                                    changelog,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.5,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Progress Bar Section
                            if (isDownloading)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        value: progress > 0 ? progress : null,
                                        backgroundColor: isDark ? Colors.white12 : Colors.black12,
                                        valueColor: const AlwaysStoppedAnimation<Color>(
                                          Color(0xFFE50914),
                                        ),
                                        minHeight: 10,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Descargando en segundo plano...',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white70 : Colors.black87,
                                          ),
                                        ),
                                        Text(
                                          '${(progress * 100).toInt()}%',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFE50914),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                            if (errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                child: Text(
                                  errorMessage,
                                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                            // Bottom Action Buttons
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                              child: Row(
                                children: [
                                  if (!isDownloading)
                                    Expanded(
                                      child: TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          foregroundColor:
                                              isDark ? Colors.white60 : Colors.black54,
                                        ),
                                        child: Text(
                                          l10n.remindLater,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                  if (!isDownloading) const SizedBox(width: 12),
                                  Expanded(
                                    flex: isDownloading ? 1 : 2,
                                    child: ElevatedButton.icon(
                                      onPressed: isDownloading
                                          ? () => Navigator.of(ctx).pop()
                                          : () {
                                              UpdateService.startDownload(release);
                                            },
                                      icon: Icon(
                                        isDownloading
                                            ? CupertinoIcons.check_mark_circled
                                            : CupertinoIcons.arrow_down_to_line_alt,
                                        size: 18,
                                      ),
                                      label: Text(
                                        isDownloading
                                            ? 'Continuar en segundo plano'
                                            : 'Actualizar ahora',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFE50914),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  bool get _isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isLocalMode = authProvider.isLocalOnlyMode;

    if (_isDesktop) {
      final content = Scaffold(
        body: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  DesktopNavigationSidebar(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (index) {
                      setState(() => _currentIndex = index);
                      NavigationHelper.desktopNavigatorKey.currentState
                          ?.popUntil((route) => route.isFirst);
                    },
                    navigatorKey: NavigationHelper.desktopNavigatorKey,
                  ),
                  Expanded(
                    child: Navigator(
                      key: NavigationHelper.desktopNavigatorKey,
                      onGenerateRoute: (settings) {
                        return PageRouteBuilder(
                          pageBuilder: (ctx, anim, _) => LazyIndexedStack(
                            index: _currentIndex,
                            children: _screens,
                          ),
                          transitionsBuilder: (ctx, animation, _, child) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                        );
                      },
                    ),
                  ),
                  if (_showRightSidebar)
                    Selector<PlayerProvider, bool>(
                      selector: (_, p) =>
                          p.currentSong != null || p.isPlayingRadio,
                      builder: (context, hasCurrentSong, _) {
                        return hasCurrentSong
                            ? const RightSidebar()
                            : const SizedBox.shrink();
                      },
                    ),
                ],
              ),
            ),
            Selector<PlayerProvider, bool>(
              selector: (_, p) => p.currentSong != null || p.isPlayingRadio,
              builder: (context, hasCurrentSong, _) {
                return hasCurrentSong
                    ? DesktopPlayerBar(
                        navigatorKey: NavigationHelper.desktopNavigatorKey,
                      )
                    : const SizedBox.shrink();
              },
            ),
          ],
        ),
      );

      return Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          const SingleActivator(LogicalKeyboardKey.space): const PlayPauseIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            PlayPauseIntent: CallbackAction<PlayPauseIntent>(
              onInvoke: (PlayPauseIntent intent) {
                final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
                playerProvider.togglePlayPause();
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: true,
            child: content,
          ),
        ),
      );
    }

    final bool liquidGlass = Provider.of<ThemeService>(context).liquidGlass;
    return Selector<PlayerProvider, bool>(
      selector: (_, p) => p.currentSong != null || p.isPlayingRadio,
      builder: (context, hasCurrentSong, _) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _handleBackButton();
          },
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            body: Column(
              children: [
                if (widget.isOfflineMode || isLocalMode)
                  Container(
                    width: double.infinity,
                    color: isLocalMode ? Colors.indigo : Colors.orange,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Row(
                        children: [
                          Icon(
                            isLocalMode
                                ? CupertinoIcons.folder_fill
                                : CupertinoIcons.wifi_slash,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isLocalMode
                                  ? AppLocalizations.of(
                                      context,
                                    )!
                                      .localFilesModeBanner
                                  : AppLocalizations.of(
                                      context,
                                    )!
                                      .offlineModeBanner,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (isLocalMode)
                  Selector<LocalMusicService, (bool, double, String)>(
                    selector: (_, s) =>
                        (s.isScanning, s.scanProgress, s.scanStatus),
                    builder: (context, data, _) {
                      final (isScanning, progress, status) = data;
                      if (!isScanning) return const SizedBox.shrink();
                      return Container(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.85),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                status,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (progress > 0)
                              Text(
                                '${(progress * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                Expanded(
                  child: Navigator(
                    key: NavigationHelper.mobileNavigatorKey,
                    onGenerateRoute: (settings) {
                      return MaterialPageRoute(
                        builder: (_) => LazyIndexedStack(
                          index: _currentIndex,
                          children: _screens,
                        ),
                      );
                    },
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasCurrentSong) const MiniPlayer(),
                    liquidGlass
                        ? _buildGlassBottomNav(context)
                        : _buildBottomNav(context),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleBackButton() {
    final navigatorState = NavigationHelper.mobileNavigatorKey.currentState;
    if (navigatorState != null && navigatorState.canPop()) {
      navigatorState.pop();
      return;
    }

    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return;
    }

    SystemNavigator.pop();
  }

  Widget _buildGlassBottomNav(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final l10n = AppLocalizations.of(context)!;

    final items = [
      (
        icon: CupertinoIcons.music_house,
        activeIcon: CupertinoIcons.music_house_fill,
        label: l10n.home,
      ),
      (
        icon: CupertinoIcons.collections,
        activeIcon: CupertinoIcons.collections_solid,
        label: l10n.library,
      ),
      (
        icon: CupertinoIcons.search,
        activeIcon: CupertinoIcons.search,
        label: l10n.search,
      ),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 4, 12, safeBottom > 0 ? safeBottom : 12),
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xF018181A)
              : const Color(0xF5FFFFFF),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.08),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
              child: Row(
                children: List.generate(items.length, (idx) {
                  final item = items[idx];
                  final isSelected = _currentIndex == idx;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        final navigatorState =
                            NavigationHelper.mobileNavigatorKey.currentState;
                        navigatorState?.popUntil((route) => route.isFirst);

                        if (idx == 2) {
                          final now = DateTime.now();
                          if (now.difference(_lastSearchTap).inSeconds > 3) {
                            _searchTapCount = 0;
                          }
                          _searchTapCount++;
                          _lastSearchTap = now;
                          if (_searchTapCount >= 11) {
                            _searchTapCount = 0;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const FantasyScreen(),
                              ),
                            );
                            return;
                          }
                        } else {
                          _searchTapCount = 0;
                        }

                        setState(() => _currentIndex = idx);
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 150),
                            child: Icon(
                              isSelected ? item.activeIcon : item.icon,
                              key: ValueKey(isSelected),
                              color: isSelected
                                  ? accent
                                  : (isDark ? Colors.white54 : Colors.black38),
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? accent
                                  : (isDark ? Colors.white54 : Colors.black38),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            final navigatorState =
                NavigationHelper.mobileNavigatorKey.currentState;
            navigatorState?.popUntil((route) => route.isFirst);

            if (index == 2) {
              final now = DateTime.now();
              if (now.difference(_lastSearchTap).inSeconds > 3) {
                _searchTapCount = 0;
              }
              _searchTapCount++;
              _lastSearchTap = now;
              if (_searchTapCount >= 11) {
                _searchTapCount = 0;
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FantasyScreen()),
                );
                return;
              }
            } else {
              _searchTapCount = 0;
            }

            setState(() => _currentIndex = index);
          },
          items: [
            BottomNavigationBarItem(
              icon: const Icon(CupertinoIcons.music_house),
              activeIcon: const Icon(CupertinoIcons.music_house_fill),
              label: l10n.home,
            ),
            BottomNavigationBarItem(
              icon: const Icon(CupertinoIcons.collections),
              activeIcon: const Icon(CupertinoIcons.collections_solid),
              label: l10n.library,
            ),
            BottomNavigationBarItem(
              icon: const Icon(CupertinoIcons.search),
              activeIcon: const Icon(CupertinoIcons.search),
              label: l10n.search,
            ),
          ],
        ),
      ),
    );
  }
}

