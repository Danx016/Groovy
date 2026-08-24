import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/song.dart';
import '../../screens/album_screen.dart';
import '../../screens/artist_screen.dart';
import '../../utils/navigation_helper.dart';
import '../../services/subsonic_service.dart';

class TrackNavigationBottomSheet extends StatefulWidget {
  final Song? song;
  final ImageProvider? coverProvider;

  const TrackNavigationBottomSheet({
    super.key,
    required this.song,
    this.coverProvider,
  });

  static void show(BuildContext context, {Song? song, ImageProvider? coverProvider}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (context) => TrackNavigationBottomSheet(
        song: song,
        coverProvider: coverProvider,
      ),
    );
  }

  @override
  State<TrackNavigationBottomSheet> createState() => _TrackNavigationBottomSheetState();
}

class _TrackNavigationBottomSheetState extends State<TrackNavigationBottomSheet> {
  String? _artistImageUrl;

  @override
  void initState() {
    super.initState();
    _fetchArtistImage();
  }

  Future<void> _fetchArtistImage() async {
    final song = widget.song;
    if (song?.artistId == null || song!.artistId!.isEmpty) return;

    try {
      final subsonic = Provider.of<SubsonicService>(context, listen: false);
      final artistInfo = await subsonic.getArtistInfo(song.artistId!);
      if (artistInfo?.mediumImageUrl != null && mounted) {
        setState(() {
          _artistImageUrl = artistInfo!.mediumImageUrl;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final song = widget.song;
    final subsonic = Provider.of<SubsonicService>(context, listen: false);

    final artistName = song?.artist ?? 'Artista';
    final albumName = song?.album ?? 'Álbum';

    final coverUrl = (song?.coverArt != null)
        ? subsonic.getCoverArtUrl(song!.coverArt, size: 150)
        : null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 1. Ir al artista
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            leading: SizedBox(
              width: 48,
              height: 48,
              child: ClipOval(
                child: _artistImageUrl != null && _artistImageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: _artistImageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _defaultArtistAvatar(isDark),
                      )
                    : _defaultArtistAvatar(isDark),
              ),
            ),
            title: Text(
              'Ir al artista',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              artistName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            onTap: () {
              Navigator.of(context).pop();
              final artId = song?.artistId;
              if (artId != null && artId.isNotEmpty) {
                NavigationHelper.push(context, ArtistScreen(artistId: artId));
              } else if (artistName.isNotEmpty) {
                NavigationHelper.push(context, ArtistScreen(artistId: artistName));
              }
            },
          ),

          // 2. Ir al álbum
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: widget.coverProvider != null
                    ? Image(image: widget.coverProvider!, fit: BoxFit.cover)
                    : (coverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: coverUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _defaultAlbumCover(isDark),
                          )
                        : _defaultAlbumCover(isDark)),
              ),
            ),
            title: Text(
              'Ir al álbum',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              albumName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            onTap: () {
              Navigator.of(context).pop();
              final albId = song?.albumId ?? song?.album;
              if (albId != null && albId.isNotEmpty) {
                NavigationHelper.push(context, AlbumScreen(albumId: albId));
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _defaultArtistAvatar(bool isDark) {
    return Container(
      color: isDark ? Colors.white12 : Colors.black12,
      child: Center(
        child: Icon(
          Icons.person_rounded,
          color: isDark ? Colors.white70 : Colors.black54,
          size: 26,
        ),
      ),
    );
  }

  Widget _defaultAlbumCover(bool isDark) {
    return Container(
      color: isDark ? Colors.white12 : Colors.black12,
      child: Center(
        child: Icon(
          Icons.album_rounded,
          color: isDark ? Colors.white70 : Colors.black54,
          size: 26,
        ),
      ),
    );
  }
}
