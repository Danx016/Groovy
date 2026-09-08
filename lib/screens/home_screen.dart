import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/models.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../services/youtube_service.dart';
import '../services/recommendation_service.dart';
import '../theme/app_theme.dart';
import '../utils/navigation_helper.dart';
import '../widgets/widgets.dart';
import 'album_screen.dart';
import 'playlist_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'account_screen.dart';
import '../l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static final _numberOnlyRegex = RegExp(r'^\d{8,}$');
  Map<String, List<Song>> _cachedMixes = const {};
  List<Song> _cachedPersonalized = const [];
  String _lastRandomKey = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      RecommendationService().refreshStudiedRecommendations();
    });
  }

  String _computeRandomKey(List<Song> songs) {
    if (songs.isEmpty) return '';
    return '${songs.length}_${songs.first.id}_${songs.last.id}';
  }

  bool get _isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = _isDesktop;
    final hPad = isDesktop ? 32.0 : 16.0;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: true,
            expandedHeight: isDesktop ? 80 : 70,
            backgroundColor: isDark ? AppTheme.darkBackground : Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.only(left: hPad, bottom: 14),
              title: Text(
                'Inicio',
                style: TextStyle(
                  fontSize: isDesktop ? 28 : 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(
                  CupertinoIcons.ellipsis_vertical,
                  color: AppTheme.appleMusicRed,
                  size: 22,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                color: isDark ? const Color(0xFF252525) : Colors.white,
                elevation: 6,
                offset: const Offset(0, 48),
                onSelected: (value) {
                  if (value == 'settings') {
                    NavigationHelper.push(context, const SettingsScreen());
                  } else if (value == 'account') {
                    NavigationHelper.push(context, const AccountScreen());
                  } else if (value == 'history') {
                    NavigationHelper.push(context, const HistoryScreen());
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'settings',
                    height: 44,
                    child: Text(
                      'Configuración',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'account',
                    height: 44,
                    child: Text(
                      'Cuenta',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'history',
                    height: 44,
                    child: Text(
                      'Historial de reproducción',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              if (isDesktop) const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: Consumer2<LibraryProvider, RecommendationService>(
              builder: (context, libraryProvider, recommendationService, _) {
                if (libraryProvider.isLoading &&
                    !libraryProvider.isInitialized) {
                  return _buildLoadingState(isDesktop, hPad);
                }

                final allSongs = libraryProvider.randomSongs;
                final key = _computeRandomKey(allSongs);

                if (recommendationService.enabled && key.isNotEmpty) {
                  if (key != _lastRandomKey) {
                    _cachedMixes = recommendationService.generateMixes(
                      allSongs,
                    );
                    _cachedPersonalized = recommendationService
                        .getPersonalizedFeed(allSongs, limit: 12);
                    _lastRandomKey = key;
                  }
                } else {
                  _cachedMixes = const {};
                  _cachedPersonalized = const [];
                  _lastRandomKey = '';
                }

                Map<String, List<Song>> mixes = Map<String, List<Song>>.from(_cachedMixes);
                final dynamicRecs = recommendationService.dynamicRecommendations;

                List<Song> personalizedFeed = dynamicRecs.isNotEmpty
                    ? dynamicRecs
                    : _cachedPersonalized
                        .where((s) =>
                            s.title.trim().isNotEmpty &&
                            !_numberOnlyRegex.hasMatch(s.title.trim()) &&
                            !s.title.startsWith('AUD-') &&
                            !s.title.startsWith('PTT-') &&
                            (s.duration == null || s.duration! >= 15))
                        .toList();

                List<Album> recentAlbums = libraryProvider.recentAlbums
                    .where((a) =>
                        a.name.trim().isNotEmpty &&
                        !_numberOnlyRegex.hasMatch(a.name.trim()) &&
                        a.name.toLowerCase() != 'unknown' &&
                        a.name.toLowerCase() != 'unknown album')
                    .toList();
                List<Playlist> playlists = libraryProvider.playlists;

                // Extract recent songs from profiles / recentlyPlayed with O(1) indexed lookup
                final cachedSongMap = libraryProvider.songsByIdMap;
                final recentSongsFromProfiles = recommendationService.recentlyPlayed
                    .where((id) => cachedSongMap.containsKey(id))
                    .map((id) => cachedSongMap[id]!)
                    .toList();

                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: isDesktop ? 0 : 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),

                      // 1. REPRODUCCIONES RECIENTES
                      if (recentSongsFromProfiles.isNotEmpty)
                        _buildMixSection(
                          context: context,
                          title: 'Reproducciones recientes',
                          songs: recentSongsFromProfiles,
                          isDesktop: isDesktop,
                          hPad: hPad,
                          onSeeAllTap: () => NavigationHelper.push(
                            context,
                            const HistoryScreen(),
                          ),
                        )
                      else if (recentAlbums.isNotEmpty) ...[
                        HorizontalScrollSection(
                          title: 'Reproducciones recientes',
                          padding: EdgeInsets.symmetric(horizontal: hPad),
                          cardSize: isDesktop ? 180 : 145,
                          onSeeAllTap: () => NavigationHelper.push(
                            context,
                            const HistoryScreen(),
                          ),
                          children: recentAlbums
                              .take(10)
                              .map(
                                (album) => AlbumCard(
                                  album: album,
                                  size: isDesktop ? 180 : 145,
                                  onTap: () => _openAlbum(context, album.id),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // 2. MIXES / RECOMENDACIONES DESTACADAS
                      if (personalizedFeed.isNotEmpty)
                        _buildMixSection(
                          context: context,
                          title: 'Mixes recomendados para ti',
                          songs: personalizedFeed,
                          isDesktop: isDesktop,
                          hPad: hPad,
                        ),

                      if (mixes.containsKey('Quick Picks'))
                        _buildMixSection(
                          context: context,
                          title: 'Selecciones rápidas',
                          songs: mixes['Quick Picks']!,
                          isDesktop: isDesktop,
                          hPad: hPad,
                        ),

                      if (mixes.containsKey('Discover Mix'))
                        _buildMixSection(
                          context: context,
                          title: 'Descubrir nuevos éxitos',
                          songs: mixes['Discover Mix']!,
                          isDesktop: isDesktop,
                          hPad: hPad,
                        ),

                      for (final entry in mixes.entries.where(
                        (e) =>
                            e.key != 'Quick Picks' && e.key != 'Discover Mix',
                      ))
                        _buildMixSection(
                          context: context,
                          title: entry.key,
                          songs: entry.value,
                          isDesktop: isDesktop,
                          hPad: hPad,
                        ),

                      // 3. PLAYLISTS
                      if (playlists.isNotEmpty) ...[
                        HorizontalScrollSection(
                          title: AppLocalizations.of(context)!.yourPlaylists,
                          padding: EdgeInsets.symmetric(horizontal: hPad),
                          cardSize: isDesktop ? 180 : 145,
                          children: playlists
                              .take(10)
                              .map(
                                (playlist) => _PlaylistCard(
                                  playlist: playlist,
                                  size: isDesktop ? 180 : 145,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PlaylistScreen(
                                        playlistId: playlist.id,
                                        playlistName: playlist.name,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // 4. FAVORITE PLAYLISTS
                      const FavoritePlaylistsSection(),

                      const SizedBox(height: 150),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(bool isDesktop, double hPad) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        HorizontalShimmerList(
          count: 5,
          child: AlbumCardShimmer(size: isDesktop ? 180 : 145),
        ),
        const SizedBox(height: 24),
        HorizontalShimmerList(
          count: 5,
          child: AlbumCardShimmer(size: isDesktop ? 180 : 145),
        ),
      ],
    );
  }

  void _openAlbum(BuildContext context, String albumId) {
    NavigationHelper.push(context, AlbumScreen(albumId: albumId));
  }

  Widget _buildMixSection({
    required BuildContext context,
    required String title,
    required List<Song> songs,
    required bool isDesktop,
    required double hPad,
    VoidCallback? onSeeAllTap,
  }) {
    final topSongs = songs.take(15).toList();
    final cardSize = isDesktop ? 180.0 : 145.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 12),
          child: GestureDetector(
            onTap: onSeeAllTap,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: isDesktop ? 22 : 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onSeeAllTap != null)
                  const Icon(
                    CupertinoIcons.chevron_right,
                    size: 18,
                    color: Colors.grey,
                  ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: cardSize + 54,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            scrollDirection: Axis.horizontal,
            itemCount: topSongs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (ctx, index) => _SongCard(
              song: topSongs[index],
              playlist: songs,
              index: index,
              size: cardSize,
            ),
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

class _SongCard extends StatelessWidget {
  final Song song;
  final List<Song> playlist;
  final int index;
  final double size;

  const _SongCard({
    required this.song,
    required this.playlist,
    required this.index,
    this.size = 145,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final youtubeService = Provider.of<YoutubeService>(context, listen: false);
    final coverUrl = song.coverArt != null
        ? (isLocalFilePath(song.coverArt)
            ? song.coverArt
            : youtubeService.getCoverArtUrl(song.coverArt!, size: 400))
        : null;

    return GestureDetector(
      onTap: () {
        final player = Provider.of<PlayerProvider>(context, listen: false);
        player.playSong(song, playlist: playlist, startIndex: index);
      },
      child: SizedBox(
        width: size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: coverUrl != null
                    ? (isLocalFilePath(coverUrl)
                        ? Image.file(
                            File(coverUrl),
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, e, _) => _placeholder(isDark),
                          )
                        : CachedNetworkImage(
                            imageUrl: coverUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 400,
                            memCacheHeight: 400,
                            placeholder: (ctx, e) => _placeholder(isDark),
                            errorWidget: (ctx, e, _) => _placeholder(isDark),
                          ))
                    : _placeholder(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              song.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1C1C1E),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              song.artist ?? 'Groovy',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
      child: const Center(
        child: Icon(
          CupertinoIcons.music_note,
          size: 36,
          color: Colors.white24,
        ),
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final dynamic playlist;
  final VoidCallback? onTap;
  final double size;

  const _PlaylistCard({required this.playlist, this.onTap, this.size = 150});

  @override
  Widget build(BuildContext context) {
    final youtubeService = Provider.of<YoutubeService>(
      context,
      listen: false,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coverArtUrl = playlist.coverArt != null
        ? youtubeService.getCoverArtUrl(playlist.coverArt!, size: 300)
        : null;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: coverArtUrl != null
                    ? CachedNetworkImage(
                        imageUrl: coverArtUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 300,
                        memCacheHeight: 300,
                        placeholder: (ctx, url) => Container(
                          color: isDark
                              ? const Color(0xFF2C2C2E)
                              : Colors.grey[300],
                          child: const Center(
                            child: Icon(
                              Icons.queue_music_rounded,
                              size: 50,
                              color: Colors.white30,
                            ),
                          ),
                        ),
                        errorWidget: (ctx, err, stack) => Container(
                          color: isDark
                              ? const Color(0xFF2C2C2E)
                              : Colors.grey[300],
                          child: const Center(
                            child: Icon(
                              Icons.queue_music_rounded,
                              size: 50,
                              color: Colors.white30,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        color:
                            isDark ? const Color(0xFF2C2C2E) : Colors.grey[300],
                        child: const Center(
                          child: Icon(
                            Icons.queue_music_rounded,
                            size: 50,
                            color: Colors.white30,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              playlist.name,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            if (playlist.songCount != null)
              Text(
                '${playlist.songCount} songs',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DesktopSongCard extends StatefulWidget {
  final Song song;
  final List<Song> playlist;
  final int index;
  final double size;

  const _DesktopSongCard({
    required this.song,
    required this.playlist,
    required this.index,
    required this.size,
  });

  @override
  State<_DesktopSongCard> createState() => _DesktopSongCardState();
}

class _DesktopSongCardState extends State<_DesktopSongCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          final p = context.read<PlayerProvider>();
          p.playSong(widget.song, playlist: widget.playlist, startIndex: widget.index);
        },
        child: SizedBox(
          width: widget.size,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedScale(
                scale: _isHovered ? 1.04 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: _isHovered
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : [],
                  ),
                  child: Stack(
                    children: [
                      AlbumArtwork(
                        coverArt: widget.song.coverArt,
                        size: widget.size,
                        borderRadius: 8,
                      ),
                      if (_isHovered)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: AppTheme.appleMusicRed,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(12),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.song.title,
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                widget.song.artist ?? '',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
