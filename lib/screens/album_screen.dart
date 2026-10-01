import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import '../l10n/app_localizations.dart';
import '../utils/screen_helper.dart';
import '../utils/navigation_helper.dart';
import '../utils/album_sanitizer.dart';
import '../services/services.dart';
import 'artist_screen.dart';

class AlbumScreen extends StatefulWidget {
  final String albumId;
  final Album? album;
  final Song? song;

  const AlbumScreen({
    super.key,
    required this.albumId,
    this.album,
    this.song,
  });

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  static final _ytIdRegex = RegExp(r'^[a-zA-Z0-9_-]{11}$');
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
    final youtubeService = Provider.of<YoutubeService>(
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

      // 0. Pre-populate from library cache if album metadata is missing or incomplete
      if (album == null ||
          album.artist == null ||
          album.artist!.isEmpty ||
          album.coverArt == null ||
          AlbumSanitizer.isPlaceholderOrSlug(album.name)) {
        try {
          final foundInCache = libraryProvider.cachedAllAlbums.firstWhere(
            (a) =>
                a.id == widget.albumId ||
                AlbumSanitizer.matches(a.id, widget.albumId) ||
                AlbumSanitizer.matches(a.name, widget.albumId),
            orElse: () => Album(id: '', name: ''),
          );
          if (foundInCache.id.isNotEmpty) {
            album = Album(
              id: foundInCache.id,
              name: (album != null &&
                      album.name.isNotEmpty &&
                      !AlbumSanitizer.isPlaceholderOrSlug(album.name))
                  ? album.name
                  : foundInCache.name,
              artist: (album?.artist != null && !AlbumSanitizer.isPlaceholder(album!.artist))
                  ? album.artist
                  : foundInCache.artist,
              artistId: album?.artistId ?? foundInCache.artistId,
              coverArt: album?.coverArt ?? foundInCache.coverArt,
              songCount: album?.songCount ?? foundInCache.songCount,
              duration: album?.duration ?? foundInCache.duration,
              year: album?.year ?? foundInCache.year,
              genre: album?.genre ?? foundInCache.genre,
              created: album?.created ?? foundInCache.created,
              artistParticipants: album?.artistParticipants ?? foundInCache.artistParticipants,
              starred: album?.starred ?? foundInCache.starred,
            );
          }
        } catch (_) {}
      }

      // 1. If in local-only mode, retrieve from local storage
      if (libraryProvider.isLocalOnlyMode) {
        songs = await libraryProvider.getAlbumSongs(widget.albumId);
      } else {
        // 2. Try online resolution via AlbumResolverService (YouTube Music browse & Deezer official tracks)
        try {
          final resolved = await AlbumResolverService().resolveAlbum(
            albumId: widget.albumId,
            existingAlbum: album,
            song: widget.song,
          );
          if (resolved != null && resolved.songs.isNotEmpty) {
            final keepName = (album != null &&
                    album.name.isNotEmpty &&
                    !AlbumSanitizer.isPlaceholderOrSlug(album.name))
                ? album.name
                : resolved.album.name;
            final keepArtist = (album?.artist != null &&
                    album!.artist!.isNotEmpty &&
                    !AlbumSanitizer.isPlaceholder(album.artist))
                ? album.artist
                : resolved.album.artist;

            album = Album(
              id: resolved.album.id,
              name: keepName,
              artist: keepArtist,
              artistId: album?.artistId ?? resolved.album.artistId,
              coverArt: resolved.album.coverArt ?? album?.coverArt,
              songCount: resolved.songs.length,
              duration: resolved.album.duration,
              year: resolved.album.year ?? album?.year,
              genre: resolved.album.genre ?? album?.genre,
              created: resolved.album.created ?? album?.created,
              artistParticipants: album?.artistParticipants ?? resolved.album.artistParticipants,
              starred: album?.starred ?? resolved.album.starred,
            );
            songs = resolved.songs;
          }
        } catch (e) {
          debugPrint('[AlbumScreen] AlbumResolver error: $e');
        }

        // 3. Fallback to YouTube service or local DB if online resolution had no songs
        if (songs.isEmpty) {
          try {
            if (!widget.albumId.startsWith('album_') && !widget.albumId.startsWith('local_album_')) {
              final ytSongs = await youtubeService.getAlbumSongs(widget.albumId);
              if (ytSongs.isNotEmpty) {
                songs = ytSongs;
              }
              final ytAlbum = await youtubeService.getAlbum(widget.albumId);
              if (ytAlbum != null) {
                final keepName = (album != null &&
                        album.name.isNotEmpty &&
                        !AlbumSanitizer.isPlaceholderOrSlug(album.name))
                    ? album.name
                    : ytAlbum.name;
                final keepArtist = (album?.artist != null &&
                        album!.artist!.isNotEmpty &&
                        !AlbumSanitizer.isPlaceholder(album.artist))
                    ? album.artist
                    : ytAlbum.artist;
                album = Album(
                  id: ytAlbum.id,
                  name: keepName,
                  artist: keepArtist,
                  artistId: album?.artistId ?? ytAlbum.artistId,
                  coverArt: album?.coverArt ?? ytAlbum.coverArt,
                  songCount: songs.isNotEmpty ? songs.length : ytAlbum.songCount,
                  duration: ytAlbum.duration,
                  year: album?.year ?? ytAlbum.year,
                );
              }
            }
            if (songs.isEmpty) {
              final localSongs = await libraryProvider.getAlbumSongs(widget.albumId);
              if (localSongs.isNotEmpty) songs = localSongs;
            }
          } catch (_) {}
        }
      }

      // 4. Sanitize album name and artist to guarantee NO dummy placeholders or raw slugs
      String rawName = album?.name ?? widget.album?.name ?? widget.song?.album ?? widget.albumId;
      String cleanTitle = AlbumSanitizer.cleanTitle(rawName);
      if (cleanTitle.isEmpty) {
        cleanTitle = widget.song?.title ?? widget.albumId;
      }

      String? safeArtist = album?.artist ?? widget.album?.artist ?? widget.song?.artist;
      if (AlbumSanitizer.isPlaceholder(safeArtist)) {
        if (songs.isNotEmpty) {
          final songWithArtist = songs.firstWhere(
            (s) => s.artist != null && !AlbumSanitizer.isPlaceholder(s.artist),
            orElse: () => songs.first,
          );
          if (songWithArtist.artist != null && !AlbumSanitizer.isPlaceholder(songWithArtist.artist)) {
            safeArtist = songWithArtist.artist;
          }
        }
      }

      String? safeCover = album?.coverArt ??
          widget.album?.coverArt ??
          widget.song?.coverArt ??
          (songs.isNotEmpty
              ? songs
                  .firstWhere((s) => s.coverArt != null && s.coverArt!.isNotEmpty,
                      orElse: () => songs.first)
                  .coverArt
              : null);

      album = Album(
        id: album?.id ?? widget.albumId,
        name: cleanTitle,
        artist: (safeArtist != null && !AlbumSanitizer.isPlaceholder(safeArtist))
            ? safeArtist
            : null,
        artistId: album?.artistId ?? widget.album?.artistId ?? widget.song?.artistId,
        coverArt: safeCover,
        songCount: songs.length,
        duration: album?.duration ?? songs.fold<int>(0, (sum, s) => sum + (s.duration ?? 0)),
        year: album?.year ?? widget.album?.year ?? widget.song?.year,
        genre: album?.genre ?? widget.album?.genre,
        created: album?.created ?? widget.album?.created,
        artistParticipants: album?.artistParticipants ?? widget.album?.artistParticipants,
        starred: album?.starred ?? widget.album?.starred,
      );

      // 5. If coverArt is still missing, resolve from first song
      if (songs.isNotEmpty && (album.coverArt == null || album.coverArt!.isEmpty)) {
        final firstCover = songs.firstWhere(
          (s) => s.coverArt != null && s.coverArt!.isNotEmpty,
          orElse: () => songs.first,
        ).coverArt;
        if (firstCover != null && firstCover.isNotEmpty) {
          album = Album(
            id: album.id,
            name: album.name,
            artist: album.artist,
            artistId: album.artistId,
            coverArt: firstCover,
            songCount: songs.length,
            duration: album.duration,
            year: album.year,
            genre: album.genre,
            created: album.created,
            artistParticipants: album.artistParticipants,
            starred: album.starred,
          );
        }
      }

      if (mounted) {
        setState(() {
          _album = album;
          _songs = songs;
          _isLoading = false;
        });
        _updateDownloadState();
        if (songs.isNotEmpty && songs.first.isLocal != true) {
          final firstSong = songs.first;
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

  String? get _resolvedCoverArt {
    final raw = _album?.coverArt;
    if (raw != null && raw.isNotEmpty) {
      if (raw.startsWith('http') ||
          raw.startsWith('/') ||
          _ytIdRegex.hasMatch(raw.replaceFirst('ytmusic://', '').replaceFirst('yt_', ''))) {
        return raw;
      }
    }
    for (final s in _songs) {
      if (s.coverArt != null && s.coverArt!.isNotEmpty) return s.coverArt;
      final cleanId = s.id.replaceFirst('ytmusic://', '').replaceFirst('yt_', '');
      if (_ytIdRegex.hasMatch(cleanId)) {
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
    final youtubeService = Provider.of<YoutubeService>(context, listen: false);
    await offlineService.initialize();
    offlineService.queuePlaylistDownload(_album!.id, _songs, youtubeService);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Queued ${_songs.length} songs for download…'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _removeDownloads() async {
    if (_songs.isEmpty || _album == null) return;
    final confirmed = await GroovyConfirmDialog.show(
      context,
      title: '¿Eliminar descargas?',
      message: '¿Eliminar las ${_songs.length} canciones descargadas de "${_album!.name}"?',
      confirmLabel: 'Eliminar',
      cancelLabel: 'Cancelar',
      isDestructive: true,
      icon: CupertinoIcons.trash_fill,
    );
    if (confirmed == true && mounted) {
      await OfflineService().cancelPlaylistDownload(_album!.id);
      await OfflineService().deletePlaylistDownloads(_songs);
    }
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
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              isStarred
                  ? 'Eliminado de álbumes favoritos'
                  : 'Agregado a álbumes favoritos',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Revert on failure
      setState(() {
        _album!.starred = isStarred;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al actualizar favoritos'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildStarButton(BuildContext context, bool isDark) {
    if (_album == null) return const SizedBox.shrink();
    return Consumer<LibraryProvider>(
      builder: (context, libraryProvider, _) {
        final isStarred = _album!.starred == true || libraryProvider.isAlbumStarred(_album!.id);
        
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
          onPressed: _toggleLike,
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
      onPressed: () => _showAlbumOptionsMenu(context),
    );
  }

  Future<void> _addAlbumToQueue() async {
    if (_songs.isEmpty) return;
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    playerProvider.addAllToQueue(_songs);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Álbum "${_album?.name ?? ""}" agregado a la cola'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAlbumOptionsMenu(BuildContext context) {
    if (_album == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subtitleColor = isDark ? Colors.white60 : Colors.black54;
    final dividerColor = isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08);
    final cover = _resolvedCoverArt;
    final isStarred = _album!.starred == true;

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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: (cover != null && cover.isNotEmpty)
                            ? (cover.startsWith('http')
                                ? CachedNetworkImage(
                                    imageUrl: cover,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => _buildFallbackCover(),
                                  )
                                : isLocalFilePath(cover)
                                    ? Image.file(
                                        File(cover),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _buildFallbackCover(),
                                      )
                                    : AlbumArtwork(coverArt: cover, size: 50))
                            : _buildFallbackCover(),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _album!.name,
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
                            '${_album!.artist ?? AppLocalizations.of(context)!.unknownArtist} • ${_songs.length} ${_songs.length == 1 ? "canción" : "canciones"}',
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
              Divider(height: 1, color: dividerColor),
              ListTile(
                leading: const Icon(Icons.queue_music_rounded, color: AppTheme.appleMusicRed),
                title: Text(
                  AppLocalizations.of(context)?.addToQueue ?? 'Agregar a la cola',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _addAlbumToQueue();
                },
              ),
              ListTile(
                leading: Icon(
                  _allDownloaded ? Icons.cloud_done : CupertinoIcons.cloud_download,
                  color: _allDownloaded ? Colors.green : AppTheme.appleMusicRed,
                ),
                title: Text(
                  _allDownloaded ? 'Eliminar descargas del álbum' : 'Descargar álbum',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  if (_allDownloaded) {
                    _removeDownloads();
                  } else {
                    _downloadAlbum();
                  }
                },
              ),
              ListTile(
                leading: const Icon(CupertinoIcons.play_circle, color: AppTheme.appleMusicRed),
                title: Text(
                  'Reproducir álbum',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _playAll(shuffle: false);
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
                  _playAll(shuffle: true);
                },
              ),
              if (_album!.artist != null && _album!.artist!.isNotEmpty)
                ListTile(
                  leading: const Icon(CupertinoIcons.person_crop_circle, color: AppTheme.appleMusicRed),
                  title: Text(
                    'Ir al artista (${_album!.artist})',
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    NavigationHelper.push(
                      context,
                      ArtistScreen(
                        artistId: _album!.artistId ?? _album!.artist!,
                        artist: Artist(
                          id: _album!.artistId ?? _album!.artist!,
                          name: _album!.artist!,
                        ),
                      ),
                    );
                  },
                ),
              ListTile(
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
                  _toggleLike();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackCover() {
    return Container(
      color: AppTheme.appleMusicRed.withValues(alpha: 0.15),
      child: const Center(
        child: Icon(
          Icons.album_rounded,
          size: 26,
          color: AppTheme.appleMusicRed,
        ),
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

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                elevation: 0,
                scrolledUnderElevation: 2,
                backgroundColor: isDark ? AppTheme.darkBackground : Colors.white,
                expandedHeight: ScreenHelper.isSmallScreen(context) ? 320 : 390,
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
                      color: isDark ? Colors.white : Colors.black,
                      size: 20,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  background: ValueListenableBuilder<Set<String>>(
                    valueListenable: OfflineService().downloadedPlaylistIds,
                    builder: (context, downloaded, _) {
                      final allDownloaded = _album != null && downloaded.contains(_album!.id);
                      final cover = _resolvedCoverArt;
                      final artworkSize = ScreenHelper.isSmallScreen(context) ? 210.0 : 270.0;

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          // 1. Ambient Blurred Backdrop
                          if (cover != null && cover.isNotEmpty)
                            Positioned.fill(
                              child: Opacity(
                                opacity: isDark ? 0.32 : 0.18,
                                child: ImageFiltered(
                                  imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
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
                                          : AlbumArtwork(
                                              coverArt: cover,
                                              size: 300,
                                            ),
                                ),
                              ),
                            ),

                          // 2. Gradient Fade to background
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    (isDark ? AppTheme.darkBackground : Colors.white).withValues(alpha: 0.65),
                                    isDark ? AppTheme.darkBackground : Colors.white,
                                  ],
                                  stops: const [0.0, 0.70, 1.0],
                                ),
                              ),
                            ),
                          ),

                          // 3. Main Elevated 3D Album Artwork
                          Center(
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: MediaQuery.of(context).padding.top + 30,
                                bottom: 20,
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: artworkSize,
                                    height: artworkSize,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: isDark ? 0.14 : 0.20),
                                        width: 1.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: isDark ? 0.60 : 0.22),
                                          blurRadius: 30,
                                          offset: const Offset(0, 15),
                                          spreadRadius: -4,
                                        ),
                                        BoxShadow(
                                          color: AppTheme.appleMusicRed.withValues(alpha: isDark ? 0.18 : 0.08),
                                          blurRadius: 36,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: AlbumArtwork(
                                        coverArt: cover,
                                        size: artworkSize,
                                        borderRadius: 18,
                                      ),
                                    ),
                                  ),

                                  // Floating Downloaded Badge
                                  if (allDownloaded)
                                    Positioned(
                                      bottom: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF1E1E24).withValues(alpha: 0.90)
                                              : Colors.white.withValues(alpha: 0.90),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          CupertinoIcons.checkmark_seal_fill,
                                          color: Colors.greenAccent,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                actions: [
                  _buildStarButton(context, isDark),
                  _buildMoreButton(context, isDark),
                  const SizedBox(width: 4),
                ],
              ),

              // Header Metadata & Controls
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 6),
                      // Album Name
                      Text(
                        _album!.name,
                        style: TextStyle(
                          fontSize: ScreenHelper.isSmallScreen(context) ? 23 : 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          color: isDark ? Colors.white : Colors.black87,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Artist with Clickable Navigation
                      MultiArtistWidget(
                        artists: _album!.artistParticipants,
                        artistFallback: _album!.artist ??
                            AppLocalizations.of(context)!.unknownArtist,
                        artistIdFallback: _album!.artistId,
                        style: TextStyle(
                          color: AppTheme.appleMusicRed,
                          fontSize: ScreenHelper.isSmallScreen(context) ? 16 : 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Metadata Capsules / Pills
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (_album!.year != null)
                            _buildMetaBadge('${_album!.year}', isDark),
                          if (_album!.genre != null && _album!.genre!.isNotEmpty)
                            _buildMetaBadge(_album!.genre!.toUpperCase(), isDark),
                          _buildMetaBadge(
                            '${_songs.length} ${_songs.length == 1 ? "canción" : "canciones"}',
                            isDark,
                          ),
                          if (totalDuration > 0)
                            _buildMetaBadge(
                              hours > 0 ? '$hours h $minutes min' : '$minutes min',
                              isDark,
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // Primary Play & Shuffle Buttons
                      Row(
                        children: [
                          Expanded(
                            child: _PlayButton(
                              icon: CupertinoIcons.play_fill,
                              label: AppLocalizations.of(context)!.play,
                              isPrimary: true,
                              onTap: () => _playAll(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _PlayButton(
                              icon: CupertinoIcons.shuffle,
                              label: AppLocalizations.of(context)!.shuffle,
                              isPrimary: false,
                              onTap: () => _playAll(shuffle: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Quick Action Bar (Download, Add to Queue, Star, More)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildQuickActionButton(
                            icon: _album!.starred == true
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            iconColor: _album!.starred == true ? Colors.amber : (isDark ? Colors.white70 : Colors.black54),
                            tooltip: _album!.starred == true ? 'En favoritos' : 'Favorito',
                            onTap: _toggleLike,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 14),
                          _buildQuickActionButton(
                            icon: _allDownloaded
                                ? Icons.cloud_done_rounded
                                : (_isQueued ? CupertinoIcons.cloud_download_fill : CupertinoIcons.cloud_download),
                            iconColor: _allDownloaded
                                ? Colors.green
                                : (_isQueued ? AppTheme.appleMusicRed : (isDark ? Colors.white70 : Colors.black54)),
                            tooltip: _allDownloaded ? 'Descargado' : 'Descargar álbum',
                            onTap: () {
                              if (_allDownloaded) {
                                _removeDownloads();
                              } else {
                                _downloadAlbum();
                              }
                            },
                            isDark: isDark,
                          ),
                          const SizedBox(width: 14),
                          _buildQuickActionButton(
                            icon: Icons.queue_music_rounded,
                            iconColor: isDark ? Colors.white70 : Colors.black54,
                            tooltip: 'Agregar a la cola',
                            onTap: _addAlbumToQueue,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 14),
                          _buildQuickActionButton(
                            icon: Icons.more_horiz_rounded,
                            iconColor: isDark ? Colors.white70 : Colors.black54,
                            tooltip: 'Opciones',
                            onTap: () => _showAlbumOptionsMenu(context),
                            isDark: isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Divider(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                        height: 1,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // Tracklist
              SliverFixedExtentList(
                itemExtent: 60.0,
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

              // Album Bottom Footer & Copyright
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 140),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Divider(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                        height: 1,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '${_songs.length} ${_songs.length == 1 ? "canción" : "canciones"} • ${hours > 0 ? "$hours horas " : ""}$minutes minutos',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '℗ ${_album!.year ?? DateTime.now().year} ${_album!.artist ?? "Groovy Cloud Music"}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.black38,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.waveform_path,
                            size: 14,
                            color: AppTheme.appleMusicRed.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Calidad Alta Definición Sin Pérdida (Lossless)',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaBadge(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
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

  Widget _buildQuickActionButton({
    required IconData icon,
    required Color iconColor,
    required String tooltip,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: iconColor, size: 20),
          ),
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _PlayButton({
    required this.icon,
    required this.label,
    this.isPrimary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isPrimary) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFFFA243C), Color(0xFFFF3C58)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFA243C).withValues(alpha: 0.38),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final btnBg = isDark ? const Color(0xFF24242A) : const Color(0xFFEBEBF0);
    return Material(
      color: btnBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
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
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
