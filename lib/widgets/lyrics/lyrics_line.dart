import 'package:flutter/material.dart';
import '../../models/lyric_line.dart';

enum LyricLineState { past, current, future }

class LyricsLineWidget extends StatefulWidget {
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
  State<LyricsLineWidget> createState() => _LyricsLineWidgetState();
}

class _LyricsLineWidgetState extends State<LyricsLineWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isCurrent = widget.state == LyricLineState.current;
    final isPast = widget.state == LyricLineState.past;

    // Authentic Apple Music Opacity Hierarchy
    final double targetOpacity = widget.isUnsynced
        ? 0.92
        : (isCurrent
            ? 1.0
            : (_isHovered
                ? 0.72
                : (widget.distance == 1
                    ? 0.38
                    : (isPast ? 0.24 : 0.20))));

    final isHighlighted = isCurrent || widget.isUnsynced;

    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 28.0),
            child: AnimatedScale(
              scale: isCurrent ? 1.0 : (_isHovered ? 0.985 : 0.97),
              alignment: Alignment.centerLeft,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontSize: isHighlighted ? 36 : 30,
                  fontWeight: isHighlighted ? FontWeight.w800 : FontWeight.w700,
                  letterSpacing: -0.6,
                  color: Colors.white.withValues(alpha: targetOpacity),
                  height: 1.2,
                  fontFamilyFallback: const [
                    '-apple-system',
                    'BlinkMacSystemFont',
                    'SF Pro Display',
                    'Roboto',
                    'sans-serif',
                  ],
                  shadows: isCurrent
                      ? [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Text(widget.line.text),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
