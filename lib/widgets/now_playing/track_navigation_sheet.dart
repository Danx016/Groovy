import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/song.dart';
import '../../models/artist.dart';
import '../../models/album.dart';
import '../../providers/library_provider.dart';
import '../../screens/album_screen.dart';
import '../../screens/artist_screen.dart';
import '../../services/youtube_service.dart';
import '../../services/theme_service.dart';
import '../../services/album_resolver_service.dart';

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
      isScrollControlled: true,
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
  String? _resolvedAlbumName;
  String? _resolvedAlbumCover;

  @override
  void initState() {
    super.initState();
    _fetchArtistImage();
    _resolveAlbumInfo();
  }

  Future<void> _resolveAlbumInfo() async {
    final song = widget.song;
    if (song == null) return;
    if (song.album != null &&
        song.album!.isNotEmpty &&
        song.album != 'Álbum' &&
        song.album != 'Album') {
      return;
    }
    try {
      final res = await AlbumResolverService().resolveAlbum(
        albumId: song.albumId ?? song.id,
        song: song,
      );
      if (res != null && mounted) {
        setState(() {
          _resolvedAlbumName = res.album.name;
          if (res.album.coverArt != null && res.album.coverArt!.isNotEmpty) {
            _resolvedAlbumCover = res.album.coverArt;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchArtistImage() async {
    final song = widget.song;
    if (song == null) return;

    try {
      final libraryProvider = Provider.of<LibraryProvider>(context, listen: false);
      final youtubeService = Provider.of<YoutubeService>(context, listen: false);

      // 1. Try artistId from song
      String? targetArtistId = song.artistId;

      // 2. If null, search in library artists
      if (targetArtistId == null || targetArtistId.isEmpty) {
        final artistName = song.artist ?? '';
        for (final a in libraryProvider.artists) {
          if (a.name.toLowerCase() == artistName.toLowerCase()) {
            targetArtistId = a.id;
            if (a.coverArt != null && mounted) {
              setState(() {
                _artistImageUrl = youtubeService.getCoverArtUrl(a.coverArt!, size: 200);
              });
            }
            break;
          }
        }
      }

      if (targetArtistId != null && targetArtistId.isNotEmpty) {
        final artistInfo = await youtubeService.getArtistInfo(targetArtistId);
        if (artistInfo?.mediumImageUrl != null && mounted) {
          setState(() {
            _artistImageUrl = artistInfo!.mediumImageUrl;
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final platformDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final isDark = themeService.themeMode == ThemeMode.dark ||
        (themeService.themeMode == ThemeMode.system && platformDark);

    final song = widget.song;
    final libraryProvider = Provider.of<LibraryProvider>(context);
    final youtubeService = Provider.of<YoutubeService>(context, listen: false);

    final artistName = song?.artist ?? 'Artista';
    final rawAlbum = song?.album;
    final albumName = _resolvedAlbumName ??
        ((rawAlbum != null &&
                rawAlbum.isNotEmpty &&
                rawAlbum != 'Álbum' &&
                rawAlbum != 'Album')
            ? rawAlbum
            : 'Álbum');

    // Find artist from library if available
    Artist? matchedArtist;
    for (final a in libraryProvider.artists) {
      if ((song?.artistId != null && a.id == song!.artistId) ||
          (a.name.toLowerCase() == artistName.toLowerCase())) {
        matchedArtist = a;
        break;
      }
    }

    final effectiveArtistId = song?.artistId ?? matchedArtist?.id ?? artistName;
    final effectiveAlbumName = _resolvedAlbumName ?? song?.album;
    final effectiveAlbumId = song?.albumId ??
        (effectiveAlbumName != null &&
                effectiveAlbumName.isNotEmpty &&
                effectiveAlbumName != 'Álbum' &&
                effectiveAlbumName != 'Album'
            ? effectiveAlbumName
            : '${song?.title} ${song?.artist ?? ""}');

    final coverUrl = _resolvedAlbumCover ??
        ((song?.coverArt != null)
            ? youtubeService.getCoverArtUrl(song!.coverArt, size: 150)
            : null);

    final artistFallbackCover = matchedArtist?.coverArt != null
        ? youtubeService.getCoverArtUrl(matchedArtist!.coverArt!, size: 150)
        : coverUrl;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 32),
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

          // 1. Ir al artista (Apple Music style)
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
                        errorWidget: (_, __, ___) => _buildArtistAvatarImage(artistFallbackCover, isDark),
                      )
                    : _buildArtistAvatarImage(artistFallbackCover, isDark),
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
              final nav = Navigator.of(context, rootNavigator: true);
              nav.pop(); // Close sheet
              if (effectiveArtistId.isNotEmpty) {
                nav.push(
                  MaterialPageRoute(
                    builder: (_) => ArtistScreen(artistId: effectiveArtistId),
                  ),
                );
              }
            },
          ),

          // 2. Ir al álbum (Apple Music style)
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
              final nav = Navigator.of(context, rootNavigator: true);
              nav.pop(); // Close sheet
              final alb = (effectiveAlbumName != null &&
                      effectiveAlbumName.isNotEmpty &&
                      effectiveAlbumName != 'Álbum' &&
                      effectiveAlbumName != 'Album')
                  ? Album(
                      id: effectiveAlbumId,
                      name: effectiveAlbumName,
                      artist: song?.artist,
                      coverArt: coverUrl,
                    )
                  : null;
              nav.push(
                MaterialPageRoute(
                  builder: (_) => AlbumScreen(
                    albumId: effectiveAlbumId,
                    album: alb,
                    song: song,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildArtistAvatarImage(String? fallbackUrl, bool isDark) {
    if (fallbackUrl != null && fallbackUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: fallbackUrl,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _defaultArtistAvatar(isDark),
      );
    }
    return _defaultArtistAvatar(isDark);
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
