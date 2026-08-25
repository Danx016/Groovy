import 'dart:async';
import 'package:flutter/material.dart';

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double pauseDuration; // in seconds
  final double scrollVelocity; // pixels per second

  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.pauseDuration = 3.5,
    this.scrollVelocity = 28.0,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  late ScrollController _scrollController;
  Timer? _timer;
  bool _needsScroll = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkNeedScroll());
  }

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _stopScroll();
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkNeedScroll());
    }
  }

  void _checkNeedScroll() {
    if (!mounted || _isDisposed) return;
    
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    
    final textWidth = textPainter.width;
    
    if (context.size != null) {
      final containerWidth = context.size!.width;
      final shouldScroll = textWidth > (containerWidth + 4);
      
      if (shouldScroll != _needsScroll) {
        setState(() {
          _needsScroll = shouldScroll;
        });
      }
      
      if (shouldScroll) {
        _startScrollCycle();
      } else {
        _stopScroll();
      }
    }
  }

  void _startScrollCycle() {
    _stopScroll();
    
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }

    _timer = Timer(Duration(milliseconds: (widget.pauseDuration * 1000).toInt()), _runScrollCycle);
  }

  void _runScrollCycle() async {
    if (!mounted || _isDisposed || !_scrollController.hasClients || !_needsScroll) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    final durationSeconds = (maxScroll / widget.scrollVelocity).clamp(1.5, 20.0);

    // 1. Scroll to end
    try {
      await _scrollController.animateTo(
        maxScroll,
        duration: Duration(milliseconds: (durationSeconds * 1000).toInt()),
        curve: Curves.easeInOutSine,
      );
    } catch (_) {
      return;
    }

    if (!mounted || _isDisposed) return;

    // 2. Pause at the end
    await Future.delayed(const Duration(milliseconds: 2600));
    if (!mounted || _isDisposed || !_scrollController.hasClients) return;

    // 3. Smooth scroll back to start
    try {
      await _scrollController.animateTo(
        0.0,
        duration: Duration(milliseconds: ((durationSeconds * 0.7) * 1000).toInt()),
        curve: Curves.easeInOutSine,
      );
    } catch (_) {
      return;
    }

    if (!mounted || _isDisposed) return;

    // 4. Repeat cycle after initial pause
    _timer = Timer(Duration(milliseconds: (widget.pauseDuration * 1000).toInt()), _runScrollCycle);
  }

  void _stopScroll() {
    _timer?.cancel();
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        Widget content = SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
          ),
        );

        if (_needsScroll) {
          content = ShaderMask(
            shaderCallback: (Rect bounds) {
              return const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
                stops: [0.0, 0.90, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: content,
          );
        }

        return content;
      },
    );
  }
}

