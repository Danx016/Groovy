import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../models/artist.dart';
import '../models/radio_station.dart';
import '../models/lyric_line.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../theme/app_theme.dart';
import '../services/youtube_service.dart';
import '../services/artist_image_service.dart';
import '../services/lrclib_service.dart';
import '../services/offline_service.dart';
import '../services/lrc_ttml_parser.dart';
import '../utils/navigation_helper.dart';
import '../screens/artist_screen.dart';
import '../screens/song_credits_screen.dart';
import '../screens/now_playing_screen.dart';
import 'album_artwork.dart';
import 'now_playing/marquee_text.dart';
import 'now_playing/now_playing_more_menu.dart';
import 'lyrics/lyrics_list_view.dart';

enum RightSidebarTab {
  nowPlaying,
  queue,
  lyrics,
}

class RightSidebar extends StatefulWidget {
  final RightSidebarTab initialTab;
  final ValueChanged<RightSidebarTab>? onTabChanged;
  final VoidCallback? onClose;

  const RightSidebar({
    super.key,
    this.initialTab = RightSidebarTab.nowPlaying,
    this.onTabChanged,
    this.onClose,
  });

  @override
  State<RightSidebar> createState() => _RightSidebarState();
}

class _RightSidebarState extends State<RightSidebar> {
  late RightSidebarTab _currentTab;
  Song? _lastSong;
  List<LyricLine> _lyrics = [];
  bool _isLoadingLyrics = false;
  Timer? _lyricsDebounceTimer;

