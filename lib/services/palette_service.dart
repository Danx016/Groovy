import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

class PaletteService {
  static final Map<String, List<Color>> _colorCache = {};

  /// Extracts rich, authentic Apple Music ambient color palettes.
  /// Generates deep, warm, radiant tones that dynamically animate across the background.
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

      Color calibrateTone(Color c, {double minSat = 0.30, double maxSat = 0.70, double minLight = 0.26, double maxLight = 0.48}) {
        final hsl = HSLColor.fromColor(c);
        final sat = hsl.saturation.clamp(minSat, maxSat);
        final light = hsl.lightness.clamp(minLight, maxLight);
        return hsl.withSaturation(sat).withLightness(light).toColor();
      }

      Color calibrateHighlight(Color c, {double minSat = 0.40, double maxSat = 0.80, double minLight = 0.45, double maxLight = 0.60}) {
        final hsl = HSLColor.fromColor(c);
        final sat = hsl.saturation.clamp(minSat, maxSat);
        final light = hsl.lightness.clamp(minLight, maxLight);
        return hsl.withSaturation(sat).withLightness(light).toColor();
      }

      Color calibrateDeep(Color c, {double minSat = 0.25, double maxSat = 0.55, double light = 0.12}) {
        final hsl = HSLColor.fromColor(c);
        final sat = hsl.saturation.clamp(minSat, maxSat);
        return hsl.withSaturation(sat).withLightness(light).toColor();
      }

      // 1. Determine primary dominant tone
      Color? dominant;
      if (palette.vibrantColor != null) {
        dominant = palette.vibrantColor!.color;
      } else if (palette.dominantColor != null) {
        dominant = palette.dominantColor!.color;
      } else if (palette.lightVibrantColor != null) {
        dominant = palette.lightVibrantColor!.color;
      } else if (palette.mutedColor != null) {
        dominant = palette.mutedColor!.color;
      } else if (palette.darkVibrantColor != null) {
        dominant = palette.darkVibrantColor!.color;
      } else if (palette.paletteColors.isNotEmpty) {
        dominant = palette.paletteColors.first.color;
      }
      dominant ??= const Color(0xFFB86B35); // Warm amber default

      final c0 = calibrateTone(dominant, minSat: 0.35, maxSat: 0.75, minLight: 0.28, maxLight: 0.48);
      final domHsl = HSLColor.fromColor(c0);

      // 2. Candidate swatches
      final candidates = <Color>[];
      if (palette.lightVibrantColor != null) candidates.add(palette.lightVibrantColor!.color);
      if (palette.vibrantColor != null) candidates.add(palette.vibrantColor!.color);
      if (palette.dominantColor != null) candidates.add(palette.dominantColor!.color);
      if (palette.mutedColor != null) candidates.add(palette.mutedColor!.color);
      if (palette.lightMutedColor != null) candidates.add(palette.lightMutedColor!.color);

      for (final pc in palette.paletteColors) {
        if (!candidates.contains(pc.color)) {
          candidates.add(pc.color);
        }
      }

      Color? secondaryWarm;
      Color? accentCool;
      Color? luminousHighlight;

      for (final raw in candidates) {
        final hsl = HSLColor.fromColor(raw);
        if (hsl.lightness < 0.06 || hsl.lightness > 0.94) continue;

        final hueDiff = (hsl.hue - domHsl.hue).abs();
        final normalizedDiff = hueDiff > 180 ? 360 - hueDiff : hueDiff;

        if (normalizedDiff > 30 && accentCool == null) {
          accentCool = calibrateTone(raw, minSat: 0.30, maxSat: 0.65, minLight: 0.26, maxLight: 0.44);
        } else if (normalizedDiff <= 30 && secondaryWarm == null && _colorDistance(raw, c0) > 20) {
          secondaryWarm = calibrateTone(raw, minSat: 0.35, maxSat: 0.70, minLight: 0.30, maxLight: 0.46);
        } else if (luminousHighlight == null && _colorDistance(raw, c0) > 25) {
          luminousHighlight = calibrateHighlight(raw, minSat: 0.40, maxSat: 0.80, minLight: 0.45, maxLight: 0.60);
        }
      }

      secondaryWarm ??= domHsl.withHue((domHsl.hue + 22) % 360).withSaturation((domHsl.saturation * 1.05).clamp(0.35, 0.70)).withLightness(0.36).toColor();
      accentCool ??= domHsl.withHue((domHsl.hue + 45) % 360).withSaturation(0.45).withLightness(0.30).toColor();
      luminousHighlight ??= domHsl.withHue((domHsl.hue + 12) % 360).withSaturation(0.60).withLightness(0.50).toColor();

      final deepBase = calibrateDeep(c0, minSat: 0.30, maxSat: 0.60, light: 0.12);

      final List<Color> result = [
        c0,                 // 0: Primary Ambient Key Tone
        secondaryWarm,      // 1: Harmonic Warm Tone
        accentCool,         // 2: Dynamic Accent
        luminousHighlight,  // 3: Radiant Sunlight Glow Highlight
        deepBase,           // 4: Deep Atmospheric Foundation
      ];

      _colorCache[imageId] = result;
      return result;
    } catch (e) {
      return [
        const Color(0xFFB86B35),
        const Color(0xFF8B4513),
        const Color(0xFFD27D2D),
        const Color(0xFFE89A4B),
        const Color(0xFF3B1E08),
      ];
    }
  }

  static double _colorDistance(Color a, Color b) {
    return (a.r - b.r).abs() * 255 +
        (a.g - b.g).abs() * 255 +
        (a.b - b.b).abs() * 255;
  }
}
