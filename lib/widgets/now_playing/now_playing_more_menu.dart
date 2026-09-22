import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/song.dart';
import '../../models/album.dart';
import '../../models/artist.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../screens/song_credits_screen.dart';
import '../../screens/album_screen.dart';
import '../../screens/artist_screen.dart';
import '../../services/youtube_service.dart';
import '../../services/offline_service.dart';
import '../../services/theme_service.dart';
import '../../utils/album_sanitizer.dart';
import 'add_to_menu.dart';
import '../groovy_confirm_dialog.dart';

class NowPlayingMoreMenu extends StatefulWidget {
  final Song? song;
  final ImageProvider? imageProvider;
  final VoidCallback? onNavigateToLyrics;

  const NowPlayingMoreMenu({
    super.key,
    this.song,
    this.imageProvider,
    this.onNavigateToLyrics,
  });

  @override
  State<NowPlayingMoreMenu> createState() => _NowPlayingMoreMenuState();
}

class _NowPlayingMoreMenuState extends State<NowPlayingMoreMenu> {
  static const Color _appleRed = Color(0xFFFA2D48);
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  void _openPlaylistPicker(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) => PlaylistSelectionBottomSheet(song: song),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final currentSong = widget.song ?? playerProvider.currentSong;

    if (currentSong == null) {
      return const SizedBox.shrink();
    }

    final themeService = Provider.of<ThemeService>(context, listen: false);
    final platformDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final isDark = themeService.themeMode == ThemeMode.dark ||
        (themeService.themeMode == ThemeMode.system && platformDark);

