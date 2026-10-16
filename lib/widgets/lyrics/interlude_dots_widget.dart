import 'dart:math' as math;
import 'package:flutter/material.dart';

class InterludeDotsWidget extends StatefulWidget {
  final Duration? currentTime;
  final Duration? targetTime;
  final bool isAnimating;

  const InterludeDotsWidget({
    super.key,
    this.currentTime,
    this.targetTime,
    this.isAnimating = true,
  });

  @override
  State<InterludeDotsWidget> createState() => _InterludeDotsWidgetState();
}

class _InterludeDotsWidgetState extends State<InterludeDotsWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant InterludeDotsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating != oldWidget.isAnimating) {
      if (widget.isAnimating) {
        if (!_controller.isAnimating) {
          _controller.repeat();
        }
      } else {
        if (_controller.isAnimating) {
          _controller.stop();
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isAnimating) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: SizedBox(
          width: 61,
          height: 27,
          child: CustomPaint(
            painter: _StaticDotsPainter(),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: SizedBox(
        width: 61,
        height: 27,
        child: CustomPaint(
          painter: _AnimatedDotsPainter(animation: _controller),
        ),
      ),
    );
  }
}

class _StaticDotsPainter extends CustomPainter {
  const _StaticDotsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.30)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    const baseRadius = 5.5 * 0.88;
    final centerY = size.height / 2;

    canvas.drawCircle(Offset(5.5, centerY), baseRadius, paint);
    canvas.drawCircle(Offset(30.5, centerY), baseRadius, paint);
    canvas.drawCircle(Offset(55.5, centerY), baseRadius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AnimatedDotsPainter extends CustomPainter {
  final Animation<double> animation;

  _AnimatedDotsPainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final t = animation.value * 2 * math.pi;
    final centerY = size.height / 2;
    const double baseRadius = 5.5;

    for (int index = 0; index < 3; index++) {
      final phase = index * (math.pi / 2.5);
      final wave = (math.sin(t + phase) + 1.0) / 2.0;
      final opacity = 0.35 + (0.55 * wave);
      final scale = 0.88 + (0.22 * wave);

      paint.color = Colors.white.withValues(alpha: opacity);
      final centerX = 5.5 + (index * 25.0);
      canvas.drawCircle(Offset(centerX, centerY), baseRadius * scale, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AnimatedDotsPainter oldDelegate) => true;
}
