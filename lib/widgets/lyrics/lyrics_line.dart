import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/lyric_line.dart';

enum LyricLineState { past, current, future }

/// Whether we're running on a mobile (touch) platform where hover is irrelevant.
final bool _isMobilePlatform =
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

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

  static final TextStyle _lyricTextStyle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: Colors.white,
    height: 1.25,
    fontFamilyFallback: _fontFallback,
  );

  @override
  Widget build(BuildContext context) {
    final isCurrent = widget.state == LyricLineState.current;

    // Authentic Apple Music Opacity: Active is 100% pure white, inactive lines are 38% dimmed white
    final double targetOpacity = widget.isUnsynced
        ? 0.95
        : (isCurrent
            ? 1.0
            : (_isHovered ? 0.75 : 0.38));

    // Fluid Apple Music style animation: smooth scale up on active line
    // and smooth opacity cross-fade between active and dimmed lines.
    // RepaintBoundary isolates the text raster on its own GPU layer so scale animations
    // execute as hardware matrix transforms at 120 FPS without re-rasterizing text glyphs.
    Widget content = AnimatedScale(
      scale: isCurrent ? 1.025 : 1.0,
      alignment: Alignment.centerLeft,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: RepaintBoundary(
        child: AnimatedOpacity(
          opacity: targetOpacity,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          child: Text(
            widget.line.text,
            style: _lyricTextStyle,
          ),
        ),
      ),
    );

    // On mobile (Android/iOS) skip MouseRegion entirely — no hover on touch
    if (_isMobilePlatform) {
      return RepaintBoundary(
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13.0, horizontal: 28.0),
            child: content,
          ),
        ),
      );
    }

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
            child: content,
          ),
        ),
      ),
    );
  }
}
