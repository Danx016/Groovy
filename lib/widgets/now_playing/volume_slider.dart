import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:volume_controller/volume_controller.dart';
import '../../providers/player_provider.dart';
import '../../services/groovy_connect_service.dart';

class VolumeSlider extends StatefulWidget {
  const VolumeSlider({super.key});

  @override
  State<VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<VolumeSlider> {
  bool _isDragging = false;
  double _dragValue = 0.0;
  double _systemVolume = 0.5;
  bool _hasListener = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && Platform.isAndroid) {
      try {
        VolumeController.instance.showSystemUI = false;
        VolumeController.instance.getVolume().then((volume) {
          if (mounted) setState(() => _systemVolume = volume);
        }).catchError((_) {});

        VolumeController.instance.addListener((volume) {
          if (!mounted) return;
          if (!_isDragging) {
            setState(() => _systemVolume = volume);
          }
          // Forward hardware volume changes to remote device if connected via Groovy Connect
          final groovyConnect = context.read<GroovyConnectService>();
          if (groovyConnect.isConnected) {
            context.read<PlayerProvider>().setVolume(volume);
          }
        });
        _hasListener = true;
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    if (_hasListener && !kIsWeb && Platform.isAndroid) {
      try {
        VolumeController.instance.removeListener();
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<PlayerProvider, GroovyConnectService>(
      builder: (context, playerProvider, groovyConnect, _) {
        final isRemote = groovyConnect.isConnected;
        final activeVolume = isRemote
            ? (_isDragging ? _dragValue : playerProvider.volume)
            : (!kIsWeb && Platform.isAndroid
                ? (_isDragging ? _dragValue : _systemVolume)
                : (_isDragging ? _dragValue : playerProvider.volume));

        return Row(
          children: [
            Icon(
              Icons.volume_mute_rounded,
              color: Colors.white.withValues(alpha: 0.50),
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (details) {
                  setState(() {
                    _isDragging = true;
                    _dragValue = activeVolume;
                  });
                },
                onHorizontalDragUpdate: (details) {
                  final box = context.findRenderObject() as RenderBox;
                  final dx = details.localPosition.dx.clamp(0.0, box.size.width);
                  final val = (dx / box.size.width).clamp(0.0, 1.0);
                  setState(() {
                    _dragValue = val;
                  });
                  playerProvider.setVolume(val);
                  if (!isRemote && !kIsWeb && Platform.isAndroid) {
                    try {
                      VolumeController.instance.setVolume(val);
                    } catch (_) {}
                  }
                },
                onHorizontalDragEnd: (details) {
                  setState(() => _isDragging = false);
                },
                onTapDown: (details) {
                  HapticFeedback.lightImpact();
                  final box = context.findRenderObject() as RenderBox;
                  final dx = details.localPosition.dx.clamp(0.0, box.size.width);
                  final val = (dx / box.size.width).clamp(0.0, 1.0);
                  setState(() {
                    _dragValue = val;
                  });
                  playerProvider.setVolume(val);
                  if (!isRemote && !kIsWeb && Platform.isAndroid) {
                    try {
                      VolumeController.instance.setVolume(val);
                    } catch (_) {}
                  }
                },
                child: Container(
                  height: 28, // Tappable area
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: CustomPaint(
                    size: const Size(double.infinity, 28),
                    painter: _VolumeSliderPainter(
                      volume: activeVolume,
                      isDragging: _isDragging,
                      activeColor: Colors.white,
                      inactiveColor: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.volume_up_rounded,
              color: Colors.white.withValues(alpha: 0.50),
              size: 18,
            ),
          ],
        );
      },
    );
  }
}

class _VolumeSliderPainter extends CustomPainter {
  final double volume;
  final bool isDragging;
  final Color activeColor;
  final Color inactiveColor;

  _VolumeSliderPainter({
    required this.volume,
    required this.isDragging,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final trackHeight = 4.0;
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    // Background track
    paint.color = inactiveColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, (size.height - trackHeight) / 2, size.width, trackHeight),
        Radius.circular(trackHeight / 2),
      ),
      paint,
    );

    // Active track
    paint.color = activeColor;
    final activeWidth = size.width * volume.clamp(0.0, 1.0);
    if (activeWidth > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, (size.height - trackHeight) / 2, activeWidth, trackHeight),
          Radius.circular(trackHeight / 2),
        ),
        paint,
      );
    }

    // Thumb (visible while dragging for precision feedback)
    if (isDragging) {
      paint.color = Colors.white;
      canvas.drawCircle(Offset(activeWidth, size.height / 2), 7, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VolumeSliderPainter oldDelegate) {
    return oldDelegate.volume != volume ||
        oldDelegate.isDragging != isDragging ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}
