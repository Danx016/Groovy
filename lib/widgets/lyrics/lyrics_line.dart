import 'dart:ui';
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 28.0),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (state) {
      case LyricLineState.past:
        return SizedBox(
          key: const ValueKey('past'),
          width: double.infinity,
          child: Text(
            line.text,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              height: 1.3,
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ),
        );
      case LyricLineState.future:
        final double sigma = (distance * 0.7).clamp(0.0, 2.5);
        return SizedBox(
          key: const ValueKey('future'),
          width: double.infinity,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: Text(
              line.text,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                height: 1.3,
                color: Colors.white.withValues(alpha: 0.28),
              ),
            ),
          ),
        );
      case LyricLineState.current:
        return SizedBox(
          key: const ValueKey('current'),
          width: double.infinity,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 1.0, end: 1.04),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                alignment: Alignment.centerLeft,
                child: child,
              );
            },
            child: line.hasWords 
                ? _buildWordByWord() 
                : _buildLineLevel(),
          ),
        );
    }
  }

  Widget _buildLineLevel() {
    return Text(
      line.text,
      style: const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.7,
        color: Colors.white,
        height: 1.28,
        shadows: [
          Shadow(
            color: Colors.black38,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
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
                  colors: [
                    Colors.white,
                    Colors.white.withValues(alpha: 0.35),
                  ],
                  stops: [progress, progress],
                ).createShader(bounds);
              },
              child: Text(
                '${word.text} ',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                  color: Colors.white,
                  height: 1.28,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
