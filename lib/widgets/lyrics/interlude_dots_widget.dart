import 'dart:math' as math;
import 'package:flutter/material.dart';

class InterludeDotsWidget extends StatefulWidget {
  final Duration? currentTime;
  final Duration? targetTime;

  const InterludeDotsWidget({
    super.key,
    this.currentTime,
    this.targetTime,
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
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value * 2 * math.pi;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                final phase = index * (math.pi / 2.5);
                final wave = (math.sin(t + phase) + 1.0) / 2.0;
                final opacity = 0.35 + (0.55 * wave);
                final scale = 0.88 + (0.22 * wave);

                return Container(
                  margin: const EdgeInsets.only(right: 14.0),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: opacity),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }
}
