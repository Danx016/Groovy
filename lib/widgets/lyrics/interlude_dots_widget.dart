import 'dart:math' as math;
import 'package:flutter/material.dart';

class InterludeDotsWidget extends StatelessWidget {
  final Duration currentTime;
  final Duration targetTime;

  const InterludeDotsWidget({
    super.key,
    required this.currentTime,
    required this.targetTime,
  });

  @override
  Widget build(BuildContext context) {
    final ms = currentTime.inMilliseconds;
    // Fluid phase wave synchronized with track playback without background tickers
    final t = (ms % 1500) / 1500.0 * 2 * math.pi;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          final phase = index * (math.pi / 2.5);
          final wave = (math.sin(t + phase) + 1.0) / 2.0;
          final opacity = 0.35 + (0.55 * wave);
          final scale = 0.90 + (0.20 * wave);

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
  }
}
