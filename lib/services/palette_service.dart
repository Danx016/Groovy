import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

class PaletteService {
  static final Map<String, List<Color>> _colorCache = {};

  /// Instant synchronous cache access (0 ms)
  static List<Color>? getCachedColors(String imageId) {
    return _colorCache[imageId];
  }

  /// Default Apple Music dark atmospheric palette (never muddy orange)
  static const List<Color> defaultPalette = [
    Color(0xFF16161E),
    Color(0xFF1E1E28),
    Color(0xFF121218),
    Color(0xFF242434),
    Color(0xFF09090D),
  ];

  /// Extracts rich, authentic Apple Music ambient color palettes.
  /// Accurately preserves dark covers without muddy color shifts,
  /// and expands the color spectrum for multi-colored artwork.
  static Future<List<Color>> extractColors(
      ImageProvider imageProvider, String imageId) async {
    if (_colorCache.containsKey(imageId)) {
      return _colorCache[imageId]!;
    }

    try {
      final palette = await PaletteGenerator.fromImageProvider(
        imageProvider,
        maximumColorCount: 20,
        size: const Size(48, 48),
      ).timeout(const Duration(seconds: 3));

      // Calculate population-weighted average lightness and saturation
      double totalWeightedLightness = 0.0;
      double totalWeightedSaturation = 0.0;
      int totalPopulation = 0;

      for (final p in palette.paletteColors) {
        final hsl = HSLColor.fromColor(p.color);
        totalWeightedLightness += hsl.lightness * p.population;
        totalWeightedSaturation += hsl.saturation * p.population;
        totalPopulation += p.population;
      }

      final avgLightness = totalPopulation > 0
          ? (totalWeightedLightness / totalPopulation)
          : 0.5;
      final avgSaturation = totalPopulation > 0
          ? (totalWeightedSaturation / totalPopulation)
          : 0.5;

      // Detect dark / nocturnal / monochrome artwork
      final isDarkArtwork = avgLightness < 0.20 ||
          (palette.dominantColor != null &&
              HSLColor.fromColor(palette.dominantColor!.color).lightness < 0.14 &&
              HSLColor.fromColor(palette.dominantColor!.color).saturation < 0.35);
      final isMonochrome = avgSaturation < 0.12;

      // Safe tone calibration functions that respect dark art and expand vibrant art
      Color calibrateDominant(Color c) {
        final hsl = HSLColor.fromColor(c);
        if (isDarkArtwork) {
          final s = hsl.saturation.clamp(0.0, 0.30);
          final l = hsl.lightness.clamp(0.07, 0.16);
          return hsl.withSaturation(s).withLightness(l).toColor();
        } else if (isMonochrome) {
          return hsl
              .withSaturation(0.0)
              .withLightness(hsl.lightness.clamp(0.15, 0.35))
              .toColor();
        } else {
          final s = hsl.saturation.clamp(0.35, 0.85);
          final l = hsl.lightness.clamp(0.24, 0.44);
          return hsl.withSaturation(s).withLightness(l).toColor();
        }
      }

      Color calibrateHighlight(Color c) {
        final hsl = HSLColor.fromColor(c);
        if (isDarkArtwork) {
          final s = hsl.saturation.clamp(0.0, 0.45);
          final l = hsl.lightness.clamp(0.16, 0.28);
          return hsl.withSaturation(s).withLightness(l).toColor();
        } else if (isMonochrome) {
          return hsl
              .withSaturation(0.0)
              .withLightness(hsl.lightness.clamp(0.30, 0.55))
              .toColor();
        } else {
          final s = hsl.saturation.clamp(0.40, 0.90);
          final l = hsl.lightness.clamp(0.38, 0.58);
          return hsl.withSaturation(s).withLightness(l).toColor();
        }
      }

      Color calibrateDeep(Color c) {
        final hsl = HSLColor.fromColor(c);
        final s = isDarkArtwork || isMonochrome
            ? hsl.saturation.clamp(0.0, 0.20)
            : hsl.saturation.clamp(0.20, 0.60);
        final l = isDarkArtwork ? 0.05 : 0.09;
        return hsl.withSaturation(s).withLightness(l).toColor();
      }

      // 1. Determine dominant anchor
      Color dominantTone;
      if (isDarkArtwork && palette.dominantColor != null) {
        dominantTone = palette.dominantColor!.color;
      } else if (palette.dominantColor != null &&
          (palette.vibrantColor == null ||
              palette.dominantColor!.population >
                  (palette.vibrantColor!.population * 2))) {
        dominantTone = palette.dominantColor!.color;
      } else if (palette.vibrantColor != null) {
        dominantTone = palette.vibrantColor!.color;
      } else if (palette.dominantColor != null) {
        dominantTone = palette.dominantColor!.color;
      } else if (palette.lightVibrantColor != null) {
        dominantTone = palette.lightVibrantColor!.color;
      } else if (palette.mutedColor != null) {
        dominantTone = palette.mutedColor!.color;
      } else if (palette.paletteColors.isNotEmpty) {
        dominantTone = palette.paletteColors.first.color;
      } else {
        dominantTone = const Color(0xFF16161E);
      }

      final c0 = calibrateDominant(dominantTone);
      final domHsl = HSLColor.fromColor(c0);

      // 2. Collect unique, distinct swatches from the cover
      final distinctColors = <Color>[];
      final sortedSwatches = List<PaletteColor>.from(palette.paletteColors)
        ..sort((a, b) {
          final scoreA =
              a.population * (0.4 + HSLColor.fromColor(a.color).saturation);
          final scoreB =
              b.population * (0.4 + HSLColor.fromColor(b.color).saturation);
          return scoreB.compareTo(scoreA);
        });

      for (final swatch in sortedSwatches) {
        final color = swatch.color;
        final hsl = HSLColor.fromColor(color);
        if (hsl.lightness > 0.95) continue;
        if (!isDarkArtwork && hsl.lightness < 0.04) continue;

        final isDistinct =
            distinctColors.every((existing) => _colorDistance(existing, color) > 36);
        if (isDistinct && _colorDistance(dominantTone, color) > 30) {
          distinctColors.add(color);
        }
        if (distinctColors.length >= 4) break;
      }

      // Check standard target swatches if they add new distinct hues
      final targetSwatches = [
        palette.vibrantColor?.color,
        palette.lightVibrantColor?.color,
        palette.darkVibrantColor?.color,
        palette.mutedColor?.color,
        palette.lightMutedColor?.color,
      ].whereType<Color>();

      for (final target in targetSwatches) {
        if (distinctColors.length >= 4) break;
        if (_colorDistance(dominantTone, target) > 32 &&
            distinctColors.every((c) => _colorDistance(c, target) > 36)) {
          distinctColors.add(target);
        }
      }

      // 3. Assign 5 harmonic tones
      Color secondary;
      Color accent;
      Color highlight;

      if (distinctColors.isNotEmpty) {
        secondary = calibrateDominant(distinctColors[0]);
      } else {
        secondary = domHsl
            .withLightness((domHsl.lightness * 0.85).clamp(0.08, 0.40))
            .toColor();
      }

      if (distinctColors.length > 1) {
        accent = calibrateDominant(distinctColors[1]);
      } else if (distinctColors.isNotEmpty) {
        accent = calibrateHighlight(distinctColors[0]);
      } else {
        accent = domHsl
            .withSaturation((domHsl.saturation * 1.1).clamp(0.0, 0.90))
            .toColor();
      }

      if (distinctColors.length > 2) {
        highlight = calibrateHighlight(distinctColors[2]);
      } else if (distinctColors.isNotEmpty) {
        highlight = calibrateHighlight(distinctColors[0]);
      } else {
        highlight = calibrateHighlight(c0);
      }

      final deepBase = calibrateDeep(c0);

      final List<Color> result = [
        c0,         // 0: Primary ambient anchor
        secondary,  // 1: Harmonic secondary tone from artwork
        accent,     // 2: Dynamic accent from artwork
        highlight,  // 3: Luminous glow highlight
        deepBase,   // 4: Deep atmospheric foundation
      ];

      _colorCache[imageId] = result;
      return result;
    } catch (e) {
      return defaultPalette;
    }
  }

  static double _colorDistance(Color a, Color b) {
    final dr = (a.r - b.r).abs() * 255;
    final dg = (a.g - b.g).abs() * 255;
    final db = (a.b - b.b).abs() * 255;
    return dr + dg + db;
  }
}
