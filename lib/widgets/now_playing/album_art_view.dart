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
      child: AnimatedScale(
        scale: isPlaying ? 1.0 : 0.86,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isPlaying ? 0.35 : 0.18),
                blurRadius: isPlaying ? 20.0 : 10.0,
                spreadRadius: 0.0,
                offset: Offset(0, isPlaying ? 10.0 : 4.0),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.0),
            child: Image(
              image: image,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.white.withValues(alpha: 0.12),
                child: const Center(
                  child: Icon(Icons.music_note_rounded, color: Colors.white70, size: 64),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
