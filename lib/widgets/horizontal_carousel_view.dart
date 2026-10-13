import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A desktop-friendly horizontal carousel with:
/// - Smooth edge fade mask so cards don't slice abruptly against window borders
/// - Navigation arrow buttons (< and >) on desktop for intuitive scrolling
/// - Mouse drag and trackpad scrolling support
class HorizontalCarouselView extends StatefulWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final IndexedWidgetBuilder? separatorBuilder;
  final double height;
  final EdgeInsets padding;
  final double? cardSize;
  final double? scrollStep;

  const HorizontalCarouselView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.separatorBuilder,
    required this.height,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.cardSize,
    this.scrollStep,
  });

  /// Factory to construct from a static list of child widgets
  factory HorizontalCarouselView.fromList({
    Key? key,
    required List<Widget> children,
    required double height,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 16),
    double itemSpacing = 14,
    double? cardSize,
    double? scrollStep,
  }) {
    return HorizontalCarouselView(
      key: key,
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
      separatorBuilder: itemSpacing > 0
          ? (context, index) => SizedBox(width: itemSpacing)
          : null,
      height: height,
      padding: padding,
      cardSize: cardSize,
      scrollStep: scrollStep,
    );
  }

  @override
  State<HorizontalCarouselView> createState() => _HorizontalCarouselViewState();
}

class _HorizontalCarouselViewState extends State<HorizontalCarouselView> {
  late final ScrollController _scrollController;
  bool _canScrollLeft = false;
  bool _canScrollRight = false;
  bool _isHoveringSection = false;

  bool get _isDesktop =>
      kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_updateScrollButtons);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateScrollButtons();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollButtons);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HorizontalCarouselView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemCount != widget.itemCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateScrollButtons();
      });
    }
  }

  void _updateScrollButtons() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final canLeft = position.pixels > 6.0;
    final canRight = position.pixels < (position.maxScrollExtent - 6.0);
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  void _scroll({required bool toRight}) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final viewport = position.viewportDimension;
    final step = widget.scrollStep ?? (viewport * 0.72).clamp(240.0, 950.0);
    final target = toRight
        ? (position.pixels + step).clamp(0.0, position.maxScrollExtent)
        : (position.pixels - step).clamp(0.0, position.maxScrollExtent);

    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateScrollButtons();
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = _isDesktop;

    // Vertical center for the arrow buttons:
    // If cardSize is given (e.g. 180), center directly on the album artwork square.
    final double buttonCenterY = widget.cardSize != null
        ? (widget.cardSize! / 2)
        : (widget.height / 2);
    const double buttonSize = 38.0;
    final double buttonTop = (buttonCenterY - (buttonSize / 2))
        .clamp(4.0, widget.height - buttonSize - 4.0);

    return MouseRegion(
      onEnter: (_) {
        if (isDesktop && !_isHoveringSection) {
          setState(() => _isHoveringSection = true);
        }
      },
      onExit: (_) {
        if (isDesktop && _isHoveringSection) {
          setState(() => _isHoveringSection = false);
        }
      },
      child: SizedBox(
        height: widget.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // List with mouse-drag support & edge fade
            Positioned.fill(
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  if (bounds.width <= 0) {
                    return const LinearGradient(
                      colors: [Color(0xFF000000), Color(0xFF000000)],
                    ).createShader(bounds);
                  }
                  const fadeWidth = 36.0;
                  final leftFrac = (_canScrollLeft ? fadeWidth / bounds.width : 0.0)
                      .clamp(0.0, 0.2);
                  final rightFrac =
                      (1.0 - (_canScrollRight ? fadeWidth / bounds.width : 0.0))
                          .clamp(0.8, 1.0);

                  return LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      if (_canScrollLeft)
                        Colors.transparent
                      else
                        const Color(0xFF000000),
                      const Color(0xFF000000),
                      const Color(0xFF000000),
                      if (_canScrollRight)
                        Colors.transparent
                      else
                        const Color(0xFF000000),
                    ],
                    stops: [
                      0.0,
                      leftFrac,
                      rightFrac,
                      1.0,
                    ],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                      PointerDeviceKind.stylus,
                    },
                  ),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      _updateScrollButtons();
                      return false;
                    },
                    child: ListView.separated(
                      controller: _scrollController,
                      padding: widget.padding,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      itemCount: widget.itemCount,
                      separatorBuilder: widget.separatorBuilder ??
                          (_, __) => const SizedBox(width: 14),
                      itemBuilder: widget.itemBuilder,
                    ),
                  ),
                ),
              ),
            ),

            // Left navigation button (<)
            if (isDesktop)
              Positioned(
                left: 8,
                top: buttonTop,
                child: AnimatedOpacity(
                  opacity: _canScrollLeft ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !_canScrollLeft,
                    child: _CarouselArrowButton(
                      icon: CupertinoIcons.chevron_left,
                      tooltip: 'Anterior',
                      isDark: isDark,
                      size: buttonSize,
                      onTap: () => _scroll(toRight: false),
                    ),
                  ),
                ),
              ),

            // Right navigation button (>)
            if (isDesktop)
              Positioned(
                right: 8,
                top: buttonTop,
                child: AnimatedOpacity(
                  opacity: _canScrollRight ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !_canScrollRight,
                    child: _CarouselArrowButton(
                      icon: CupertinoIcons.chevron_right,
                      tooltip: 'Siguiente',
                      isDark: isDark,
                      size: buttonSize,
                      onTap: () => _scroll(toRight: true),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CarouselArrowButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool isDark;
  final double size;
  final VoidCallback onTap;

  const _CarouselArrowButton({
    required this.icon,
    required this.tooltip,
    required this.isDark,
    required this.size,
    required this.onTap,
  });

  @override
  State<_CarouselArrowButton> createState() => _CarouselArrowButtonState();
}

class _CarouselArrowButtonState extends State<_CarouselArrowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark
        ? (_isHovered ? const Color(0xFF2C2C2E) : const Color(0xE61C1C1E))
        : (_isHovered ? Colors.white : const Color(0xF5FFFFFF));

    final iconColor = widget.isDark ? Colors.white : const Color(0xFF1C1C1E);

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _isHovered ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.isDark
                      ? Colors.white.withValues(alpha: _isHovered ? 0.35 : 0.18)
                      : Colors.black.withValues(alpha: _isHovered ? 0.2 : 0.1),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: _isHovered ? 0.35 : 0.22),
                    blurRadius: _isHovered ? 10 : 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                widget.icon,
                size: 18,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
