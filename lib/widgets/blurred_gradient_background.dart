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
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeColors = widget.colors.isNotEmpty 
      ? List<Color>.from(widget.colors)
      : [const Color(0xFF7A5C38), const Color(0xFF9E7B4C), const Color(0xFF4A3520)];
      
    while (safeColors.length < 4) {
      safeColors.add(safeColors.last.withValues(alpha: 0.85));
    }

    return Stack(
      children: [
        // 1. Hardware accelerated custom painted gradient background
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _AppleMusicMeshPainter(
                animation: _controller,
                colors: safeColors,
              ),
            ),
          ),
        ),

        // 2. Subtle contrast overlay for crystal-clear readability
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.08),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.22),
                ],
                stops: const [0.0, 0.4, 1.0],
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
  }
}

class _AppleMusicMeshPainter extends CustomPainter {
  final Animation<double> animation;
  final List<Color> colors;

  _AppleMusicMeshPainter({
    required this.animation,
    required this.colors,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final w = size.width;
    final h = size.height;

    // 1. Draw base linear gradient
    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          colors[0].withValues(alpha: 0.95),
          colors[1].withValues(alpha: 0.88),
          colors[2].withValues(alpha: 0.92),
          colors[3].withValues(alpha: 0.95),
        ],
        stops: const [0.0, 0.35, 0.70, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), basePaint);

    // 2. Draw animated fluid radial blob 1 (Top / Center)
    final blob1Center = Offset(
      w * 0.3 + (w * 0.2 * math.sin(t * math.pi)),
      h * 0.15 + (h * 0.1 * math.cos(t * math.pi)),
    );
    final blob1Radius = w * 0.9;
    final blob1Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          colors[1].withValues(alpha: 0.85),
          colors[1].withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: blob1Center, radius: blob1Radius));
    canvas.drawCircle(blob1Center, blob1Radius, blob1Paint);

    // 3. Draw animated fluid radial blob 2 (Bottom / Right)
    final blob2Center = Offset(
      w * 0.75 - (w * 0.15 * math.cos(t * math.pi)),
      h * 0.75 - (h * 0.1 * math.sin(t * math.pi)),
    );
    final blob2Radius = w * 1.0;
    final blob2Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          colors[0].withValues(alpha: 0.80),
          colors[0].withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: blob2Center, radius: blob2Radius));
    canvas.drawCircle(blob2Center, blob2Radius, blob2Paint);

    // 4. Draw animated pulsating blob 3 (Middle / Left)
    final blob3Center = Offset(
      w * 0.25 + (w * 0.1 * math.sin(t * math.pi * 2)),
      h * 0.50 + (h * 0.15 * math.cos(t * math.pi * 2)),
    );
    final blob3Radius = w * 0.75;
    final blob3Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          colors[2].withValues(alpha: 0.75),
          colors[2].withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: blob3Center, radius: blob3Radius));
    canvas.drawCircle(blob3Center, blob3Radius, blob3Paint);
  }

  @override
  bool shouldRepaint(covariant _AppleMusicMeshPainter oldDelegate) {
    return true;
  }
}
