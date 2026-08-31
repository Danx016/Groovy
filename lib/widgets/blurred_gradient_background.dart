import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:math' as math;

class BlurredGradientBackground extends StatefulWidget {
  final List<Color> colors;
  final ImageProvider? image;
  final Widget child;

  const BlurredGradientBackground({
    super.key,
    required this.colors,
    this.image,
    required this.child,
  });

  @override
  State<BlurredGradientBackground> createState() => _BlurredGradientBackgroundState();
}

class _BlurredGradientBackgroundState extends State<BlurredGradientBackground>
    with TickerProviderStateMixin {
  late AnimationController _motionController;
  late AnimationController _colorController;
  List<Color> _oldColors = [];
  List<Color> _targetColors = [];

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _targetColors = _normalizeColors(widget.colors);
    _oldColors = List<Color>.from(_targetColors);

    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  List<Color> _normalizeColors(List<Color> raw) {
    if (raw.isEmpty) {
      return [
        const Color(0xFFE64A19),
        const Color(0xFFFF7043),
        const Color(0xFF7B1FA2),
        const Color(0xFFFFAB91),
        const Color(0xFF100604),
      ];
    }
    final list = List<Color>.from(raw);
    while (list.length < 5) {
      list.add(list.last);
    }
    return list;
  }

  @override
  void didUpdateWidget(covariant BlurredGradientBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.colors != oldWidget.colors) {
      _oldColors = _getCurrentInterpolatedColors();
      _targetColors = _normalizeColors(widget.colors);
      _colorController.forward(from: 0.0);
    }
  }

  List<Color> _getCurrentInterpolatedColors() {
    final t = CurvedAnimation(
      parent: _colorController,
      curve: Curves.easeInOutCubic,
    ).value;

    final count = math.min(_oldColors.length, _targetColors.length);
    final result = <Color>[];
    for (int i = 0; i < count; i++) {
      result.add(Color.lerp(_oldColors[i], _targetColors[i], t) ?? _targetColors[i]);
    }
    return result.isEmpty ? _targetColors : result;
  }

  @override
  void dispose() {
    _motionController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Dark Foundation
        const ColoredBox(color: Colors.black),

        // 2. Blurred Artwork Ambient Anchor (Matches Apple Music's authentic tonal palette)
        if (widget.image != null)
          Positioned.fill(
            child: RepaintBoundary(
              child: Transform.scale(
                scale: 1.4,
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(
                    sigmaX: 70,
                    sigmaY: 70,
                    tileMode: TileMode.clamp,
                  ),
                  child: Image(
                    image: widget.image!,
                    fit: BoxFit.cover,
                    opacity: const AlwaysStoppedAnimation(0.58),
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ),
          ),

        // 3. Fluid Animated Mesh Light Orbs (Diffusion Blended)
        Positioned.fill(
          child: RepaintBoundary(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: 55,
                sigmaY: 55,
                tileMode: TileMode.clamp,
              ),
              child: AnimatedBuilder(
                animation: Listenable.merge([_motionController, _colorController]),
                builder: (context, _) {
                  final activeColors = _getCurrentInterpolatedColors();
                  return CustomPaint(
                    painter: _AppleMusicMeshPainter(
                      time: _motionController.value,
                      colors: activeColors,
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        // 4. Apple Music Atmospheric Vignette & Contrast Overlay
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.12),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.28),
                    Colors.black.withValues(alpha: 0.52),
                  ],
                  stops: const [0.0, 0.35, 0.72, 1.0],
                ),
              ),
            ),
          ),
        ),

        // 5. Child Content (Lyrics, Cover, Controls)
        Positioned.fill(
          child: RepaintBoundary(
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

class _AppleMusicMeshPainter extends CustomPainter {
  final double time; // 0.0 to 1.0 continuous loop
  final List<Color> colors;

  _AppleMusicMeshPainter({
    required this.time,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final c0 = colors[0]; // Primary Dominant Vibrant Tone
    final c1 = colors.length > 1 ? colors[1] : colors[0]; // Warm Harmonic Secondary
    final c2 = colors.length > 2 ? colors[2] : colors[0]; // Dynamic Contrast Accent
    final c3 = colors.length > 3 ? colors[3] : colors[1]; // Luminous Highlight
    final c4 = colors.length > 4 ? colors[4] : colors[0]; // Deep Base

    // Harmonic trigonometric angles for liquid flow
    final a1 = time * 2.0 * math.pi;
    final a2 = time * 4.0 * math.pi + 1.2;
    final a3 = time * 3.0 * math.pi + 2.4;
    final a4 = time * 2.0 * math.pi + 3.8;

    // Helper to draw a glowing liquid chromatic orb
    void drawOrb({
      required double centerX,
      required double centerY,
      required double radius,
      required Color color,
      double peakAlpha = 0.90,
    }) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: peakAlpha),
            color.withValues(alpha: peakAlpha * 0.70),
            color.withValues(alpha: peakAlpha * 0.30),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.35, 0.70, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(centerX, centerY), radius: radius));
      canvas.drawCircle(Offset(centerX, centerY), radius, paint);
    }

    // 1. Orb 1: Vibrant Key Color (Drifts across top-left, center & top-right)
    final n1X = w * 0.35 + (w * 0.32 * math.sin(a1)) + (w * 0.10 * math.cos(a2));
    final n1Y = h * 0.28 + (h * 0.22 * math.cos(a1)) + (h * 0.08 * math.sin(a2));
    final n1R = w * 1.35 + (w * 0.18 * math.sin(a1));
    drawOrb(centerX: n1X, centerY: n1Y, radius: n1R, color: c0, peakAlpha: 0.92);

    // 2. Orb 2: Warm Secondary (Swirling across bottom-right & center)
    final n2X = w * 0.65 - (w * 0.30 * math.cos(a1)) + (w * 0.10 * math.sin(a3));
    final n2Y = h * 0.65 - (h * 0.24 * math.sin(a1)) + (h * 0.08 * math.cos(a3));
    final n2R = w * 1.40 + (w * 0.15 * math.cos(a2));
    drawOrb(centerX: n2X, centerY: n2Y, radius: n2R, color: c1, peakAlpha: 0.90);

    // 3. Orb 3: Contrast Accent (Sweeping top-right to bottom-center)
    final n3X = w * 0.72 + (w * 0.24 * math.sin(a3)) - (w * 0.10 * math.cos(a1));
    final n3Y = h * 0.26 + (h * 0.22 * math.cos(a3)) + (h * 0.08 * math.sin(a1));
    final n3R = w * 1.25 + (w * 0.14 * math.sin(a3));
    drawOrb(centerX: n3X, centerY: n3Y, radius: n3R, color: c2, peakAlpha: 0.85);

    // 4. Orb 4: Luminous Center Highlight (Pulsing radiant core)
    final n4X = w * 0.50 + (w * 0.18 * math.sin(a2));
    final n4Y = h * 0.48 + (h * 0.16 * math.cos(a4));
    final n4R = w * 1.10 + (w * 0.16 * math.sin(a1));
    drawOrb(centerX: n4X, centerY: n4Y, radius: n4R, color: c3, peakAlpha: 0.80);

    // 5. Orb 5: Deep Chromatic Foundation (Bottom-left ambient anchor)
    final n5X = w * 0.22 + (w * 0.18 * math.cos(a4));
    final n5Y = h * 0.78 + (h * 0.15 * math.sin(a1));
    final n5R = w * 1.35 + (w * 0.12 * math.cos(a3));
    drawOrb(centerX: n5X, centerY: n5Y, radius: n5R, color: c4, peakAlpha: 0.88);
  }

  @override
  bool shouldRepaint(covariant _AppleMusicMeshPainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.colors != colors;
  }
}



