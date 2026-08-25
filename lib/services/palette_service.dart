import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

class PaletteService {
  static final Map<String, List<Color>> _colorCache = {};

  /// Extracts rich, luminous Apple Music-style color palettes.
  /// Prioritizes the true dominant tone of the artwork as the ambient base
  /// and pairs it with vibrant complementary & accent swatches.
  static Future<List<Color>> extractColors(
      ImageProvider imageProvider, String imageId) async {
    if (_colorCache.containsKey(imageId)) {
      return _colorCache[imageId]!;
    }

    try {
      final palette = await PaletteGenerator.fromImageProvider(
        imageProvider,
        maximumColorCount: 32,
        size: const Size(96, 96),
      ).timeout(const Duration(seconds: 4));

      Color boostVibrancy(Color c, {double minSat = 0.72, double minLight = 0.32, double maxLight = 0.48}) {
        final hsl = HSLColor.fromColor(c);
        // Strongly amplify saturation to eliminate muddy grayish tones
        final boostedSat = (hsl.saturation * 1.65).clamp(minSat, 1.0);
        // Calibrate lightness into rich, glowing sweet-spot
        double adjustedLight = hsl.lightness;
        if (adjustedLight < minLight) adjustedLight = minLight;
        if (adjustedLight > maxLight) adjustedLight = maxLight;
        return hsl.withSaturation(boostedSat).withLightness(adjustedLight).toColor();
      }

      // 1. Determine the true dominant ambient color
      Color? dominant;
      if (palette.dominantColor != null && palette.dominantColor!.color.computeLuminance() > 0.05) {
        dominant = palette.dominantColor!.color;
      } else if (palette.vibrantColor != null) {
        dominant = palette.vibrantColor!.color;
      } else if (palette.paletteColors.isNotEmpty) {
        dominant = palette.paletteColors.first.color;
      }
      dominant ??= const Color(0xFFC04822); // Warm fallback
      final c0 = boostVibrancy(dominant, minSat: 0.75, minLight: 0.34, maxLight: 0.46);

      // 2. Collect candidate swatches
      final candidates = <Color>[];
      if (palette.vibrantColor != null) candidates.add(palette.vibrantColor!.color);
      if (palette.lightVibrantColor != null) candidates.add(palette.lightVibrantColor!.color);
      if (palette.darkVibrantColor != null) candidates.add(palette.darkVibrantColor!.color);
      if (palette.mutedColor != null) candidates.add(palette.mutedColor!.color);
      if (palette.lightMutedColor != null) candidates.add(palette.lightMutedColor!.color);
      if (palette.darkMutedColor != null) candidates.add(palette.darkMutedColor!.color);

      for (final pc in palette.paletteColors) {
        if (!candidates.contains(pc.color)) {
          candidates.add(pc.color);
        }
      }

      // 3. Find contrasting secondary and accent colors
      final domHsl = HSLColor.fromColor(c0);
      Color? secondaryWarm;
      Color? accentCool;
      Color? vibrantHighlight;

      for (final raw in candidates) {
        final hsl = HSLColor.fromColor(raw);
        if (hsl.saturation < 0.12 && (hsl.lightness < 0.10 || hsl.lightness > 0.90)) continue;

        final hueDiff = (hsl.hue - domHsl.hue).abs();
        final normalizedDiff = hueDiff > 180 ? 360 - hueDiff : hueDiff;

        if (normalizedDiff > 50 && accentCool == null) {
          accentCool = boostVibrancy(raw, minSat: 0.80, minLight: 0.38, maxLight: 0.50);
        } else if (normalizedDiff <= 50 && secondaryWarm == null && _colorDistance(raw, c0) > 30) {
          secondaryWarm = boostVibrancy(raw, minSat: 0.78, minLight: 0.36, maxLight: 0.48);
        } else if (vibrantHighlight == null && _colorDistance(raw, c0) > 40) {
          vibrantHighlight = boostVibrancy(raw, minSat: 0.85, minLight: 0.42, maxLight: 0.54);
        }
      }

      // Synthesize missing harmonic colors if artwork is monochromatic
      secondaryWarm ??= domHsl.withHue((domHsl.hue + 25) % 360).withSaturation(0.85).withLightness(0.44).toColor();
      accentCool ??= domHsl.withHue((domHsl.hue + 180) % 360).withSaturation(0.80).withLightness(0.40).toColor();
      vibrantHighlight ??= domHsl.withHue((domHsl.hue + 45) % 360).withSaturation(0.90).withLightness(0.50).toColor();

      // Deep ambient shadow tone
      final deepBase = domHsl.withSaturation(0.85).withLightness(0.20).toColor();

      final List<Color> result = [
        c0,               // Primary Dominant (e.g. Diomedes rich terracotta/crimson)
        secondaryWarm,    // Secondary Warm Body (e.g. amber / fiery orange)
        accentCool,       // Contrasting Accent (e.g. blue / cyan / gold)
        vibrantHighlight, // High-energy floating highlight
        deepBase,         // Deep rich ambient depth
      ];

      _colorCache[imageId] = result;
      return result;
    } catch (e) {
      return [
        const Color(0xFFB8401C),
        const Color(0xFFE26B28),
        const Color(0xFF2A68C8),
        const Color(0xFFFF9500),
        const Color(0xFF5A1A0C),
      ];
    }
  }

  static double _colorDistance(Color a, Color b) {
    return (a.r - b.r).abs() * 255 +
        (a.g - b.g).abs() * 255 +
        (a.b - b.b).abs() * 255;
  }
}



