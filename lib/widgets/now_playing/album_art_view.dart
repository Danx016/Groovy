import 'package:flutter/material.dart';

class AlbumArtView extends StatelessWidget {
  final ImageProvider image;
  final String tag;
  final bool isPlaying;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  const AlbumArtView({
    super.key,
    required this.image,
    required this.tag,
    this.isPlaying = true,
    this.isFavorite = false,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: isPlaying ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 480),
        curve: const Cubic(0.22, 1.0, 0.36, 1.0),
        builder: (context, animValue, child) {
          final scale = 0.86 + (0.14 * animValue);
          final blurRadius = 14.0 + (16.0 * animValue);
          final shadowAlpha = 0.18 + (0.20 * animValue);
          final offsetY = 6.0 + (8.0 * animValue);
          final radius = 20.0 + (3.0 * animValue);

          return Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: shadowAlpha),
                    blurRadius: blurRadius,
                    spreadRadius: 0.0,
                    offset: Offset(0, offsetY),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: Image(
                  image: image,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.white.withValues(alpha: 0.12),
                    child: const Center(
                      child: Icon(Icons.music_note_rounded, color: Colors.white70, size: 64),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
