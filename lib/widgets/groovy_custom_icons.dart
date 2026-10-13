import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Vector icons customized to match the user's provided Spotify desktop icon set.

/// 1. Sidebar Panel Toggle ("Vista que suena")
/// A rectangle frame with a vertical sidebar dividing line on the right,
/// and a chevron '>' pointing right inside the left main panel.
class GroovySidebarPanelIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const GroovySidebarPanelIcon({super.key, this.size = 20, this.color});

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black87);

    return CustomPaint(
      size: Size(size, size),
      painter: _SidebarPanelPainter(effectiveColor),
    );
  }
}

class _SidebarPanelPainter extends CustomPainter {
  final Color color;
  _SidebarPanelPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final strokeWidth = (w * 0.08).clamp(1.4, 2.2);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Outer rounded rectangle frame
    final outerRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(w * 0.10, h * 0.12, w * 0.90, h * 0.88),
      Radius.circular(w * 0.15),
    );
    canvas.drawRRect(outerRect, paint);

    // Vertical dividing line for the right sidebar panel
    final splitX = w * 0.65;
    canvas.drawLine(
      Offset(splitX, h * 0.12),
      Offset(splitX, h * 0.88),
      paint,
    );

    // Chevron '>' inside the left main panel
    final arrowPath = Path();
    final arrowLeft = w * 0.31;
    final arrowTip = w * 0.44;
    final arrowTop = h * 0.38;
    final arrowBottom = h * 0.62;
    final arrowMid = h * 0.50;

    arrowPath.moveTo(arrowLeft, arrowTop);
    arrowPath.lineTo(arrowTip, arrowMid);
    arrowPath.lineTo(arrowLeft, arrowBottom);
    canvas.drawPath(arrowPath, paint);
  }

  @override
  bool shouldRepaint(covariant _SidebarPanelPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 2. Lyrics Microphone Icon ("Letras")
/// A 45-degree angled stage/handheld microphone outline.
class GroovyLyricsMicIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const GroovyLyricsMicIcon({super.key, this.size = 20, this.color});

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black87);

    return CustomPaint(
      size: Size(size, size),
      painter: _LyricsMicPainter(effectiveColor),
    );
  }
}

class _LyricsMicPainter extends CustomPainter {
  final Color color;
  _LyricsMicPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final strokeWidth = (w * 0.085).clamp(1.4, 2.0);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.translate(w / 2, h / 2);
    // Rotate 45 degrees clockwise: head points to top-right, handle points to bottom-left
    canvas.rotate(math.pi / 4);

    final headRadius = w * 0.17;
    final headTopY = -h * 0.39;
    final neckY = -h * 0.05;

    // 1. Microphone Capsule Dome (head)
    final headPath = Path();
    headPath.moveTo(-headRadius, neckY);
    headPath.lineTo(-headRadius, headTopY + headRadius);
    headPath.arcToPoint(
      Offset(headRadius, headTopY + headRadius),
      radius: Radius.circular(headRadius),
    );
    headPath.lineTo(headRadius, neckY);
    canvas.drawPath(headPath, paint);

    // 2. Neck divider line (flush across the base of the capsule head)
    canvas.drawLine(
      Offset(-headRadius, neckY),
      Offset(headRadius, neckY),
      paint,
    );

    // 3. Handle (tapered body with smooth rounded bottom cap)
    final handleTopWidth = headRadius * 0.80;
    final handleBottomWidth = headRadius * 0.48;
    final handleBottomY = h * 0.33;

    final handlePath = Path();
    handlePath.moveTo(-handleTopWidth, neckY);
    handlePath.lineTo(-handleBottomWidth, handleBottomY);
    handlePath.arcToPoint(
      Offset(handleBottomWidth, handleBottomY),
      radius: Radius.circular(handleBottomWidth),
    );
    handlePath.lineTo(handleTopWidth, neckY);
    canvas.drawPath(handlePath, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LyricsMicPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 3. Queue Icon ("Cola de reproducción")
/// A horizontal rounded pill at top and two horizontal lines below it.
class GroovyQueueListIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const GroovyQueueListIcon({super.key, this.size = 20, this.color});

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black87);

    return CustomPaint(
      size: Size(size, size),
      painter: _QueueListPainter(effectiveColor),
    );
  }
}

class _QueueListPainter extends CustomPainter {
  final Color color;
  _QueueListPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final strokeWidth = (w * 0.085).clamp(1.5, 2.2);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Top pill (rounded rectangle)
    final topPill = RRect.fromRectAndRadius(
      Rect.fromLTRB(w * 0.12, h * 0.18, w * 0.88, h * 0.38),
      Radius.circular(h * 0.10),
    );
    canvas.drawRRect(topPill, paint);

    // Middle horizontal line
    canvas.drawLine(
      Offset(w * 0.12, h * 0.58),
      Offset(w * 0.88, h * 0.58),
      paint,
    );

