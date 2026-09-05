import 'dart:io';
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

import '../services/services.dart';

class ArtistScreen extends StatefulWidget {
  final String artistId;

  const ArtistScreen({super.key, required this.artistId});

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
    _loadArtistDetails();
  }

  Future<void> _loadArtistDetails() async {
    final libraryProvider = Provider.of<LibraryProvider>(
      context,
      listen: false,
    );
    final youtubeService = libraryProvider.youtubeService;

    try {
      Artist? artist;
      List<Song> topSongs = [];
      List<Album> albums = [];

      if (libraryProvider.isLocalOnlyMode) {
        artist = libraryProvider.artists.firstWhere(
          (a) => a.id == widget.artistId,
          orElse: () => Artist(id: widget.artistId, name: widget.artistId),
        );
        albums = await libraryProvider.getArtistAlbums(widget.artistId);

        topSongs = libraryProvider.cachedAllSongs
            .where((s) => s.artistId == widget.artistId)
            .toList();
      } else {
        // First check if widget.artistId matches an artist in libraryProvider
        Artist? libraryMatch;
        for (final a in libraryProvider.artists) {
          if (a.id == widget.artistId || a.name.toLowerCase() == widget.artistId.toLowerCase()) {
            libraryMatch = a;
            break;
          }
        }
        final targetId = libraryMatch?.id ?? widget.artistId;

        try {
          artist = await youtubeService.getArtist(targetId);
          _artistInfo = await youtubeService.getArtistInfo(targetId);

          topSongs = await youtubeService.getArtistTopSongs(targetId);
          albums = await youtubeService.getArtistAlbums(targetId);
          if (albums.isNotEmpty) {
            final topSongIds = topSongs.map((s) => s.id).toSet();
            final seenIds = {...topSongIds};
            const chunkSize = 5;
            final allAlbumSongs = <Song>[];
            for (var i = 0; i < albums.length; i += chunkSize) {
              final chunk =
                  albums.sublist(i, (i + chunkSize).clamp(0, albums.length));
              final results = await Future.wait(
                  chunk.map((a) => youtubeService.getAlbumSongs(a.id)));
              allAlbumSongs.addAll(results
                  .expand((songs) => songs)
                  .where((s) => seenIds.add(s.id)));
            }
            topSongs = [...topSongs, ...allAlbumSongs];
          }
        } catch (serverErr) {
          debugPrint('Library getArtist error: $serverErr');
        }
      }

      // If artist was not found in local DB or has no top songs, fetch online via YouTube
      if (artist == null || topSongs.isEmpty) {
        final artistName = widget.artistId;
        artist ??= Artist(
          id: widget.artistId,
          name: artistName,
        );

        try {
          final ytResult =
              await YoutubeService().search(artistName, songCount: 30);
          if (ytResult.songs.isNotEmpty) {
            topSongs = ytResult.songs;
            albums = ytResult.albums;
            if (artist.coverArt == null && topSongs.isNotEmpty) {
              artist = Artist(
                id: artist.id,
                name: artist.name,
                coverArt: topSongs.first.coverArt,
              );
            }
          }
        } catch (ytErr) {
          debugPrint('Online artist search error: $ytErr');
        }
      }

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
            albumMap[key] = Album(
              id: s.albumId ?? 'album_${aName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
              name: aName,
              artist: s.artist ?? artist?.name ?? '',
              coverArt: s.coverArt,
              year: s.year,
            );
          }
        }
      }
      albums = albumMap.values.toList();

      // Fetch artist full discography online via Deezer and merge
      if (artist != null) {
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
      }

      // Resolve high-resolution artist image if missing or empty
      String? coverArtUrl = artist?.coverArt ?? artist?.artistImageUrl;
      if (artist != null) {
        final fallbackCover = topSongs.isNotEmpty ? topSongs.first.coverArt : null;
        try {
          final resolved = await ArtistImageService()
              .getArtistImageUrl(artist.name, fallbackCoverArt: fallbackCover)
              .timeout(const Duration(seconds: 3));
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
      }

      if (mounted) {
        setState(() {
          _artist = artist;
          _topSongs = topSongs;
          _albums = albums;
          _resolvedCoverArt = coverArtUrl;
          _isLoading = false;
        });
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

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_artist == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(AppLocalizations.of(context)!.artistDataNotFound),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 240,
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.arrow_left,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _artist!.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: _buildHeaderBackground(context),
            ),
            actions: [
              _buildStarButton(context),
              _buildMoreButton(context),
            ],
          ),
          if (_topSongs.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
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
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_topSongs.isNotEmpty) ...[
                    Text(
                      AppLocalizations.of(context)!.topSongs,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemExtent: 68.0,
                      itemCount: _topSongs.take(5).length,
                      itemBuilder: (context, index) {
                        final song = _topSongs[index];
                        return SongTile(
                          song: song,
                          playlist: _topSongs,
                          index: index,
                          showAlbum: true,
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (_albums.isNotEmpty) ...[
                    Text(
                      'Discografía',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 180,
                        childAspectRatio: 0.72,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _albums.length,
                      itemBuilder: (context, index) {
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
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (_artistInfo?.biography != null &&
                      _artistInfo!.biography!.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Text(
                      'About ${_artist!.name}',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _artistInfo!.biography!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color
                            ?.withValues(alpha: 0.8),
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBackground(BuildContext context) {
    final cover = _resolvedCoverArt ?? _artist?.coverArt ?? _artist?.artistImageUrl;

    if (cover != null && cover.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (cover.startsWith('http'))
            CachedNetworkImage(
              imageUrl: cover,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              placeholder: (ctx, url) => Container(
                color: AppTheme.appleMusicRed.withValues(alpha: 0.15),
                child: const Center(
                  child: Icon(
                    CupertinoIcons.mic_fill,
                    size: 64,
                    color: AppTheme.appleMusicRed,
                  ),
                ),
              ),
              errorWidget: (ctx, url, err) => Container(
                color: AppTheme.appleMusicRed.withValues(alpha: 0.15),
                child: const Center(
                  child: Icon(
                    CupertinoIcons.mic_fill,
                    size: 64,
                    color: AppTheme.appleMusicRed,
                  ),
                ),
              ),
            )
          else if (isLocalFilePath(cover))
            Image.file(
              File(cover),
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, __, ___) => Container(
                color: AppTheme.appleMusicRed.withValues(alpha: 0.15),
                child: const Center(
                  child: Icon(
                    CupertinoIcons.mic_fill,
                    size: 64,
                    color: AppTheme.appleMusicRed,
                  ),
                ),
              ),
            )
          else
            AlbumArtwork(
              coverArt: cover,
              size: 400,
            ),
          // Top gradient to ensure back button and actions contrast nicely
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 100,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Bottom gradient to make white title text razor-sharp and clean
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 140,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.5),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      color: AppTheme.appleMusicRed.withValues(alpha: 0.15),
      child: const Center(
        child: Icon(
          CupertinoIcons.mic_fill,
          size: 64,
          color: AppTheme.appleMusicRed,
        ),
      ),
    );
  }

  Widget _buildStarButton(BuildContext context) {
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
              color: Colors.black.withValues(alpha: 0.35),
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

  Widget _buildMoreButton(BuildContext context) {
    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
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

  void _showArtistOptionsMenu(BuildContext context) {
    if (_artist == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subtitleColor = isDark ? Colors.white60 : Colors.black54;
    final dividerColor = isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    ClipOval(
                      child: SizedBox(
                        width: 50,
                        height: 50,
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
                                    : AlbumArtwork(coverArt: _resolvedCoverArt, size: 50))
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
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_albums.length} ${_albums.length == 1 ? "álbum" : "álbumes"} • ${_topSongs.length} canciones',
                            style: TextStyle(
                              fontSize: 13,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: dividerColor),
              ListTile(
                leading: const Icon(Icons.queue_music_rounded, color: AppTheme.appleMusicRed),
                title: Text(
                  AppLocalizations.of(context)?.addToQueue ?? 'Agregar a la cola',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _addArtistToQueue();
                },
              ),
              ListTile(
                leading: const Icon(CupertinoIcons.cloud_download, color: AppTheme.appleMusicRed),
                title: Text(
                  'Descargar álbumes',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadArtistAlbums();
                },
              ),
              ListTile(
                leading: const Icon(CupertinoIcons.play_circle, color: AppTheme.appleMusicRed),
                title: Text(
                  'Reproducir canciones',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _playTopSongs();
                },
              ),
              ListTile(
                leading: const Icon(CupertinoIcons.shuffle, color: AppTheme.appleMusicRed),
                title: Text(
                  'Reproducción aleatoria',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _playTopSongs(shuffle: true);
                },
              ),
              AnimatedBuilder(
                animation: FavoriteArtistsService(),
                builder: (context, _) {
                  final isStarred = FavoriteArtistsService().isFavorite(
                    _artist!.id,
                    artistName: _artist!.name,
                  );
                  return ListTile(
                    leading: Icon(
                      isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: isStarred ? Colors.amber : AppTheme.appleMusicRed,
                    ),
                    title: Text(
                      isStarred ? 'Quitar de favoritos' : 'Agregar a favoritos',
                      style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _toggleFavoriteArtist();
                    },
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
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

    final accent = Theme.of(context).colorScheme.primary;

    return Material(
      color: accent.withValues(alpha: isDark ? 0.15 : 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
