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

      Color calibrateAppleMusic(Color c, {double maxSat = 0.58, double minLight = 0.18, double maxLight = 0.36}) {
        final hsl = HSLColor.fromColor(c);
        // Keep natural saturation, gently cap high neon saturation
        final sat = hsl.saturation.clamp(0.24, maxSat);
        // Calibrate lightness to Apple Music's deep, ambient sweet-spot
        final light = hsl.lightness.clamp(minLight, maxLight);
        return hsl.withSaturation(sat).withLightness(light).toColor();
      }

      // 1. Determine the true dominant ambient color
      Color? dominant;
      if (palette.mutedColor != null) {
        dominant = palette.mutedColor!.color;
      } else if (palette.darkMutedColor != null) {
        dominant = palette.darkMutedColor!.color;
      } else if (palette.dominantColor != null) {
        dominant = palette.dominantColor!.color;
      } else if (palette.darkVibrantColor != null) {
        dominant = palette.darkVibrantColor!.color;
      } else if (palette.vibrantColor != null) {
        dominant = palette.vibrantColor!.color;
      } else if (palette.paletteColors.isNotEmpty) {
        dominant = palette.paletteColors.first.color;
      }
      dominant ??= const Color(0xFF5C3A2E); // Deep warm sienna fallback
      final c0 = calibrateAppleMusic(dominant, maxSat: 0.52, minLight: 0.20, maxLight: 0.32);

      // 2. Collect candidate swatches
      final candidates = <Color>[];
      if (palette.darkMutedColor != null) candidates.add(palette.darkMutedColor!.color);
      if (palette.mutedColor != null) candidates.add(palette.mutedColor!.color);
      if (palette.darkVibrantColor != null) candidates.add(palette.darkVibrantColor!.color);
      if (palette.vibrantColor != null) candidates.add(palette.vibrantColor!.color);
      if (palette.lightMutedColor != null) candidates.add(palette.lightMutedColor!.color);
      if (palette.lightVibrantColor != null) candidates.add(palette.lightVibrantColor!.color);

      for (final pc in palette.paletteColors) {
        if (!candidates.contains(pc.color)) {
          candidates.add(pc.color);
        }
      }

      // 3. Find harmonic secondary, accent and depth colors
      final domHsl = HSLColor.fromColor(c0);
      Color? secondaryWarm;
      Color? accentCool;
      Color? subtleHighlight;

      for (final raw in candidates) {
        final hsl = HSLColor.fromColor(raw);
        if (hsl.lightness < 0.08 || hsl.lightness > 0.92) continue;

        final hueDiff = (hsl.hue - domHsl.hue).abs();
        final normalizedDiff = hueDiff > 180 ? 360 - hueDiff : hueDiff;

        if (normalizedDiff > 45 && accentCool == null) {
          accentCool = calibrateAppleMusic(raw, maxSat: 0.50, minLight: 0.22, maxLight: 0.38);
        } else if (normalizedDiff <= 45 && secondaryWarm == null && _colorDistance(raw, c0) > 25) {
          secondaryWarm = calibrateAppleMusic(raw, maxSat: 0.55, minLight: 0.22, maxLight: 0.35);
        } else if (subtleHighlight == null && _colorDistance(raw, c0) > 35) {
          subtleHighlight = calibrateAppleMusic(raw, maxSat: 0.50, minLight: 0.26, maxLight: 0.40);
        }
      }

      // Synthesize missing harmonic colors if artwork is monochromatic
      secondaryWarm ??= domHsl.withHue((domHsl.hue + 20) % 360).withSaturation((domHsl.saturation * 1.1).clamp(0.28, 0.55)).withLightness(0.28).toColor();
      accentCool ??= domHsl.withHue((domHsl.hue + 160) % 360).withSaturation(0.40).withLightness(0.24).toColor();
      subtleHighlight ??= domHsl.withHue((domHsl.hue + 35) % 360).withSaturation(0.48).withLightness(0.34).toColor();

      // Deep rich ambient base tone
      final deepBase = domHsl.withSaturation((domHsl.saturation * 0.9).clamp(0.20, 0.45)).withLightness(0.14).toColor();

      final List<Color> result = [
        c0,               // Primary Dominant Base (Apple Music ambient anchor)
        secondaryWarm,    // Secondary Warm Body (rich harmonic body)
        accentCool,       // Accent Contrast (subtle cool depth)
        subtleHighlight,  // Soft Luminous Highlight
        deepBase,         // Deep Ambient Foundation
      ];

      _colorCache[imageId] = result;
      return result;
    } catch (e) {
      return [
        const Color(0xFF5A3628),
        const Color(0xFF7A4A38),
        const Color(0xFF384A5C),
        const Color(0xFF885642),
        const Color(0xFF2C1A14),
      ];
    }
  }

  static double _colorDistance(Color a, Color b) {
    return (a.r - b.r).abs() * 255 +
        (a.g - b.g).abs() * 255 +
        (a.b - b.b).abs() * 255;
  }
}