    // Bottom horizontal line
    canvas.drawLine(
      Offset(w * 0.12, h * 0.80),
      Offset(w * 0.88, h * 0.80),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _QueueListPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 4. Device Connect Icon ("Conectar a un dispositivo")
/// Phone outline on the left, speaker box with tweeter & woofer on the right.
class GroovyDeviceConnectIcon extends StatelessWidget {
  final double size;
  final Color? color;
  final bool isConnected;
  final Color connectedColor;

  const GroovyDeviceConnectIcon({
    super.key,
    this.size = 20,
    this.color,
    this.isConnected = false,
    this.connectedColor = const Color(0xFFFA2D48),
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isConnected
        ? connectedColor
        : (color ??
            (Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black87));

    return CustomPaint(
      size: Size(size, size),
      painter: _DeviceConnectPainter(effectiveColor),
    );
  }
}

class _DeviceConnectPainter extends CustomPainter {
  final Color color;
  _DeviceConnectPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final strokeWidth = (w * 0.08).clamp(1.4, 2.0);

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Phone outline on the left (wraps top, left, bottom)
    final phonePath = Path();
    final phoneRadius = Radius.circular(w * 0.08);
    phonePath.moveTo(w * 0.40, h * 0.32);
    phonePath.lineTo(w * 0.18, h * 0.32);
    phonePath.arcToPoint(Offset(w * 0.10, h * 0.40), radius: phoneRadius);
    phonePath.lineTo(w * 0.10, h * 0.72);
    phonePath.arcToPoint(Offset(w * 0.18, h * 0.80), radius: phoneRadius);
    phonePath.lineTo(w * 0.40, h * 0.80);
    canvas.drawPath(phonePath, strokePaint);

    // Speaker box on the right
    final speakerRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(w * 0.44, h * 0.18, w * 0.90, h * 0.86),
      Radius.circular(w * 0.12),
    );
    canvas.drawRRect(speakerRect, strokePaint);

    // Tweeter dot
    canvas.drawCircle(Offset(w * 0.67, h * 0.38), w * 0.05, fillPaint);

    // Woofer circle with center dot
    canvas.drawCircle(
      Offset(w * 0.67, h * 0.63),
      w * 0.11,
      strokePaint..strokeWidth = strokeWidth * 0.8,
    );
    canvas.drawCircle(Offset(w * 0.67, h * 0.63), w * 0.045, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _DeviceConnectPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 5. Diagonal Expand Icon ("Pantalla completa")
/// Two diagonal arrows pointing outwards to top-right and bottom-left: ⤢
class GroovyDiagonalExpandIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const GroovyDiagonalExpandIcon({super.key, this.size = 18, this.color});

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black87);

    return CustomPaint(
      size: Size(size, size),
      painter: _DiagonalExpandPainter(effectiveColor),
    );
  }
}

class _DiagonalExpandPainter extends CustomPainter {
  final Color color;
  _DiagonalExpandPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final strokeWidth = (w * 0.09).clamp(1.5, 2.2);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final tipTR = Offset(w * 0.82, h * 0.18);
    final tipBL = Offset(w * 0.18, h * 0.82);

    // 1. Top-Right Arrow (head + stem)
    final trHead = Path()
      ..moveTo(w * 0.54, h * 0.18)
      ..lineTo(tipTR.dx, tipTR.dy)
      ..lineTo(w * 0.82, h * 0.46);
    canvas.drawPath(trHead, paint);

    canvas.drawLine(
      Offset(w * 0.56, h * 0.44),
      tipTR,
      paint,
    );

    // 2. Bottom-Left Arrow (head + stem)
    final blHead = Path()
      ..moveTo(w * 0.46, h * 0.82)
      ..lineTo(tipBL.dx, tipBL.dy)
      ..lineTo(w * 0.18, h * 0.54);
    canvas.drawPath(blHead, paint);

    canvas.drawLine(
      Offset(w * 0.44, h * 0.56),
      tipBL,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _DiagonalExpandPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 5b. Diagonal Collapse Icon ("Salir de pantalla completa")
/// Two diagonal arrows pointing inwards toward center from top-right and bottom-left: ⤡
class GroovyDiagonalCollapseIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const GroovyDiagonalCollapseIcon({super.key, this.size = 18, this.color});

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black87);

    return CustomPaint(
      size: Size(size, size),
      painter: _DiagonalCollapsePainter(effectiveColor),
    );
  }
}

class _DiagonalCollapsePainter extends CustomPainter {
  final Color color;
  _DiagonalCollapsePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final strokeWidth = (w * 0.09).clamp(1.5, 2.2);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final tipTR = Offset(w * 0.54, h * 0.46);
    final tipBL = Offset(w * 0.46, h * 0.54);

    // 1. Top-Right Arrow pointing inward (stem from top-right + head pointing inward)
    final trHead = Path()
      ..moveTo(w * 0.54, h * 0.20)
      ..lineTo(tipTR.dx, tipTR.dy)
      ..lineTo(w * 0.80, h * 0.46);
    canvas.drawPath(trHead, paint);

    canvas.drawLine(
      Offset(w * 0.82, h * 0.18),
      tipTR,
      paint,
    );

    // 2. Bottom-Left Arrow pointing inward (stem from bottom-left + head pointing inward)
    final blHead = Path()
      ..moveTo(w * 0.46, h * 0.80)
      ..lineTo(tipBL.dx, tipBL.dy)
      ..lineTo(w * 0.20, h * 0.54);
    canvas.drawPath(blHead, paint);

