import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import '../widgets/blurred_gradient_background.dart';
import '../widgets/now_playing/album_art_view.dart';
import '../widgets/now_playing/marquee_text.dart';
import '../widgets/now_playing/playback_controls.dart';
import '../widgets/now_playing/playback_progress_slider.dart';
import '../widgets/now_playing/now_playing_bottom_actions.dart';
import '../widgets/lyrics/lyrics_list_view.dart';
import '../models/lyric_line.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import 'album_screen.dart';
import '../utils/navigation_helper.dart';
import '../utils/album_sanitizer.dart';
import '../models/song.dart';
import '../models/album.dart';
import '../services/palette_service.dart';
import '../services/youtube_service.dart';
import '../services/offline_service.dart';
import '../services/lrc_ttml_parser.dart';
import '../widgets/now_playing/queue_view.dart';
import '../widgets/now_playing/now_playing_more_menu.dart';
import '../widgets/now_playing/track_navigation_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/lrclib_service.dart';
import '../services/groovy_connect_service.dart';
import '../widgets/connect/groovy_connect_modal.dart';
import '../theme/app_theme.dart';

class NowPlayingScreen extends StatefulWidget {
  final ImageProvider image;
  final String title;
  final String artist;
  final String heroTag;
  final List<LyricLine> lyrics;
  final Song? song;
  final double topPadding;

  const NowPlayingScreen({
    super.key,
    required this.image,
    required this.title,
    required this.artist,
    required this.heroTag,
    this.lyrics = const [],
    this.song,
    this.topPadding = 0.0,
  });

  static final Map<String, List<LyricLine>> _lyricsCache = {};

  static String getLyricsCacheKey(Song song) {
    final artist = LrcLibService.normalizeForMatching(LrcLibService.cleanArtist(song.artist ?? ''));
    final title = LrcLibService.normalizeForMatching(LrcLibService.cleanTitle(song.title));
    return '$artist|$title';
  }

  static List<LyricLine>? getCachedLyrics(Song song) {
    if (_lyricsCache.containsKey(song.id)) return _lyricsCache[song.id];
    final key = getLyricsCacheKey(song);
    if (_lyricsCache.containsKey(key)) return _lyricsCache[key];
    return null;
  }

  static void setCachedLyrics(Song song, List<LyricLine> lyrics) {
    _lyricsCache[song.id] = lyrics;
    _lyricsCache[getLyricsCacheKey(song)] = lyrics;
  }

  static bool isSameTrack(Song? a, Song? b) {
    if (a == null || b == null) return false;
    if (a.id == b.id) return true;
    final aTitle = LrcLibService.normalizeForMatching(LrcLibService.cleanTitle(a.title));
    final bTitle = LrcLibService.normalizeForMatching(LrcLibService.cleanTitle(b.title));
    final aArtist = LrcLibService.normalizeForMatching(LrcLibService.cleanArtist(a.artist ?? ''));
    final bArtist = LrcLibService.normalizeForMatching(LrcLibService.cleanArtist(b.artist ?? ''));
    if (aTitle.isNotEmpty && aTitle == bTitle) {
      if (aArtist.isEmpty || bArtist.isEmpty) return true;
      if (aArtist == bArtist || aArtist.contains(bArtist) || bArtist.contains(aArtist)) return true;
    }
    return false;
  }

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {

  late PageController _pageController;
  int _currentPage = 0;
  List<Color> _bgColors = [];
  List<LyricLine> _fetchedLyrics = [];
  bool _isLoadingLyrics = true;
  bool _isFetchingLyrics = false;
  Song? _lastSong;
  ImageProvider? _currentImageProvider;
  bool _showLyricsInLandscape = true;
  Timer? _colorDebounceTimer;
  Timer? _lyricsDebounceTimer;
  bool _wasFullScreenBefore = false;
  bool _isWindowFullScreen = false;

  bool _isLocalFilePath(String? s) {
    if (s == null || s.isEmpty) return false;
    if (s.startsWith('file://')) return true;
    if (s.startsWith('/')) return true;
    if (s.length > 2 && s[1] == ':') return true;
    return false;
  }

  ImageProvider _resolveImageProvider(Song? song, YoutubeService youtubeService) {
    if (song == null) {
      return const AssetImage('assets/default_cover.png');
    }

    // 1. Check if PlayerProvider resolved an artwork URL (from disk cache or directUrl)
    final resolvedUrl = _playerProvider?.resolvedArtworkUrl;
    if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
      if (_isLocalFilePath(resolvedUrl)) {
        try {
          final filePath = resolvedUrl.startsWith('file://')
              ? Uri.parse(resolvedUrl).toFilePath()
              : resolvedUrl;
          final file = File(filePath);
          if (file.existsSync()) {
            return FileImage(file);
          }
        } catch (_) {}
      } else if (resolvedUrl.startsWith('http://') || resolvedUrl.startsWith('https://')) {
        return CachedNetworkImageProvider(resolvedUrl);
      }
    }

    final raw = (song.coverArt != null && song.coverArt!.isNotEmpty)
        ? song.coverArt!
        : song.id;

    if (song.isLocal || _isLocalFilePath(raw)) {
      try {
        final filePath = raw.startsWith('file://')
            ? Uri.parse(raw).toFilePath()
            : raw;
        final localFile = File(filePath);
        if (localFile.existsSync()) {
          return FileImage(localFile);
        }
      } catch (_) {}
    }

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      final upgraded = youtubeService.getCoverArtUrl(raw, size: 800);
      return CachedNetworkImageProvider(upgraded.isNotEmpty ? upgraded : raw);
    }

