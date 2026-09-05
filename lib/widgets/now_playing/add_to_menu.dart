import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/models.dart';
import '../../services/youtube_service.dart';
import '../../providers/library_provider.dart';
import '../../l10n/app_localizations.dart';

class AddToMenu extends StatelessWidget {
  final Song song;
  final ImageProvider? coverProvider;

  const AddToMenu({
    super.key,
    required this.song,
    this.coverProvider,
  });

  @override
  Widget build(BuildContext context) {
    final libraryProvider = Provider.of<LibraryProvider>(context);
    final inLibSong = libraryProvider.cachedAllSongs.firstWhere(
      (s) => s.id == song.id,
      orElse: () => song,
    );
    final isStarred = inLibSong.starred ?? (song.starred ?? false);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(bottom: 32, top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 24),

          // Header (Cover, Title, Artist)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 56,
                    height: 56,
                    color: Colors.grey.withValues(alpha: 0.2),
                    child: coverProvider != null
                        ? Image(image: coverProvider!, fit: BoxFit.cover)
                        : const Icon(Icons.music_note, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song.artist ?? AppLocalizations.of(context)!.unknownArtist,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.black54,
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
          
          const SizedBox(height: 16),
          Divider(color: Colors.grey.withValues(alpha: 0.2)),
          
          // Menu Options
          ListTile(
            leading: const Icon(Icons.playlist_add_rounded),
            title: Text(AppLocalizations.of(context)!.addToPlaylist),
            onTap: () {
              Navigator.of(context).pop();
              _showPlaylistSelector(context, song);
            },
          ),
          ListTile(
            leading: const Icon(Icons.library_add_check_rounded),
            title: Text(AppLocalizations.of(context)!.addToLibrary),
            onTap: () async {
              Navigator.of(context).pop();
              final lib = Provider.of<LibraryProvider>(context, listen: false);
              await lib.addSongToLibrary(song);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Añadida a tu Biblioteca (Canciones, Artistas y Álbumes)'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: Icon(isStarred ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isStarred ? Colors.redAccent : null),
            title: Text(isStarred ? AppLocalizations.of(context)!.removeFromFavorites : AppLocalizations.of(context)!.addToFavorites),
            onTap: () async {
              Navigator.of(context).pop();
              final lib = Provider.of<LibraryProvider>(context, listen: false);
              final newFav = await lib.toggleStarSong(song);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(newFav ? 'Añadida a Canciones que te gustan' : AppLocalizations.of(context)!.removeFromFavorites),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showPlaylistSelector(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) => PlaylistSelectionBottomSheet(song: song),
    );
  }
}

class PlaylistSelectionBottomSheet extends StatefulWidget {
  final Song song;

  const PlaylistSelectionBottomSheet({super.key, required this.song});

  @override
  State<PlaylistSelectionBottomSheet> createState() => _PlaylistSelectionBottomSheetState();
}

class _PlaylistSelectionBottomSheetState extends State<PlaylistSelectionBottomSheet> {
  List<Playlist>? _playlists;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    final youtubeService = Provider.of<YoutubeService>(context, listen: false);
    try {
      final playlists = await youtubeService.getPlaylists();
      if (mounted) {
        setState(() {
          _playlists = playlists;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorLoadingPlaylists(e.toString()))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(bottom: 32, top: 16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.selectPlaylist,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            )
          else if (_playlists == null || _playlists!.isEmpty)
             Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(AppLocalizations.of(context)!.noPlaylists),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _playlists!.length,
                itemBuilder: (context, index) {
                  final playlist = _playlists![index];
                  return ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: playlist.coverArt != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: CachedNetworkImage(
                                imageUrl: Provider.of<YoutubeService>(context, listen: false)
                                    .getCoverArtUrl(playlist.coverArt!, size: 100),
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => const Icon(Icons.queue_music_rounded, color: Colors.grey),
                              ),
                            )
                          : const Icon(Icons.queue_music_rounded, color: Colors.grey),
                    ),
                    title: Text(playlist.name),
                    subtitle: Text(AppLocalizations.of(context)!.songsCount(playlist.songCount ?? 0)),
                    onTap: () async {
                      Navigator.of(context).pop();
                      final youtubeService = Provider.of<YoutubeService>(context, listen: false);

                      // Check if song already exists in the playlist
                      bool isDuplicate = false;
                      try {
                        final fullPlaylist =
                            await youtubeService.getPlaylist(playlist.id);
                        final existingSongs =
                            fullPlaylist.songs ?? playlist.songs ?? [];
                        isDuplicate = existingSongs.any(
                          (s) =>
                              s.id == widget.song.id ||
                              (s.title.trim().toLowerCase() ==
                                      widget.song.title.trim().toLowerCase() &&
                                  (s.artist ?? '').trim().toLowerCase() ==
                                      (widget.song.artist ?? '').trim().toLowerCase()),
                        );
                      } catch (_) {
                        if (playlist.songs != null) {
                          isDuplicate = playlist.songs!.any((s) => s.id == widget.song.id);
                        }
                      }

                      if (isDuplicate) {
                        if (!context.mounted) return;
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Already in playlist'),
                            content: Text(
                              '"${widget.song.title}" is already in "${playlist.name}". Do you still want to add it?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Add anyway'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true) return;
                      }

                      if (!context.mounted) return;
                      try {
                        final libraryProvider = Provider.of<LibraryProvider>(context, listen: false);
                        await libraryProvider.addSongToLibrary(widget.song);

                        try {
                          await youtubeService.updatePlaylist(playlistId: playlist.id, songIdsToAdd: [widget.song.id]);
                        } catch (e) {
                          debugPrint('Playlist sync note: $e');
                        }

                        final currentSongs = List<Song>.from(playlist.songs ?? []);
                        if (!currentSongs.any((s) => s.id == widget.song.id)) {
                          currentSongs.add(widget.song);
                        }
                        final updatedPlaylist = playlist.copyWith(
                          songs: currentSongs,
                          songCount: currentSongs.length,
                        );
                        await libraryProvider.database.insertOrUpdatePlaylist(updatedPlaylist);
                        await libraryProvider.loadPlaylists();

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppLocalizations.of(context)!.addedToPlaylist(widget.song.title, playlist.name))),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                             SnackBar(content: Text(AppLocalizations.of(context)!.errorAddingToPlaylist(e.toString()))),
                          );
                        }
                      }
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
