import 'package:flutter/material.dart';

class AnimatedEqualizer extends StatefulWidget {
  final Color color;
  final bool isPlaying;

  const AnimatedEqualizer({
    super.key,
    required this.color,
    required this.isPlaying,
  });

  @override
  State<AnimatedEqualizer> createState() => _AnimatedEqualizerState();
}

class _AnimatedEqualizerState extends State<AnimatedEqualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(AnimatedEqualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        if (!_controller.isAnimating) _controller.repeat();
      } else {
        _controller.stop();
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
    return RepaintBoundary(
      child: CustomPaint(
        size: const Size(15, 16),
        painter: _EqualizerBarsPainter(
          animation: _controller,
          color: widget.color,
          isPlaying: widget.isPlaying,
        ),
      ),
    );
  }
}

class _EqualizerBarsPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;
  final bool isPlaying;

  _EqualizerBarsPainter({
    required this.animation,
    required this.color,
    required this.isPlaying,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;

    const barWidth = 3.0;
    const barRadius = Radius.circular(2.0);
    const offsets = [0.0, 0.4, 0.75];
    const speeds = [1.0, 1.4, 0.9];

    for (int i = 0; i < 3; i++) {
      final double progress;
      if (!isPlaying) {
        progress = 0.0;
      } else {
        final t = (animation.value * speeds[i] + offsets[i]) % 1.0;
        progress = (t <= 0.5) ? t * 2.0 : (1.0 - t) * 2.0;
      }
      final barHeight = 4.0 + 12.0 * progress;
      final x = 1.0 + i * 5.0;
      final y = size.height - barHeight;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          barRadius,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_EqualizerBarsPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isPlaying != isPlaying;
  }
}
