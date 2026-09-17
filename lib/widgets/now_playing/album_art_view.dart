import 'package:flutter/material.dart';
import 'animated_album_art_view.dart';

class AlbumArtView extends StatelessWidget {
  final ImageProvider image;
  final String tag;
  final bool isPlaying;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  final Color? dominantColor;

  const AlbumArtView({
    super.key,
    required this.image,
    required this.tag,
    this.isPlaying = true,
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.dominantColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedAlbumArtView(
      image: image,
      tag: tag,
      isPlaying: isPlaying,
      isFavorite: isFavorite,
      onFavoriteToggle: onFavoriteToggle,
      dominantColor: dominantColor,
    );
  }
}
