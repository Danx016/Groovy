import 'dart:io';
import 'package:flutter/foundation.dart';
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

  static final List<String> _fontFallback = !kIsWeb && Platform.isAndroid
      ? const ['Roboto', 'sans-serif']
      : const [
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
      color: Color(0x33000000),
      blurRadius: 2,
      offset: Offset(0, 1.5),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isCurrent = widget.state == LyricLineState.current;

    // Authentic Apple Music Opacity: Active is 100% pure white, inactive lines are 38% dimmed white
    final double targetOpacity = widget.isUnsynced
        ? 0.95
        : (isCurrent
            ? 1.0
            : (_isHovered
                ? 0.75
                : (widget.distance == 1
                    ? 0.40
                    : 0.36)));

    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13.0, horizontal: 28.0),
            child: AnimatedScale(
              scale: isCurrent ? 1.025 : 1.0,
              alignment: Alignment.centerLeft,
              duration: const Duration(milliseconds: 550),
              curve: const Cubic(0.25, 0.1, 0.25, 1.0),
              child: AnimatedOpacity(
                opacity: targetOpacity,
                duration: const Duration(milliseconds: 550),
                curve: const Cubic(0.25, 0.1, 0.25, 1.0),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 550),
                  curve: const Cubic(0.25, 0.1, 0.25, 1.0),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: Colors.white,
                    height: 1.25,
                    fontFamilyFallback: _fontFallback,
                    shadows: _currentLineShadow,
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