    canvas.drawLine(
      Offset(w * 0.18, h * 0.82),
      tipBL,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _DiagonalCollapsePainter oldDelegate) =>
      oldDelegate.color != color;
}


/// 6. Miniplayer / Viewfinder Icon ("Minirreproductor")
/// Four outer rounded corner brackets forming a frame: ⛶
class GroovyViewfinderIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const GroovyViewfinderIcon({super.key, this.size = 18, this.color});

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black87);

    return CustomPaint(
      size: Size(size, size),
      painter: _ViewfinderPainter(effectiveColor),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  final Color color;
  _ViewfinderPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final strokeWidth = (w * 0.09).clamp(1.5, 2.2);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final arm = w * 0.24;
    final r = w * 0.08;

    // Top-Left corner
    final tl = Path();
    tl.moveTo(w * 0.12, h * 0.12 + arm);
    tl.lineTo(w * 0.12, h * 0.12 + r);
    tl.quadraticBezierTo(w * 0.12, h * 0.12, w * 0.12 + r, h * 0.12);
    tl.lineTo(w * 0.12 + arm, h * 0.12);
    canvas.drawPath(tl, paint);

    // Top-Right corner
    final tr = Path();
    tr.moveTo(w * 0.88 - arm, h * 0.12);
    tr.lineTo(w * 0.88 - r, h * 0.12);
    tr.quadraticBezierTo(w * 0.88, h * 0.12, w * 0.88, h * 0.12 + r);
    tr.lineTo(w * 0.88, h * 0.12 + arm);
    canvas.drawPath(tr, paint);

    // Bottom-Left corner
    final bl = Path();
    bl.moveTo(w * 0.12, h * 0.88 - arm);
    bl.lineTo(w * 0.12, h * 0.88 - r);
    bl.quadraticBezierTo(w * 0.12, h * 0.88, w * 0.12 + r, h * 0.88);
    bl.lineTo(w * 0.12 + arm, h * 0.88);
    canvas.drawPath(bl, paint);

    // Bottom-Right corner
    final br = Path();
    br.moveTo(w * 0.88 - arm, h * 0.88);
    br.lineTo(w * 0.88 - r, h * 0.88);
    br.quadraticBezierTo(w * 0.88, h * 0.88, w * 0.88, h * 0.88 - r);
    br.lineTo(w * 0.88, h * 0.88 - arm);
    canvas.drawPath(br, paint);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 7. Inward Corners Icon ("Salir de pantalla completa" / Minimize)
/// Four corner brackets pointing inward towards the center: ><
class GroovyInwardCornersIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const GroovyInwardCornersIcon({super.key, this.size = 18, this.color});

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black87);

    return CustomPaint(
      size: Size(size, size),
      painter: _InwardCornersPainter(effectiveColor),
    );
  }
}

class _InwardCornersPainter extends CustomPainter {
  final Color color;
  _InwardCornersPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final strokeWidth = (w * 0.09).clamp(1.5, 2.2);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = w / 2;
    final cy = h / 2;
    final gap = w * 0.12; // distance from center to corner
    final arm = w * 0.24; // length of arm
    final r = w * 0.07;   // smooth corner radius

    // 1. Top-Left corner (arms go UP and LEFT from inner corner)
    final tl = Path();
    tl.moveTo(cx - gap - arm, cy - gap);
    tl.lineTo(cx - gap - r, cy - gap);
    tl.quadraticBezierTo(cx - gap, cy - gap, cx - gap, cy - gap - r);
    tl.lineTo(cx - gap, cy - gap - arm);
    canvas.drawPath(tl, paint);

    // 2. Top-Right corner (arms go UP and RIGHT from inner corner)
    final tr = Path();
    tr.moveTo(cx + gap + arm, cy - gap);
    tr.lineTo(cx + gap + r, cy - gap);
    tr.quadraticBezierTo(cx + gap, cy - gap, cx + gap, cy - gap - r);
    tr.lineTo(cx + gap, cy - gap - arm);
    canvas.drawPath(tr, paint);

    // 3. Bottom-Left corner (arms go DOWN and LEFT from inner corner)
    final bl = Path();
    bl.moveTo(cx - gap - arm, cy + gap);
    bl.lineTo(cx - gap - r, cy + gap);
    bl.quadraticBezierTo(cx - gap, cy + gap, cx - gap, cy + gap + r);
    bl.lineTo(cx - gap, cy + gap - arm);
    canvas.drawPath(bl, paint);

    // 4. Bottom-Right corner (arms go DOWN and RIGHT from inner corner)
    final br = Path();
    br.moveTo(cx + gap + arm, cy + gap);
    br.lineTo(cx + gap + r, cy + gap);
    br.quadraticBezierTo(cx + gap, cy + gap, cx + gap, cy + gap + r);
    br.lineTo(cx + gap, cy + gap + arm);
    canvas.drawPath(br, paint);
  }

  @override
  bool shouldRepaint(covariant _InwardCornersPainter oldDelegate) =>
      oldDelegate.color != color;
}
