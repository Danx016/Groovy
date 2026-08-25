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
        scale: isPlaying ? 1.0 : 0.82,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isPlaying ? 0.48 : 0.22),
                blurRadius: isPlaying ? 38.0 : 16.0,
                spreadRadius: isPlaying ? 2.0 : 0.0,
                offset: Offset(0, isPlaying ? 18.0 : 8.0),
              ),
            ],
            image: DecorationImage(
              image: image,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}


