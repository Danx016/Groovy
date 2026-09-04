import 'package:flutter/material.dart';

class AlbumArtView extends StatelessWidget {
  final ImageProvider image;
  final String tag;
  final bool isPlaying;

  const AlbumArtView({
    super.key,
    required this.image,
    required this.tag,
    this.isPlaying = true,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      child: AnimatedScale(
        scale: isPlaying ? 1.0 : 0.85,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isPlaying ? 0.40 : 0.20),
                blurRadius: isPlaying ? 28.0 : 14.0,
                spreadRadius: 0.0,
                offset: Offset(0, isPlaying ? 14.0 : 6.0),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14.0),
            child: Image(
              image: image,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
        ),
      ),
    );
  }
}
