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
    final totalMs = targetTime.inMilliseconds;
    final currentMs = currentTime.inMilliseconds;
    final msLeft = totalMs - currentMs;

    // If already past target time, collapse
    if (msLeft <= 0) {
      return const SizedBox(width: double.infinity, height: 0);
    }

    // 1. Countdown phase (last 3 seconds before vocals start)
    // 3 dots -> 2 dots -> 1 dot -> 0 dots
    int visibleCount = 3;
    if (msLeft <= 750) {
      visibleCount = 0;
    } else if (msLeft <= 1750) {
      visibleCount = 1;
    } else if (msLeft <= 2750) {
      visibleCount = 2;
    }

    // 2. Progressive illumination phase (prior to final 3 seconds)
    // As the song intro plays, dots smoothly illuminate 1 -> 2 -> 3
    final fillWindowMs = (totalMs - 2750).clamp(1000, 30000);
    final fillProgress = (currentMs / fillWindowMs).clamp(0.0, 1.0);

    return AnimatedSize(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      child: Container(
        height: 36,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(3, (index) {
            final isVisible = index < visibleCount;
            
            // Progressive fill threshold for each dot: [0..0.33], [0.33..0.66], [0.66..1.0]
            final dotStart = index * 0.333;
            final dotEnd = (index + 1) * 0.333;
            final dotFill = ((fillProgress - dotStart) / (dotEnd - dotStart)).clamp(0.0, 1.0);

            // Interpolate opacity gently from 0.22 (unlit) to 0.95 (fully illuminated)
            final opacity = isVisible ? (0.22 + (0.73 * dotFill)) : 0.0;
            final scale = isVisible ? (0.85 + (0.25 * dotFill)) : 0.0;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.only(right: 14.0),
              width: isVisible ? 11 : 0,
              height: isVisible ? 11 : 0,
              child: AnimatedScale(
                scale: scale,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: opacity),
                    shape: BoxShape.circle,
                    boxShadow: dotFill > 0.6 && isVisible
                        ? [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.30 * dotFill),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
