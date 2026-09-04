import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../utils/navigation_helper.dart';
import 'album_screen.dart';
import 'artists_screen.dart';
import 'albums_screen.dart';
import 'all_songs_screen.dart';
import 'playlists_screen.dart';
import 'settings_screen.dart';
import 'account_screen.dart';
import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../widgets/album_artwork.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final libraryProvider = Provider.of<LibraryProvider>(context, listen: false);
      await libraryProvider.ensureLibraryLoaded();
      await libraryProvider.loadPlaylists();
      await libraryProvider.loadArtists();
      await libraryProvider.loadRecentAlbums();
    });
  }

  void _navigate(BuildContext context, Widget screen) {
    NavigationHelper.push(context, screen);
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.newPlaylist),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.playlistName,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final libraryProvider = Provider.of<LibraryProvider>(
                  context,
                  listen: false,
                );
                await libraryProvider.createPlaylist(controller.text);
                await libraryProvider.refresh();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)!.playlistCreated(controller.text)),
                    ),
                  );
                }
              }
            },
            child: Text(AppLocalizations.of(context)!.create),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white12 : Colors.black12;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : Colors.white,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // 1. Top App Bar with Red Action Buttons
          SliverAppBar(
            pinned: true,
            floating: true,
            expandedHeight: 56,
            backgroundColor: isDark ? AppTheme.darkBackground : Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.playlist_add,
                  color: AppTheme.appleMusicRed,
                  size: 26,
                ),
                tooltip: 'Nueva playlist',
                onPressed: () => _showCreatePlaylistDialog(context),
              ),
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
                ],
              ),
              const SizedBox(width: 4),
            ],
          ),

          // 2. Large Apple Music Header ("Biblioteca" + "Editar")
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Biblioteca',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      'Editar',
                      style: TextStyle(
                        color: AppTheme.appleMusicRed,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Apple Music Navigation Categories (Playlists, Artistas, Álbumes, Canciones)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  Divider(height: 1, color: dividerColor),

                  // 1. Playlists
                  _AppleMusicLibraryTile(
                    icon: CupertinoIcons.music_note_list,
                    title: 'Playlists',
                    dividerColor: dividerColor,
                    onTap: () => _navigate(context, const PlaylistsScreen()),
                  ),

                  // 2. Artistas
                  _AppleMusicLibraryTile(
                    icon: CupertinoIcons.mic,
                    title: 'Artistas',
                    dividerColor: dividerColor,
                    onTap: () => _navigate(context, const ArtistsScreen()),
                  ),

                  // 3. Álbumes
                  _AppleMusicLibraryTile(
                    icon: CupertinoIcons.square_stack_3d_down_right,
                    title: 'Álbumes',
                    dividerColor: dividerColor,
                    onTap: () => _navigate(context, const AlbumsScreen()),
                  ),

                  // 4. Canciones
                  _AppleMusicLibraryTile(
                    icon: CupertinoIcons.music_note,
                    title: 'Canciones',
                    dividerColor: dividerColor,
                    onTap: () => _navigate(context, const AllSongsScreen()),
                  ),
                ],
              ),
            ),
          ),

          // 4. Section Title: "Agregadas recientemente"
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 32.0, 16.0, 16.0),
              child: Text(
                'Agregadas recientemente',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),

          // 5. Grid of Recently Added Albums / Songs
          Consumer<LibraryProvider>(
            builder: (context, libraryProvider, _) {
              List<Album> albums = List<Album>.from(
                libraryProvider.isLocalOnlyMode
                    ? libraryProvider.cachedAllAlbums
                    : (libraryProvider.recentAlbums.isNotEmpty
                        ? libraryProvider.recentAlbums
                        : libraryProvider.cachedAllAlbums),
              );

              // Sort by created descending so the newest items are first
              albums.sort((a, b) {
                final aDate = a.created ?? DateTime.fromMillisecondsSinceEpoch(0);
                final bDate = b.created ?? DateTime.fromMillisecondsSinceEpoch(0);
                return bDate.compareTo(aDate);
              });

              if (albums.isEmpty && libraryProvider.cachedAllSongs.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.music_albums,
                            size: 48,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No hay música en tu biblioteca',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Agrega canciones, álbumes o playlists usando el menú (···) de cualquier canción.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black45,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              if (albums.isEmpty && libraryProvider.cachedAllSongs.isNotEmpty) {
                final songs = libraryProvider.cachedAllSongs.take(20).toList();
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 18.0,
                      crossAxisSpacing: 16.0,
                      childAspectRatio: 0.78,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final song = songs[index];
                        return GestureDetector(
                          onTap: () {
                            final player = Provider.of<PlayerProvider>(context, listen: false);
                            player.playSong(song);
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: AlbumArtwork(
                                    coverArt: song.coverArt,
                                    size: double.infinity,
                                    borderRadius: 10,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                song.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                song.artist ?? 'Artista desconocido',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
                      childCount: songs.length,
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 18.0,
                    crossAxisSpacing: 16.0,
                    childAspectRatio: 0.78,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final album = albums[index];
                      final artistName = album.artistParticipants?.isNotEmpty == true
                          ? album.artistParticipants!.map((r) => r.name).join(', ')
                          : (album.artist ?? 'Varios Artistas');

                      return GestureDetector(
                        onTap: () {
                          NavigationHelper.push(
                            context,
                            AlbumScreen(albumId: album.id, album: album),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Square Album Cover
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: AlbumArtwork(
                                  coverArt: album.coverArt,
                                  size: double.infinity,
                                  borderRadius: 10,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Album Name
                            Text(
                              album.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),

                            // Artist Name
                            Text(
                              artistName,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: albums.length,
                  ),
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

class _AppleMusicLibraryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color dividerColor;
  final VoidCallback onTap;

  const _AppleMusicLibraryTile({
    required this.icon,
    required this.title,
    required this.dividerColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14.0),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: AppTheme.appleMusicRed,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.3,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: dividerColor, indent: 40),
        ],
      ),
    );
  }
}
