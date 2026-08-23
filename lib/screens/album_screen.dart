import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/subsonic_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import '../l10n/app_localizations.dart';
import '../utils/screen_helper.dart';
import '../services/offline_service.dart';

import '../services/services.dart';

class AlbumScreen extends StatefulWidget {
  final String albumId;
  final Album? album;

  const AlbumScreen({super.key, required this.albumId, this.album});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  Album? _album;
  List<Song> _songs = [];
  bool _isLoading = true;

  bool _allDownloaded = false;
  bool _isQueued = false;

  @override
  void initState() {
    super.initState();
    _album = widget.album;
    _loadAlbum();
    OfflineService().downloadedPlaylistIds.addListener(_updateDownloadState);
    OfflineService().queuedPlaylistIds.addListener(_updateDownloadState);
  }

  @override
  void dispose() {
    OfflineService().downloadedPlaylistIds.removeListener(_updateDownloadState);
    OfflineService().queuedPlaylistIds.removeListener(_updateDownloadState);
    super.dispose();
  }

  void _updateDownloadState() {
    if (!mounted || _album == null) return;
    final offline = OfflineService();
    final allDown = offline.downloadedPlaylistIds.value.contains(_album!.id);
    final queued = offline.queuedPlaylistIds.value.contains(_album!.id);
    if (allDown != _allDownloaded || queued != _isQueued) {
      setState(() {
        _allDownloaded = allDown;
        _isQueued = queued;
      });
    }
  }

