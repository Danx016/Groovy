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

  static const List<String> _fontFallback = [
    '-apple-system',
    'BlinkMacSystemFont',
    'SF Pro Display',
    'SF Pro Text',
    'Inter',
    'Segoe UI',
    'Roboto',
    'sans-serif',
  ];

  static const List<Shadow> _currentLineShadow = [
    Shadow(
      color: Color(0x99000000),
      blurRadius: 20,
      offset: Offset(0, 4),
    ),
    Shadow(
      color: Color(0x40000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isCurrent = widget.state == LyricLineState.current;
    final isPast = widget.state == LyricLineState.past;

    // Authentic Apple Music Opacity Hierarchy
    final double targetOpacity = widget.isUnsynced
        ? 0.95
        : (isCurrent
            ? 1.0
            : (_isHovered
                ? 0.80
                : (widget.distance == 1
                    ? 0.42
                    : (widget.distance == 2
                        ? 0.26
                        : (isPast ? 0.22 : 0.18)))));

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
            padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 28.0),
            child: AnimatedScale(
              scale: isCurrent ? 1.03 : (_isHovered ? 0.98 : 0.96),
              alignment: Alignment.centerLeft,
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeInOutCubic,
              child: AnimatedOpacity(
                opacity: targetOpacity,
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeInOutCubic,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeInOutCubic,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: isHighlighted ? FontWeight.w800 : FontWeight.w700,
                    letterSpacing: -0.6,
                    color: Colors.white,
                    height: 1.22,
                    fontFamilyFallback: _fontFallback,
                    shadows: isCurrent ? _currentLineShadow : null,
                  ),
                  child: Text(widget.line.text),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
