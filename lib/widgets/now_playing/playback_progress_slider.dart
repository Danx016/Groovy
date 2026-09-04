import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PlaybackProgressSlider extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final bool isBuffering;
  final Stream<Duration>? positionStream;
  final Stream<Duration>? bufferedPositionStream;
  final Stream<bool>? isBufferingStream;
  final ValueChanged<Duration> onChanged;
  final Color accentColor;

  const PlaybackProgressSlider({
    super.key,
    required this.position,
    required this.duration,
    this.bufferedPosition = Duration.zero,
    this.isBuffering = false,
    this.positionStream,
    this.bufferedPositionStream,
    this.isBufferingStream,
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
  late Duration _currentPosition;
  late Duration _currentBufferedPosition;
  late bool _currentIsBuffering;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _bufSub;
  StreamSubscription<bool>? _bufferingSub;
  int _lastUpdateMillis = 0;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.position;
    _currentBufferedPosition = widget.bufferedPosition;
    _currentIsBuffering = widget.isBuffering;

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (_currentIsBuffering) {
      _shimmerController.repeat();
    }

    _subscribeStreams();
  }

  void _subscribeStreams() {
    _posSub?.cancel();
    _bufSub?.cancel();
    _bufferingSub?.cancel();

    if (widget.positionStream != null) {
      _posSub = widget.positionStream!.listen((pos) {
        final now = DateTime.now().millisecondsSinceEpoch;
        // Throttle UI position rebuilds to 4 times a second (250ms) for 0% CPU overhead
        if (!_isDragging && (now - _lastUpdateMillis >= 250 || pos == Duration.zero)) {
          _lastUpdateMillis = now;
          if (mounted) {
            setState(() {
              _currentPosition = pos;
            });
          }
        }
      });
    }

    if (widget.bufferedPositionStream != null) {
      _bufSub = widget.bufferedPositionStream!.listen((buf) {
        if (mounted && buf != _currentBufferedPosition) {
          setState(() {
            _currentBufferedPosition = buf;
          });
        }
      });
    }

    if (widget.isBufferingStream != null) {
      _bufferingSub = widget.isBufferingStream!.listen((buffering) {
        if (mounted && buffering != _currentIsBuffering) {
          setState(() {
            _currentIsBuffering = buffering;
          });
          if (buffering) {
            _shimmerController.repeat();
          } else {
            _shimmerController.stop();
          }
        }
      });
    }
  }

  @override
  void didUpdateWidget(PlaybackProgressSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.positionStream == null && widget.position != oldWidget.position && !_isDragging) {
      _currentPosition = widget.position;
    }
    if (widget.positionStream != oldWidget.positionStream) {
      _subscribeStreams();
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _bufSub?.cancel();
    _bufferingSub?.cancel();
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
        : _currentPosition.inMilliseconds.toDouble();
        
    final safeMax = maxDuration > 0 ? maxDuration : 1.0;
    final progress = (currentDuration / safeMax).clamp(0.0, 1.0);
    final bufferedProgress = (_currentBufferedPosition.inMilliseconds / safeMax).clamp(0.0, 1.0);
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
            height: 24, // Touch target
            alignment: Alignment.center,
            child: _currentIsBuffering
                ? AnimatedBuilder(
                    animation: _shimmerController,
                    builder: (context, _) {
                      return CustomPaint(
                        size: const Size(double.infinity, 24),
                        painter: _AppleMusicSliderPainter(
                          progress: progress,
                          bufferedProgress: bufferedProgress,
                          isBuffering: true,
                          shimmerPhase: _shimmerController.value,
                          isDragging: _isDragging,
                          activeColor: Colors.white.withValues(alpha: 0.95),
                          bufferedColor: Colors.white.withValues(alpha: 0.35),
                          inactiveColor: Colors.white.withValues(alpha: 0.22),
                        ),
                      );
                    },
                  )
                : CustomPaint(
                    size: const Size(double.infinity, 24),
                    painter: _AppleMusicSliderPainter(
                      progress: progress,
                      bufferedProgress: bufferedProgress,
                      isBuffering: false,
                      shimmerPhase: 0.0,
                      isDragging: _isDragging,
                      activeColor: Colors.white.withValues(alpha: 0.95),
                      bufferedColor: Colors.white.withValues(alpha: 0.35),
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
            // Elapsed position (e.g. 0:03)
            SizedBox(
              width: 55,
              child: Text(
                _formatDuration(Duration(milliseconds: currentDuration.toInt())),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.60),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  letterSpacing: -0.2,
                ),
              ),
            ),

            // Negative remaining duration (-4:10)
            SizedBox(
              width: 55,
              child: Text(
                "-${_formatDuration(remainingDuration)}",
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.60),
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

class _AppleMusicSliderPainter extends CustomPainter {
  final double progress;
  final double bufferedProgress;
  final bool isBuffering;
  final double shimmerPhase;
  final bool isDragging;
  final Color activeColor;
  final Color bufferedColor;
  final Color inactiveColor;

  _AppleMusicSliderPainter({
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
    final trackHeight = isDragging ? 7.0 : 4.0;
    final trackY = (size.height - trackHeight) / 2.0;
    final r = trackHeight / 2.0;
    final radius = Radius.circular(r);

    // 1. Inactive Background Track
    final inactivePaint = Paint()..color = inactiveColor;
    final inactiveRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, trackY, size.width, trackHeight),
      radius,
    );
    canvas.drawRRect(inactiveRRect, inactivePaint);

    // 2. Buffered Track
    if (bufferedProgress > 0.0) {
      final bufferedWidth = (size.width * bufferedProgress).clamp(0.0, size.width);
      final bufferedPaint = Paint()..color = bufferedColor;
      final bufferedRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, trackY, bufferedWidth, trackHeight),
        radius,
      );
      canvas.drawRRect(bufferedRRect, bufferedPaint);
    }

    // 3. Active Playback Track
    final activeWidth = (size.width * progress).clamp(0.0, size.width);
    if (activeWidth > 0.0) {
      final activePaint = Paint()..color = activeColor;
      final activeRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, trackY, activeWidth, trackHeight),
        radius,
      );
      canvas.drawRRect(activeRRect, activePaint);
    }

    // 4. Shimmer wave if buffering
    if (isBuffering) {
      final shimmerPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            Colors.white.withValues(alpha: 0.60),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(
          Rect.fromLTWH(
            (shimmerPhase * size.width * 1.5) - (size.width * 0.3),
            trackY,
            size.width * 0.3,
            trackHeight,
          ),
        );
      canvas.drawRRect(inactiveRRect, shimmerPaint);
    }

    // 5. Apple Music Scrubbing Indicator / Pill
    if (isDragging) {
      final thumbX = activeWidth.clamp(r, size.width - r);
      final thumbPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      // Glow shadow
      canvas.drawCircle(
        Offset(thumbX, size.height / 2.0),
        7.0,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // Solid white thumb
      canvas.drawCircle(Offset(thumbX, size.height / 2.0), 6.0, thumbPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AppleMusicSliderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.bufferedProgress != bufferedProgress ||
        oldDelegate.isBuffering != isBuffering ||
        oldDelegate.shimmerPhase != shimmerPhase ||
        oldDelegate.isDragging != isDragging ||
        oldDelegate.activeColor != activeColor;
  }
}
