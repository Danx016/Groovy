import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/album.dart';
import '../providers/library_provider.dart';
import '../theme/app_theme.dart';
import '../utils/navigation_helper.dart';
import '../widgets/album_artwork.dart';
import 'album_screen.dart';

class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  List<Album> _albums = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAlbums() async {
    final libraryProvider = Provider.of<LibraryProvider>(
      context,
      listen: false,
    );

    await libraryProvider.ensureLibraryLoaded();

    final db = libraryProvider.database;
    final localAlbums = await db.getAllAlbums();

    final map = <String, Album>{};
    for (final a in localAlbums) {
      map[a.id] = a;
    }
    for (final a in libraryProvider.cachedAllAlbums) {
      map[a.id] = a;
    }

    final list = map.values.toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (mounted) {
      setState(() {
        _albums = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    List<Album> displayed = _albums;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      displayed = displayed.where((a) {
        return a.name.toLowerCase().contains(q) ||
            (a.artist?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkBackground : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            CupertinoIcons.arrow_left,
            color: AppTheme.appleMusicRed,
            size: 24,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Álbumes',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: CupertinoSearchTextField(
              controller: _searchController,
              placeholder: 'Buscar álbumes',
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.appleMusicRed),
                  )
                : displayed.isEmpty
                    ? Center(
                        child: Text(
                          'No se encontraron álbumes',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black45,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16).copyWith(bottom: 120),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 18.0,
                          crossAxisSpacing: 16.0,
                          childAspectRatio: 0.78,
                        ),
                        itemCount: displayed.length,
                        itemBuilder: (context, index) {
                          final album = displayed[index];
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
                                Text(
                                  album.artist ?? 'Varios Artistas',
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
                      ),
          ),
        ],
      ),
    );
  }
}
