import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../utils/navigation_helper.dart';
import 'album_screen.dart';
import 'artists_screen.dart';
import 'albums_screen.dart';
import 'all_songs_screen.dart';
import 'playlists_screen.dart';
import 'downloads_screen.dart';
import 'favorites_screen.dart';
import 'genres_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'account_screen.dart';
import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../widgets/album_artwork.dart';
import '../widgets/playlist_import_modal.dart';

class _LibraryCategoryItem {
  final String id;
  final String title;
  final IconData icon;
  final Widget Function() screenBuilder;
  bool isVisible;

  _LibraryCategoryItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.screenBuilder,
  }) : isVisible = true;
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  static const String _keyCategoryOrder = 'library_category_order_v2';
  static const String _keyHiddenCategories = 'library_hidden_categories_v2';

  bool _isEditing = false;
  List<_LibraryCategoryItem> _categories = [];

  @override
  void initState() {
    super.initState();
    _initCategories();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadCategoryPreferences();
      if (!mounted) return;
      final libraryProvider = Provider.of<LibraryProvider>(context, listen: false);
      await libraryProvider.ensureLibraryLoaded();
      await Future.wait([
        libraryProvider.loadPlaylists(),
        libraryProvider.loadArtists(),
        libraryProvider.loadRecentAlbums(),
      ]);
    });
  }

  void _initCategories() {
    _categories = [
      _LibraryCategoryItem(
        id: 'playlists',
        title: 'Listas de reproducción',
        icon: CupertinoIcons.music_note_list,
        screenBuilder: () => const PlaylistsScreen(),
      ),
      _LibraryCategoryItem(
        id: 'artists',
        title: 'Artistas',
        icon: CupertinoIcons.mic,
        screenBuilder: () => const ArtistsScreen(),
      ),
      _LibraryCategoryItem(
        id: 'albums',
        title: 'Álbumes',
        icon: CupertinoIcons.square_stack_3d_down_right,
        screenBuilder: () => const AlbumsScreen(),
      ),
      _LibraryCategoryItem(
        id: 'songs',
        title: 'Canciones',
        icon: CupertinoIcons.music_note,
        screenBuilder: () => const AllSongsScreen(),
      ),
      _LibraryCategoryItem(
        id: 'downloads',
        title: 'Descargas',
        icon: CupertinoIcons.arrow_down_circle,
        screenBuilder: () => const DownloadsScreen(),
      ),
      _LibraryCategoryItem(
        id: 'favorites',
        title: 'Favoritos',
        icon: CupertinoIcons.star_fill,
        screenBuilder: () => const FavoritesScreen(),
      ),
      _LibraryCategoryItem(
        id: 'genres',
        title: 'Géneros',
        icon: CupertinoIcons.guitars,
        screenBuilder: () => const GenresScreen(),
      ),
      _LibraryCategoryItem(
        id: 'history',
        title: 'Historial',
        icon: CupertinoIcons.time,
        screenBuilder: () => const HistoryScreen(),
      ),
    ];
  }

  Future<void> _loadCategoryPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrder = prefs.getStringList(_keyCategoryOrder);
      final hiddenSet = prefs.getStringList(_keyHiddenCategories)?.toSet() ?? {};

      if (savedOrder != null && savedOrder.isNotEmpty) {
        final byId = {for (final c in _categories) c.id: c};
        final reordered = <_LibraryCategoryItem>[];
        for (final id in savedOrder) {
          if (byId.containsKey(id)) {
            final item = byId.remove(id)!;
            item.isVisible = !hiddenSet.contains(id);
            reordered.add(item);
          }
        }
        for (final remaining in byId.values) {
          remaining.isVisible = !hiddenSet.contains(remaining.id);
          reordered.add(remaining);
        }
        if (mounted) {
          setState(() {
            _categories = reordered;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            for (final c in _categories) {
              c.isVisible = !hiddenSet.contains(c.id);
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _saveCategoryPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final order = _categories.map((c) => c.id).toList();
      final hidden = _categories.where((c) => !c.isVisible).map((c) => c.id).toList();
      await prefs.setStringList(_keyCategoryOrder, order);
      await prefs.setStringList(_keyHiddenCategories, hidden);
    } catch (_) {}
  }

  void _navigate(BuildContext context, Widget screen) {
    NavigationHelper.push(context, screen);
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final controller = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.newPlaylist),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.playlistName,
            ),
            autofocus: true,
            onSubmitted: (_) async {
              final name = controller.text.trim();
              if (name.isNotEmpty && !isSubmitting) {
                setState(() => isSubmitting = true);
                final libraryProvider = Provider.of<LibraryProvider>(
                  context,
                  listen: false,
                );
                await libraryProvider.createPlaylist(name);
                await libraryProvider.refresh();
                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)!.playlistCreated(name)),
                    ),
                  );
                }
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final name = controller.text.trim();
                      if (name.isNotEmpty) {
                        setState(() => isSubmitting = true);
                        final libraryProvider = Provider.of<LibraryProvider>(
                          context,
                          listen: false,
                        );
                        await libraryProvider.createPlaylist(name);
                        await libraryProvider.refresh();
                        if (dialogCtx.mounted) {
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(AppLocalizations.of(context)!.playlistCreated(name)),
                            ),
                          );
                        }
                      }
                    },
              child: Text(AppLocalizations.of(context)!.create),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white12 : Colors.black12;

    return Scaffold(
      backgroundColor: isDark
          ? (NavigationHelper.isDesktop
              ? const Color(0xFF121212)
              : AppTheme.darkBackground)
          : Colors.white,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // 1. Top App Bar with Red Action Buttons
          SliverAppBar(
            pinned: true,
            floating: true,
            expandedHeight: 56,
            backgroundColor: isDark
                ? (NavigationHelper.isDesktop
                    ? const Color(0xFF121212)
                    : AppTheme.darkBackground)
                : Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: Icon(
                  CupertinoIcons.square_arrow_down,
                  color: AppTheme.appleMusicRed,
                  size: 22,
                ),
                tooltip: 'Importar playlist',
                onPressed: () => PlaylistImportModal.show(context),
              ),
              IconButton(
                icon: Icon(
                  Icons.playlist_add,
                  color: AppTheme.appleMusicRed,
                  size: 26,
                ),
                tooltip: 'Nueva playlist',
                onPressed: () => _showCreatePlaylistDialog(context),
              ),
              PopupMenuButton<String>(
                icon: Icon(
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
                  } else if (value == 'import_playlist') {
                    PlaylistImportModal.show(context);
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
                    value: 'import_playlist',
                    height: 44,
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.square_arrow_down, color: AppTheme.appleMusicRed, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Importar playlist',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
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

          // 2. Large Apple Music Header ("Biblioteca" + "Editar" / "Listo")
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
                    onPressed: () {
                      setState(() {
                        if (_isEditing) {
                          _saveCategoryPreferences();
                          _isEditing = false;
                        } else {
                          _isEditing = true;
                        }
                      });
                    },
                    child: Text(
                      _isEditing ? 'Listo' : 'Editar',
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

          // 3. Apple Music Navigation Categories (Normal or Edit Mode)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  Divider(height: 1, color: dividerColor),
                  if (_isEditing)
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _categories.length,
                      buildDefaultDragHandles: false,
                      onReorderItem: (oldIndex, newIndex) {
                        setState(() {
                          final item = _categories.removeAt(oldIndex);
                          _categories.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        return Container(
                          key: ValueKey('edit_cat_${cat.id}'),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: dividerColor, width: 0.5),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                // Checkbox / Toggle visibility
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      cat.isVisible = !cat.isVisible;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 12.0),
                                    child: Icon(
                                      cat.isVisible
                                          ? CupertinoIcons.checkmark_circle_fill
                                          : CupertinoIcons.circle,
                                      color: cat.isVisible
                                          ? AppTheme.appleMusicRed
                                          : (isDark ? Colors.white30 : Colors.black26),
                                      size: 24,
                                    ),
                                  ),
                                ),
                                Icon(
                                  cat.icon,
                                  color: cat.isVisible
                                      ? AppTheme.appleMusicRed
                                      : (isDark ? Colors.white30 : Colors.black38),
                                  size: 22,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    cat.title,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w400,
                                      color: cat.isVisible
                                          ? (isDark ? Colors.white : Colors.black87)
                                          : (isDark ? Colors.white38 : Colors.black38),
                                    ),
                                  ),
                                ),
                                // Drag handle
                                ReorderableDragStartListener(
                                  index: index,
                                  child: Container(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Icon(
                                      CupertinoIcons.bars,
                                      color: isDark ? Colors.white38 : Colors.black38,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  else
                    ..._categories
                        .where((cat) => cat.isVisible)
                        .map(
                          (cat) => _AppleMusicLibraryTile(
                            icon: cat.icon,
                            title: cat.title,
                            dividerColor: dividerColor,
                            onTap: () => _navigate(context, cat.screenBuilder()),
                          ),
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
                            size: 64,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Tu biblioteca está vacía',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.76,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 20,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final album = albums[index];
                      final artistName = album.artist?.isNotEmpty == true
                          ? album.artist!
                          : 'Artista desconocido';

                      return InkWell(
                        onTap: () {
                          NavigationHelper.push(
                            context,
                            AlbumScreen(albumId: album.id, album: album),
                          );
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Square Album Artwork
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