  static final Map<String, List<LyricLine>> _lyricsCache = {};

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
  }

  @override
  void didUpdateWidget(covariant RightSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      setState(() => _currentTab = widget.initialTab);
    }
  }

  @override
  void dispose() {
    _lyricsDebounceTimer?.cancel();
    super.dispose();
  }

  void _switchTab(RightSidebarTab tab) {
    setState(() => _currentTab = tab);
    widget.onTabChanged?.call(tab);
  }

  void _onSongChanged(Song? song) {
    if (song == null) {
      setState(() {
        _lastSong = null;
        _lyrics = [];
        _isLoadingLyrics = false;
      });
      return;
    }

    if (_lastSong?.id == song.id) return;
    _lastSong = song;

    _lyricsDebounceTimer?.cancel();

    if (_lyricsCache.containsKey(song.id)) {
      setState(() {
        _lyrics = _lyricsCache[song.id]!;
        _isLoadingLyrics = false;
      });
    } else {
      setState(() {
        _lyrics = [];
        _isLoadingLyrics = true;
      });
      _lyricsDebounceTimer = Timer(const Duration(milliseconds: 180), () {
        if (mounted) _fetchLyrics(song);
      });
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

  Future<void> _fetchLyrics(Song song) async {
    final songId = song.id;
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

      // 2. Online fetch via LRCLIB
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

      if (!mounted || _lastSong?.id != songId) return;

      _lyricsCache[songId] = parsed;
      setState(() {
        _lyrics = parsed;
        _isLoadingLyrics = false;
      });
    } catch (_) {
      if (mounted && _lastSong?.id == songId) {
        setState(() {
          _lyrics = [];
          _isLoadingLyrics = false;
        });
      }
    }
  }

  void _navigateToArtist(BuildContext context, Song song) {
    final artistName = song.artist ?? '';
    final artistId = song.artistId ?? artistName;
    final artistObj = Artist(
      id: artistId,
      name: artistName,
      coverArt: song.coverArt,
    );

    NavigationHelper.push(
      context,
      ArtistScreen(artistId: artistId, artist: artistObj),
    );
  }

  void _openCredits(BuildContext context, Song song) {
    NavigationHelper.push(
      context,
      SongCreditsScreen(song: song),
    );
  }

  void _openFullscreenNowPlaying(BuildContext context, Song song) {
    final youtubeService = Provider.of<YoutubeService>(context, listen: false);
    final coverUrl = song.coverArt != null
        ? youtubeService.getCoverArtUrl(song.coverArt, size: 600)
        : null;
    final ImageProvider imageProvider;
    if (coverUrl != null && coverUrl.isNotEmpty) {
      if (song.isLocal || isLocalFilePath(coverUrl)) {
        imageProvider = FileImage(File(coverUrl));
      } else {
        imageProvider = CachedNetworkImageProvider(coverUrl);
      }
    } else {
      imageProvider = const AssetImage('assets/default_cover.png');
    }

    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (ctx, anim, secondaryAnim) => NowPlayingScreen(
          image: imageProvider,
          title: song.title,
          artist: (song.artistParticipants?.isNotEmpty == true
                  ? song.artistParticipants!.map((a) => a.name).join(', ')
                  : song.artist) ??
              '',
          heroTag: 'sidebar_fs_${song.id}',
          song: song,
        ),
        transitionsBuilder: (ctx, anim, secondaryAnim, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  void _openMoreMenu(BuildContext context, Song song) {
    final youtubeService = Provider.of<YoutubeService>(context, listen: false);
    final coverUrl = song.coverArt != null
        ? youtubeService.getCoverArtUrl(song.coverArt, size: 600)
        : null;
    final imageProvider = coverUrl != null
        ? CachedNetworkImageProvider(coverUrl)
        : const AssetImage('assets/default_cover.png') as ImageProvider;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) => NowPlayingMoreMenu(
        song: song,
        imageProvider: imageProvider,
        onNavigateToLyrics: () {
          Navigator.of(context).pop();
          _switchTab(RightSidebarTab.lyrics);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return RepaintBoundary(
      child: Consumer<PlayerProvider>(
        builder: (context, player, _) {
          final currentSong = player.currentSong;
          final radioStation = player.currentRadioStation;
          final isPlayingRadio = player.isPlayingRadio && radioStation != null;

          if (currentSong != null) {
            _onSongChanged(currentSong);
          }

        return Container(
          width: 350,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF121212) : const Color(0xFFF9F9FB),
            border: Border(
              left: BorderSide(
                color: isDark ? const Color(0xFF282828) : const Color(0xFFE5E5E5),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              // Top Header (Context Title + Action Icons)
              _buildTopHeader(
                context,
                isDark,
                currentSong: currentSong,
                radioStation: radioStation,
              ),

              // Segmented Tab Switcher (Vista que suena | Cola | Letras)
              if (!isPlayingRadio)
                _buildSegmentedTabs(isDark, theme.colorScheme.primary),

              const Divider(height: 1, color: Color(0x1F888888)),

              // Main Body Content
              Expanded(
                child: isPlayingRadio
                    ? _buildRadioContent(context, isDark, radioStation)
                    : currentSong == null
                        ? _buildEmptyState(isDark)
                        : _buildTabBody(context, isDark, player, currentSong),
              ),
            ],
          ),
        );
      },
    ),
  );
}

  Widget _buildTopHeader(
    BuildContext context,
    bool isDark, {
    Song? currentSong,
    RadioStation? radioStation,
  }) {
    final headerTitle = currentSong != null
        ? (currentSong.album != null &&
                currentSong.album!.isNotEmpty &&
                currentSong.album != 'Album' &&
                currentSong.album != 'Álbum')
            ? currentSong.album!
            : currentSong.title
        : radioStation?.name ?? 'Groovy Music';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
      child: Row(
        children: [
          Icon(
            Icons.view_sidebar_rounded,
            size: 18,
            color: isDark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              headerTitle,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (currentSong != null) ...[
            IconButton(
              icon: Icon(
                Icons.more_horiz_rounded,
                size: 20,
                color: isDark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText,
              ),
              onPressed: () => _openMoreMenu(context, currentSong),
              tooltip: 'Más opciones',
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: Icon(
                Icons.open_in_full_rounded,
                size: 18,
                color: isDark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText,
              ),
              onPressed: () => _openFullscreenNowPlaying(context, currentSong),
              tooltip: 'Pantalla completa',
              visualDensity: VisualDensity.compact,
            ),
          ],
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 20,
              color: isDark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText,
            ),
            onPressed: widget.onClose,
            tooltip: 'Cerrar panel',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedTabs(bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          _buildPillTab(
            label: 'Vista actual',
            icon: Icons.slideshow_rounded,
            tab: RightSidebarTab.nowPlaying,
            isDark: isDark,
            primaryColor: primaryColor,
          ),
          const SizedBox(width: 6),
          _buildPillTab(
            label: 'Cola',
            icon: Icons.queue_music_rounded,
            tab: RightSidebarTab.queue,
            isDark: isDark,
            primaryColor: primaryColor,
          ),
          const SizedBox(width: 6),
          _buildPillTab(
            label: 'Letras',
            icon: Icons.lyrics_rounded,
            tab: RightSidebarTab.lyrics,
            isDark: isDark,
            primaryColor: primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildPillTab({
    required String label,
    required IconData icon,
    required RightSidebarTab tab,
    required bool isDark,
    required Color primaryColor,
  }) {
    final isSelected = _currentTab == tab;

    return Expanded(
      child: InkWell(
        onTap: () => _switchTab(tab),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8ED))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? (isDark ? const Color(0xFF3E3E3E) : const Color(0xFFD1D1D6))
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBody(
    BuildContext context,
    bool isDark,
    PlayerProvider player,
    Song currentSong,
  ) {
    switch (_currentTab) {
      case RightSidebarTab.nowPlaying:
        return _buildNowPlayingView(context, isDark, player, currentSong);
      case RightSidebarTab.queue:
        return _buildQueueView(context, isDark, player);
      case RightSidebarTab.lyrics:
        return _buildLyricsView(context, isDark, player);
    }
  }

  // ==========================================
  // 1. VISTA QUE SUENA (NOW PLAYING VIEW)
  // Matching Spotify Desktop + Groovy Mobile
  // ==========================================
  Widget _buildNowPlayingView(
    BuildContext context,
    bool isDark,
    PlayerProvider player,
    Song currentSong,
  ) {
    final theme = Theme.of(context);
    final cardBg = isDark ? const Color(0xFF202020) : const Color(0xFFEFEFF2);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Large Album Art with rounded corners & shadow
          Center(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.38),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AlbumArtwork(
                    coverArt: currentSong.coverArt,
                    size: 318,
                    borderRadius: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title & Artist Info + Favorite & Share buttons
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MarqueeText(
                      text: currentSong.title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => _navigateToArtist(context, currentSong),
                        child: Text(
                          currentSong.artist ?? 'Artista Desconocido',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? const Color(0xFFB3B3B3)
                                : const Color(0xFF6B6B6B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Favorite Heart/Star Button
              Consumer<LibraryProvider>(
                builder: (context, lib, _) {
                  final isFav = lib.isSongStarred(currentSong.id) ||
                      (currentSong.starred ?? false);
                  return IconButton(
                    icon: Icon(
                      isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isFav
                          ? AppTheme.appleMusicRed
                          : (isDark ? Colors.white70 : Colors.black54),
                      size: 24,
                    ),
                    onPressed: () async {
                      final newFav = await lib.toggleStarSong(currentSong);
                      player.updateSongStarred(currentSong.id, newFav);
                    },
                    tooltip: isFav ? 'Quitar de favoritos' : 'Añadir a favoritos',
                  );
                },
              ),

              // Options Menu Button
              IconButton(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: isDark ? Colors.white70 : Colors.black54,
                  size: 22,
                ),
                onPressed: () => _openMoreMenu(context, currentSong),
                tooltip: 'Más opciones',
              ),
            ],
          ),

          const SizedBox(height: 18),

          // CARD 1: CRÉDITOS / SOBRE EL ARTISTA (Exact match to Image 1)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Créditos',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => _openCredits(context, currentSong),
                        child: Text(
                          'Mostrar todo',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFFB3B3B3)
                                : const Color(0xFF6B6B6B),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    // Artist Avatar
                    _ArtistCardAvatar(
                      artistName: currentSong.artist ?? '',
                      fallbackCover: currentSong.coverArt,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentSong.artist ?? 'Artista Principal',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Artista Principal',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? const Color(0xFFB3B3B3)
                                  : const Color(0xFF757575),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // "Seguir" / "Ver artista" Button
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: isDark ? Colors.white38 : Colors.black26,
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _navigateToArtist(context, currentSong),
                      child: Text(
                        'Ver artista',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // CARD 2: SIGUIENTE EN COLA (Exact match to Image 1)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Siguiente en cola',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => _switchTab(RightSidebarTab.queue),
                        child: Text(
                          'Abrir cola',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFFB3B3B3)
                                : const Color(0xFF6B6B6B),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (player.currentIndex + 1 < player.queue.length) ...[
                  Builder(
                    builder: (context) {
                      final nextSong = player.queue[player.currentIndex + 1];
                      return InkWell(
                        onTap: () => player.skipNext(),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: AlbumArtwork(
                                  coverArt: nextSong.coverArt,
                                  size: 46,
                                  borderRadius: 6,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nextSong.title,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      nextSong.artist ?? '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? const Color(0xFFB3B3B3)
                                            : const Color(0xFF757575),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.skip_next_rounded,
                                size: 22,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ] else ...[
                  Text(
                    'No hay más canciones en la cola',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),

          // CARD 3: LETRAS SINCRONIZADAS (Card preview from Mobile App)
          InkWell(
            onTap: () => _switchTab(RightSidebarTab.lyrics),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lyrics_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Letras',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Ver completas',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFB3B3B3)
                              : const Color(0xFF6B6B6B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isLoadingLyrics) ...[
                    Row(
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Cargando letras...',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ] else if (_lyrics.isNotEmpty) ...[
                    _SidebarMiniLyrics(
                      lyrics: _lyrics,
                      positionStream: player.positionStream,
                      currentPosition: player.position,
                      primaryColor: theme.colorScheme.primary,
                      isDark: isDark,
                    ),
                  ] else ...[
                    Text(
                      'No hay letras disponibles para esta canción',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ==========================================
  // 2. COLA DE REPRODUCCIÓN (QUEUE VIEW)
  // ==========================================
  Widget _buildQueueView(
    BuildContext context,
    bool isDark,
    PlayerProvider player,
  ) {
    final queue = player.queue;
    final currentIndex = player.currentIndex;

    if (queue.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.queue_music_rounded,
              size: 56,
              color: isDark ? AppTheme.darkTertiaryText : AppTheme.lightSecondaryText,
            ),
            const SizedBox(height: 14),
            Text(
              'No hay canciones en la cola',
              style: TextStyle(
                color: isDark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              Text(
                '${queue.length} canciones en la cola',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText,
                ),
              ),
              const Spacer(),
              if (queue.length > 1)
                IconButton(
                  icon: Icon(
                    Icons.shuffle_rounded,
                    size: 18,
                    color: player.shuffleEnabled
                        ? Theme.of(context).colorScheme.primary
                        : (isDark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText),
                  ),
                  onPressed: () => player.toggleShuffle(),
                  tooltip: 'Mezclar cola',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: queue.length,
            itemBuilder: (context, index) {
              final song = queue[index];
              final isPlaying = currentIndex == index;

              return _QueueItem(
                song: song,
                isPlaying: isPlaying,
                index: index + 1,
                onTap: () => player.skipToIndex(index),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 3. LETRAS COMPLETAS (LYRICS VIEW)
  // Full synchronized lyrics view from mobile
  // ==========================================
  Widget _buildLyricsView(
    BuildContext context,
    bool isDark,
    PlayerProvider player,
  ) {
    if (_isLoadingLyrics) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Buscando letras sincronizadas...',
              style: TextStyle(
                color: isDark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_lyrics.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lyrics_rounded,
                size: 56,
                color: isDark ? AppTheme.darkTertiaryText : AppTheme.lightSecondaryText,
              ),
              const SizedBox(height: 16),
              Text(
                'No se encontraron letras',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'No hay letras disponibles para este tema en la base de datos.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => _switchTab(RightSidebarTab.nowPlaying),
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Volver a vista actual'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: LyricsListView(
            lyrics: _lyrics,
            positionStream: player.positionStream,
            initialPosition: player.position,
            isActive: _currentTab == RightSidebarTab.lyrics,
            onSeek: (pos) => player.seek(pos),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // RADIO STREAM CONTENT
  // ==========================================
  Widget _buildRadioContent(
    BuildContext context,
    bool isDark,
    RadioStation station,
  ) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.radio_rounded,
              color: Colors.white,
              size: 80,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            station.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'TRANSMISIÓN EN VIVO',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF202020) : const Color(0xFFEFEFF2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detalles de la emisión',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  station.streamUrl,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_note_rounded,
            size: 56,
            color: isDark ? AppTheme.darkTertiaryText : AppTheme.lightSecondaryText,
          ),
          const SizedBox(height: 16),
          Text(
            'Nada reproduciéndose',
            style: TextStyle(
              color: isDark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtistCardAvatar extends StatefulWidget {
  final String artistName;
  final String? fallbackCover;

  const _ArtistCardAvatar({
    required this.artistName,
    this.fallbackCover,
  });

  @override
  State<_ArtistCardAvatar> createState() => _ArtistCardAvatarState();
}

class _ArtistCardAvatarState extends State<_ArtistCardAvatar> {
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _ArtistCardAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artistName != widget.artistName) {
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.artistName.trim().isEmpty) return;
    final url = await ArtistImageService().getArtistImageUrl(
      widget.artistName,
      fallbackCoverArt: widget.fallbackCover,
    );
    if (mounted) {
      setState(() => _imageUrl = url);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey[850],
        backgroundImage: CachedNetworkImageProvider(_imageUrl!),
      );
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.grey[850],
      child: const Icon(Icons.person_rounded, color: Colors.white70, size: 24),
    );
  }
}

class _QueueItem extends StatefulWidget {
  final Song song;
  final bool isPlaying;
  final int index;
  final VoidCallback onTap;

  const _QueueItem({
    required this.song,
    required this.isPlaying,
    required this.index,
    required this.onTap,
  });

  @override
  State<_QueueItem> createState() => _QueueItemState();
}

class _QueueItemState extends State<_QueueItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          color: _isHovered
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05))
              : Colors.transparent,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: AlbumArtwork(
                  coverArt: widget.song.coverArt,
                  size: 42,
                  borderRadius: 4,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.song.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: widget.isPlaying
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: widget.isPlaying
                            ? primaryColor
                            : (isDark ? Colors.white : Colors.black),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.song.artist != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.song.artist!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.darkSecondaryText
                              : AppTheme.lightSecondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.isPlaying)
                Icon(
                  Icons.volume_up_rounded,
                  size: 16,
                  color: primaryColor,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarMiniLyrics extends StatefulWidget {
  final List<LyricLine> lyrics;
  final Stream<Duration>? positionStream;
  final Duration currentPosition;
  final Color primaryColor;
  final bool isDark;

  const _SidebarMiniLyrics({
    required this.lyrics,
    this.positionStream,
    required this.currentPosition,
    required this.primaryColor,
    required this.isDark,
  });

  @override
  State<_SidebarMiniLyrics> createState() => _SidebarMiniLyricsState();
}

class _SidebarMiniLyricsState extends State<_SidebarMiniLyrics> {
  int _activeIdx = -1;
  StreamSubscription<Duration>? _sub;

  @override
  void initState() {
    super.initState();
    _updateIndex(widget.currentPosition);
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant _SidebarMiniLyrics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.positionStream != widget.positionStream) {
      _subscribe();
    }
    if (oldWidget.lyrics != widget.lyrics) {
      _updateIndex(widget.currentPosition);
    }
  }

  void _subscribe() {
    _sub?.cancel();
    if (widget.positionStream != null) {
      _sub = widget.positionStream!.listen((pos) {
        _updateIndex(pos);
      });
    }
  }

  void _updateIndex(Duration pos) {
    if (widget.lyrics.isEmpty) return;
    int low = 0;
    int high = widget.lyrics.length - 1;
    int newIdx = -1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (widget.lyrics[mid].startTime <= pos) {
        newIdx = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    if (newIdx != _activeIdx) {
      setState(() {
        _activeIdx = newIdx;
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentLine = _activeIdx >= 0 && _activeIdx < widget.lyrics.length
        ? widget.lyrics[_activeIdx].text
        : widget.lyrics.first.text;
    final nextLine = _activeIdx + 1 < widget.lyrics.length
        ? widget.lyrics[_activeIdx + 1].text
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          currentLine,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: widget.primaryColor,
            height: 1.3,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (nextLine != null && nextLine.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            nextLine,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: widget.isDark ? Colors.white38 : Colors.black38,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