    final fallbackCover = youtubeService.getCoverArtUrl(raw, size: 800);
    if (fallbackCover.isNotEmpty) {
      return CachedNetworkImageProvider(fallbackCover);
    }

    final songIdCover = youtubeService.getCoverArtUrl(song.id, size: 800);
    if (songIdCover.isNotEmpty) {
      return CachedNetworkImageProvider(songIdCover);
    }

    return const AssetImage('assets/default_cover.png');
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _fetchedLyrics = widget.lyrics;
    _currentImageProvider = widget.image;
    _lastSong = widget.song;

    // 1. Instant synchronous color lookup from cache
    final songId = widget.song?.id ?? widget.heroTag;
    final cached = PaletteService.getCachedColors(songId);
    if (cached != null) {
      _bgColors = cached;
    } else {
      _bgColors = PaletteService.defaultPalette;
    }

    // 2. Instant lyrics cache check to prevent spinner flash
    if (_fetchedLyrics.isEmpty && widget.song != null) {
      final cachedLyrics = NowPlayingScreen.getCachedLyrics(widget.song!);
      if (cachedLyrics != null && cachedLyrics.isNotEmpty) {
        _fetchedLyrics = cachedLyrics;
        _isLoadingLyrics = false;
      }
    }

    // 3. Defer palette extraction slightly until after the transition frame
    // so entering NowPlayingScreen (bottom sheet on Android or fade on Windows)
    // runs at 120 FPS buttery smooth without any frame drops!
    if (cached == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _extractColors();
      });
    }

    // 4. Defer network lyrics fetch slightly (200ms) to ensure smooth entry
    if (_fetchedLyrics.isEmpty) {
      _lyricsDebounceTimer = Timer(const Duration(milliseconds: 200), () {
        if (mounted) _fetchLyrics();
      });
    }

    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      _initFullScreenState();
    }
  }

  PlayerProvider? _playerProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<PlayerProvider>(context, listen: false);
    if (_playerProvider != provider) {
      _playerProvider?.removeListener(_onPlayerChanged);
      _playerProvider = provider;
      _playerProvider?.addListener(_onPlayerChanged);
      _onPlayerChanged();
    }
  }

  void _onPlayerChanged() {
    if (!mounted || _playerProvider == null) return;
    final currentSong = _playerProvider!.currentSong;
    if (currentSong == null) return;

    final youtubeService = Provider.of<YoutubeService>(context, listen: false);
    final newImageProvider = _resolveImageProvider(currentSong, youtubeService);

    // Remote playback resilience: treat songs with the same title and artist as identical
    // even if telemetry or cross-device resolution reports a different ID format (e.g. dz_... vs yt_...)
    final isSameSong = NowPlayingScreen.isSameTrack(_lastSong, currentSong);

    final isSongChange = !isSameSong;
    final isImageChange = _currentImageProvider != newImageProvider;

    if (isSongChange || isImageChange) {
      _lastSong = currentSong;
      
      // 1. Instant cached color check
      final cachedColors = PaletteService.getCachedColors(currentSong.id);
      
      // 2. Instant lyrics cache check across both ID and artist|title
      final cachedLyrics = NowPlayingScreen.getCachedLyrics(currentSong);
      final hasCachedLyrics = cachedLyrics != null && cachedLyrics.isNotEmpty;

      _colorDebounceTimer?.cancel();
      if (isSongChange) {
        _lyricsDebounceTimer?.cancel();
      }

      // Single atomic setState: update artwork, colors, and lyrics in one frame
      setState(() {
        _currentImageProvider = newImageProvider;
        if (cachedColors != null) {
          _bgColors = cachedColors;
        }
        if (isSongChange) {
          _fetchedLyrics = cachedLyrics ?? <LyricLine>[];
          _isLoadingLyrics = !hasCachedLyrics;
        } else if (_fetchedLyrics.isEmpty && hasCachedLyrics) {
          _fetchedLyrics = cachedLyrics;
          _isLoadingLyrics = false;
        }
      });

      // 4. Stagger background work so UI frame stays 120 FPS buttery smooth
      if (cachedColors == null) {
        _colorDebounceTimer = Timer(const Duration(milliseconds: 140), () {
          if (mounted) _extractColors();
        });
      }

      if (isSongChange && !hasCachedLyrics) {
        _lyricsDebounceTimer = Timer(const Duration(milliseconds: 220), () {
          if (mounted) _fetchLyrics();
        });
      } else if (!isSongChange && _fetchedLyrics.isEmpty && !hasCachedLyrics && !_isFetchingLyrics) {
        _lyricsDebounceTimer ??= Timer(const Duration(milliseconds: 220), () {
          if (mounted) _fetchLyrics();
        });
      }
    }
  }

  List<LyricLine> _extractParsedLines(Map<String, dynamic> raw) {
    if (raw['structuredLyrics'] != null) {
      final structured = raw['structuredLyrics'] as List?;
      if (structured != null && structured.isNotEmpty) {
        final firstStruct = structured.first;
        if (firstStruct is Map) {
          final lines = firstStruct['line'] as List?;
          if (lines != null) {
            final res = <LyricLine>[];
            for (final l in lines) {
              if (l is Map) {
                final startVal = l['start'];
                final startMs = (startVal is num)
                    ? startVal.toInt()
                    : (int.tryParse(startVal?.toString() ?? '') ?? 0);
                final val = l['value']?.toString() ?? '';
                if (val.isNotEmpty) {
                  res.add(LyricLine(
                    startTime: Duration(milliseconds: startMs),
                    text: val,
                  ));
                }
              }
            }
            if (res.isNotEmpty) return res;
          }
        }
      }
    }
    if (raw['syncedLyrics'] != null && raw['syncedLyrics'] is String) {
      final lrcText = raw['syncedLyrics'] as String;
      final parsed = LrcParser.parseLrc(lrcText);
      if (parsed.isNotEmpty) return parsed;
    }
    if (raw['value'] != null && raw['value'] is String) {
      final lrcText = raw['value'] as String;
      final parsed = LrcParser.parseLrc(lrcText);
      if (parsed.isNotEmpty) return parsed;
    }
    if (raw['plainLyrics'] != null && raw['plainLyrics'] is String) {
      final text = raw['plainLyrics'] as String;
      final parsed = LrcParser.parseLrc(text);
      if (parsed.isNotEmpty) return parsed;
    }
    return [];
  }

  Future<void> _fetchLyrics({bool force = false}) async {
    if (_lastSong == null) {
      if (mounted) setState(() => _isLoadingLyrics = false);
      return;
    }
    if (_isFetchingLyrics && !force) return;

    final songId = _lastSong!.id;
    final song = _lastSong!;

    // Instant cache check: if already fetched, show immediately without spinner
    if (!force) {
      final cachedLyrics = NowPlayingScreen.getCachedLyrics(song);
      if (cachedLyrics != null && cachedLyrics.isNotEmpty) {
        if (mounted) {
          setState(() {
            _fetchedLyrics = cachedLyrics;
            _isLoadingLyrics = false;
          });
        }
        return;
      }
    }

    _isFetchingLyrics = true;
    if (mounted) {
      setState(() => _isLoadingLyrics = true);
    }

    try {
      final offlineService = OfflineService();

      List<LyricLine> parsed = [];

      // 1. Instant disk cache lookup for any song
      final raw = await offlineService.getLocalLyrics(songId)
          .timeout(const Duration(seconds: 3), onTimeout: () => null);
      if (raw != null) {
        parsed = _extractParsedLines(raw);
      }

      // 2. Online fetch: Try LRCLIB, YouTube CC, and Genius with exact duration matching
      if (parsed.isEmpty && !offlineService.isOfflineMode) {
        // Check if song changed before starting expensive network calls
        if (!mounted || !NowPlayingScreen.isSameTrack(_lastSong, song)) {
          return;
        }
        final durSeconds = (song.duration != null && song.duration! > 0)
            ? song.duration!
            : (_playerProvider?.duration.inSeconds ?? 0);
        final lrcLibRes = await LrcLibService().searchLyrics(
          artist: song.artist,
          title: song.title,
          durationSeconds: durSeconds > 0 ? durSeconds : null,
          songId: songId,
        ).timeout(const Duration(seconds: 15), onTimeout: () => null).catchError((_) => null);

        if (lrcLibRes != null) {
          parsed = _extractParsedLines(lrcLibRes);
          offlineService.saveLyrics(songId, lrcLibRes).catchError((_) {});
        }
      }

      if (!mounted) return;

      if (parsed.isNotEmpty) {
        NowPlayingScreen.setCachedLyrics(song, parsed);
        if (_lastSong != null && _lastSong!.id != songId) {
          NowPlayingScreen.setCachedLyrics(_lastSong!, parsed);
        }
      }

      final isStillSameSong = NowPlayingScreen.isSameTrack(_lastSong, song);
      if (mounted && isStillSameSong) {
        setState(() {
          _fetchedLyrics = parsed;
          _isLoadingLyrics = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching lyrics: $e');
    } finally {
      // ALWAYS reset loading state if still mounted - prevents infinite spinner
      _isFetchingLyrics = false;
      if (mounted) {
        setState(() {
          _isLoadingLyrics = false;
        });
      }
    }
  }

  Future<void> _extractColors() async {
    if (_currentImageProvider == null || _lastSong == null) return;
    final imageId = _lastSong!.id;
    final colors = await PaletteService.extractColors(_currentImageProvider!, imageId);
    if (mounted && _lastSong?.id == imageId && _bgColors != colors) {
      setState(() {
        _bgColors = colors;
      });
    }
  }

  Future<void> _initFullScreenState() async {
    try {
      _wasFullScreenBefore = await windowManager.isFullScreen();
      if (!_wasFullScreenBefore) {
        await windowManager.setFullScreen(true);
      }
      if (mounted) {
        setState(() => _isWindowFullScreen = true);
      }
    } catch (e) {
      debugPrint('Error entering full screen in NowPlayingScreen: $e');
    }
  }

  Future<void> _toggleWindowFullScreen() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      try {
        final isFs = await windowManager.isFullScreen();
        await windowManager.setFullScreen(!isFs);
        if (mounted) {
          setState(() => _isWindowFullScreen = !isFs);
        }
      } catch (e) {
        debugPrint('Error toggling full screen: $e');
      }
    }
  }

  void _exitFullScreen() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      try {
        if (!_wasFullScreenBefore) {
          await windowManager.setFullScreen(false);
        }
      } catch (e) {
        debugPrint('Error exiting full screen: $e');
      }
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      if (!_wasFullScreenBefore) {
        windowManager.setFullScreen(false);
      }
    }
    _playerProvider?.removeListener(_onPlayerChanged);
    _colorDebounceTimer?.cancel();
    _lyricsDebounceTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _bgColors.isNotEmpty ? _bgColors.first : Colors.white;

    return Theme(
      data: ThemeData.dark(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
              // 1. Shared Animated Fluid Mesh Gradient Background
              Positioned.fill(
                child: BlurredGradientBackground(
                  colors: _bgColors,
                  image: _currentImageProvider ?? widget.image,
                  child: const SizedBox.expand(),
                ),
              ),

              // 2. Foreground Content Area
              Positioned.fill(
                child: SafeArea(
                  top: false, // Explicitly controlled via effectiveTopPadding for pixel-perfect spacing on all devices
                  bottom: true,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isLandscape = constraints.maxWidth > constraints.maxHeight;

                      if (isLandscape) {
                        return _buildLandscapeLayout(context, accentColor);
                      }

                      return _buildPortraitLayout(context, accentColor, constraints);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildPortraitLayout(BuildContext context, Color accentColor, BoxConstraints constraints) {
    final isCompact = constraints.maxHeight < 680;
    final mediaQuery = MediaQuery.of(context);
    final rawStatus = math.max(
      widget.topPadding,
      math.max(mediaQuery.padding.top, mediaQuery.viewPadding.top),
    );
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    // On mobile devices, status bar is typically between 30px and 48px.
    // If rawStatus was not detected (e.g. inside a modal bottom sheet), default to a safe 38px.
    final statusBarHeight = isMobile ? math.max(rawStatus, 38.0) : rawStatus;
    final effectiveTopPadding = statusBarHeight + (isCompact ? 8.0 : 12.0);
    final coverTopPadding = statusBarHeight + (isCompact ? 2.0 : 6.0);

    return Column(
      children: [
        // Swipable Main Content Area (Cover <-> Lyrics <-> Queue)
        // Maintained at constant stable height so page swiping is 120 FPS fluid without layout shifts
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            children: [
              _KeepAlivePage(child: _buildCoverPage(context, isCompact, coverTopPadding)),
              _KeepAlivePage(child: _buildLyricsPage(effectiveTopPadding)),
              _KeepAlivePage(child: _buildQueuePage(effectiveTopPadding)),
            ],
          ),
        ),

        // Fixed Bottom Controls (Scrubber + Playback Controls + Bottom Actions)
        _buildBottomSection(accentColor, isCompact),
      ],
    );
  }


  Widget _buildTrackMiniHeader(BuildContext context) {
    return Selector<PlayerProvider, (Song?, bool)>(
      selector: (_, p) => (p.currentSong, p.currentSong?.starred ?? false),
      builder: (context, data, child) {
        final provider = Provider.of<PlayerProvider>(context, listen: false);
        final currentSong = data.$1 ?? widget.song;
        final title = currentSong?.title ?? widget.title;
        final artist = currentSong?.artist ?? widget.artist;
        final isStarred = currentSong?.starred ?? false;

        return RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
            children: [
              // Cover Thumbnail -> Navigate to Album or Page 0
              GestureDetector(
                onTap: () {
                  if (currentSong != null) {
                    final cleanAlb = AlbumSanitizer.cleanTitle(currentSong.album);
                    final effectiveAlbumId = (currentSong.albumId != null && currentSong.albumId!.isNotEmpty)
                        ? currentSong.albumId!
                        : (cleanAlb.isNotEmpty
                            ? cleanAlb
                            : '${currentSong.title} ${currentSong.artist ?? ""}');
                    final alb = (cleanAlb.isNotEmpty)
                        ? Album(
                            id: effectiveAlbumId,
                            name: cleanAlb,
                            artist: currentSong.artist,
                            coverArt: currentSong.coverArt,
                          )
                        : null;
                    NavigationHelper.push(
                      context,
                      AlbumScreen(
                        albumId: effectiveAlbumId,
                        album: alb,
                        song: currentSong,
                      ),
                    );
                  } else {
                    _pageController.animateToPage(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: Consumer<LibraryProvider>(
                  builder: (context, lib, _) {
                    final isFav = currentSong != null &&
                        (lib.isSongStarred(currentSong.id) || (currentSong.starred ?? false));
                    return Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image(
                              image: _currentImageProvider ?? widget.image,
                              fit: BoxFit.cover,
                            ),
                            if (isFav)
                              Positioned(
                                bottom: 2,
                                right: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.star_rounded,
                                    color: Color(0xFFFFD60A),
                                    size: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Title & Artist -> Sheet Options
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    TrackNavigationBottomSheet.show(
                      context,
                      song: currentSong,
                      coverProvider: _currentImageProvider ?? widget.image,
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        artist,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.65),
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Consumer<GroovyConnectService>(
                        builder: (context, groovyConnect, _) {
                          if (!groovyConnect.isConnected) return const SizedBox.shrink();
                          final devName = groovyConnect.connectedDevice?.name ?? 'Dispositivo';
                          return Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.speaker_phone_rounded,
                                  size: 11,
                                  color: AppTheme.appleMusicRed,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    devName,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.appleMusicRed,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Favorite Button
              Consumer<LibraryProvider>(
                builder: (context, lib, _) {
                  final isFav = currentSong != null
                      ? (lib.isSongStarred(currentSong.id) || (currentSong.starred ?? false))
                      : isStarred;
                  return _CircleActionButton(
                    margin: const EdgeInsets.only(right: 8),
                    onTap: () async {
                      if (currentSong != null) {
                        HapticFeedback.lightImpact();
                        final newFav = await lib.toggleStarSong(currentSong);
                        provider.updateSongStarred(currentSong.id, newFav);
                      }
                    },
                    icon: Icon(
                      isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: isFav ? const Color(0xFFFFD60A) : Colors.white.withValues(alpha: 0.90),
                      size: 21,
                    ),
                  );
                },
              ),

              // More Options Button (Vertical 3 dots)
              _CircleActionButton(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    useRootNavigator: true,
                    builder: (context) => NowPlayingMoreMenu(
                      song: currentSong,
                      imageProvider: _currentImageProvider ?? widget.image,
                      onNavigateToLyrics: () => _pageController.animateToPage(
                        1,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                    ),
                  );
                },
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: Colors.white.withValues(alpha: 0.90),
                  size: 21,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

  Widget _buildCoverPage(BuildContext context, bool isCompact, [double topPadding = 0]) {
    return Selector<PlayerProvider, (Song?, bool, bool)>(
      selector: (_, p) => (p.currentSong, p.currentSong?.starred ?? false, p.isPlaying),
      builder: (context, data, child) {
        final provider = Provider.of<PlayerProvider>(context, listen: false);
        final currentSong = data.$1 ?? widget.song;
        final title = currentSong?.title ?? widget.title;
        final artist = currentSong?.artist ?? widget.artist;
        final isStarred = data.$2;
        final isPlaying = data.$3;

        return Column(
          children: [
            if (topPadding > 0) SizedBox(height: topPadding),
            // Big Album Artwork
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: isCompact ? 2.0 : 6.0,
                  ),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: AlbumArtView(
                      image: _currentImageProvider ?? widget.image,
                      tag: (currentSong?.id == widget.song?.id) ? widget.heroTag : 'cover_${currentSong?.id ?? widget.heroTag}',
                      isPlaying: isPlaying,
                      dominantColor: _bgColors.isNotEmpty ? _bgColors.first : null,
                    ),
                  ),
                ),
              ),
            ),

            // Song Info (Title, Artist, Favorite, More)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 26.0,
                vertical: 6.0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        TrackNavigationBottomSheet.show(
                          context,
                          song: currentSong,
                          coverProvider: _currentImageProvider ?? widget.image,
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MarqueeText(
                            text: title,
                            style: TextStyle(
                              fontSize: isCompact ? 20 : 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: isCompact ? 15 : 17,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.65),
                              letterSpacing: -0.2,
                            ),
                          ),
                          Consumer<GroovyConnectService>(
                            builder: (context, groovyConnect, _) {
                              if (!groovyConnect.isConnected) {
                                return const SizedBox.shrink();
                              }
                              final devName = groovyConnect.connectedDevice?.name ?? 'Dispositivo';
                              return Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    GroovyConnectModal.show(context);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.appleMusicRed.withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppTheme.appleMusicRed.withValues(alpha: 0.4),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.speaker_phone_rounded,
                                          size: 13,
                                          color: AppTheme.appleMusicRed,
                                        ),
                                        const SizedBox(width: 5),
                                        Flexible(
                                          child: Text(
                                            'Escuchando en $devName',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.appleMusicRed,
                                              letterSpacing: -0.2,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Star Button
                  Consumer<LibraryProvider>(
                    builder: (context, lib, _) {
                      final isFav = currentSong != null
                          ? (lib.isSongStarred(currentSong.id) || (currentSong.starred ?? false))
                          : isStarred;
                      return _CircleActionButton(
                        onTap: () async {
                          if (currentSong != null) {
                            HapticFeedback.lightImpact();
                            final newFav = await lib.toggleStarSong(currentSong);
                            provider.updateSongStarred(currentSong.id, newFav);
                          }
                        },
                        icon: Icon(
                          isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: isFav ? const Color(0xFFFFD60A) : Colors.white.withValues(alpha: 0.90),
                          size: 21,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  // More Options Button (Vertical 3 dots)
                  _CircleActionButton(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        useRootNavigator: true,
                        builder: (context) => NowPlayingMoreMenu(
                          song: currentSong,
                          imageProvider: _currentImageProvider ?? widget.image,
                          onNavigateToLyrics: () => _pageController.animateToPage(
                            1,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          ),
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: Colors.white.withValues(alpha: 0.90),
                      size: 21,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLyricsPage([double topPadding = 0]) {
    final provider = context.read<PlayerProvider>();
    return Column(
      children: [
        if (topPadding > 0) SizedBox(height: topPadding),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 2.0),
          child: _buildTrackMiniHeader(context),
        ),
        Expanded(
          child: _fetchedLyrics.isNotEmpty
              ? LyricsListView(
                  lyrics: _fetchedLyrics,
                  positionStream: provider.positionStream,
                  initialPosition: provider.position,
                  isActive: _currentPage == 1,
                  onSeek: (duration) {
                    provider.seek(duration);
                  },
                )
              : Center(
                  child: _isLoadingLyrics
                      ? const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Cargando letra...',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              "Letra no disponible",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () => _fetchLyrics(),
                              icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 18),
                              label: const Text(
                                'Buscar de nuevo',
                                style: TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                ),
        ),
      ],
    );
  }

  Widget _buildQueuePage([double topPadding = 0]) {
    return Column(
      children: [
        if (topPadding > 0) SizedBox(height: topPadding),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 2.0),
          child: _buildTrackMiniHeader(context),
        ),
        const Expanded(
          child: QueueView(),
        ),
      ],
    );
  }

  Widget _buildBottomSection(Color accentColor, bool isCompact) {
    return Selector<PlayerProvider, (bool, bool, RepeatMode, Duration)>(
      selector: (_, p) => (p.isPlaying, p.shuffleEnabled, p.repeatMode, p.duration),
      builder: (context, data, child) {
        final provider = Provider.of<PlayerProvider>(context, listen: false);
        final isPlaying = data.$1;
        final shuffleEnabled = data.$2;
        final repeatMode = data.$3;
        final duration = data.$4;

        return RepaintBoundary(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Scrubber Progress Slider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: RepaintBoundary(
                  child: PlaybackProgressSlider(
                    position: provider.position,
                    duration: duration,
                    bufferedPosition: provider.bufferedPosition,
                    isBuffering: provider.isBuffering,
                    positionStream: provider.positionStream,
                    bufferedPositionStream: provider.bufferedPositionStream,
                    isBufferingStream: provider.isBufferingStream,
                    accentColor: Colors.white,
                    onChanged: (val) {
                      provider.seek(val);
                    },
                  ),
                ),
              ),

              SizedBox(height: isCompact ? 4 : 8),

              // 2. 3-Button Iconic Playback Controls
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: PlaybackControls(
                  isPlaying: isPlaying,
                  isShuffleEnabled: shuffleEnabled,
                  isRepeatEnabled: repeatMode != RepeatMode.off,
                  accentColor: accentColor,
                  onPlayPause: () => provider.togglePlayPause(),
                  onNext: () => provider.skipNext(),
                  onPrevious: () => provider.skipPrevious(),
                  onShuffleToggle: () => provider.toggleShuffle(),
                  onRepeatToggle: () => provider.toggleRepeat(),
                ),
              ),

              // 3. Bottom Actions (Lyrics, Cast, Queue)
              NowPlayingBottomActions(
                isLyricsActive: _currentPage == 1,
                isQueueActive: _currentPage == 2,
                accentColor: accentColor,
                onLyricsTap: () {
                  if (_currentPage == 1) {
                    _pageController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  } else {
                    _pageController.animateToPage(1, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  }
                },
                onQueueTap: () {
                  if (_currentPage == 2) {
                    _pageController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  } else {
                    _pageController.animateToPage(2, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  }
                },
              ),

              SizedBox(height: isCompact ? 8 : 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLandscapeLayout(BuildContext context, Color accentColor) {
    return Selector<PlayerProvider, (Song?, bool, Duration)>(
      selector: (_, p) => (p.currentSong, p.isPlaying, p.duration),
      builder: (context, data, child) {
        final provider = Provider.of<PlayerProvider>(context, listen: false);
        final currentSong = data.$1 ?? widget.song;
        final isPlaying = data.$2;
        final duration = data.$3;
        final title = currentSong?.title ?? widget.title;
        final artist = (currentSong?.artistParticipants?.isNotEmpty == true
            ? currentSong!.artistParticipants!.map((a) => a.name).join(', ')
            : currentSong?.artist) ?? widget.artist;
        final album = currentSong?.album ?? '';
        final hasLyrics = _showLyricsInLandscape;

        return Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                _exitFullScreen();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.f11) {
                _toggleWindowFullScreen();
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: Stack(
            children: [
              // Main Apple Music View (2-Column if has lyrics, or Centered if no lyrics)
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (hasLyrics) {
                      return _buildTwoColumnLandscape(
                        context,
                        constraints,
                        provider,
                        isPlaying,
                        duration,
                        title,
                        artist,
                        album,
                        currentSong,
                      );
                    } else {
                      return _buildCenteredLandscape(
                        context,
                        constraints,
                        provider,
                        isPlaying,
                        duration,
                        title,
                        artist,
                        album,
                        currentSong,
                      );
                    }
                  },
                ),
              ),

              // Window Controls (Top Right: Close Fullscreen, Close)
              Positioned(
                top: 24,
                right: 28,
                child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _GlassIconButton(
                    icon: _isWindowFullScreen
                        ? Icons.close_fullscreen_rounded
                        : Icons.fullscreen_rounded,
                    size: 18,
                    tooltip: _isWindowFullScreen
                        ? 'Salir de pantalla completa (F11)'
                        : 'Pantalla completa (F11)',
                    onTap: _toggleWindowFullScreen,
                  ),
                  const SizedBox(width: 8),
                  _GlassIconButton(
                    icon: Icons.close_rounded,
                    size: 20,
                    tooltip: 'Cerrar (Esc)',
                    onTap: _exitFullScreen,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

  Widget _buildTwoColumnLandscape(
    BuildContext context,
    BoxConstraints constraints,
    PlayerProvider provider,
    bool isPlaying,
    Duration duration,
    String title,
    String artist,
    String album,
    Song? currentSong,
  ) {
    final availableHeight = constraints.maxHeight;
    final coverSize = (availableHeight * 0.44).clamp(180.0, 380.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Column: Artwork, Metadata, Scrubber, Controls
          Expanded(
            flex: 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Album Art
                SizedBox(
                  width: coverSize,
                  height: coverSize,
                  child: AlbumArtView(
                    image: _currentImageProvider ?? widget.image,
                    tag: (currentSong?.id == widget.song?.id) ? widget.heroTag : 'cover_${currentSong?.id ?? widget.heroTag}',
                    isPlaying: isPlaying,
                    dominantColor: _bgColors.isNotEmpty ? _bgColors.first : null,
                  ),
                ),

                const SizedBox(height: 20),

                // Title & Favorite
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Consumer<LibraryProvider>(
                        builder: (context, lib, _) {
                          final isFav = currentSong != null
                              ? (lib.isSongStarred(currentSong.id) || (currentSong.starred ?? false))
                              : false;
                          return GestureDetector(
                            onTap: () async {
                              if (currentSong != null) {
                                HapticFeedback.lightImpact();
                                final newFav = await lib.toggleStarSong(currentSong);
                                provider.updateSongStarred(currentSong.id, newFav);
                              }
                            },
                            child: Icon(
                              isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: isFav ? const Color(0xFFFFD60A) : Colors.white38,
                              size: 20,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),

                // Artist
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Text(
                    artist,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                const SizedBox(height: 16),

                // Progress Slider
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: PlaybackProgressSlider(
                    position: provider.position,
                    duration: duration,
                    bufferedPosition: provider.bufferedPosition,
                    isBuffering: provider.isBuffering,
                    positionStream: provider.positionStream,
                    bufferedPositionStream: provider.bufferedPositionStream,
                    isBufferingStream: provider.isBufferingStream,
                    accentColor: Colors.white,
                    onChanged: (val) {
                      provider.seek(val);
                    },
                  ),
                ),

                const SizedBox(height: 8),

                // Apple Music Controls
                _buildAppleMusicLandscapeControls(
                  context,
                  provider,
                  isPlaying,
                  currentSong,
                ),
              ],
            ),
          ),

          const SizedBox(width: 32),

          // Right Column: Lyrics or Queue
          Expanded(
            flex: 6,
            child: _buildLandscapeRightPanel(context, provider),
          ),
        ],
      ),
    );
  }

  Widget _buildCenteredLandscape(
    BuildContext context,
    BoxConstraints constraints,
    PlayerProvider provider,
    bool isPlaying,
    Duration duration,
    String title,
    String artist,
    String album,
    Song? currentSong,
  ) {
    final availableHeight = constraints.maxHeight;
    final coverSize = (availableHeight * 0.46).clamp(240.0, 440.0);
    final displaySubtitle = album.isNotEmpty ? '$artist — $album' : artist;

    return Center(
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Centered Cover Art
              SizedBox(
                width: coverSize,
                height: coverSize,
                child: AlbumArtView(
                  image: _currentImageProvider ?? widget.image,
                  tag: (currentSong?.id == widget.song?.id) ? widget.heroTag : 'cover_${currentSong?.id ?? widget.heroTag}',
                  isPlaying: isPlaying,
                  dominantColor: _bgColors.isNotEmpty ? _bgColors.first : null,
                ),
              ),

              const SizedBox(height: 28),

              // 2. Track Title (Centered)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 550),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(height: 6),

              // 3. Artist & Album (Centered)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Text(
                  displaySubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(height: 20),

              // 4. Scrubber Progress Slider (Centered, max width 440)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: PlaybackProgressSlider(
                  position: provider.position,
                  duration: duration,
                  bufferedPosition: provider.bufferedPosition,
                  isBuffering: provider.isBuffering,
                  positionStream: provider.positionStream,
                  bufferedPositionStream: provider.bufferedPositionStream,
                  isBufferingStream: provider.isBufferingStream,
                  accentColor: Colors.white,
                  onChanged: (val) {
                    provider.seek(val);
                  },
                ),
              ),

              const SizedBox(height: 12),

              // 5. Centered Apple Music Control Bar
              _buildAppleMusicLandscapeControls(
                context,
                provider,
                isPlaying,
                currentSong,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLandscapeRightPanel(BuildContext context, PlayerProvider provider) {
    if (!_showLyricsInLandscape) {
      return const QueueView();
    }

    if (_isLoadingLyrics) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.5,
            ),
            SizedBox(height: 16),
            Text(
              'Cargando letra...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_fetchedLyrics.isNotEmpty) {
      return LyricsListView(
        lyrics: _fetchedLyrics,
        positionStream: provider.positionStream,
        initialPosition: provider.position,
        isActive: true,
        onSeek: (duration) => provider.seek(duration),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lyrics_outlined,
            size: 56,
            color: Colors.white.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 16),
          Text(
            'Letra no disponible',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.70),
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _fetchLyrics(),
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            label: const Text(
              'Buscar de nuevo',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppleMusicLandscapeControls(
    BuildContext context,
    PlayerProvider provider,
    bool isPlaying,
    Song? currentSong,
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Volume Popup Button
          _VolumePopupButton(provider: provider),

          // More Options (...)
          IconButton(
            icon: const Icon(
              Icons.more_horiz_rounded,
              color: Colors.white70,
              size: 22,
            ),
            tooltip: 'Más opciones',
            onPressed: () {
              if (currentSong != null) {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  useRootNavigator: true,
                  builder: (ctx) => NowPlayingMoreMenu(
                    song: currentSong,
                    imageProvider: _currentImageProvider ?? widget.image,
                    onNavigateToLyrics: () {
                      setState(() {
                        _showLyricsInLandscape = true;
                      });
                    },
                  ),
                );
              }
            },
          ),

          // Previous Track
          IconButton(
            icon: const Icon(
              Icons.fast_rewind_rounded,
              color: Colors.white,
              size: 32,
            ),
            tooltip: 'Anterior',
            onPressed: () => provider.skipPrevious(),
          ),

          // Play / Pause Prominent Button
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 30,
              ),
              tooltip: isPlaying ? 'Pausar' : 'Reproducir',
              onPressed: () => provider.togglePlayPause(),
            ),
          ),

          // Next Track
          IconButton(
            icon: const Icon(
              Icons.fast_forward_rounded,
              color: Colors.white,
              size: 32,
            ),
            tooltip: 'Siguiente',
            onPressed: () => provider.skipNext(),
          ),

          // Lyrics / Queue Toggle
          IconButton(
            icon: Icon(
              Icons.chat_bubble_outline_rounded,
              color: _showLyricsInLandscape ? Colors.white : Colors.white38,
              size: 22,
            ),
            tooltip: 'Letras',
            onPressed: () {
              setState(() {
                _showLyricsInLandscape = !_showLyricsInLandscape;
              });
            },
          ),
        ],
      ),
    );
  }
}

class _CircleActionButton extends StatefulWidget {
  final Widget icon;
  final VoidCallback onTap;
  final EdgeInsets? margin;

  const _CircleActionButton({
    required this.icon,
    required this.onTap,
    this.margin,
  });

  @override
  State<_CircleActionButton> createState() => _CircleActionButtonState();
}

class _CircleActionButtonState extends State<_CircleActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() => _isPressed = true);
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.82 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: _isPressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: Container(
          width: 34,
          height: 34,
          margin: widget.margin,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.18),
          ),
          child: Center(
            child: widget.icon,
          ),
        ),
      ),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _VolumePopupButton extends StatelessWidget {
  final PlayerProvider provider;
  const _VolumePopupButton({required this.provider});

  @override
  Widget build(BuildContext context) {
    final vol = provider.volume;
    final isMuted = vol == 0;
    final icon = isMuted
        ? Icons.volume_off_rounded
        : vol < 0.5
            ? Icons.volume_down_rounded
            : Icons.volume_up_rounded;

    return PopupMenuButton<double>(
      icon: Icon(icon, color: Colors.white70, size: 22),
      tooltip: 'Volumen',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFF1E1E1E),
      offset: const Offset(0, -60),
      itemBuilder: (ctx) => [
        PopupMenuItem<double>(
          enabled: false,
          child: StatefulBuilder(
            builder: (context, setMenuState) {
              return SizedBox(
                width: 160,
                child: Row(
                  children: [
                    Icon(
                      provider.volume == 0
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: const SliderThemeData(
                          trackHeight: 3,
                          thumbShape:
                              RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape:
                              RoundSliderOverlayShape(overlayRadius: 12),
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: Colors.white,
                        ),
                        child: Slider(
                          value: provider.volume.clamp(0.0, 1.0),
                          onChanged: (v) {
                            setMenuState(() {});
                            provider.setVolume(v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GlassIconButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final String tooltip;
  final VoidCallback onTap;

  const _GlassIconButton({
    required this.icon,
    this.size = 18,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<_GlassIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isHovered
                  ? Colors.white.withValues(alpha: 0.28)
                  : Colors.white.withValues(alpha: 0.12),
            ),
            child: Icon(
              widget.icon,
              size: widget.size,
              color: _isHovered
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ),
      ),
    );
  }
}



