import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/models.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/auth_provider.dart';
import '../services/subsonic_service.dart';
import '../services/recommendation_service.dart';
import '../services/offline_service.dart';
import '../theme/app_theme.dart';
import '../utils/navigation_helper.dart';
import '../widgets/widgets.dart';
import 'album_screen.dart';
import 'playlist_screen.dart';
import 'history_screen.dart';
import '../l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return AppLocalizations.of(context)!.goodMorning;
    if (hour < 17) return AppLocalizations.of(context)!.goodAfternoon;
    return AppLocalizations.of(context)!.goodEvening;
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
              IconButton(
                icon: const Icon(
                  CupertinoIcons.ellipsis_vertical,
                  color: AppTheme.appleMusicRed,
                  size: 22,
                ),
                tooltip: 'Historial de reproducción',
                onPressed: () {
                  NavigationHelper.push(context, const HistoryScreen());
                },
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
                            !RegExp(r'^\d{8,}$').hasMatch(s.title.trim()) &&
                            !s.title.startsWith('AUD-') &&
                            !s.title.startsWith('PTT-') &&
                            (s.duration == null || s.duration! >= 15))
                        .toList();

                List<Album> recentAlbums = libraryProvider.recentAlbums
                    .where((a) =>
                        a.name.trim().isNotEmpty &&
                        !RegExp(r'^\d{8,}$').hasMatch(a.name.trim()) &&
                        a.name.toLowerCase() != 'unknown' &&
                        a.name.toLowerCase() != 'unknown album')
                    .toList();
                List<Playlist> playlists = libraryProvider.playlists;

                // Extract recent songs from profiles / recentlyPlayed
                final cachedSongMap = {for (var s in libraryProvider.cachedAllSongs) s.id: s};
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
    IconData? icon,
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
    final subsonic = Provider.of<SubsonicService>(context, listen: false);
    final coverUrl = song.coverArt != null
        ? (isLocalFilePath(song.coverArt)
            ? song.coverArt
            : subsonic.getCoverArtUrl(song.coverArt!, size: 400))
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

class _QuickAccessGrid extends StatelessWidget {
  final List<dynamic> albums;
  final List<dynamic> playlists;
  final bool isDesktop;
  final double hPad;

  const _QuickAccessGrid({
    required this.albums,
    required this.playlists,
    this.isDesktop = false,
    this.hPad = 16,
  });

  @override
  Widget build(BuildContext context) {
    final raw = [...albums, ...playlists].take(isDesktop ? 9 : 6).toList();

    final items =
        (!isDesktop && raw.length.isOdd) ? raw.sublist(0, raw.length - 1) : raw;

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final subsonicService = Provider.of<SubsonicService>(
      context,
      listen: false,
    );

    if (isDesktop) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: hPad),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 280,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 3.2,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) =>
              _buildTile(context, items[index], subsonicService),
        ),
      );
    }

    const tileHeight = 56.0;
    const spacing = 8.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tileWidth = (constraints.maxWidth - spacing) / 2;
          final ratio = tileWidth / tileHeight;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              childAspectRatio: ratio,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) =>
                _buildTile(context, items[index], subsonicService),
          );
        },
      ),
    );
  }

  Widget _buildTile(
    BuildContext context,
    dynamic item,
    SubsonicService subsonicService,
  ) {
    if (item is Song) {
      final title = item.title;
      final imageUrl = item.coverArt != null
          ? (isLocalFilePath(item.coverArt)
              ? item.coverArt
              : subsonicService.getCoverArtUrl(item.coverArt!, size: 100))
          : null;
      return _QuickAccessTile(
        title: title,
        imageUrl: imageUrl,
        onTap: () {
          final player = Provider.of<PlayerProvider>(context, listen: false);
          player.playSong(item, playlist: [item]);
        },
      );
    }

    final isPlaylist = item.runtimeType.toString().contains('Playlist');
    String? imageUrl;
    String title;
    VoidCallback onTap;

    if (isPlaylist) {
      title = item.name;
      imageUrl = item.coverArt != null
          ? (isLocalFilePath(item.coverArt)
              ? item.coverArt
              : subsonicService.getCoverArtUrl(item.coverArt!, size: 100))
          : null;
      onTap = () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  PlaylistScreen(playlistId: item.id, playlistName: item.name),
            ),
          );
    } else {
      title = item.name;
      imageUrl = item.coverArt != null
          ? (isLocalFilePath(item.coverArt)
              ? item.coverArt
              : subsonicService.getCoverArtUrl(item.coverArt!, size: 100))
          : null;
      onTap = () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => AlbumScreen(albumId: item.id)),
          );
    }

    return _QuickAccessTile(title: title, imageUrl: imageUrl, onTap: onTap);
  }
}

class _QuickAccessTile extends StatefulWidget {
  final String title;
  final String? imageUrl;
  final VoidCallback onTap;

  const _QuickAccessTile({
    required this.title,
    this.imageUrl,
    required this.onTap,
  });

  @override
  State<_QuickAccessTile> createState() => _QuickAccessTileState();
}