  Future<void> _loadAlbum() async {
    final subsonicService = Provider.of<SubsonicService>(
      context,
      listen: false,
    );
    final libraryProvider = Provider.of<LibraryProvider>(
      context,
      listen: false,
    );

    try {
      Album? album = widget.album;
      List<Song> songs = [];

      if (libraryProvider.isLocalOnlyMode) {
        album ??= libraryProvider.cachedAllAlbums.firstWhere(
          (a) => a.id == widget.albumId,
          orElse: () => Album(id: widget.albumId, name: widget.albumId),
        );
        songs = await libraryProvider.getAlbumSongs(widget.albumId);
      } else {
        try {
          album ??= await subsonicService.getAlbum(widget.albumId);
          songs = await libraryProvider.getAlbumSongs(widget.albumId);
        } catch (_) {}
      }

      // Filter songs specifically for this album
      if (album != null && songs.isNotEmpty) {
        final albumNameLower = album.name.trim().toLowerCase();
        final filteredSongs = songs.where((s) {
          final sAlbumLower = s.album?.trim().toLowerCase() ?? '';
          return s.albumId == album?.id || (albumNameLower.isNotEmpty && sAlbumLower == albumNameLower);
        }).toList();
        if (filteredSongs.isNotEmpty) {
          songs = filteredSongs;
        }
      }

      // If no songs found or only 1 track matched from cache, search online specifically for this album
      if (songs.isEmpty || (album != null && songs.length <= 1)) {
        final albumName = album?.name ?? widget.albumId;
        final artistName = album?.artist ?? '';
        album ??= Album(
          id: widget.albumId,
          name: albumName,
          artist: artistName,
        );

        final searchQuery = artistName.isNotEmpty && !albumName.toLowerCase().contains(artistName.toLowerCase())
            ? '$albumName $artistName'
            : albumName;

        try {
          final ytResult =
              await YoutubeService().search('$searchQuery album', songCount: 25);
          if (ytResult.songs.isNotEmpty) {
            songs = ytResult.songs;
            if (album.coverArt == null || album.coverArt!.isEmpty) {
              album = Album(
                id: album.id,
                name: album.name,
                artist: artistName.isNotEmpty ? artistName : songs.first.artist,
                coverArt: songs.first.coverArt,
                songCount: songs.length,
              );
            }
          }
        } catch (e) {
          debugPrint('Online album search error: $e');
        }
      }

      // If coverArt is missing or not a valid URL/ID, resolve from the tracks
      if (songs.isNotEmpty) {
        final currentCover = album?.coverArt ?? '';
        final hasValidCover = currentCover.startsWith('http') ||
            currentCover.startsWith('/') ||
            RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(currentCover.replaceFirst('ytmusic://', '').replaceFirst('yt_', ''));

        if (!hasValidCover) {
          final firstValidCover = songs.firstWhere(
            (s) => s.coverArt != null && s.coverArt!.isNotEmpty,
            orElse: () => songs.first,
          );
          final cover = firstValidCover.coverArt ?? firstValidCover.id;
          if (cover.isNotEmpty) {
            album = Album(
              id: album?.id ?? widget.albumId,
              name: album?.name ?? widget.albumId,
              artist: album?.artist ?? firstValidCover.artist,
              coverArt: cover,
              songCount: songs.length,
            );
          }
        }
      }

      if (mounted) {
        setState(() {
          _album = album;
          _songs = songs;
          _isLoading = false;
        });
        _updateDownloadState();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? get _resolvedCoverArt {
    final raw = _album?.coverArt;
    if (raw != null && raw.isNotEmpty) {
      if (raw.startsWith('http') ||
          raw.startsWith('/') ||
          RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(raw.replaceFirst('ytmusic://', '').replaceFirst('yt_', ''))) {
        return raw;
      }
    }
    for (final s in _songs) {
      if (s.coverArt != null && s.coverArt!.isNotEmpty) return s.coverArt;
      final cleanId = s.id.replaceFirst('ytmusic://', '').replaceFirst('yt_', '');
      if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(cleanId)) {
        return cleanId;
      }
    }
    return raw;
  }

  void _playAll({bool shuffle = false}) {
    if (_songs.isEmpty) return;

    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    List<Song> playlist = List.from(_songs);
    if (shuffle) {
      playlist.shuffle();
    }

    playerProvider.playSong(playlist.first, playlist: playlist, startIndex: 0);
  }

  Future<void> _downloadAlbum() async {
    if (_songs.isEmpty || _album == null) return;
    final offlineService = OfflineService();
    final subsonicService = Provider.of<SubsonicService>(context, listen: false);
    await offlineService.initialize();
    offlineService.queuePlaylistDownload(_album!.id, _songs, subsonicService);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Queued ${_songs.length} songs for download…'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _cancelDownload() async {
    if (_album == null) return;
    await OfflineService().cancelPlaylistDownload(_album!.id);
  }

  Future<void> _removeDownloads() async {
    if (_songs.isEmpty || _album == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove downloads?'),
        content: Text('Remove all ${_songs.length} downloaded songs from "${_album!.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await OfflineService().cancelPlaylistDownload(_album!.id);
      await OfflineService().deletePlaylistDownloads(_songs);
    }
  }

  Widget _buildDownloadButton(BuildContext context) {
    if (_allDownloaded) {
      return IconButton(
        tooltip: 'Downloaded — tap to remove',
        onPressed: _removeDownloads,
        icon: const Icon(Icons.cloud_done, color: Colors.green),
      );
    }
    if (_isQueued) {
      return IconButton(
        tooltip: 'Downloading — tap to cancel',
        onPressed: _cancelDownload,
        icon: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      tooltip: 'Download album',
      onPressed: _downloadAlbum,
      icon: const Icon(CupertinoIcons.cloud_download),
    );
  }

  Future<void> _toggleLike() async {
    if (_album == null) return;
    
    final libraryProvider = Provider.of<LibraryProvider>(context, listen: false);
    final isStarred = _album!.starred == true;
    
    setState(() {
      _album!.starred = !isStarred;
    });

    try {
      if (isStarred) {
        await libraryProvider.unstar(albumId: _album!.id);
      } else {
        await libraryProvider.star(albumId: _album!.id);
      }
    } catch (e) {
      // Revert on failure
      setState(() {
        _album!.starred = isStarred;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update liked status')),
        );
      }
    }
  }

  Widget _buildLikeButton(BuildContext context) {
    if (_album == null) return const SizedBox.shrink();
    final isStarred = _album!.starred == true;
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return IconButton(
      tooltip: isStarred ? 'Unlike' : 'Like',
      onPressed: _toggleLike,
      icon: Icon(
        isStarred ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
        color: isStarred ? primaryColor : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const AlbumArtworkShimmer(size: 250),
                    const SizedBox(height: 24),
                    Shimmer.fromColors(
                      baseColor:
                          isDark ? AppTheme.darkCard : const Color(0xFFE0E0E0),
                      highlightColor: isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFF5F5F5),
                      child: Container(
                        width: 200,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Shimmer.fromColors(
                      baseColor:
                          isDark ? AppTheme.darkCard : const Color(0xFFE0E0E0),
                      highlightColor: isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFF5F5F5),
                      child: Container(
                        width: 150,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => const SongTileShimmer(),
                childCount: 10,
              ),
            ),
          ],
        ),
      );
    }

    if (_album == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(AppLocalizations.of(context)!.albumNotFound)),
      );
    }

    final totalDuration = _songs.fold<int>(
      0,
      (sum, song) => sum + (song.duration ?? 0),
    );
    final hours = totalDuration ~/ 3600;
    final minutes = (totalDuration % 3600) ~/ 60;

    final isOffline = Provider.of<AuthProvider>(context, listen: false).state ==
        AuthState.offlineMode;

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: ScreenHelper.isSmallScreen(context) ? 280 : 360,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.back,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: ValueListenableBuilder<Set<String>>(
                    valueListenable: OfflineService().downloadedPlaylistIds,
                    builder: (context, downloaded, _) {
                      final allDownloaded = _album != null && downloaded.contains(_album!.id);
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(
                              top: MediaQuery.of(context).padding.top + 40,
                              left: ScreenHelper.isSmallScreen(context) ? 24 : 40,
                              right: ScreenHelper.isSmallScreen(context) ? 24 : 40,
                              bottom: ScreenHelper.isSmallScreen(context) ? 60 : 80,
                            ),
                            child: AlbumArtwork(
                              coverArt: _resolvedCoverArt,
                              size: ScreenHelper.isSmallScreen(context) ? 200 : 280,
                              borderRadius: 10,
                              preserveAspectRatio: true,
                            ),
                          ),
                          if (allDownloaded)
                            Positioned(
                              bottom: 86,
                              right: 46,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  CupertinoIcons.arrow_down_circle_fill,
                                  color: Colors.grey,
                                  size: 28,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                actions: [
                  if (!isOffline) _buildLikeButton(context),
                  if (!isOffline) _buildDownloadButton(context),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _album!.name,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontSize:
                              ScreenHelper.isSmallScreen(context) ? 22 : null,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      MultiArtistWidget(
                        artists: _album!.artistParticipants,
                        artistFallback: _album!.artist ??
                            AppLocalizations.of(context)!.unknownArtist,
                        artistIdFallback: _album!.artistId,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AppTheme.appleMusicRed,
                          fontSize:
                              ScreenHelper.isSmallScreen(context) ? 16 : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (_album!.genre != null)
                            _album!.genre!.toUpperCase(),
                          if (_album!.year != null) _album!.year.toString(),
                          if (hours > 0)
                            '$hours HR $minutes MIN'
                          else
                            '$minutes MIN',
                        ].join(' • '),
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _PlayButton(
                              icon: CupertinoIcons.play_fill,
                              label: AppLocalizations.of(context)!.play,
                              onTap: () => _playAll(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _PlayButton(
                              icon: CupertinoIcons.shuffle,
                              label: AppLocalizations.of(context)!.shuffle,
                              onTap: () => _playAll(shuffle: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              SliverFixedExtentList(
                itemExtent: 58.0,
                delegate: SliverChildBuilderDelegate((context, index) {
                  final song = _songs[index];
                  return SongTile(
                    song: song,
                    playlist: _songs,
                    index: index,
                    showArtwork: false,
                    showTrackNumber: true,
                    showArtist: false,
                  );
                }, childCount: _songs.length),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 150)),
            ],
          ),
        ],
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
