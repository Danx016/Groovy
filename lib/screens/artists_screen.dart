import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/artist.dart';
import '../providers/library_provider.dart';
import '../services/services.dart';
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LibraryProvider>(context, listen: false).loadArtists();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final libraryProvider = Provider.of<LibraryProvider>(context);

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
                        leading: _ArtistAvatar(
                          artist: artist,
                          isDark: isDark,
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
                            ArtistScreen(artistId: artist.id, artist: artist),
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

class _ArtistAvatar extends StatefulWidget {
  final Artist artist;
  final bool isDark;

  const _ArtistAvatar({
    required this.artist,
    required this.isDark,
  });

  @override
  State<_ArtistAvatar> createState() => _ArtistAvatarState();
}

class _ArtistAvatarState extends State<_ArtistAvatar> {
  Future<String?>? _imageFuture;

  @override
  void initState() {
    super.initState();
    _initFutureIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _ArtistAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artist.name != widget.artist.name) {
      _initFutureIfNeeded();
    }
  }

  void _initFutureIfNeeded() {
    final hasCover = widget.artist.coverArt != null && widget.artist.coverArt!.isNotEmpty;
    if (!hasCover) {
      final cached = ArtistImageService.getCachedArtistImageUrl(widget.artist.name);
      if (cached == null) {
        _imageFuture = ArtistImageService().getArtistImageUrl(widget.artist.name);
      } else {
        _imageFuture = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCover = widget.artist.coverArt != null && widget.artist.coverArt!.isNotEmpty;
    return ClipOval(
      child: Container(
        width: 48,
        height: 48,
        color: widget.isDark ? Colors.white12 : Colors.black12,
        child: hasCover
            ? AlbumArtwork(
                coverArt: widget.artist.coverArt,
                size: 48,
                borderRadius: 24,
              )
            : _buildOnlineImage(),
      ),
    );
  }

  Widget _buildOnlineImage() {
    final cached = ArtistImageService.getCachedArtistImageUrl(widget.artist.name);
    if (cached != null && cached.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: cached,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _buildFallbackIcon(),
      );
    }

    return FutureBuilder<String?>(
      future: _imageFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
          return CachedNetworkImage(
            imageUrl: snapshot.data!,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _buildFallbackIcon(),
          );
        }
        return _buildFallbackIcon();
      },
    );
  }

  Widget _buildFallbackIcon() {
    return Icon(
      CupertinoIcons.person_solid,
      color: widget.isDark ? Colors.white54 : Colors.black45,
      size: 24,
    );
  }
}
