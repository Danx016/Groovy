import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PlaybackProgressSlider extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final bool isBuffering;
  final ValueChanged<Duration> onChanged;
  final Color accentColor;

  const PlaybackProgressSlider({
    super.key,
    required this.position,
    required this.duration,
    this.bufferedPosition = Duration.zero,
    this.isBuffering = false,
    required this.onChanged,
    required this.accentColor,
  });

  @override
  State<PlaybackProgressSlider> createState() => _PlaybackProgressSliderState();
}

class _PlaybackProgressSliderState extends State<PlaybackProgressSlider>
    with SingleTickerProviderStateMixin {
  bool _isDragging = false;
  double _dragValue = 0.0;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) duration = Duration.zero;
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = duration.inMinutes.remainder(60);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${duration.inHours}:${twoDigits(minutes)}:$seconds";
    }
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final maxDuration = widget.duration.inMilliseconds.toDouble();
    final currentDuration = _isDragging 
        ? _dragValue 
        : widget.position.inMilliseconds.toDouble();
        
    final safeMax = maxDuration > 0 ? maxDuration : 1.0;
    final progress = (currentDuration / safeMax).clamp(0.0, 1.0);
    final bufferedProgress = (widget.bufferedPosition.inMilliseconds / safeMax).clamp(0.0, 1.0);
    final remainingMillis = (safeMax - currentDuration).clamp(0.0, safeMax);
    final remainingDuration = Duration(milliseconds: remainingMillis.toInt());

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) {
            HapticFeedback.selectionClick();
            setState(() {
              _isDragging = true;
            });
          },
          onHorizontalDragUpdate: (details) {
            final box = context.findRenderObject() as RenderBox;
            final dx = details.localPosition.dx.clamp(0.0, box.size.width);
            setState(() {
              _dragValue = (dx / box.size.width) * safeMax;
            });
          },
          onHorizontalDragEnd: (details) {
            setState(() {
              _isDragging = false;
            });
            HapticFeedback.lightImpact();
            widget.onChanged(Duration(milliseconds: _dragValue.toInt()));
          },
          onTapDown: (details) {
            final box = context.findRenderObject() as RenderBox;
            final dx = details.localPosition.dx.clamp(0.0, box.size.width);
            final tapValue = (dx / box.size.width) * safeMax;
            HapticFeedback.selectionClick();
            widget.onChanged(Duration(milliseconds: tapValue.toInt()));
          },
          child: Container(
            height: 28, // Tappable hit target
            alignment: Alignment.center,
            child: AnimatedBuilder(
              animation: _shimmerController,
              builder: (context, _) {
                return CustomPaint(
                  size: const Size(double.infinity, 28),
                  painter: _SliderPainter(
                    progress: progress,
                    bufferedProgress: bufferedProgress,
                    isBuffering: widget.isBuffering,
                    shimmerPhase: _shimmerController.value,
                    isDragging: _isDragging,
                    activeColor: Colors.white.withValues(alpha: 0.95),
                    bufferedColor: Colors.white.withValues(alpha: 0.35),
                    inactiveColor: Colors.white.withValues(alpha: 0.18),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Elapsed position
            SizedBox(
              width: 55,
              child: Text(
                _formatDuration(Duration(milliseconds: currentDuration.toInt())),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  letterSpacing: -0.2,
                ),
              ),
            ),

            // Negative remaining duration (-M:SS)
            SizedBox(
              width: 55,
              child: Text(
                "-${_formatDuration(remainingDuration)}",
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SliderPainter extends CustomPainter {
  final double progress;
  final double bufferedProgress;
  final bool isBuffering;
  final double shimmerPhase;
  final bool isDragging;
  final Color activeColor;
  final Color bufferedColor;
  final Color inactiveColor;

  _SliderPainter({
    required this.progress,
    required this.bufferedProgress,
    required this.isBuffering,
    required this.shimmerPhase,
    required this.isDragging,
    required this.activeColor,
    required this.bufferedColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final trackHeight = isDragging ? 6.5 : 4.5;
    final trackRadius = Radius.circular(trackHeight / 2);
    final centerY = size.height / 2;

    // 1. Inactive background track
    final inactivePaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.fill;

    final trackRect = Rect.fromLTWH(0, centerY - trackHeight / 2, size.width, trackHeight);
    final inactiveRRect = RRect.fromRectAndRadius(trackRect, trackRadius);
    canvas.drawRRect(inactiveRRect, inactivePaint);

    // 2. Buffered range track (Apple Music audio cache ahead)
    final bufferedWidth = (size.width * bufferedProgress).clamp(0.0, size.width);
    if (bufferedWidth > 0) {
      final bufferedPaint = Paint()
        ..color = bufferedColor
        ..style = PaintingStyle.fill;

      final bufferedRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, centerY - trackHeight / 2, bufferedWidth, trackHeight),
        trackRadius,
      );
      canvas.drawRRect(bufferedRRect, bufferedPaint);
    }

    // 3. Apple Music Loading / Buffering Shimmer Wave
    if (isBuffering) {
      final shimmerPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment(-1.5 + shimmerPhase * 3.0, 0.0),
          end: Alignment(-0.5 + shimmerPhase * 3.0, 0.0),
          colors: [
            Colors.transparent,
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0.90),
            Colors.white.withValues(alpha: 0.55),
            Colors.transparent,
          ],
          stops: const [0.0, 0.35, 0.50, 0.65, 1.0],
        ).createShader(trackRect);

      canvas.drawRRect(inactiveRRect, shimmerPaint);
    }

    // 4. Played Active progress track
    final activeWidth = (size.width * progress).clamp(0.0, size.width);
    if (activeWidth > 0) {
      final activePaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.fill;

      final activeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, centerY - trackHeight / 2, activeWidth, trackHeight),
        trackRadius,
      );
      canvas.drawRRect(activeRect, activePaint);
    }

    // 5. Interactive Thumb Knob (visible and expanding when dragging)
    if (isDragging) {
      final thumbRadius = trackHeight + 3.0;

      // Soft shadow behind thumb
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      canvas.drawCircle(Offset(activeWidth, centerY + 1), thumbRadius, shadowPaint);

      final thumbPaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(activeWidth, centerY), thumbRadius, thumbPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SliderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.bufferedProgress != bufferedProgress ||
        oldDelegate.isBuffering != isBuffering ||
        oldDelegate.shimmerPhase != shimmerPhase ||
        oldDelegate.isDragging != isDragging ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.bufferedColor != bufferedColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}