class _QuickAccessTileState extends State<_QuickAccessTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isDark
              ? (_isHovered ? AppTheme.darkElevated : AppTheme.darkCard)
              : (_isHovered ? Colors.grey[300] : Colors.grey[200]),
          borderRadius: BorderRadius.circular(4),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(4),
                  ),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: widget.imageUrl != null
                        ? (isLocalFilePath(widget.imageUrl)
                            ? Image.file(
                                File(widget.imageUrl!),
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, e, _) => Container(
                                  color: Colors.grey[800],
                                  child: const Icon(
                                    Icons.music_note,
                                    color: Colors.white30,
                                  ),
                                ),
                              )
                            : CachedNetworkImage(
                                imageUrl: widget.imageUrl!,
                                fit: BoxFit.cover,
                                memCacheWidth: 300,
                                memCacheHeight: 300,
                                placeholder: (ctx, e) =>
                                    Container(color: Colors.grey[800]),
                                errorWidget: (ctx, e, _) => Container(
                                  color: Colors.grey[800],
                                  child: const Icon(
                                    Icons.music_note,
                                    color: Colors.white30,
                                  ),
                                ),
                              ))
                        : Container(
                            color: Colors.grey[800],
                            child: const Icon(
                              Icons.music_note,
                              color: Colors.white30,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
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
    final subsonicService = Provider.of<SubsonicService>(
      context,
      listen: false,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coverArtUrl = playlist.coverArt != null
        ? subsonicService.getCoverArtUrl(playlist.coverArt!, size: 300)
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

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  final double hPad;

  const _SectionTitle({required this.title, this.icon, this.hPad = 16});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: AppTheme.appleMusicRed),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopSongTableHeader extends StatelessWidget {
  final double hPad;
  const _DesktopSongTableHeader({this.hPad = 16});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.1,
      color: isDark ? Colors.white38 : Colors.black38,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 4),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text('#', style: labelStyle, textAlign: TextAlign.center),
          ),
          const SizedBox(width: 12),
          const SizedBox(width: 40),
          const SizedBox(width: 12),
          Expanded(flex: 5, child: Text('TITLE', style: labelStyle)),
          Expanded(flex: 3, child: Text('ALBUM', style: labelStyle)),
          const SizedBox(width: 40),
          SizedBox(
            width: 52,
            child: Text('TIME', style: labelStyle, textAlign: TextAlign.right),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _DesktopSongRow extends StatefulWidget {
  final Song song;
  final List<Song> playlist;
  final int index;
  final double hPad;

  const _DesktopSongRow({
    required this.song,
    required this.playlist,
    required this.index,
    this.hPad = 16,
  });

  @override
  State<_DesktopSongRow> createState() => _DesktopSongRowState();
}

class _DesktopSongRowState extends State<_DesktopSongRow> {
  bool _hovered = false;

  String _formatDuration(int? seconds) {
    if (seconds == null) return '--:--';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final song = widget.song;
    final subsonicService = Provider.of<SubsonicService>(
      context,
      listen: false,
    );

    final isPlaying = context.select<PlayerProvider, bool>(
      (p) => (p.currentSong?.id == song.id) && p.isPlaying,
    );

    final rowBg = _hovered
        ? (isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04))
        : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.read<PlayerProvider>().playSong(
              song,
              playlist: widget.playlist,
              startIndex: widget.index,
            ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: rowBg,
          padding: EdgeInsets.fromLTRB(widget.hPad, 6, widget.hPad, 6),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Center(
                  child: _hovered
                      ? Icon(
                          Icons.play_arrow_rounded,
                          size: 18,
                          color: isDark ? Colors.white : Colors.black,
                        )
                      : isPlaying
                          ? Icon(
                              Icons.bar_chart_rounded,
                              size: 18,
                              color: AppTheme.appleMusicRed,
                            )
                          : Text(
                              '${widget.index + 1}',
                              style: TextStyle(
                                fontSize: 13,
                                color: isPlaying
                                    ? AppTheme.appleMusicRed
                                    : (isDark
                                        ? Colors.white60
                                        : Colors.black54),
                              ),
                              textAlign: TextAlign.center,
                            ),
                ),
              ),
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: song.coverArt != null
                      ? CachedNetworkImage(
                          imageUrl: subsonicService.getCoverArtUrl(
                            song.coverArt!,
                            size: 80,
                          ),
                          fit: BoxFit.cover,
                          memCacheWidth: 100,
                          memCacheHeight: 100,
                          placeholder: (ctx, url) =>
                              Container(color: Colors.grey[800]),
                          errorWidget: (ctx, err, stack) => Container(
                            color: Colors.grey[800],
                            child: const Icon(
                              Icons.music_note,
                              size: 16,
                              color: Colors.white30,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey[800],
                          child: const Icon(
                            Icons.music_note,
                            size: 16,
                            color: Colors.white30,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      song.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isPlaying
                            ? AppTheme.appleMusicRed
                            : (isDark ? Colors.white : Colors.black),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (song.artist != null)
                      Text(
                        song.artist!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  song.album ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: 40,
                child: _hovered || song.starred == true
                    ? IconButton(
                        icon: Icon(
                          song.starred == true
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 16,
                          color: song.starred == true
                              ? AppTheme.appleMusicRed
                              : (isDark ? Colors.white38 : Colors.black38),
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          context.read<PlayerProvider>().toggleFavoriteForSong(
                                song,
                              );
                        },
                      )
                    : const SizedBox.shrink(),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  _formatDuration(song.duration),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
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
