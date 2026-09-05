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

    // Authentic Apple Music Opacity Hierarchy
    final double targetOpacity = isUnsynced
        ? 0.95
        : (isCurrent
            ? 1.0
            : (distance == 1
                ? 0.48
                : (isPast ? 0.24 : 0.16)));

    final isHighlighted = isCurrent || isUnsynced;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 24.0),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              fontSize: 32,
              fontWeight: isHighlighted ? FontWeight.w800 : FontWeight.w700,
              letterSpacing: -0.6,
              color: Colors.white.withValues(alpha: targetOpacity),
              height: 1.25,
              fontFamilyFallback: const [
                '-apple-system',
                'BlinkMacSystemFont',
                'SF Pro Display',
                'Roboto',
                'sans-serif',
              ],
              shadows: isCurrent
                  ? const [
                      Shadow(
                        color: Colors.black45,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(line.text),
          ),
        ),
      ),
    );
  }
}
