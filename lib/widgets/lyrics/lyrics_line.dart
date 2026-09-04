import 'package:flutter/material.dart';
import '../../models/lyric_line.dart';

enum LyricLineState { past, current, future }

class LyricsLineWidget extends StatelessWidget {
  final LyricLine line;
  final LyricLineState state;
  final VoidCallback onTap;
  final int distance;
  final bool isUnsynced;

  const LyricsLineWidget({
    super.key,
    required this.line,
    required this.state,
    required this.onTap,
    this.distance = 0,
    this.isUnsynced = false,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrent = state == LyricLineState.current;
    final isPast = state == LyricLineState.past;

    // Authentic Apple Music Opacity Hierarchy (Direct Single-Pass Render)
    final double targetOpacity = isUnsynced
        ? 0.92
        : (isCurrent
            ? 1.0
            : (distance == 1
                ? 0.42
                : (isPast ? 0.24 : 0.18)));

    final isHighlighted = isCurrent || isUnsynced;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          style: TextStyle(
            fontSize: isHighlighted ? 33 : 30,
            fontWeight: isHighlighted ? FontWeight.w800 : FontWeight.w700,
            letterSpacing: isHighlighted ? -0.8 : -0.5,
            color: Colors.white.withValues(alpha: targetOpacity),
            height: 1.24,
            fontFamilyFallback: const [
              '-apple-system',
              'BlinkMacSystemFont',
              'SF Pro Display',
              'SF Pro Text',
              'Inter',
              'Roboto',
              'sans-serif',
            ],
            shadows: isCurrent
                ? [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.40),
                      blurRadius: 14,
                      offset: const Offset(0, 3),
                    ),
                    Shadow(
                      color: Colors.white.withValues(alpha: 0.20),
                      blurRadius: 18,
                      offset: Offset.zero,
                    ),
                  ]
                : (isUnsynced
                    ? [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null),
          ),
          child: Text(line.text),
        ),
      ),
    );
  }
}
