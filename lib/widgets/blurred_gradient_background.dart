import 'package:flutter/material.dart';
import 'dart:math' as math;

class BlurredGradientBackground extends StatefulWidget {
  final List<Color> colors;
  final Widget child;

  const BlurredGradientBackground({
    super.key,
    required this.colors,
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
      duration: const Duration(seconds: 18),
    )..repeat();

    _targetColors = _normalizeColors(widget.colors);
    _oldColors = List<Color>.from(_targetColors);

    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
  }

  List<Color> _normalizeColors(List<Color> raw) {
    if (raw.isEmpty) {
      return [
        const Color(0xFFC76020),
        const Color(0xFFE88A38),
        const Color(0xFF8B3A12),
        const Color(0xFF4A1E0B),
      ];
    }
    final list = List<Color>.from(raw);
    while (list.length < 4) {
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
    final t = _colorController.value;
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
    return AnimatedBuilder(
      animation: Listenable.merge([_motionController, _colorController]),
      builder: (context, _) {
        final activeColors = _getCurrentInterpolatedColors();
        return Stack(
          children: [
            // 1. Hardware accelerated fluid animated mesh gradient
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _AppleMusicMeshPainter(
                    time: _motionController.value,
                    colors: activeColors,
                  ),
                ),
              ),
            ),

            // 2. Ultra-subtle Apple Music contrast overlay for perfect text readability
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.04),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.20),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),

            // 3. Child content isolated in its own render layer
            RepaintBoundary(
              child: widget.child,
            ),
          ],
        );
      },
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

    final c0 = colors[0]; // Primary Dominant tone (Artwork ambient anchor)
    final c1 = colors.length > 1 ? colors[1] : colors[0]; // Secondary Warm / Body tone
    final c2 = colors.length > 2 ? colors[2] : colors[0]; // Accent Contrast tone (e.g. Cobalt Blue or Cyan)
    final c3 = colors.length > 3 ? colors[3] : colors[1]; // Vibrant Highlight (e.g. Golden / Amber pulse)
    final c4 = colors.length > 4 ? colors[4] : colors[0]; // Deep Ambient Depth

    final angle = time * 2 * math.pi;

    // 1. Base luminous ambient gradient anchored by dominant tone c0
    final baseGradient = LinearGradient(
      begin: Alignment(
        0.3 * math.cos(angle * 0.7),
        -1.0 + 0.15 * math.sin(angle * 0.8),
      ),
      end: Alignment(
        -0.3 * math.cos(angle * 0.8),
        1.0 - 0.15 * math.sin(angle * 0.7),
      ),
      colors: [
        c0.withValues(alpha: 0.95),
        c0.withValues(alpha: 0.90),
        c1.withValues(alpha: 0.88),
        c4.withValues(alpha: 0.92),
      ],
      stops: const [0.0, 0.40, 0.75, 1.0],
    );

    final basePaint = Paint()
      ..shader = baseGradient.createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), basePaint);

    // Helper to paint a diffused luminous radial blob
    void drawBlob({
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
            color.withValues(alpha: peakAlpha * 0.65),
            color.withValues(alpha: peakAlpha * 0.20),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.38, 0.72, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(centerX, centerY), radius: radius));
      canvas.drawCircle(Offset(centerX, centerY), radius, paint);
    }

    // 2. Node 1: Top-Left Dominant Luminous Swell
    final n1X = w * 0.25 + (w * 0.18 * math.sin(angle * 0.9));
    final n1Y = h * 0.22 + (h * 0.14 * math.cos(angle * 1.1));
    final n1R = w * 1.25 + (w * 0.12 * math.sin(angle * 0.8));
    drawBlob(centerX: n1X, centerY: n1Y, radius: n1R, color: c0, peakAlpha: 0.92);

    // 3. Node 2: Top-Right Accent Contrast Floating Light (e.g. Cobalt Blue or Contrast)
    final n2X = w * 0.82 + (w * 0.16 * math.cos(angle * 0.8));
    final n2Y = h * 0.25 + (h * 0.16 * math.sin(angle * 1.3));
    final n2R = w * 1.10 + (w * 0.10 * math.cos(angle * 0.7));
    drawBlob(centerX: n2X, centerY: n2Y, radius: n2R, color: c2, peakAlpha: 0.85);

    // 4. Node 3: Bottom-Right Fiery Body Warmth
    final n3X = w * 0.80 + (w * 0.18 * math.sin(angle * 1.2));
    final n3Y = h * 0.78 + (h * 0.15 * math.cos(angle * 0.9));
    final n3R = w * 1.35 + (w * 0.15 * math.sin(angle * 1.0));
    drawBlob(centerX: n3X, centerY: n3Y, radius: n3R, color: c1, peakAlpha: 0.92);

    // 5. Node 4: Bottom-Left Ambient Glow
    final n4X = w * 0.18 + (w * 0.15 * math.cos(angle * 1.4));
    final n4Y = h * 0.75 + (h * 0.16 * math.sin(angle * 1.0));
    final n4R = w * 1.15 + (w * 0.12 * math.cos(angle * 1.2));
    drawBlob(centerX: n4X, centerY: n4Y, radius: n4R, color: c4, peakAlpha: 0.88);

    // 6. Node 5: Center Vibrant Pulse Highlight
    final n5X = w * 0.50 + (w * 0.12 * math.sin(angle * 1.6));
    final n5Y = h * 0.45 + (h * 0.12 * math.cos(angle * 1.5));
    final n5R = w * 1.05 + (w * 0.10 * math.sin(angle * 1.4));
    drawBlob(centerX: n5X, centerY: n5Y, radius: n5R, color: c3, peakAlpha: 0.75);
  }

  @override
  bool shouldRepaint(covariant _AppleMusicMeshPainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.colors != colors;
  }
}


