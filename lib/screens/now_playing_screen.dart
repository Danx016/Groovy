import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
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

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {

  late PageController _pageController;
  int _currentPage = 0;
  List<Color> _bgColors = [];
  List<LyricLine> _fetchedLyrics = [];
  bool _isLoadingLyrics = true;
  Song? _lastSong;
  ImageProvider? _currentImageProvider;
  bool _showLyricsControls = true;
  bool _showLyricsInLandscape = true;
  Timer? _colorDebounceTimer;
  Timer? _lyricsDebounceTimer;

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
    }

    // 2. Lock 120Hz display refresh rate on Android
    if (!kIsWeb && Platform.isAndroid) {
      FlutterDisplayMode.setHighRefreshRate().catchError((_) {});
    }

    // 3. Enter true OS fullscreen on desktop for borderless Apple Music experience
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      windowManager.setFullScreen(true).catchError((_) {});
    }

    // 4. Extract palette immediately (runs async, caches instantly)
    if (_bgColors.isEmpty) {
      _extractColors();
    }

    // 5. Defer network lyrics fetch slightly (160ms) to ensure 120Hz smooth entry
    if (_fetchedLyrics.isEmpty) {
      Future.delayed(const Duration(milliseconds: 160), () {
        if (mounted) _fetchLyrics();
      });
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
    if (currentSong != null && _lastSong?.id != currentSong.id) {
      _lastSong = currentSong;
      _updateImageProviderAndColors();
      
      _lyricsDebounceTimer?.cancel();
      if (_lyricsCache.containsKey(currentSong.id)) {
        setState(() {
          _fetchedLyrics = _lyricsCache[currentSong.id]!;
          _isLoadingLyrics = false;
        });
      } else {
        setState(() => _isLoadingLyrics = true);
        _lyricsDebounceTimer = Timer(const Duration(milliseconds: 150), () {
          if (mounted) _fetchLyrics();
        });
      }
    }
  }

  static final Map<String, List<LyricLine>> _lyricsCache = {};

  Future<void> _updateImageProviderAndColors() async {
    if (_lastSong == null) return;
    final youtubeService = Provider.of<YoutubeService>(context, listen: false);
    final coverUrl = _lastSong!.coverArt != null ? youtubeService.getCoverArtUrl(_lastSong!.coverArt, size: 600) : null;
    if (coverUrl != null) {
      _currentImageProvider = CachedNetworkImageProvider(coverUrl);
    } else {
      _currentImageProvider = const AssetImage('assets/default_cover.png');
    }
    
    // Debounce palette extraction to keep UI butter-smooth during rapid skips
    _colorDebounceTimer?.cancel();
    _colorDebounceTimer = Timer(const Duration(milliseconds: 80), () {
      if (mounted) _extractColors();
    });
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

  Future<void> _fetchLyrics() async {
    if (_lastSong == null) return;
    final songId = _lastSong!.id;
    final song = _lastSong!;

    // Instant cache check: if already fetched, show immediately without spinner
    if (_lyricsCache.containsKey(songId)) {
      if (mounted) {
        setState(() {
          _fetchedLyrics = _lyricsCache[songId]!;
          _isLoadingLyrics = false;
        });
      }
      return;
    }
    
    if (mounted) {
      setState(() => _isLoadingLyrics = true);
    }

    try {
      final offlineService = OfflineService();
      
      List<LyricLine> parsed = [];

      // 1. Offline / Local check
      if (offlineService.isOfflineMode || song.isLocal || offlineService.isSongDownloaded(songId)) {
        final raw = await offlineService.getLocalLyrics(songId);
        if (raw != null) {
          parsed = _extractParsedLines(raw);
        }
      }
      
      // 2. Online fetch: Try LRCLIB for synchronized lyrics
      if (parsed.isEmpty && !offlineService.isOfflineMode) {
        final lrcLibRes = await LrcLibService().searchLyrics(
          artist: song.artist,
          title: song.title,
          durationSeconds: song.duration,
        ).catchError((_) => null);

        if (lrcLibRes != null) {
          parsed = _extractParsedLines(lrcLibRes);
        }
      }
      
      // If user switched songs while loading, discard this result
      if (!mounted || _lastSong?.id != songId) return;

      _lyricsCache[songId] = parsed;

      if (mounted && _lastSong?.id == songId) {
        setState(() {
          _fetchedLyrics = parsed;
          _isLoadingLyrics = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching lyrics: $e');
      if (mounted && _lastSong?.id == songId) {
        setState(() {
          _fetchedLyrics = [];
          _isLoadingLyrics = false;
        });
      }
    } finally {
      if (mounted && _lastSong?.id == songId) {
        setState(() => _isLoadingLyrics = false);
      }
    }
  }

  Future<void> _extractColors() async {
    if (_currentImageProvider == null || _lastSong == null) return;
    final imageId = _lastSong!.id;
    final colors = await PaletteService.extractColors(_currentImageProvider!, imageId);
    if (mounted) {
      setState(() {
        _bgColors = colors;
      });
    }
  }

  void _exitFullScreen() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      await windowManager.setFullScreen(false).catchError((_) {});
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      windowManager.setFullScreen(false).catchError((_) {});
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
    final statusBarHeight = MediaQuery.of(context).viewPadding.top;
    final effectiveTopPadding = math.max(statusBarHeight, 38.0) + 8.0;

    return Column(
      children: [
        // 1. Smooth Universal Header (Crossfades between Drag Pill and Track Info Header)
        Padding(
          padding: EdgeInsets.only(
            top: _currentPage == 0 ? (widget.topPadding > 0 ? widget.topPadding * 0.3 : 10.0) : effectiveTopPadding,
            left: 20.0,
            right: 20.0,
            bottom: 4.0,
          ),
          child: AnimatedCrossFade(
            firstChild: _buildDragHandle(isCompact),
            secondChild: _buildTrackMiniHeader(context),
            crossFadeState: _currentPage == 0
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 250),
          ),
        ),

        // 2. Swipable Main Content Area (Cover <-> Lyrics <-> Queue)
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
              _KeepAlivePage(child: _buildCoverPage(context, isCompact)),
              _KeepAlivePage(child: _buildLyricsPage()),
              _KeepAlivePage(child: _buildQueuePage()),
            ],
          ),
        ),

        // 3. Unified Fixed Bottom Controls (Scrubber + Playback Controls + Bottom Actions)
        _buildBottomSection(accentColor, isCompact),
      ],
    );
  }

  Widget _buildDragHandle(bool isCompact) {
    return const SizedBox.shrink();
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
                    final effectiveAlbumId = (currentSong.albumId != null && currentSong.albumId!.isNotEmpty)
                        ? currentSong.albumId!
                        : (currentSong.album != null && currentSong.album!.isNotEmpty && currentSong.album != 'Album' && currentSong.album != 'Álbum')
                            ? currentSong.album!
                            : '${currentSong.title} ${currentSong.artist ?? ""}';
                    final alb = (currentSong.album != null &&
                            currentSong.album!.isNotEmpty &&
                            currentSong.album != 'Album' &&
                            currentSong.album != 'Álbum')
                        ? Album(
                            id: effectiveAlbumId,
                            name: currentSong.album!,
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

  Widget _buildCoverPage(BuildContext context, bool isCompact) {
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
            // Big Album Artwork
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 36.0,
                    vertical: isCompact ? 2.0 : 8.0,
                  ),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: AlbumArtView(
                      image: _currentImageProvider ?? widget.image,
                      tag: currentSong?.id ?? widget.heroTag,
                      isPlaying: isPlaying,
                    ),
                  ),
                ),
              ),
            ),

            // Song Info (Title, Artist, Favorite, More)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 32.0,
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

  Widget _buildLyricsPage() {
    final provider = context.read<PlayerProvider>();
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        setState(() {
          _showLyricsControls = !_showLyricsControls;
        });
      },
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
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Letra no disponible",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
    );
  }

  Widget _buildQueuePage() {
    return const QueueView();
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
        final hideControlsInLyrics = _currentPage == 1 && !_showLyricsControls;

        return RepaintBoundary(
          child: AnimatedCrossFade(
            firstChild: Column(
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

              SizedBox(height: isCompact ? 4 : 8),

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
          secondChild: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              const SizedBox(height: 8),
            ],
          ),
          crossFadeState: hideControlsInLyrics
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
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

        return Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                (event.logicalKey == LogicalKeyboardKey.escape ||
                    event.logicalKey == LogicalKeyboardKey.f11)) {
              _exitFullScreen();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Stack(
            children: [
              // 1. Two-Column Apple Music Layout
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxCoverSize = (constraints.maxHeight * 0.44).clamp(240.0, 380.0);

                  return Row(
                    children: [
                      // LEFT COLUMN: Artwork + Metadata + Lossless + Scrubber + Controls
                      Expanded(
                        flex: 5,
                        child: Center(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Album Cover with rounded corners and shadow
                                Container(
                                  width: maxCoverSize,
                                  height: maxCoverSize,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.45),
                                        blurRadius: 36,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 18),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image(
                                      image: _currentImageProvider ?? widget.image,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 22),

                                // Song Title
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 380),
                                  child: Text(
                                    title,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 23,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: -0.4,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 4),

                                // Artist — Album
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 380),
                                  child: Text(
                                    album.isNotEmpty &&
                                            album != 'Album' &&
                                            album != 'Álbum' &&
                                            album != title
                                        ? '$artist — $album'
                                        : artist,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.70),
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Lossless Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.graphic_eq_rounded,
                                        size: 13,
                                        color: Colors.white.withValues(alpha: 0.85),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Lossless',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white.withValues(alpha: 0.85),
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

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
                                    onChanged: (val) => provider.seek(val),
                                  ),
                                ),
                                const SizedBox(height: 6),

                                // Playback Controls Row (Volume, More, Previous, Play/Pause, Next, Lyrics)
                                _buildAppleMusicLandscapeControls(context, provider, isPlaying, currentSong),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // RIGHT COLUMN: Apple Music Synchronized Lyrics
                      Expanded(
                        flex: 6,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16.0, 32.0, 48.0, 32.0),
                          child: _buildLandscapeRightPanel(context, provider),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // 2. Window Controls (Top Right: Close Fullscreen, Close)
            Positioned(
              top: 24,
              right: 28,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _GlassIconButton(
                    icon: Icons.close_fullscreen_rounded,
                    size: 18,
                    tooltip: 'Salir de pantalla completa (Esc)',
                    onTap: _exitFullScreen,
                  ),
                  const SizedBox(width: 8),
                  _GlassIconButton(
                    icon: Icons.close_rounded,
                    size: 20,
                    tooltip: 'Cerrar',
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

  Widget _buildLandscapeRightPanel(BuildContext context, PlayerProvider provider) {
    if (!_showLyricsInLandscape) {
      return const QueueView();
    }

    if (_isLoadingLyrics) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2.5,
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



