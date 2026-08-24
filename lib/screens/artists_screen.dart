import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/artist.dart';
import '../providers/library_provider.dart';
import '../services/subsonic_service.dart';
import '../theme/app_theme.dart';
import '../utils/navigation_helper.dart';
import '../widgets/album_artwork.dart';
import 'artist_screen.dart';

class ArtistsScreen extends StatefulWidget {
  const ArtistsScreen({super.key});

  @override
  State<ArtistsScreen> createState() => _ArtistsScreenState();
}

class _ArtistsScreenState extends State<ArtistsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final libraryProvider = Provider.of<LibraryProvider>(context);
    final subsonicService = Provider.of<SubsonicService>(context, listen: false);

    List<Artist> artists = libraryProvider.artists;
    if (_searchQuery.isNotEmpty) {
      artists = artists
          .where((a) => a.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
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
          'Artistas',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: CupertinoSearchTextField(
              controller: _searchController,
              placeholder: 'Buscar artistas',
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
          ),
          Expanded(
            child: artists.isEmpty
                ? Center(
                    child: Text(
                      'No se encontraron artistas',
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: artists.length,
                    separatorBuilder: (context, index) => Divider(
                      indent: 72,
                      height: 1,
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                    itemBuilder: (context, index) {
                      final artist = artists[index];
                      return ListTile(
                        leading: ClipOval(
                          child: Container(
                            width: 48,
                            height: 48,
                            color: isDark ? Colors.white12 : Colors.black12,
                            child: (artist.coverArt != null)
                                ? AlbumArtwork(
                                    coverArt: artist.coverArt,
                                    size: 48,
                                    borderRadius: 24,
                                  )
                                : Icon(
                                    CupertinoIcons.person_solid,
                                    color: isDark ? Colors.white54 : Colors.black45,
                                    size: 24,
                                  ),
                          ),
                        ),
                        title: Text(
                          artist.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: artist.albumCount != null
                            ? Text(
                                '${artist.albumCount} ${artist.albumCount == 1 ? 'álbum' : 'álbumes'}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              )
                            : null,
                        trailing: const Icon(
                          CupertinoIcons.chevron_forward,
                          size: 16,
                          color: Colors.grey,
                        ),
                        onTap: () {
                          NavigationHelper.push(
                            context,
                            ArtistScreen(artistId: artist.id),
                          );
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
