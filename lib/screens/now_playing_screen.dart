import 'dart:async';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
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
import '../services/palette_service.dart';
import '../services/subsonic_service.dart';
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
  Timer? _colorDebounceTimer;
  Timer? _lyricsDebounceTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _fetchedLyrics = widget.lyrics;
    _currentImageProvider = widget.image;
    _lastSong = widget.song;
    _extractColors();
    _fetchLyrics();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<PlayerProvider>(context);
    if (provider.currentSong != null && _lastSong?.id != provider.currentSong?.id) {
      _lastSong = provider.currentSong;
      _updateImageProviderAndColors();
      
      // Debounce lyrics fetch so rapid skipping doesn't spawn parallel requests
      _lyricsDebounceTimer?.cancel();
      if (_lyricsCache.containsKey(_lastSong!.id)) {
        _fetchedLyrics = _lyricsCache[_lastSong!.id]!;
        _isLoadingLyrics = false;
      } else {
        _lyricsDebounceTimer = Timer(const Duration(milliseconds: 150), () {
          if (mounted) _fetchLyrics();
        });
      }
    }
  }

  static final Map<String, List<LyricLine>> _lyricsCache = {};

  Future<void> _updateImageProviderAndColors() async {
    if (_lastSong == null) return;
    final subsonic = Provider.of<SubsonicService>(context, listen: false);
    final coverUrl = _lastSong!.coverArt != null ? subsonic.getCoverArtUrl(_lastSong!.coverArt, size: 600) : null;
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
        final lines = structured.first['line'] as List?;
        if (lines != null) {
          return lines.map((l) {
            return LyricLine(
              startTime: Duration(milliseconds: l['start'] as int),
              text: l['value'] as String,
            );
          }).toList();
        }
      }
    }
    if (raw['value'] != null) {
      final lrcText = raw['value'] as String;
      return LrcParser.parseLrc(lrcText);
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
      final subsonic = Provider.of<SubsonicService>(context, listen: false);
      final offlineService = OfflineService();
      
      List<LyricLine> parsed = [];

      // 1. Offline / Local check
      if (offlineService.isOfflineMode || song.isLocal || offlineService.isSongDownloaded(songId)) {
        final raw = await offlineService.getLocalLyrics(songId);
        if (raw != null) {
          parsed = _extractParsedLines(raw);
        }
      }
      
      // 2. Online fetch: Try OpenSubsonic and LRCLIB in parallel, prioritizing synchronized lyrics
      if (parsed.isEmpty && !offlineService.isOfflineMode) {
        final results = await Future.wait([
          subsonic.getLyricsBySongId(songId).catchError((_) => null),
          LrcLibService().searchLyrics(
            artist: song.artist,
            title: song.title,
            durationSeconds: song.duration,
          ).catchError((_) => null),
          subsonic.getLyrics(
            artist: song.artist,
            title: song.title,
            duration: song.duration,
          ).catchError((_) => null),
        ]).timeout(
          const Duration(seconds: 7),
          onTimeout: () => [null, null, null],
        );

        final openSubsonicRes = results[0];
        final lrcLibRes = results[1];
        final legacySubsonicRes = results[2];

        List<LyricLine> candidate1 = openSubsonicRes != null ? _extractParsedLines(openSubsonicRes) : [];
        List<LyricLine> candidate2 = lrcLibRes != null ? _extractParsedLines(lrcLibRes) : [];
        List<LyricLine> candidate3 = legacySubsonicRes != null ? _extractParsedLines(legacySubsonicRes) : [];

        bool isSynced(List<LyricLine> lines) => lines.any((l) => l.startTime > Duration.zero);

        if (isSynced(candidate1)) {
          parsed = candidate1;
        } else if (isSynced(candidate2)) {
          parsed = candidate2;
        } else if (isSynced(candidate3)) {
          parsed = candidate3;
        } else if (candidate1.isNotEmpty) {
          parsed = candidate1;
        } else if (candidate2.isNotEmpty) {
          parsed = candidate2;
        } else {
          parsed = candidate3;
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

  @override
  void dispose() {
    _colorDebounceTimer?.cancel();
    _lyricsDebounceTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    // Implement drag down to dismiss (shrink and slide down)
    // This requires a more complex CustomRoute or wrapping the whole scaffold 
    // in a Transform. For simplicity in this demo, a basic pop can be triggered
    // if the drag goes far enough, but a true interactive dismissal requires
    // Navigator route transition manipulation.
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _bgColors.isNotEmpty ? _bgColors.first : Colors.white;

    return Theme(
      data: ThemeData.dark(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          child: Stack(
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
      ),
    );
  }

  Widget _buildPortraitLayout(BuildContext context, Color accentColor, BoxConstraints constraints) {
    final isCompact = constraints.maxHeight < 680;

    return Column(
      children: [
        // 1. Smooth Universal Header (Crossfades between Drag Pill and Track Info Header)
        Padding(
          padding: EdgeInsets.only(
            top: widget.topPadding > 0 ? widget.topPadding * 0.3 : 6,
            left: 16.0,
            right: 16.0,
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
              _buildCoverPage(context, isCompact),
              _buildLyricsPage(),
              _buildQueuePage(),
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
    return Consumer<PlayerProvider>(
      builder: (context, provider, child) {
        final currentSong = provider.currentSong ?? widget.song;
        final title = currentSong?.title ?? widget.title;
        final artist = currentSong?.artist ?? widget.artist;
        final isStarred = currentSong?.starred ?? false;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              // Cover Thumbnail -> Navigate to Album or Page 0
              GestureDetector(
                onTap: () {
                  if (currentSong?.albumId != null && currentSong!.albumId!.isNotEmpty) {
                    NavigationHelper.push(context, AlbumScreen(albumId: currentSong.albumId!));
                  } else {
                    _pageController.animateToPage(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: Container(
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
                    child: Image(
                      image: _currentImageProvider ?? widget.image,
                      fit: BoxFit.cover,
                    ),
                  ),
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
                  final isFav = currentSong != null ? (currentSong.starred ?? false) : isStarred;
                  return _CircleActionButton(
                    margin: const EdgeInsets.only(right: 8),
                    onTap: () async {
                      if (currentSong != null) {
                        HapticFeedback.lightImpact();
                        await lib.toggleStarSong(currentSong);
                        provider.toggleFavoriteForSong(currentSong);
                      }
                    },
                    icon: Icon(
                      isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: isFav ? const Color(0xFFFFD600) : Colors.white,
                      size: 20,
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
                    builder: (context) => const NowPlayingMoreMenu(),
                  );
                },
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCoverPage(BuildContext context, bool isCompact) {
    return Consumer<PlayerProvider>(
      builder: (context, provider, child) {
        final currentSong = provider.currentSong ?? widget.song;
        final title = currentSong?.title ?? widget.title;
        final artist = currentSong?.artist ?? widget.artist;
        final isStarred = currentSong?.starred ?? false;

        return Column(
          children: [
            // Big Album Artwork
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 32.0,
                    vertical: isCompact ? 8.0 : 14.0,
                  ),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: AlbumArtView(
                      image: _currentImageProvider ?? widget.image,
                      tag: currentSong?.id ?? widget.heroTag,
                      isPlaying: provider.isPlaying,
                    ),
                  ),
                ),
              ),
            ),

            // Song Info (Title, Artist, Favorite, More)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 28.0,
                vertical: isCompact ? 8.0 : 14.0,
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
                      final isFav = currentSong != null ? (currentSong.starred ?? false) : isStarred;
                      return _CircleActionButton(
                        onTap: () async {
                          if (currentSong != null) {
                            HapticFeedback.lightImpact();
                            await lib.toggleStarSong(currentSong);
                            provider.toggleFavoriteForSong(currentSong);
                          }
                        },
                        icon: Icon(
                          isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: isFav ? const Color(0xFFFFD600) : Colors.white,
                          size: 20,
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
                        builder: (context) => const NowPlayingMoreMenu(),
                      );
                    },
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: Colors.white,
                      size: 20,
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
    return Consumer<PlayerProvider>(
      builder: (context, provider, child) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            setState(() {
              _showLyricsControls = !_showLyricsControls;
            });
          },
          child: _fetchedLyrics.isNotEmpty
              ? StreamBuilder<Duration>(
                  stream: provider.positionStream,
                  initialData: provider.position,
                  builder: (context, snapshot) {
                    return LyricsListView(
                      lyrics: _fetchedLyrics,
                      currentTime: snapshot.data ?? Duration.zero,
                      onSeek: (duration) {
                        provider.seek(duration);
                      },
                    );
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
      },
    );
  }

  Widget _buildQueuePage() {
    return const QueueView();
  }

  Widget _buildBottomSection(Color accentColor, bool isCompact) {
    return Consumer<PlayerProvider>(
      builder: (context, provider, child) {
        final hideControlsInLyrics = _currentPage == 1 && !_showLyricsControls;

        return AnimatedCrossFade(
          firstChild: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Scrubber Progress Slider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: StreamBuilder<Duration>(
                  stream: provider.positionStream,
                  initialData: provider.position,
                  builder: (context, snapshot) {
                    return StreamBuilder<Duration>(
                      stream: provider.bufferedPositionStream,
                      initialData: provider.bufferedPosition,
                      builder: (context, bufSnap) {
                        return StreamBuilder<bool>(
                          stream: provider.isBufferingStream,
                          initialData: provider.isBuffering,
                          builder: (context, buffSnap) {
                            return PlaybackProgressSlider(
                              position: snapshot.data ?? Duration.zero,
                              duration: provider.duration,
                              bufferedPosition: bufSnap.data ?? Duration.zero,
                              isBuffering: buffSnap.data ?? false,
                              accentColor: Colors.white,
                              onChanged: (val) {
                                provider.seek(val);
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),

              SizedBox(height: isCompact ? 4 : 8),

              // 2. 3-Button Iconic Playback Controls
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: PlaybackControls(
                  isPlaying: provider.isPlaying,
                  isShuffleEnabled: provider.shuffleEnabled,
                  isRepeatEnabled: provider.repeatMode != RepeatMode.off,
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

              SizedBox(height: isCompact ? 4 : 8),
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
        );
      },
    );
  }

  Widget _buildLandscapeLayout(BuildContext context, Color accentColor) {
    return Consumer<PlayerProvider>(
      builder: (context, provider, child) {
        final currentSong = provider.currentSong ?? widget.song;
        final title = currentSong?.title ?? widget.title;
        final artist = currentSong?.artist ?? widget.artist;
        final isStarred = currentSong?.starred ?? false;

        return Row(
          children: [
            // Left: Album Art or Middle page
            Expanded(
              flex: 5,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32.0, 32.0, 16.0, 24.0),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: AlbumArtView(
                      image: _currentImageProvider ?? widget.image,
                      tag: currentSong?.id ?? widget.heroTag,
                      isPlaying: provider.isPlaying,
                    ),
                  ),
                ),
              ),
            ),

            // Right: Controls & Details
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 24.0, 32.0, 16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Title & Artist
                    Row(
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
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.65),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Consumer<LibraryProvider>(
                          builder: (context, lib, _) {
                            final isFav = currentSong != null ? (currentSong.starred ?? false) : isStarred;
                            return _CircleActionButton(
                              onTap: () async {
                                if (currentSong != null) {
                                  HapticFeedback.lightImpact();
                                  await lib.toggleStarSong(currentSong);
                                  provider.toggleFavoriteForSong(currentSong);
                                }
                              },
                              icon: Icon(
                                isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                                color: isFav ? const Color(0xFFFFD600) : Colors.white,
                                size: 20,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        _CircleActionButton(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              useRootNavigator: true,
                              builder: (context) => const NowPlayingMoreMenu(),
                            );
                          },
                          icon: const Icon(
                            Icons.more_vert_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Progress Slider
                    StreamBuilder<Duration>(
                      stream: provider.positionStream,
                      initialData: provider.position,
                      builder: (context, snapshot) {
                        return StreamBuilder<Duration>(
                          stream: provider.bufferedPositionStream,
                          initialData: provider.bufferedPosition,
                          builder: (context, bufSnap) {
                            return StreamBuilder<bool>(
                              stream: provider.isBufferingStream,
                              initialData: provider.isBuffering,
                              builder: (context, buffSnap) {
                                return PlaybackProgressSlider(
                                  position: snapshot.data ?? Duration.zero,
                                  duration: provider.duration,
                                  bufferedPosition: bufSnap.data ?? Duration.zero,
                                  isBuffering: buffSnap.data ?? false,
                                  accentColor: Colors.white,
                                  onChanged: (val) {
                                    provider.seek(val);
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 8),

                    // Playback Controls
                    PlaybackControls(
                      isPlaying: provider.isPlaying,
                      isShuffleEnabled: provider.shuffleEnabled,
                      isRepeatEnabled: provider.repeatMode != RepeatMode.off,
                      accentColor: accentColor,
                      onPlayPause: () => provider.togglePlayPause(),
                      onNext: () => provider.skipNext(),
                      onPrevious: () => provider.skipPrevious(),
                      onShuffleToggle: () => provider.toggleShuffle(),
                      onRepeatToggle: () => provider.toggleRepeat(),
                    ),
                    const SizedBox(height: 8),

                    // Bottom Actions
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
                  ],
                ),
              ),
            ),
          ],
        );
      },
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
