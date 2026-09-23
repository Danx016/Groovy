import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../services/youtube_service.dart';
import '../services/player_ui_settings_service.dart';
import '../services/offline_service.dart';

bool isLocalFilePath(String? s) {
  if (s == null || s.isEmpty) return false;
  if (s.startsWith('file://')) return true;
  if (s.startsWith('/')) return true;
  if (s.length > 2 && s[1] == ':') return true;
  return false;
}

class _ImageUrlCache {
  static final Map<String, String> _cache = {};

  static String getUrl(YoutubeService service, String? coverArt, int size) {
    if (coverArt == null || coverArt.isEmpty) return '';
    return _cache.putIfAbsent(
      coverArt,
      () => service.getCoverArtUrl(coverArt, size: 800),
    );
  }
}

class AlbumArtwork extends StatelessWidget {
  final String? coverArt;
  final double size;

  final double? borderRadius;
  final BoxShadow? shadow;

  final bool preserveAspectRatio;
  final IconData? placeholderIcon;

  const AlbumArtwork({
    super.key,
    this.coverArt,
    this.size = 150,
    this.borderRadius,
    this.shadow,
    this.preserveAspectRatio = false,
    this.placeholderIcon,
  });

  @override
  Widget build(BuildContext context) {
    final svc = PlayerUiSettingsService();
    final shape = svc.getArtworkShape();
    final globalRadius = svc.getAlbumArtCornerRadius();
    final shadowLevel = svc.getArtworkShadow();
    final shadowColor = svc.getArtworkShadowColor();

    final resolvedRadius = borderRadius ??
        (shape == 'circle'
            ? 9999.0
            : shape == 'square'
                ? 0.0
                : globalRadius);

    return _buildContent(
      context,
      resolvedRadius,
      shadowLevel,
      shadowColor,
    );
  }

  BoxShadow? _resolvedShadow(
    BuildContext context,
    double resolvedRadius,
    String shadowLevel,
    String shadowColor,
    bool isDark,
  ) {
    if (shadow != null) return shadow;
    if (shadowLevel == 'none') return null;
    final Color color;
    switch (shadowColor) {
      case 'accent':
        color = Theme.of(context).colorScheme.primary;
        break;
      default:
        color = Colors.black;
    }
    double opacity;
    double blur;
    Offset offset;
    switch (shadowLevel) {
      case 'medium':
        opacity = isDark ? 0.35 : 0.25;
        blur = size / 6;
        offset = Offset(0, size / 20);
        break;
      case 'strong':
        opacity = isDark ? 0.55 : 0.40;
        blur = size / 4;
        offset = Offset(0, size / 12);
        break;
      default:
        opacity = isDark ? 0.22 : 0.14;
        blur = size / 10;
        offset = Offset(0, size / 30);
    }
    return BoxShadow(
      color: color.withValues(alpha: opacity),
      blurRadius: blur,
      offset: offset,
    );
  }

  Widget _buildContent(
    BuildContext context,
    double resolvedRadius,
    String shadowLevel,
    String shadowColor,
  ) {
    final bool isFlexible = !size.isFinite || size.isNaN;
    final validSize = isFlexible ? 150.0 : size;

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final targetSize = (isFlexible ? 350.0 : validSize) * dpr;
    final int minClamp;
    final int maxClamp;
    if (validSize <= 80) {
      minClamp = 120;
      maxClamp = 320;
    } else if (validSize <= 180) {
      minClamp = 320;
      maxClamp = 640;
    } else {
      minClamp = 600;
      maxClamp = 1200;
    }
    final cacheSize = targetSize.toInt().clamp(minClamp, maxClamp);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedShadow = _resolvedShadow(
      context,
      resolvedRadius,
      shadowLevel,
      shadowColor,
      isDark,
    );

    if (preserveAspectRatio) {
      return Container(
        constraints: isFlexible ? null : BoxConstraints(maxWidth: validSize),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(resolvedRadius),
          boxShadow: resolvedShadow != null ? [resolvedShadow] : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(resolvedRadius),
          child: _buildImageNatural(isDark, cacheSize),
        ),
      );
    }

