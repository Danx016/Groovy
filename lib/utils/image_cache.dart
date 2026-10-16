import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImageCacheConfig {
  static void configure() {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      // Mobile: Keep memory bounded to 80 MB & 150 images to prevent Android LMK Out-Of-Memory (OOM) crashes
      PaintingBinding.instance.imageCache.maximumSize = 150;
      PaintingBinding.instance.imageCache.maximumSizeBytes = 80 << 20; // 80 MB
    } else {
      // Desktop: 150 MB & 400 images
      PaintingBinding.instance.imageCache.maximumSize = 400;
      PaintingBinding.instance.imageCache.maximumSizeBytes = 150 << 20; // 150 MB
    }
  }
}

class ImagePreloader {

  static Future<void> preloadImages(
    BuildContext context,
    List<String> imageUrls,
  ) async {
    for (final url in imageUrls) {
      if (url.isNotEmpty) {
        try {
          await precacheImage(CachedNetworkImageProvider(url), context);
        } catch (_) {
          
        }
      }
    }
  }

  static Future<void> preloadImage(
    BuildContext context,
    String imageUrl,
  ) async {
    if (imageUrl.isEmpty) return;

    try {
      await precacheImage(CachedNetworkImageProvider(imageUrl), context);
    } catch (_) {
      
    }
  }
}
