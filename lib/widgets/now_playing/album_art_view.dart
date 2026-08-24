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
        scale: isPlaying ? 1.0 : 0.86,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 28.0,
                spreadRadius: 2.0,
                offset: const Offset(0, 14),
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

