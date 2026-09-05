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
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image(
                  image: image,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
                if (isFavorite)
                  Positioned(
                    top: 14,
                    right: 14,
                    child: GestureDetector(
                      onTap: onFavoriteToggle,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1.0,
                          ),
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFD60A),
                          size: 22,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
