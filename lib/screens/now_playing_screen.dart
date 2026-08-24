import 'package:flutter/material.dart' hide RepeatMode;
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
import 'artist_screen.dart';
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
      _fetchLyrics();
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
    _extractColors();
  }

  Future<void> _fetchLyrics() async {
    if (_lastSong == null) return;
    final songId = _lastSong!.id;

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
      
      Map<String, dynamic>? rawLyrics;
      
      if (offlineService.isOfflineMode || _lastSong!.isLocal || offlineService.isSongDownloaded(songId)) {
        rawLyrics = await offlineService.getLocalLyrics(songId);
      }
      
      if (rawLyrics == null && !offlineService.isOfflineMode) {
        rawLyrics = await Future.any([
          subsonic.getLyricsBySongId(songId),
          subsonic.getLyrics(
            artist: _lastSong!.artist, 
            title: _lastSong!.title,
            duration: _lastSong!.duration,
          ),
        ]).timeout(
          const Duration(seconds: 6),
          onTimeout: () => null,
        );
      }
      
      // If user switched songs while loading, discard this result
      if (!mounted || _lastSong?.id != songId) return;

      List<LyricLine> parsed = [];
      if (rawLyrics != null) {
        if (rawLyrics['value'] != null) {
          final lrcText = rawLyrics['value'] as String;
          parsed = LrcParser.parseLrc(lrcText);
        } else if (rawLyrics['structuredLyrics'] != null) {
          final structured = rawLyrics['structuredLyrics'] as List?;
          if (structured != null && structured.isNotEmpty) {
            final lines = structured.first['line'] as List?;
            if (lines != null) {
              parsed = lines.map((l) {
                return LyricLine(
                  startTime: Duration(milliseconds: l['start'] as int),
                  text: l['value'] as String,
                );
              }).toList();
            }
          }
        }
      }
      
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
    // The accent color can be derived from the extracted colors, or white
    final accentColor = _bgColors.isNotEmpty ? _bgColors.first : Colors.white;
    final playerProvider = Provider.of<PlayerProvider>(context);
    final songForBadge = playerProvider.currentSong ?? widget.song;
    String qualityBadge = 'Lossless';
    if (songForBadge?.hasDolbyAtmos == true) {
      qualityBadge = 'Dolby Atmos';
    } else if (songForBadge?.suffix != null) {
      final s = songForBadge!.suffix!.toUpperCase();
      if (s == 'FLAC' || s == 'ALAC' || s == 'WAV') {
        qualityBadge = 'Lossless';
      } else if (s == 'DSD' || s == 'DSF' || ((songForBadge.bitRate ?? 0) > 1411)) {
        qualityBadge = 'Hi-Res Lossless';
      } else {
        qualityBadge = s;
      }
    }

    return Theme(
      // Force dark mode for Now Playing as per Apple Music
      data: ThemeData.dark(),
      child: Scaffold(
        backgroundColor: Colors.black, // Fallback background
        body: GestureDetector(
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          child: Stack(
            children: [
              // 1. Shared Animated Background
              Positioned.fill(
                child: RepaintBoundary(
                  child: BlurredGradientBackground(
                    colors: _bgColors,
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      children: [
                        // Page 0: Main Cover Art View
                        _buildMainView(accentColor, qualityBadge),
                        
                        // Page 1: Apple Music Lyrics View
                        _buildLyricsPageView(accentColor, qualityBadge),
                        
                        // Page 2: Queue View
                        const QueueView(),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Drag Handle (Top)
              Align(
                alignment: Alignment.topCenter,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
                    margin: EdgeInsets.only(top: widget.topPadding > 0 ? widget.topPadding + 6 : 12),
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.38),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Header (Persistent across pages)
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: widget.topPadding > 0 ? widget.topPadding + 14 : 20, 
                    left: 8.0, 
                    right: 8.0
                  ),
                  child: _currentPage == 1 
                      ? _buildLyricsHeader(context)
                      : (_currentPage == 2
                          ? _buildQueueHeader(context)
                          : const SizedBox.shrink()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQueueHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 32),
            onPressed: () {
              _pageController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
            },
          ),
          const Text(
            "A continuación",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 28),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                useRootNavigator: true,
                builder: (context) => const NowPlayingMoreMenu(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsHeader(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, provider, child) {
        final currentSong = provider.currentSong ?? widget.song;
        final title = currentSong?.title ?? widget.title;
        final artist = currentSong?.artist ?? widget.artist;
        final isStarred = currentSong?.starred ?? false;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            children: [
              // 1. Album Cover Art -> Navigate to Album
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
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image(
                      image: _currentImageProvider ?? widget.image,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 2. Title & Artist -> Apple Music Sheet (Ir al artista / Ir al álbum)
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
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Star (Favorite) Button
              Consumer<LibraryProvider>(
                builder: (context, lib, _) {
                  final isFav = currentSong != null ? (currentSong.starred ?? false) : isStarred;
                  return GestureDetector(
                    onTap: () async {
                      if (currentSong != null) {
                        await lib.toggleStarSong(currentSong);
                      }
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                      child: Center(
                        child: Icon(
                          isFav ? Icons.star_rounded : Icons.star_border_rounded,
                          color: isFav ? const Color(0xFFFFD600) : Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  );
                },
              ),

              // 4. More Options Button
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    useRootNavigator: true,
                    builder: (context) => const NowPlayingMoreMenu(),
                  );
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.more_horiz_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLyricsPageView(Color accentColor, String qualityBadge) {
    return Consumer<PlayerProvider>(
      builder: (context, provider, child) {
        return SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 60), // Space for lyrics header

              // Scrollable Lyrics View
              Expanded(
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
              ),

              // Scrubber Progress Slider & Audio Quality Badge
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: StreamBuilder<Duration>(
                  stream: provider.positionStream,
                  initialData: provider.position,
                  builder: (context, snapshot) {
                    return PlaybackProgressSlider(
                      position: snapshot.data ?? Duration.zero,
                      duration: provider.duration,
                      accentColor: Colors.white,
                      qualityBadge: qualityBadge,
                      onChanged: (val) {
                        provider.seek(val);
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // 3-Button Iconic Playback Controls
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

              const SizedBox(height: 10),

              // Bottom Actions (Lyrics active chip, Cast, Queue)
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

              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }


  Widget _buildMainView(Color accentColor, [String? qualityBadgeParam]) {
    return Consumer<PlayerProvider>(
      builder: (context, provider, child) {
        final currentSong = provider.currentSong ?? widget.song;
        final title = currentSong?.title ?? widget.title;
        final artist = currentSong?.artist ?? widget.artist;
        final isStarred = currentSong?.starred ?? false;

        String qualityBadge = qualityBadgeParam ?? 'Lossless';
        if (qualityBadgeParam == null) {
          if (currentSong?.hasDolbyAtmos == true) {
            qualityBadge = 'Dolby Atmos';
          } else if (currentSong?.suffix != null) {
            final s = currentSong!.suffix!.toUpperCase();
            if (s == 'FLAC' || s == 'ALAC' || s == 'WAV') {
              qualityBadge = 'Lossless';
            } else if (s == 'DSD' || s == 'DSF' || ((currentSong.bitRate ?? 0) > 1411)) {
              qualityBadge = 'Hi-Res Lossless';
            } else {
              qualityBadge = s;
            }
          }
        }

        return SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isLandscape = constraints.maxWidth > constraints.maxHeight;

              if (isLandscape) {
                return Row(
                  children: [
                    // Left: Album Art
                    Expanded(
                      flex: 5,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(32.0, 48.0, 16.0, 24.0),
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
                        padding: const EdgeInsets.fromLTRB(16.0, 48.0, 32.0, 16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Title & Artist with Star and More buttons
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
                                // Star Button
                                Consumer<LibraryProvider>(
                                  builder: (context, lib, _) {
                                    final isFav = currentSong != null ? (currentSong.starred ?? false) : isStarred;
                                    return GestureDetector(
                                      onTap: () async {
                                        if (currentSong != null) {
                                          await lib.toggleStarSong(currentSong);
                                        }
                                      },
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withValues(alpha: 0.14),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            isFav ? Icons.star_rounded : Icons.star_border_rounded,
                                            color: isFav ? const Color(0xFFFFD600) : Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                // More Options Button
                                GestureDetector(
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      backgroundColor: Colors.transparent,
                                      isScrollControlled: true,
                                      useRootNavigator: true,
                                      builder: (context) => const NowPlayingMoreMenu(),
                                    );
                                  },
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(alpha: 0.14),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.more_horiz_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
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
                                return PlaybackProgressSlider(
                                  position: snapshot.data ?? Duration.zero,
                                  duration: provider.duration,
                                  accentColor: Colors.white,
                                  qualityBadge: qualityBadge,
                                  onChanged: (val) {
                                    provider.seek(val);
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
              }

              // Portrait layout with flexible spacing
              final isCompact = constraints.maxHeight < 680;
              return Column(
                children: [
                  SizedBox(height: isCompact ? 16 : 28), // Space for top drag handle
                  
                  // Album Art
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 36.0 : 44.0,
                          vertical: isCompact ? 8.0 : 16.0,
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

                  // Title & Artist + Star & More Options (Apple Music Row)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 28.0,
                      vertical: isCompact ? 10.0 : 16.0,
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
                                    letterSpacing: -0.3,
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
                            return GestureDetector(
                              onTap: () async {
                                if (currentSong != null) {
                                  await lib.toggleStarSong(currentSong);
                                }
                              },
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.14),
                                ),
                                child: Center(
                                  child: Icon(
                                    isFav ? Icons.star_rounded : Icons.star_border_rounded,
                                    color: isFav ? const Color(0xFFFFD600) : Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        // More Options Button
                        GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              useRootNavigator: true,
                              builder: (context) => const NowPlayingMoreMenu(),
                            );
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.14),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.more_horiz_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Progress Slider & Lossless Badge
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28.0),
                    child: StreamBuilder<Duration>(
                      stream: provider.positionStream,
                      initialData: provider.position,
                      builder: (context, snapshot) {
                        return PlaybackProgressSlider(
                          position: snapshot.data ?? Duration.zero,
                          duration: provider.duration,
                          accentColor: Colors.white,
                          qualityBadge: qualityBadge,
                          onChanged: (val) {
                            provider.seek(val);
                          },
                        );
                      },
                    ),
                  ),

                  SizedBox(height: isCompact ? 10 : 20),

                  // 3-Button Iconic Playback Controls
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

                  SizedBox(height: isCompact ? 10 : 20),

                  // Bottom Actions (Lyrics, Cast, Queue)
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

                  SizedBox(height: isCompact ? 6 : 16),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

