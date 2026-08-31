import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../cast_button.dart';

class NowPlayingBottomActions extends StatelessWidget {
  final VoidCallback onLyricsTap;
  final VoidCallback onQueueTap;
  final bool isLyricsActive;
  final bool isQueueActive;
  final Color accentColor;

  const NowPlayingBottomActions({
    super.key,
    required this.onLyricsTap,
    required this.onQueueTap,
    this.isLyricsActive = false,
    this.isQueueActive = false,
    this.accentColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36.0, vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 1. Apple Music Lyrics Button (Speech bubble with quotes)
          _ActionButton(
            customIcon: CustomPaint(
              size: const Size(22, 22),
              painter: _LyricsIconPainter(
                color: isLyricsActive
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.60),
                isFilled: isLyricsActive,
              ),
            ),
            isActive: isLyricsActive,
            onTap: onLyricsTap,
          ),

          // 2. Apple Music AirPlay / Cast Button
          CastButton(
            iconSize: 22,
            iconColor: Colors.white.withValues(alpha: 0.60),
          ),

          // 3. Apple Music Queue Button (3 bullet lines)
          _ActionButton(
            customIcon: CustomPaint(
              size: const Size(22, 22),
              painter: _QueueListIconPainter(
                color: isQueueActive
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.60),
              ),
            ),
            isActive: isQueueActive,
            onTap: onQueueTap,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final Widget customIcon;
  final VoidCallback onTap;
  final bool isActive;

  const _ActionButton({
    required this.customIcon,
    required this.onTap,
    this.isActive = false,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() => _isPressed = true);
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.82 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: _isPressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: widget.isActive
                ? Colors.white.withValues(alpha: 0.22)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: SizedBox(
            width: 24,
            height: 24,
            child: Center(
              child: widget.customIcon,
            ),
          ),
        ),
      ),
    );
  }
}

class _LyricsIconPainter extends CustomPainter {
  final Color color;
  final bool isFilled;

  _LyricsIconPainter({required this.color, this.isFilled = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = isFilled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Speech bubble rounded rect
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(2.5, 3.0, w - 5.0, h - 7.5),
      const Radius.circular(5.0),
    );

    // Tail at bottom left
    final tailPath = Path()
      ..moveTo(6.5, h - 4.5)
      ..lineTo(3.5, h - 1.5)
      ..lineTo(10.5, h - 4.5);

    if (isFilled) {
      canvas.drawRRect(rect, paint);
      final tailFill = Path()
        ..moveTo(6.0, h - 5.0)
        ..lineTo(3.5, h - 1.5)
        ..lineTo(10.5, h - 5.0)
        ..close();
      canvas.drawPath(tailFill, paint);
    } else {
      canvas.drawRRect(rect, paint);
      canvas.drawPath(tailPath, paint);
    }

    // Two small quotation marks inside
    final quotePaint = Paint()
      ..color = isFilled ? Colors.black87 : color
      ..style = PaintingStyle.fill;

    // Left quote
    canvas.drawCircle(Offset(w * 0.40, h * 0.42), 1.4, quotePaint);
    final leftTail = Path()
      ..moveTo(w * 0.40 + 1.1, h * 0.42)
      ..lineTo(w * 0.40 - 0.4, h * 0.42 + 2.3)
      ..lineTo(w * 0.40 - 1.1, h * 0.42)
      ..close();
    canvas.drawPath(leftTail, quotePaint);

    // Right quote
    canvas.drawCircle(Offset(w * 0.60, h * 0.42), 1.4, quotePaint);
    final rightTail = Path()
      ..moveTo(w * 0.60 + 1.1, h * 0.42)
      ..lineTo(w * 0.60 - 0.4, h * 0.42 + 2.3)
      ..lineTo(w * 0.60 - 1.1, h * 0.42)
      ..close();
    canvas.drawPath(rightTail, quotePaint);
  }

  @override
  bool shouldRepaint(covariant _LyricsIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.isFilled != isFilled;
}

class _QueueListIconPainter extends CustomPainter {
  final Color color;

  _QueueListIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    final rowY = [h * 0.26, h * 0.50, h * 0.74];

    for (final y in rowY) {
      // Bullet dot
      canvas.drawCircle(Offset(3.5, y), 1.6, dotPaint);
      // Horizontal line
      canvas.drawLine(Offset(8.5, y), Offset(w - 2.5, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _QueueListIconPainter oldDelegate) =>
      oldDelegate.color != color;
}
