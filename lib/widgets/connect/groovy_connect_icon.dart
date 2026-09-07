import 'package:flutter/material.dart';

/// A beautifully rendered vector icon representing Spotify Connect / Device playback.
/// Features a desktop monitor/screen in the background and a speaker box in the foreground.
class GroovyConnectIcon extends StatelessWidget {
  final double size;
  final Color? color;
  final bool isConnected;
  final Color connectedColor;

  const GroovyConnectIcon({
    super.key,
    this.size = 24.0,
    this.color,
    this.isConnected = false,
    this.connectedColor = const Color(0xFF34C759),
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isConnected
        ? connectedColor
        : (color ?? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black));

    return CustomPaint(
      size: Size(size, size),
      painter: _ConnectIconPainter(
        color: effectiveColor,
        isConnected: isConnected,
      ),
    );
  }
}

class _ConnectIconPainter extends CustomPainter {
  final Color color;
  final bool isConnected;

  _ConnectIconPainter({
    required this.color,
    required this.isConnected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.085;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // ----------------------------------------------------
    // 1. Background Monitor / Screen (Left & Top)
    // ----------------------------------------------------
    // Outer monitor frame: x from 0.08w to 0.70w, y from 0.18h to 0.76h
    // Since the speaker overlaps the right portion, we draw the screen outline
    // that wraps around the left, top, and bottom-left with a stand at the bottom.
    final screenPath = Path();
    final screenRadius = Radius.circular(w * 0.09);

    // Screen top-left corner and left edge down to bottom-left
    screenPath.moveTo(w * 0.52, h * 0.20);
    screenPath.lineTo(w * 0.16, h * 0.20);
    screenPath.arcToPoint(
      Offset(w * 0.07, h * 0.29),
      radius: screenRadius,
    );
    screenPath.lineTo(w * 0.07, h * 0.65);
    screenPath.arcToPoint(
      Offset(w * 0.16, h * 0.74),
      radius: screenRadius,
    );
    screenPath.lineTo(w * 0.38, h * 0.74);

    // Stand base at the bottom
    screenPath.moveTo(w * 0.15, h * 0.88);
    screenPath.lineTo(w * 0.32, h * 0.88);

    canvas.drawPath(screenPath, paint);

    // ----------------------------------------------------
    // 2. Foreground Speaker (Right side)
    // ----------------------------------------------------
    // Speaker box rounded rectangle: x: 0.44w to 0.93w, y: 0.28h to 0.90h
    final speakerRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(w * 0.44, h * 0.26, w * 0.93, h * 0.90),
      Radius.circular(w * 0.12),
    );
    canvas.drawRRect(speakerRect, paint);

    // Tweeter (small upper dot/circle)
    final tweeterRadius = w * 0.055;
    final tweeterCenter = Offset(w * 0.685, h * 0.45);
    canvas.drawCircle(tweeterCenter, tweeterRadius, fillPaint);

    // Woofer (larger lower circle)
    final wooferRadius = w * 0.115;
    final wooferCenter = Offset(w * 0.685, h * 0.69);
    
    // Draw woofer ring and solid center
    final wooferPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.85;
    canvas.drawCircle(wooferCenter, wooferRadius, wooferPaint);

    final wooferCenterPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(wooferCenter, wooferRadius * 0.55, wooferCenterPaint);
  }

  @override
  bool shouldRepaint(covariant _ConnectIconPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isConnected != isConnected;
  }
}