    final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subtitleColor = isDark ? Colors.white60 : Colors.black54;
    final dividerColor = isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08);

    final libraryProvider = Provider.of<LibraryProvider>(context, listen: false);
    final isStarred = libraryProvider.isSongStarred(currentSong.id) || (currentSong.starred ?? false);
    final isInLibrary = libraryProvider.isSongInLibrary(currentSong.id);
    final offlineService = OfflineService();
    final isDownloaded = offlineService.isSongDownloaded(currentSong.id);

    final youtubeService = Provider.of<YoutubeService>(context, listen: false);
    final coverUrl = currentSong.coverArt != null
        ? youtubeService.getCoverArtUrl(currentSong.coverArt, size: 300)
        : null;

    final ImageProvider? effectiveImage = widget.imageProvider ??
        (coverUrl != null
            ? CachedNetworkImageProvider(coverUrl)
            : null);

    return RepaintBoundary(
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

            // Header (Artwork Thumbnail + Title + Artist + Album)
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
                      child: effectiveImage != null
                          ? Image(
                              image: effectiveImage,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[300],
                                child: const Icon(CupertinoIcons.music_note, size: 24, color: Colors.grey),
                              ),
                            )
                          : Container(
                              color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[300],
                              child: const Icon(CupertinoIcons.music_note, size: 24, color: Colors.grey),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentSong.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currentSong.artist ?? 'Artista desconocido',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _appleRed,
                          ),
                        ),
                        if (currentSong.album != null && currentSong.album!.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            currentSong.album!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: subtitleColor,
                            ),
                          ),
                        ],
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
            _buildMenuItem(
              icon: isInLibrary ? CupertinoIcons.minus : CupertinoIcons.add,
              title: isInLibrary ? 'Eliminar de la biblioteca' : 'Agregar a la biblioteca',
              textColor: textColor,
              onTap: () async {
                Navigator.of(context).pop();
                final messenger = ScaffoldMessenger.of(context);
                if (isInLibrary) {
                  await libraryProvider.removeSongFromLibrary(currentSong);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Eliminada de la biblioteca'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                } else {
                  await libraryProvider.addSongToLibrary(currentSong);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Agregada a la biblioteca'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),

            // Reproducir a continuación y Añadir a la cola (cuando se abre para una canción específica)
            if (widget.song != null) ...[
              _buildMenuItem(
                icon: Icons.play_arrow_rounded,
                title: 'Reproducir a continuación',
                textColor: textColor,
                onTap: () {
                  Navigator.of(context).pop();
                  playerProvider.addToQueueNext(currentSong);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Se reproducirá a continuación'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              _buildMenuItem(
                icon: Icons.queue_music_rounded,
                title: 'Añadir a la cola',
                textColor: textColor,
                onTap: () {
                  Navigator.of(context).pop();
                  playerProvider.addAllToQueue([currentSong]);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Añadida a la cola'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],

            // 2. Descargar canción para modo offline
            if (_isDownloading)
              _buildMenuItem(
                iconWidget: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    value: _downloadProgress > 0 ? _downloadProgress : null,
                    strokeWidth: 2.2,
                    color: _appleRed,
                  ),
                ),
                title: 'Descargando... ${(_downloadProgress * 100).toInt()}%',
                textColor: textColor,
                onTap: () {},
              )
            else if (isDownloaded)
              _buildMenuItem(
                icon: CupertinoIcons.arrow_down_circle_fill,
                iconColor: Colors.green,
                title: 'Descargada (Eliminar descarga)',
                textColor: textColor,
                onTap: () async {
                  final nav = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  final confirm = await GroovyConfirmDialog.show(
                    context,
                    title: 'Eliminar descarga',
                    message:
                        '¿Deseas eliminar "${currentSong.title}" de tus descargas sin conexión?',
                    confirmLabel: 'Eliminar',
                    cancelLabel: 'Cancelar',
                    isDestructive: true,
                    icon: CupertinoIcons.trash_fill,
                  );
                  if (confirm == true) {
                    await offlineService.deleteSong(currentSong.id);
                    if (mounted) {
                      nav.pop();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Descarga eliminada'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                },
              )
            else
              _buildMenuItem(
                icon: CupertinoIcons.arrow_down_circle,
                title: 'Descargar canción',
                textColor: textColor,
                onTap: () async {
                  setState(() {
                    _isDownloading = true;
                    _downloadProgress = 0.0;
                  });
                  final nav = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  final success = await offlineService.downloadSong(
                    currentSong,
                    youtubeService,
                    onProgress: (p) {
                      if (mounted) {
                        setState(() => _downloadProgress = p);
                      }
                    },
                  );
                  if (mounted) {
                    setState(() => _isDownloading = false);
                    nav.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Descargada para modo offline (audio y letras sincronizadas)'
                              : 'No se pudo descargar la canción',
                        ),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                },
              ),

            // 3. Agregar a una playlist...
            _buildMenuItem(
              icon: Icons.playlist_add_rounded,
              title: 'Agregar a una playlist...',
              textColor: textColor,
              onTap: () {
                Navigator.of(context).pop();
                _openPlaylistPicker(context, currentSong);
              },
            ),

            // 3. Ver créditos
            _buildMenuItem(
              icon: CupertinoIcons.info_circle,
              title: 'Ver créditos',
              textColor: textColor,
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (ctx) => SongCreditsScreen(
                      song: currentSong,
                      imageProvider: effectiveImage,
                      onNavigateToLyrics: widget.onNavigateToLyrics,
                    ),
                  ),
                );
              },
            ),

            // 4. Ir al álbum
            _buildMenuItem(
              icon: Icons.album_rounded,
              title: 'Ir al álbum',
              textColor: textColor,
              onTap: () {
                Navigator.of(context).pop();
                final cleanAlb = AlbumSanitizer.cleanTitle(currentSong.album);
                final effectiveAlbumId = currentSong.albumId ??
                    (cleanAlb.isNotEmpty
                        ? cleanAlb
                        : '${currentSong.title} ${currentSong.artist ?? ""}');
                final alb = (cleanAlb.isNotEmpty)
                    ? Album(
                        id: effectiveAlbumId,
                        name: cleanAlb,
                        artist: currentSong.artist,
                        coverArt: currentSong.coverArt,
                      )
                    : null;
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (ctx) => AlbumScreen(
                      albumId: effectiveAlbumId,
                      album: alb,
                      song: currentSong,
                    ),
                  ),
                );
              },
            ),

            // 5. Ir al artista
            _buildMenuItem(
              icon: Icons.person_rounded,
              title: 'Ir al artista',
              textColor: textColor,
              onTap: () {
                Navigator.of(context).pop();
                final artistId = currentSong.artistId ?? currentSong.artist ?? '';
                if (artistId.isNotEmpty) {
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (ctx) => ArtistScreen(
                        artistId: artistId,
                        artist: Artist(
                          id: artistId,
                          name: currentSong.artist ?? artistId,
                          coverArt: currentSong.coverArt,
                        ),
                      ),
                    ),
                  );
                }
              },
            ),

            // 6. Agregar a Favoritos / Eliminar de Favoritos
            _buildMenuItem(
              icon: isStarred ? CupertinoIcons.star_fill : CupertinoIcons.star,
              title: isStarred ? 'Eliminar de Favoritos' : 'Agregar a Favoritos',
              textColor: textColor,
              onTap: () async {
                Navigator.of(context).pop();
                final messenger = ScaffoldMessenger.of(context);
                final newFav = await libraryProvider.toggleStarSong(currentSong);
                playerProvider.updateSongStarred(currentSong.id, newFav);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(newFav ? 'Agregada a Favoritos' : 'Eliminada de Favoritos'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildMenuItem({
    IconData? icon,
    Widget? iconWidget,
    Color? iconColor,
    required String title,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 13.0),
        child: Row(
          children: [
            iconWidget ?? Icon(icon, color: iconColor ?? _appleRed, size: 24),
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
}
