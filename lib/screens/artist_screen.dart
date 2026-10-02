import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'album_screen.dart';
import '../utils/album_sanitizer.dart';
import '../utils/screen_helper.dart';
import '../services/services.dart';

class ArtistScreen extends StatefulWidget {
  final String artistId;
  final Artist? artist;

  const ArtistScreen({super.key, required this.artistId, this.artist});

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  Artist? _artist;
  ArtistInfo? _artistInfo;
  List<Song> _topSongs = [];
  List<Album> _albums = [];
  bool _isLoading = true;
  String? _resolvedCoverArt;

  @override
  void initState() {
    super.initState();
    FavoriteArtistsService().initialize();
    final initialName = widget.artist?.name ?? widget.artistId;
    _resolvedCoverArt = ArtistImageService.getCachedArtistImageUrl(initialName);
    _loadArtistDetails();
  }

  Future<void> _loadArtistDetails() async {
    final libraryProvider = Provider.of<LibraryProvider>(
      context,
      listen: false,
    );
    final youtubeService = libraryProvider.youtubeService;

    try {
      final rawName = widget.artist?.name ?? widget.artistId;
      String cleanArtistQuery = rawName;
      if (cleanArtistQuery.toLowerCase().startsWith('artist_') ||
          cleanArtistQuery.toLowerCase().startsWith('local_artist_')) {
        cleanArtistQuery = cleanArtistQuery
            .replaceAll(RegExp(r'^(artist_|local_artist_)', caseSensitive: false), '')
            .replaceAll(RegExp(r'_+'), ' ')
            .trim();
      }

      // Keep the original reliable artist name (never override with random search result artist or channel ID)
      final reliableArtistName = (widget.artist?.name != null &&
              widget.artist!.name.isNotEmpty &&
              !widget.artist!.name.toLowerCase().startsWith('artist_') &&
              !widget.artist!.name.toLowerCase().startsWith('local_artist_') &&
              !widget.artist!.name.startsWith('UC') &&
              !widget.artist!.name.startsWith('FE'))
          ? widget.artist!.name
          : (!cleanArtistQuery.startsWith('UC') && !cleanArtistQuery.startsWith('FE'))
              ? cleanArtistQuery
              : (widget.artist?.name ?? cleanArtistQuery);

      Artist? artist = widget.artist;
      if (artist != null &&
          (artist.name.toLowerCase().startsWith('artist_') ||
              artist.name.toLowerCase().startsWith('local_artist_') ||
              artist.name.contains('__') ||
              artist.name.startsWith('UC') ||
              artist.name.startsWith('FE'))) {
        artist = Artist(
          id: artist.id,
          name: reliableArtistName,
          coverArt: artist.coverArt,
          albumCount: artist.albumCount,
          artistImageUrl: artist.artistImageUrl,
          isLocal: artist.isLocal,
        );
      }

      List<Song> topSongs = [];
      List<Album> albums = [];

      if (libraryProvider.isLocalOnlyMode) {
        artist = libraryProvider.artists.firstWhere(
          (a) => a.id == widget.artistId || a.name.toLowerCase() == cleanArtistQuery.toLowerCase(),
          orElse: () => Artist(id: widget.artistId, name: cleanArtistQuery),
        );
        albums = await libraryProvider.getArtistAlbums(widget.artistId);

        topSongs = libraryProvider.cachedAllSongs
            .where((s) => s.artistId == widget.artistId || (s.artist != null && s.artist!.toLowerCase() == cleanArtistQuery.toLowerCase()))
            .toList();
      } else {
        // First check if widget.artistId matches an artist in libraryProvider
        Artist? libraryMatch;
        for (final a in libraryProvider.artists) {
          if (a.id == widget.artistId ||
              a.name.toLowerCase() == widget.artistId.toLowerCase() ||
              a.name.toLowerCase() == reliableArtistName.toLowerCase()) {
            libraryMatch = a;
            break;
          }
        }
        // When not a local library match, always query by the artist's real name instead of channel ID
        final queryTarget = libraryMatch?.id ?? reliableArtistName;

        try {
          final results = await Future.wait([
            libraryMatch != null
                ? Future.value(libraryMatch)
                : youtubeService.getArtist(queryTarget).then<Artist?>((a) => a).catchError((_) => null),
            youtubeService.getArtistInfo(queryTarget).catchError((_) => null),
            youtubeService.getArtistTopSongs(queryTarget).catchError((_) => <Song>[]),
            youtubeService.getArtistAlbums(queryTarget).catchError((_) => <Album>[]),
          ]);
          if (libraryMatch != null) {
            artist = libraryMatch;
          }
          _artistInfo = results[1] as ArtistInfo?;
          topSongs = (results[2] as List<Song>?) ?? [];
          albums = (results[3] as List<Album>?) ?? [];

          // Strict filtering: ensure topSongs and albums strictly belong to this artist
          final cleanLower = reliableArtistName.toLowerCase().trim();
          topSongs = topSongs.where((s) {
            final a = s.artist?.toLowerCase().trim();
            if (a == null || a.isEmpty) return true;
            return a.contains(cleanLower) || cleanLower.contains(a);
          }).toList();

          albums = albums.where((alb) {
            final a = alb.artist?.toLowerCase().trim();
            if (a == null || a.isEmpty) return true;
            return a.contains(cleanLower) || cleanLower.contains(a);
          }).toList();

          if (topSongs.length < 5 && albums.isNotEmpty) {
            final topSongIds = topSongs.map((s) => s.id).toSet();
            final seenIds = {...topSongIds};
            final albumsToFetch = albums.take(3).toList();
            final albumSongResults = await Future.wait(
              albumsToFetch.map((a) => youtubeService.getAlbumSongs(a.id).catchError((_) => <Song>[])),
            );
            final allAlbumSongs = albumSongResults
                .expand((songs) => songs)
                .where((s) => seenIds.add(s.id))
                .where((s) {
                  final a = s.artist?.toLowerCase().trim();
                  if (a == null || a.isEmpty) return true;
                  return a.contains(cleanLower) || cleanLower.contains(a);
                });
            topSongs = [...topSongs, ...allAlbumSongs];
          }
        } catch (serverErr) {
          debugPrint('Library getArtist error: $serverErr');
        }
      }

      // If artist has no top songs, fetch online via YouTube with reliableArtistName
      if (topSongs.isEmpty) {
        artist ??= Artist(
          id: widget.artistId,
          name: reliableArtistName,
          coverArt: widget.artist?.coverArt ?? widget.artist?.artistImageUrl,
        );

        try {
          final ytResult =
              await YoutubeService().search(reliableArtistName, songCount: 30);
          if (ytResult.songs.isNotEmpty) {
            final cleanLower = reliableArtistName.toLowerCase().trim();
            final matchingSongs = ytResult.songs.where((s) {
              final a = s.artist?.toLowerCase().trim();
              if (a == null) return false;
              return a.contains(cleanLower) || cleanLower.contains(a);
            }).toList();

            topSongs = matchingSongs.isNotEmpty ? matchingSongs : ytResult.songs;
            if (albums.isEmpty && ytResult.albums.isNotEmpty) {
              albums = ytResult.albums.where((alb) {
                final a = alb.artist?.toLowerCase().trim();
                if (a == null || a.isEmpty) return true;
                return a.contains(cleanLower) || cleanLower.contains(a);
              }).toList();
            }
          }
        } catch (ytErr) {
          debugPrint('Online artist search error: $ytErr');
        }
      }

      // Final guarantee: always keep the reliable artist name and valid cover art
      artist = Artist(
        id: widget.artistId,
        name: reliableArtistName,
        coverArt: widget.artist?.coverArt ?? widget.artist?.artistImageUrl ?? artist?.coverArt,
        albumCount: artist?.albumCount ?? albums.length,
        artistImageUrl: widget.artist?.artistImageUrl ?? widget.artist?.coverArt ?? artist?.artistImageUrl,
        isLocal: artist?.isLocal ?? false,
      );

      // Ensure all unique albums from topSongs are included in albums
      final albumMap = <String, Album>{};
      for (final a in albums) {
        albumMap[a.name.toLowerCase().trim()] = a;
      }
      for (final s in topSongs) {
        final aName = s.album?.trim();
        if (aName != null && aName.isNotEmpty) {
          final key = aName.toLowerCase();
          if (!albumMap.containsKey(key)) {
            final cleanTitle = AlbumSanitizer.cleanTitle(aName);
            albumMap[key] = Album(
              id: s.albumId ?? 'album_${aName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
              name: cleanTitle.isNotEmpty ? cleanTitle : aName,
              artist: s.artist ?? artist.name,
              coverArt: s.coverArt,
              year: s.year,
            );
          }
        }
      }
      albums = albumMap.values.toList();

      // Fetch artist full discography online via Deezer and merge
      try {
        final onlineAlbums = await ArtistImageService()
            .getArtistAlbums(artist.name)
            .timeout(const Duration(seconds: 4));
        for (final oa in onlineAlbums) {
          final key = oa.name.toLowerCase().trim();
          if (!albumMap.containsKey(key)) {
            albumMap[key] = oa;
          }
        }
        albums = albumMap.values.toList();
      } catch (_) {}

      // Resolve high-resolution artist image if missing or empty
      String? coverArtUrl = ArtistImageService.getCachedArtistImageUrl(artist.name) ??
          artist.coverArt ??
          artist.artistImageUrl;
      try {
        final resolved = await ArtistImageService()
            .getArtistImageUrl(artist.name)
            .timeout(const Duration(seconds: 4));
        if (resolved != null && resolved.isNotEmpty) {
          coverArtUrl = resolved;
          artist = Artist(
            id: artist.id,
            name: artist.name,
            coverArt: resolved,
            albumCount: artist.albumCount ?? albums.length,
            artistImageUrl: resolved,
            isLocal: artist.isLocal,
          );
          libraryProvider.updateArtistCoverArt(
            artist.id,
            resolved,
            artistName: artist.name,
          );
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _artist = artist;
          _topSongs = topSongs;
          _albums = albums;
          _resolvedCoverArt = coverArtUrl;
          _isLoading = false;
        });
        if (topSongs.isNotEmpty && topSongs.first.isLocal != true) {
          final firstSong = topSongs.first;
          final cleanId = firstSong.id.replaceFirst('ytmusic://', '').replaceFirst('yt_', '').trim();
          if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(cleanId)) {
            YtDlpService().warmUpStreamCache(cleanId);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addArtistToQueue() async {
    if (_albums.isEmpty) return;

    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final libraryProvider = Provider.of<LibraryProvider>(
      context,
      listen: false,
    );
    final youtubeService = libraryProvider.youtubeService;

    final messenger = ScaffoldMessenger.of(context);
    final loc = AppLocalizations.of(context);

    try {
      final songsToQueue = <Song>[];
      for (final album in _albums) {
        final albumSongs = libraryProvider.isLocalOnlyMode
            ? libraryProvider.cachedAllSongs
                .where((s) => s.albumId == album.id)
                .toList()
            : await youtubeService.getAlbumSongs(album.id);

        songsToQueue.addAll(albumSongs);
      }

      if (songsToQueue.isNotEmpty) {
        playerProvider.addAllToQueue(songsToQueue);
      }

      if (!mounted) return;

      final addedToQueueMessage =
          loc?.addedArtistToQueue ?? 'Added artist to Queue';
      messenger.showSnackBar(
        SnackBar(
          content: Text(addedToQueueMessage),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final addedToQueueErrorMessage =
          loc?.addedArtistToQueueError ?? 'Failed adding artist to Queue';
      messenger.showSnackBar(
        SnackBar(
          content: Text(addedToQueueErrorMessage),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _downloadArtistAlbums() async {
    if (_albums.isEmpty) return;

    final offlineService = OfflineService();
    final libraryProvider = Provider.of<LibraryProvider>(context, listen: false);
    final youtubeService = libraryProvider.youtubeService;

    await offlineService.initialize();
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    int queuedSongs = 0;

    for (final album in _albums) {
      final albumSongs = libraryProvider.isLocalOnlyMode
          ? libraryProvider.cachedAllSongs
              .where((s) => s.albumId == album.id)
              .toList()
          : await youtubeService.getAlbumSongs(album.id);

      if (albumSongs.isNotEmpty) {
        offlineService.queuePlaylistDownload(album.id, albumSongs, youtubeService);
        queuedSongs += albumSongs.length;
      }
    }

    if (mounted && queuedSongs > 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Queued $queuedSongs songs from ${_albums.length} albums for download…'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _playTopSongs({bool shuffle = false}) {
    if (_topSongs.isEmpty) return;

    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    var songs = List<Song>.from(_topSongs);
    if (shuffle) {
      songs.shuffle();
    }

    playerProvider.playSong(songs.first, playlist: songs, startIndex: 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pageBgColor = isDark ? AppTheme.darkBackground : Colors.white;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: pageBgColor,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_artist == null) {
      return Scaffold(
        backgroundColor: pageBgColor,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(
          child: Text(AppLocalizations.of(context)!.artistDataNotFound),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = ScreenHelper.isSmallScreen(context);
    final topPadding = MediaQuery.of(context).padding.top;
    final artworkSize = isSmall
        ? (screenWidth - 64.0).clamp(285.0, 345.0)
        : (screenWidth * 0.36).clamp(300.0, 360.0);
    final topOffset = topPadding + (isSmall ? 48.0 : 56.0);
    const bottomOffset = 18.0;
    final headerExpandedHeight = topOffset + artworkSize + bottomOffset;

    return Scaffold(
      backgroundColor: pageBgColor,
      body: CustomScrollView(
        slivers: [
          // 1. Hero AppBar with Collapsible Title & Ambient Large Artwork
          SliverAppBar(
            pinned: true,
            expandedHeight: headerExpandedHeight,
            backgroundColor: pageBgColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 2,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.75),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  CupertinoIcons.back,
                  color: isDark ? Colors.white : Colors.black87,
                  size: 20,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                final top = constraints.biggest.height;
                final isCollapsed = top <= (kToolbarHeight + topPadding + 20);

                return FlexibleSpaceBar(
                  centerTitle: true,
                  collapseMode: CollapseMode.parallax,
                  title: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isCollapsed ? 1.0 : 0.0,
                    child: Text(
                      _artist!.name,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  background: _buildHeaderBackground(
                    context,
                    pageBgColor,
                    isDark,
                    topOffset,
                    bottomOffset,
                    artworkSize,
                  ),
                );
              },
            ),
            actions: [
              _buildStarButton(context, isDark),
              _buildMoreButton(context, isDark),
              const SizedBox(width: 4),
            ],
          ),

          // 2. Artist Name, Badges & Primary Play/Shuffle Controls
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 6),

                  // Artist Name (Apple Music typography)
                  Text(
                    _artist!.name,
                    style: TextStyle(
                      fontSize: isSmall ? 23 : 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // Metadata Badges
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildMetaBadge('ARTISTA', isDark),
                      if (_albums.isNotEmpty)
                        _buildMetaBadge(
                          '${_albums.length} ${_albums.length == 1 ? "álbum" : "álbumes"}',
                          isDark,
                        ),
                      if (_topSongs.isNotEmpty)
                        _buildMetaBadge(
                          '${_topSongs.length} canciones',
                          isDark,
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Primary Play & Shuffle Buttons (Apple Music style)
                  if (_topSongs.isNotEmpty)
                    Row(
                      children: [
                        Expanded(
                          child: _PlayButton(
                            icon: CupertinoIcons.play_fill,
                            label: AppLocalizations.of(context)!.play,
                            onTap: () => _playTopSongs(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PlayButton(
                            icon: CupertinoIcons.shuffle,
                            label: AppLocalizations.of(context)!.shuffle,
                            onTap: () => _playTopSongs(shuffle: true),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),

          // 3. Canciones Populares (Top Songs)
          if (_topSongs.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Text(
                  AppLocalizations.of(context)!.topSongs,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = _topSongs[index];
                    return SongTile(
                      song: song,
                      playlist: _topSongs,
                      index: index,
                      showArtist: false,
                      showAlbum: true,
                      showDuration: true,
                    );
                  },
                  childCount: _topSongs.take(8).length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],

          // 4. Discografía
          if (_albums.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Text(
                  'Discografía',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  childAspectRatio: 0.72,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final album = _albums[index];
                    return AlbumCard(
                      album: album,
                      size: double.infinity,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              AlbumScreen(albumId: album.id, album: album),
                        ),
                      ),
                    );
                  },
                  childCount: _albums.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],

          // 5. Acerca de / Biografía
          if (_artistInfo?.biography != null && _artistInfo!.biography!.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Acerca de ${_artist!.name}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Text(
                        _artistInfo!.biography!,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaBadge(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white70 : Colors.black54,
          letterSpacing: -0.1,
        ),
      ),
    );
  }

  Widget _buildHeaderBackground(
    BuildContext context,
    Color pageBgColor,
    bool isDark,
    double topOffset,
    double bottomOffset,
    double artworkSize,
  ) {
    final cover = _resolvedCoverArt ?? _artist?.coverArt ?? _artist?.artistImageUrl;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Ambient Blurred Backdrop
        if (cover != null && cover.isNotEmpty)
          Positioned.fill(
            child: Opacity(
              opacity: isDark ? 0.36 : 0.28,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
                child: cover.startsWith('http')
                    ? CachedNetworkImage(
                        imageUrl: cover,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      )
                    : isLocalFilePath(cover)
                        ? Image.file(
                            File(cover),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          )
                        : AlbumArtwork(coverArt: cover, size: 320),
              ),
            ),
          ),

        // 2. Gradient overlay fading cleanly into page background
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  pageBgColor.withValues(alpha: 0.65),
                  pageBgColor,
                ],
                stops: const [0.0, 0.70, 1.0],
              ),
            ),
          ),
        ),

        // 3. Main Elevated 3D Artist Artwork (matching AlbumScreen)
        Center(
          child: Padding(
            padding: EdgeInsets.only(
              top: topOffset,
              bottom: bottomOffset,
            ),
            child: Container(
              width: artworkSize,
              height: artworkSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.14)
                      : Colors.black.withValues(alpha: 0.08),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.50 : 0.18),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: (cover != null && cover.isNotEmpty)
                    ? (cover.startsWith('http')
                        ? CachedNetworkImage(
                            imageUrl: cover,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _buildFallbackAvatar(),
                          )
                        : isLocalFilePath(cover)
                            ? Image.file(
                                File(cover),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildFallbackAvatar(),
                              )
                            : AlbumArtwork(
                                coverArt: cover,
                                size: artworkSize,
                                borderRadius: 20,
                              ))
                    : _buildFallbackAvatar(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStarButton(BuildContext context, bool isDark) {
    if (_artist == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: FavoriteArtistsService(),
      builder: (context, _) {
        final isStarred = FavoriteArtistsService().isFavorite(
          _artist!.id,
          artistName: _artist!.name,
        );

        return IconButton(
          icon: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.45)
                  : Colors.black.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
              color: isStarred ? Colors.amber : Colors.white,
              size: 22,
            ),
          ),
          tooltip: isStarred ? 'Quitar de favoritos' : 'Agregar a favoritos',
          onPressed: _toggleFavoriteArtist,
        );
      },
    );
  }

  Widget _buildMoreButton(BuildContext context, bool isDark) {
    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.black.withValues(alpha: 0.45)
              : Colors.black.withValues(alpha: 0.25),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.more_vert_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
      tooltip: 'Más opciones',
      onPressed: () => _showArtistOptionsMenu(context),
    );
  }

  Future<void> _toggleFavoriteArtist() async {
    if (_artist == null) return;
    final wasStarred = FavoriteArtistsService().isFavorite(
      _artist!.id,
      artistName: _artist!.name,
    );
    await FavoriteArtistsService().toggleFavorite(
      _artist!.id,
      artistName: _artist!.name,
    );

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          wasStarred
              ? 'Eliminado de artistas favoritos'
              : 'Agregado a artistas favoritos',
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _addArtistToQueueNext() async {
    if (_topSongs.isEmpty) return;
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    for (int i = _topSongs.length - 1; i >= 0; i--) {
      await playerProvider.addToQueueNext(_topSongs[i]);
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Se reproducirá a continuación "${_artist?.name ?? ""}"'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showArtistOptionsMenu(BuildContext context) {
    if (_artist == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subtitleColor = isDark ? Colors.white60 : Colors.black54;
    final dividerColor = isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08);
    const appleRed = Color(0xFFFA2D48);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => RepaintBoundary(
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                blurRadius: 16,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),

                // Top pill handle
                Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),

                const SizedBox(height: 14),

                // Header (Artist Thumbnail + Name + "Artista" (red) + Albums & Songs count)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18.0),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: (_resolvedCoverArt != null && _resolvedCoverArt!.isNotEmpty)
                              ? (_resolvedCoverArt!.startsWith('http')
                                  ? CachedNetworkImage(
                                      imageUrl: _resolvedCoverArt!,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => _buildFallbackAvatar(),
                                    )
                                  : isLocalFilePath(_resolvedCoverArt)
                                      ? Image.file(
                                          File(_resolvedCoverArt!),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => _buildFallbackAvatar(),
                                        )
                                      : AlbumArtwork(coverArt: _resolvedCoverArt, size: 54, borderRadius: 10))
                              : _buildFallbackAvatar(),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _artist!.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Artista',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: appleRed,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '${_albums.length} ${_albums.length == 1 ? "álbum" : "álbumes"} • ${_topSongs.length} canciones',
                              style: TextStyle(
                                fontSize: 13,
                                color: subtitleColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                Divider(height: 1, color: dividerColor),
                const SizedBox(height: 4),

                // 1. Agregar a la biblioteca / Eliminar de la biblioteca
                AnimatedBuilder(
                  animation: FavoriteArtistsService(),
                  builder: (context, _) {
                    final isStarred = FavoriteArtistsService().isFavorite(
                      _artist!.id,
                      artistName: _artist!.name,
                    );
                    return _buildMoreMenuItem(
                      icon: isStarred ? CupertinoIcons.minus : CupertinoIcons.add,
                      title: isStarred ? 'Eliminar de la biblioteca' : 'Agregar a la biblioteca',
                      textColor: textColor,
                      appleRed: appleRed,
                      onTap: () {
                        Navigator.pop(ctx);
                        _toggleFavoriteArtist();
                      },
                    );
                  },
                ),

                // 2. Reproducir a continuación
                _buildMoreMenuItem(
                  icon: Icons.play_arrow_rounded,
                  title: 'Reproducir a continuación',
                  textColor: textColor,
                  appleRed: appleRed,
                  onTap: () {
                    Navigator.pop(ctx);
                    _addArtistToQueueNext();
                  },
                ),

                // 3. Añadir a la cola
                _buildMoreMenuItem(
                  icon: Icons.queue_music_rounded,
                  title: 'Añadir a la cola',
                  textColor: textColor,
                  appleRed: appleRed,
                  onTap: () {
                    Navigator.pop(ctx);
                    _addArtistToQueue();
                  },
                ),

                // 4. Descargar álbumes
                _buildMoreMenuItem(
                  icon: CupertinoIcons.arrow_down_circle,
                  title: 'Descargar álbumes',
                  textColor: textColor,
                  appleRed: appleRed,
                  onTap: () {
                    Navigator.pop(ctx);
                    _downloadArtistAlbums();
                  },
                ),

                // 5. Reproducir canciones
                _buildMoreMenuItem(
                  icon: CupertinoIcons.play_circle,
                  title: 'Reproducir canciones',
                  textColor: textColor,
                  appleRed: appleRed,
                  onTap: () {
                    Navigator.pop(ctx);
                    _playTopSongs();
                  },
                ),

                // 6. Reproducción aleatoria
                _buildMoreMenuItem(
                  icon: CupertinoIcons.shuffle,
                  title: 'Reproducción aleatoria',
                  textColor: textColor,
                  appleRed: appleRed,
                  onTap: () {
                    Navigator.pop(ctx);
                    _playTopSongs(shuffle: true);
                  },
                ),

                // 7. Agregar a Favoritos / Eliminar de Favoritos
                AnimatedBuilder(
                  animation: FavoriteArtistsService(),
                  builder: (context, _) {
                    final isStarred = FavoriteArtistsService().isFavorite(
                      _artist!.id,
                      artistName: _artist!.name,
                    );
                    return _buildMoreMenuItem(
                      icon: isStarred ? CupertinoIcons.star_fill : CupertinoIcons.star,
                      iconColor: isStarred ? Colors.amber : appleRed,
                      title: isStarred ? 'Eliminar de Favoritos' : 'Agregar a Favoritos',
                      textColor: textColor,
                      appleRed: appleRed,
                      onTap: () {
                        Navigator.pop(ctx);
                        _toggleFavoriteArtist();
                      },
                    );
                  },
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreMenuItem({
    required IconData icon,
    Color? iconColor,
    required String title,
    required Color textColor,
    required Color appleRed,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 13.0),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? appleRed, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar() {
    return Container(
      color: AppTheme.appleMusicRed.withValues(alpha: 0.15),
      child: const Center(
        child: Icon(
          CupertinoIcons.mic_fill,
          size: 24,
          color: AppTheme.appleMusicRed,
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PlayButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final btnBg = isDark
        ? const Color(0xFF2C2C2E)
        : const Color(0xFFF2F2F7);

    return Material(
      color: btnBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppTheme.appleMusicRed, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.appleMusicRed,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
