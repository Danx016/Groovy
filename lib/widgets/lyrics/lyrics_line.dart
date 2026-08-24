import 'package:flutter/material.dart';
import '../../models/lyric_line.dart';

enum LyricLineState { past, current, future }

class LyricsLineWidget extends StatelessWidget {
  final LyricLine line;
  final LyricLineState state;
  final Duration currentTime;
  final VoidCallback onTap;
  final int distance;

  const LyricsLineWidget({
    super.key,
    required this.line,
    required this.state,
    required this.currentTime,
    required this.onTap,
    this.distance = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrent = state == LyricLineState.current;
    final isPast = state == LyricLineState.past;

    final targetOpacity = isCurrent ? 1.0 : (isPast ? 0.40 : 0.28);
    final targetScale = isCurrent ? 1.0 : 0.94;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 28.0),
        child: AnimatedScale(
          scale: targetScale,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: Alignment.centerLeft,
          child: AnimatedOpacity(
            opacity: targetOpacity,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: _buildText(isCurrent),
          ),
        ),
      ),
    );
  }

  Widget _buildText(bool isCurrent) {
    if (isCurrent && line.hasWords) {
      return _buildWordByWord();
    }

    return Text(
      line.text,
      style: TextStyle(
        fontSize: isCurrent ? 32 : 28,
        fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w800,
        letterSpacing: -0.6,
        color: Colors.white,
        height: 1.25,
        shadows: isCurrent
            ? [
                const Shadow(
                  color: Colors.black54,
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
    );
  }

  Widget _buildWordByWord() {
    return RichText(
      text: TextSpan(
        children: line.words!.map((word) {
          double progress = 0.0;
          if (currentTime >= word.startTime && currentTime <= word.endTime) {
            final duration = word.endTime.inMilliseconds - word.startTime.inMilliseconds;
            final elapsed = currentTime.inMilliseconds - word.startTime.inMilliseconds;
            progress = (elapsed / (duration > 0 ? duration : 1)).clamp(0.0, 1.0);
          } else if (currentTime > word.endTime) {
            progress = 1.0;
          }

          return WidgetSpan(
            child: ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  colors: const [
                    Colors.white,
                    Colors.white,
                    Colors.white38,
                    Colors.white38,
                  ],
                  stops: [
                    0.0,
                    progress,
                    progress,
                    1.0,
                  ],
                ).createShader(bounds);
              },
              child: Text(
                '${word.text} ',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                  color: Colors.white,
                  height: 1.25,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 20,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
