import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Ultra-lightweight album art widget for the Now Playing screen.
///
/// Pure Flutter [Image] + [Hero] + [RepaintBoundary] — zero video players,
/// zero looping animation controllers, zero Apple Music API calls.
/// The only animation is a subtle elastic scale driven by [TweenAnimationBuilder]
/// that smoothly scales the art in/out when playback pauses or resumes.
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
    Widget buildFallback() {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              dominantColor ?? const Color(0xFF2C2C2E),
              const Color(0xFF1C1C1E),
            ],
          ),
        ),
        child: const Center(
          child: Icon(Icons.music_note_rounded, color: Colors.white70, size: 64),
        ),
      );
    }

    Widget buildErrorFallback() {
      debugPrint('[AlbumArtView] Image error for tag $tag');
      final match = RegExp(r'([a-zA-Z0-9_-]{11})').firstMatch(tag);
      final videoId = match?.group(1);
      if (videoId != null && videoId.isNotEmpty) {
        return ClipRect(
          child: Transform.scale(
            scale: 4.0 / 3.0,
            alignment: Alignment.center,
            child: Image.network(
              'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => buildFallback(),
            ),
          ),
        );
      }
      return buildFallback();
    }

    final String? imgUrl = image is CachedNetworkImageProvider
        ? (image as CachedNetworkImageProvider).url
        : (image is NetworkImage ? (image as NetworkImage).url : null);
    final bool isYtDefault = imgUrl != null &&
        imgUrl.contains('i.ytimg.com') &&
        (imgUrl.contains('/hqdefault') ||
         imgUrl.contains('/mqdefault') ||
         imgUrl.contains('/sddefault') ||
         imgUrl.contains('/default'));

    final innerImage = Image(
      image: image,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) => buildErrorFallback(),
    );

    // Inner image: clipped, Hero-wrapped, gapless, medium quality for speed, with cached deep shadow.
    final imageWidget = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 24.0,
            spreadRadius: 0.0,
            offset: Offset(0, 10.0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22.0),
        child: Hero(
          tag: tag,
          child: isYtDefault
              ? ClipRect(
                  child: Transform.scale(
                    scale: 4.0 / 3.0,
                    alignment: Alignment.center,
                    child: innerImage,
                  ),
                )
              : innerImage,
        ),
      ),
    );

    return RepaintBoundary(
      child: AnimatedScale(
        scale: isPlaying ? 1.0 : 0.88,
        duration: const Duration(milliseconds: 350),
        curve: const Cubic(0.22, 1.0, 0.36, 1.0),
        alignment: Alignment.center,
        child: imageWidget,
      ),
    );
  }
}
