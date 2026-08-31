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
        maximumColorCount: 16,
        size: const Size(48, 48),
      ).timeout(const Duration(milliseconds: 1500));

      Color calibrateVibrant(Color c, {double minSat = 0.55, double maxSat = 0.92, double minLight = 0.32, double maxLight = 0.50}) {
        final hsl = HSLColor.fromColor(c);
        final sat = hsl.saturation.clamp(minSat, maxSat);
        final light = hsl.lightness.clamp(minLight, maxLight);
        return hsl.withSaturation(sat).withLightness(light).toColor();
      }

      Color calibrateDeep(Color c, {double minSat = 0.35, double maxSat = 0.75, double light = 0.12}) {
        final hsl = HSLColor.fromColor(c);
        final sat = hsl.saturation.clamp(minSat, maxSat);
        return hsl.withSaturation(sat).withLightness(light).toColor();
      }

      // 1. Determine primary dominant vibrant tone (Apple Music uses vivid dominant or vibrant swatch)
      Color? dominant;
      if (palette.vibrantColor != null) {
        dominant = palette.vibrantColor!.color;
      } else if (palette.dominantColor != null && HSLColor.fromColor(palette.dominantColor!.color).saturation > 0.20) {
        dominant = palette.dominantColor!.color;
      } else if (palette.lightVibrantColor != null) {
        dominant = palette.lightVibrantColor!.color;
      } else if (palette.darkVibrantColor != null) {
        dominant = palette.darkVibrantColor!.color;
      } else if (palette.mutedColor != null) {
        dominant = palette.mutedColor!.color;
      } else if (palette.paletteColors.isNotEmpty) {
        dominant = palette.paletteColors.first.color;
      }
      dominant ??= const Color(0xFFE64A19); // Rich fiery orange fallback

      final c0 = calibrateVibrant(dominant, minSat: 0.65, maxSat: 0.95, minLight: 0.36, maxLight: 0.52);
      final domHsl = HSLColor.fromColor(c0);

      // 2. Collect candidate swatches sorted by saturation and vibrancy
      final candidates = <Color>[];
      if (palette.vibrantColor != null) candidates.add(palette.vibrantColor!.color);
      if (palette.lightVibrantColor != null) candidates.add(palette.lightVibrantColor!.color);
      if (palette.darkVibrantColor != null) candidates.add(palette.darkVibrantColor!.color);
      if (palette.dominantColor != null) candidates.add(palette.dominantColor!.color);
      if (palette.mutedColor != null) candidates.add(palette.mutedColor!.color);
      if (palette.darkMutedColor != null) candidates.add(palette.darkMutedColor!.color);

      for (final pc in palette.paletteColors) {
        if (!candidates.contains(pc.color)) {
          candidates.add(pc.color);
        }
      }

      // 3. Find harmonic secondary, accent/contrast, and luminous highlight
      Color? secondaryWarm;
      Color? accentCool;
      Color? luminousHighlight;

      for (final raw in candidates) {
        final hsl = HSLColor.fromColor(raw);
        if (hsl.lightness < 0.10 || hsl.lightness > 0.90) continue;

        final hueDiff = (hsl.hue - domHsl.hue).abs();
        final normalizedDiff = hueDiff > 180 ? 360 - hueDiff : hueDiff;

        if (normalizedDiff > 40 && accentCool == null) {
          accentCool = calibrateVibrant(raw, minSat: 0.60, maxSat: 0.92, minLight: 0.34, maxLight: 0.52);
        } else if (normalizedDiff <= 40 && secondaryWarm == null && _colorDistance(raw, c0) > 30) {
          secondaryWarm = calibrateVibrant(raw, minSat: 0.60, maxSat: 0.90, minLight: 0.36, maxLight: 0.52);
        } else if (luminousHighlight == null && _colorDistance(raw, c0) > 40) {
          luminousHighlight = calibrateVibrant(raw, minSat: 0.65, maxSat: 0.95, minLight: 0.45, maxLight: 0.60);
        }
      }

      // Synthesize rich harmonic color wheel offsets if artwork is monochromatic
      secondaryWarm ??= domHsl.withHue((domHsl.hue + 28) % 360).withSaturation((domHsl.saturation * 1.05).clamp(0.60, 0.92)).withLightness(0.42).toColor();
      accentCool ??= domHsl.withHue((domHsl.hue + 145) % 360).withSaturation(0.72).withLightness(0.40).toColor();
      luminousHighlight ??= domHsl.withHue((domHsl.hue + 45) % 360).withSaturation(0.85).withLightness(0.54).toColor();

      // Deep rich ambient base tone (tinted dark atmospheric foundation)
      final deepBase = calibrateDeep(c0, minSat: 0.40, maxSat: 0.80, light: 0.11);

      final List<Color> result = [
        c0,                 // 0: Dominant Rich Key Color
        secondaryWarm,      // 1: Harmonic Warm Tone
        accentCool,         // 2: Dynamic Contrast Accent
        luminousHighlight,  // 3: Glowing Luminous Highlight
        deepBase,           // 4: Deep Atmospheric Foundation
      ];

      _colorCache[imageId] = result;
      return result;
    } catch (e) {
      return [
        const Color(0xFFE64A19),
        const Color(0xFFFF7043),
        const Color(0xFF5E35B1),
        const Color(0xFFFFAB91),
        const Color(0xFF1A0A06),
      ];
    }
  }

  static double _colorDistance(Color a, Color b) {
    return (a.r - b.r).abs() * 255 +
        (a.g - b.g).abs() * 255 +
        (a.b - b.b).abs() * 255;
  }
}



