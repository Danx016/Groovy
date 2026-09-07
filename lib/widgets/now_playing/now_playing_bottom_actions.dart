import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/cast_service.dart';
import '../../services/upnp_service.dart';
import '../connect/groovy_connect_icon.dart';
import '../connect/groovy_connect_modal.dart';

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
    final isCastConnected = context.select<CastService, bool>((s) => s.isConnected);
    final isUpnpConnected = context.select<UpnpService, bool>((s) => s.isConnected);
    final isDeviceConnected = isCastConnected || isUpnpConnected;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36.0, vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 1. Apple Music Lyrics Button (Speech bubble with quotes)
          _ActionButton(
            customIcon: Icon(
              isLyricsActive
                  ? CupertinoIcons.quote_bubble_fill
                  : CupertinoIcons.quote_bubble,
              size: 22,
              color: isLyricsActive
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.60),
            ),
            isActive: isLyricsActive,
            onTap: onLyricsTap,
          ),

          // 2. Groovy Connect / Device Output Button
          _ActionButton(
            customIcon: GroovyConnectIcon(
              size: 22,
              color: isDeviceConnected
                  ? const Color(0xFF1ED760)
                  : Colors.white.withValues(alpha: 0.65),
              isConnected: isDeviceConnected,
              connectedColor: const Color(0xFF1ED760),
            ),
            isActive: isDeviceConnected,
            onTap: () {
              GroovyConnectModal.show(context);
            },
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
