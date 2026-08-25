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
    return Stack(
      children: [
        // 1. Hardware accelerated fluid animated mesh gradient (isolated in render layer)
        Positioned.fill(
          child: RepaintBoundary(
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

        // 2. Ultra-subtle Apple Music contrast overlay for perfect text readability
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
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
        ),

        // 3. Child content isolated in its own render layer — NEVER rebuilt on background motion ticks!
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

    final c0 = colors[0]; // Primary Dominant tone (Artwork ambient anchor)
    final c1 = colors.length > 1 ? colors[1] : colors[0]; // Secondary Warm tone
    final c2 = colors.length > 2 ? colors[2] : colors[0]; // Accent Contrast tone
    final c3 = colors.length > 3 ? colors[3] : colors[1]; // Subtle Highlight tone
    final c4 = colors.length > 4 ? colors[4] : colors[0]; // Deep Ambient Depth

    // Pure 2*pi angle with exact integer harmonics for a 100% mathematically seamless loop
    final a1 = time * 2.0 * math.pi;     // 1x fundamental cycle
    final a2 = time * 4.0 * math.pi;     // 2x harmonic cycle
    final a3 = time * 6.0 * math.pi;     // 3x harmonic cycle

    // 1. Deep Atmospheric Foundation Gradient
    final baseGradient = LinearGradient(
      begin: Alignment(
        0.35 * math.cos(a1),
        -1.0 + 0.20 * math.sin(a1),
      ),
      end: Alignment(
        -0.35 * math.cos(a1),
        1.0 - 0.20 * math.sin(a1),
      ),
      colors: [
        c0.withValues(alpha: 0.95),
        c1.withValues(alpha: 0.90),
        c4.withValues(alpha: 0.92),
        c4.withValues(alpha: 0.98),
      ],
      stops: const [0.0, 0.35, 0.70, 1.0],
    );

    final basePaint = Paint()
      ..shader = baseGradient.createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), basePaint);

    // Helper to paint a diffused luminous radial blob with multi-stop Gaussian falloff
    void drawBlob({
      required double centerX,
      required double centerY,
      required double radius,
      required Color color,
      double peakAlpha = 0.85,
    }) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: peakAlpha),
            color.withValues(alpha: peakAlpha * 0.70),
            color.withValues(alpha: peakAlpha * 0.35),
            color.withValues(alpha: peakAlpha * 0.10),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.30, 0.60, 0.82, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(centerX, centerY), radius: radius));
      canvas.drawCircle(Offset(centerX, centerY), radius, paint);
    }

    // 2. Node 1: Top-Left to Center-Right Organic Flow
    final n1X = w * 0.30 + (w * 0.25 * math.sin(a1)) + (w * 0.08 * math.cos(a2));
    final n1Y = h * 0.25 + (h * 0.18 * math.cos(a1)) + (h * 0.06 * math.sin(a2));
    final n1R = w * 1.30 + (w * 0.15 * math.sin(a1));
    drawBlob(centerX: n1X, centerY: n1Y, radius: n1R, color: c0, peakAlpha: 0.88);

    // 3. Node 2: Top-Right to Bottom-Center Accent Drift (Cool/Accent depth)
    final n2X = w * 0.75 + (w * 0.22 * math.cos(a1)) - (w * 0.07 * math.sin(a2));
    final n2Y = h * 0.30 + (h * 0.20 * math.sin(a1)) + (h * 0.08 * math.cos(a2));
    final n2R = w * 1.15 + (w * 0.12 * math.cos(a1));
    drawBlob(centerX: n2X, centerY: n2Y, radius: n2R, color: c2, peakAlpha: 0.78);

    // 4. Node 3: Bottom-Right to Top-Center Warm Flow
    final n3X = w * 0.70 - (w * 0.26 * math.sin(a1)) + (w * 0.06 * math.sin(a3));
    final n3Y = h * 0.75 - (h * 0.22 * math.cos(a1)) + (h * 0.05 * math.cos(a2));
    final n3R = w * 1.35 + (w * 0.16 * math.cos(a1));
    drawBlob(centerX: n3X, centerY: n3Y, radius: n3R, color: c1, peakAlpha: 0.88);

    // 5. Node 4: Bottom-Left to Center Ambient Depth
    final n4X = w * 0.22 + (w * 0.20 * math.cos(a1)) + (w * 0.08 * math.sin(a2));
    final n4Y = h * 0.70 + (h * 0.18 * math.sin(a1)) - (h * 0.06 * math.cos(a3));
    final n4R = w * 1.20 + (w * 0.14 * math.sin(a2));
    drawBlob(centerX: n4X, centerY: n4Y, radius: n4R, color: c4, peakAlpha: 0.82);

    // 6. Node 5: Center Fluid Highlight Pulse
    final n5X = w * 0.50 + (w * 0.15 * math.sin(a2));
    final n5Y = h * 0.48 + (h * 0.14 * math.cos(a2));
    final n5R = w * 1.05 + (w * 0.12 * math.cos(a1));
    drawBlob(centerX: n5X, centerY: n5Y, radius: n5R, color: c3, peakAlpha: 0.65);
  }

  @override
  bool shouldRepaint(covariant _AppleMusicMeshPainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.colors != colors;
  }
}