    return Container(
      width: isFlexible ? double.infinity : validSize,
      height: isFlexible ? double.infinity : validSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(resolvedRadius),
        boxShadow: resolvedShadow != null && (isFlexible || validSize > 60)
            ? [resolvedShadow]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(resolvedRadius),
        child: _buildImage(isDark, cacheSize),
      ),
    );
  }

  Widget _buildImageNatural(bool isDark, int cacheSize) {
    if (coverArt == null || coverArt!.isEmpty) return _buildPlaceholder(isDark);

    if (isLocalFilePath(coverArt)) {
      try {
        final path = coverArt!.startsWith('file://')
            ? Uri.parse(coverArt!).toFilePath()
            : coverArt!;
        final artFile = File(path);
        if (artFile.existsSync()) {
          return Image.file(
            artFile,
            key: ValueKey(coverArt),
            fit: BoxFit.contain,
            cacheWidth: cacheSize,
            cacheHeight: cacheSize,
            filterQuality: FilterQuality.medium,
            errorBuilder: (ctx, err, stack) => _buildPlaceholder(isDark),
          );
        }
      } catch (_) {}
    }

    if (OfflineService().downloadedSongIds.value.isNotEmpty) {
      final offlinePath =
          OfflineService().getLocalCoverArtPathByCoverArtId(coverArt);
      if (offlinePath != null) {
        return Image.file(
          File(offlinePath),
          key: ValueKey('offline_natural_$coverArt'),
          fit: BoxFit.contain,
          cacheWidth: cacheSize,
          cacheHeight: cacheSize,
          filterQuality: FilterQuality.medium,
          errorBuilder: (ctx, err, stack) => _buildPlaceholder(isDark),
        );
      }
    }

    return Builder(
      builder: (context) {
        final imageUrl = _ImageUrlCache.getUrl(
          Provider.of<YoutubeService>(context, listen: false),
          coverArt,
          cacheSize,
        );
        if (imageUrl.isEmpty) return _buildPlaceholder(isDark);
        return CachedNetworkImage(
          imageUrl: imageUrl,
          key: ValueKey('natural_$imageUrl'),
          fit: BoxFit.contain,
          memCacheWidth: cacheSize,
          memCacheHeight: cacheSize,
          maxWidthDiskCache: 1200,
          maxHeightDiskCache: 1200,
          filterQuality: FilterQuality.medium,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          useOldImageOnUrlChange: false,
          placeholder: (ctx, url) => _buildPlaceholder(isDark),
          errorWidget: (ctx, err, stack) {
            debugPrint('AlbumArtwork error (natural): $err');
            return _buildNetworkImageFallback(imageUrl, isDark, BoxFit.contain);
          },
        );
      },
    );
  }

  Widget _buildImage(bool isDark, int cacheSize) {
    if (coverArt == null || coverArt!.isEmpty) return _buildPlaceholder(isDark);

    if (isLocalFilePath(coverArt)) {
      try {
        final path = coverArt!.startsWith('file://')
            ? Uri.parse(coverArt!).toFilePath()
            : coverArt!;
        final artFile = File(path);
        if (artFile.existsSync()) {
          return Image.file(
            artFile,
            key: ValueKey(coverArt),
            fit: BoxFit.cover,
            cacheWidth: cacheSize,
            cacheHeight: cacheSize,
            filterQuality: FilterQuality.medium,
            errorBuilder: (ctx, err, stack) => _buildPlaceholder(isDark),
          );
        }
      } catch (_) {}
    }

    if (OfflineService().downloadedSongIds.value.isNotEmpty) {
      final offlinePath =
          OfflineService().getLocalCoverArtPathByCoverArtId(coverArt);
      if (offlinePath != null) {
        return Image.file(
          File(offlinePath),
          key: ValueKey('offline_$coverArt'),
          fit: BoxFit.cover,
          cacheWidth: cacheSize,
          cacheHeight: cacheSize,
          filterQuality: FilterQuality.medium,
          errorBuilder: (ctx, err, stack) => _buildPlaceholder(isDark),
        );
      }
    }

    return Builder(
      builder: (context) {
        final imageUrl = _ImageUrlCache.getUrl(
          Provider.of<YoutubeService>(context, listen: false),
          coverArt,
          cacheSize,
        );
        if (imageUrl.isEmpty) return _buildPlaceholder(isDark);
        return CachedNetworkImage(
          imageUrl: imageUrl,
          key: ValueKey('cover_$imageUrl'),
          fit: BoxFit.cover,
          memCacheWidth: cacheSize,
          memCacheHeight: cacheSize,
          maxWidthDiskCache: 1200,
          maxHeightDiskCache: 1200,
          filterQuality: FilterQuality.medium,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          useOldImageOnUrlChange: false,
          placeholder: (ctx, url) => _buildPlaceholder(isDark),
          errorWidget: (ctx, err, stack) {
            debugPrint('AlbumArtwork error: $err');
            return _buildNetworkImageFallback(imageUrl, isDark, BoxFit.cover);
          },
        );
      },
    );
  }

  Widget _buildNetworkImageFallback(String url, bool isDark, BoxFit fit) {
    String fallbackUrl = url;
    if (url.contains('/sddefault.jpg') || url.contains('/mqdefault.jpg')) {
      fallbackUrl =
          url.replaceAll(RegExp(r'/(sd|mq)default\.jpg'), '/hqdefault.jpg');
    } else if (url.contains('=w800-h800') || url.contains('=w1200-h1200')) {
      fallbackUrl = url.replaceAll(RegExp(r'=w\d+-h\d+[^/]*'), '=w544-h544');
    }
    return Image.network(
      fallbackUrl,
      fit: fit,
      filterQuality: FilterQuality.medium,
      errorBuilder: (ctx, err, stack) {
        debugPrint('Network image fallback error: $err');
        final match = RegExp(r'([a-zA-Z0-9_-]{11})').firstMatch(url);
        final vid = match?.group(1);
        if (vid != null &&
            vid.isNotEmpty &&
            !fallbackUrl.contains('/vi/$vid/')) {
          return Image.network(
            'https://i.ytimg.com/vi/$vid/hqdefault.jpg',
            fit: fit,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => _buildPlaceholder(isDark),
          );
        }
        return _buildPlaceholder(isDark);
      },
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    final iconSize = size.isFinite ? (size / 2.8).clamp(16.0, 60.0) : 48.0;
    final defaultIcon = (borderRadius != null &&
            borderRadius! >= (size.isFinite ? size / 2 - 2 : 20))
        ? Icons.person_rounded
        : Icons.music_note_rounded;
    final effectiveIcon = placeholderIcon ?? defaultIcon;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF2C2C2E), const Color(0xFF1C1C1E)]
              : [const Color(0xFFE5E5EA), const Color(0xFFD1D1D6)],
        ),
      ),
      child: Center(
        child: Icon(
          effectiveIcon,
          size: iconSize,
          color: isDark ? Colors.white38 : Colors.black26,
        ),
      ),
    );
  }
}
