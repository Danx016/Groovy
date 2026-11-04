import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import 'album_artwork.dart';

class PlaylistMosaicCover extends StatelessWidget {
  final Playlist playlist;
  final double size;
  final double borderRadius;
  final IconData? fallbackIcon;

  const PlaylistMosaicCover({
    super.key,
    required this.playlist,
    this.size = 60,
    this.borderRadius = 8,
    this.fallbackIcon,
  });

  static final List<List<Color>> _presetGradients = [
    [const Color(0xFFFA2D48), const Color(0xFF5856D6)],
    [const Color(0xFFFF5E3A), const Color(0xFFFF2A68)],
    [const Color(0xFF34C759), const Color(0xFF007AFF)],
    [const Color(0xFF5856D6), const Color(0xFFAF52DE)],
    [const Color(0xFFFF9500), const Color(0xFFFF2D55)],
    [const Color(0xFF1D2671), const Color(0xFFC33764)],
  ];

  @override
  Widget build(BuildContext context) {
    // 1. If explicit coverArt exists, display it
    final explicitCover = playlist.coverArt;
    if (explicitCover != null && explicitCover.isNotEmpty && !explicitCover.startsWith('gradient:')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: AlbumArtwork(
          coverArt: explicitCover,
          size: size,
          borderRadius: borderRadius,
        ),
      );
    }

    // 2. Check for gradient preset flag
    if (explicitCover != null && explicitCover.startsWith('gradient:')) {
      final gradIdx = int.tryParse(explicitCover.split(':').last) ?? 0;
      final colors = _presetGradients[gradIdx % _presetGradients.length];
      return _buildGradientCover(colors);
    }

    // 3. Auto Mosaic (from playlist songs)
    final songs = playlist.songs ?? [];
    final covers = <String>[];
    for (final song in songs) {
      final c = song.coverArt;
      if (c != null && c.isNotEmpty && !covers.contains(c)) {
        covers.add(c);
        if (covers.length >= 4) break;
      }
    }

    if (covers.length >= 4) {
      // 2x2 Mosaic Collage
      final halfSize = size / 2;
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: SizedBox(
          width: size,
          height: size,
          child: Column(
            children: [
              Row(
                children: [
                  AlbumArtwork(coverArt: covers[0], size: halfSize, borderRadius: 0),
                  AlbumArtwork(coverArt: covers[1], size: halfSize, borderRadius: 0),
                ],
              ),
              Row(
                children: [
                  AlbumArtwork(coverArt: covers[2], size: halfSize, borderRadius: 0),
                  AlbumArtwork(coverArt: covers[3], size: halfSize, borderRadius: 0),
                ],
              ),
            ],
          ),
        ),
      );
    } else if (covers.isNotEmpty) {
      // Single track cover fallback
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: AlbumArtwork(
          coverArt: covers.first,
          size: size,
          borderRadius: borderRadius,
        ),
      );
    }

    // 4. Default gradient with music icon based on playlist title hash
    final hash = playlist.name.hashCode.abs();
    final colors = _presetGradients[hash % _presetGradients.length];
    return _buildGradientCover(colors);
  }

  Widget _buildGradientCover(List<Color> colors) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          fallbackIcon ?? CupertinoIcons.music_note_list,
          color: Colors.white,
          size: size * 0.42,
        ),
      ),
    );
  }
}
