import 'package:flutter/material.dart';

class PlaybackProgressSlider extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onChanged;
  final Color accentColor;
  final String? qualityBadge;

  const PlaybackProgressSlider({
    super.key,
    required this.position,
    required this.duration,
    required this.onChanged,
    required this.accentColor,
    this.qualityBadge,
  });

  @override
  State<PlaybackProgressSlider> createState() => _PlaybackProgressSliderState();
}

class _PlaybackProgressSliderState extends State<PlaybackProgressSlider> {
  bool _isDragging = false;
  double _dragValue = 0.0;

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
    final remainingDuration = widget.duration - Duration(milliseconds: currentDuration.toInt());

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) {
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
            widget.onChanged(Duration(milliseconds: _dragValue.toInt()));
          },
          onTapDown: (details) {
            final box = context.findRenderObject() as RenderBox;
            final dx = details.localPosition.dx.clamp(0.0, box.size.width);
            final tapValue = (dx / box.size.width) * safeMax;
            widget.onChanged(Duration(milliseconds: tapValue.toInt()));
          },
          child: Container(
            height: 24, // Tappable area
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: CustomPaint(
              size: const Size(double.infinity, 24),
              painter: _SliderPainter(
                progress: progress,
                isDragging: _isDragging,
                activeColor: Colors.white.withValues(alpha: 0.9),
                inactiveColor: Colors.white.withValues(alpha: 0.22),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Current position
            SizedBox(
              width: 55,
              child: Text(
                _formatDuration(Duration(milliseconds: currentDuration.toInt())),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),

            // Remaining duration
            SizedBox(
              width: 55,
              child: Text(
                "-${_formatDuration(remainingDuration)}",
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
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
  final bool isDragging;
  final Color activeColor;
  final Color inactiveColor;

  _SliderPainter({
    required this.progress,
    required this.isDragging,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final trackHeight = isDragging ? 6.0 : 4.0;
    final trackRadius = Radius.circular(trackHeight / 2);
    
    final centerY = size.height / 2;
    
    // Inactive track
    final inactivePaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.fill;
    
    final inactiveRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, centerY - trackHeight / 2, size.width, trackHeight),
      trackRadius,
    );
    canvas.drawRRect(inactiveRect, inactivePaint);
    
    // Active track
    final activeWidth = size.width * progress;
    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;
      
    final activeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, centerY - trackHeight / 2, activeWidth, trackHeight),
      trackRadius,
    );
    canvas.drawRRect(activeRect, activePaint);

    // Thumb (only visible when dragging)
    if (isDragging) {
      final thumbRadius = trackHeight + 2.5;
      final thumbPaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(activeWidth, centerY), thumbRadius, thumbPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SliderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.isDragging != isDragging ||
           oldDelegate.activeColor != activeColor ||
           oldDelegate.inactiveColor != inactiveColor;
  }
}

