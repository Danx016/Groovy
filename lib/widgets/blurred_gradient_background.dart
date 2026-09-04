import 'package:flutter/material.dart';

class BlurredGradientBackground extends StatelessWidget {
  final List<Color> colors;
  final ImageProvider? image;
  final Widget child;

  const BlurredGradientBackground({
    super.key,
    required this.colors,
    this.image,
    required this.child,
  });

  List<Color> _normalizedColors(List<Color> raw) {
    if (raw.isEmpty) {
      return const [
        Color(0xFFB86B35), // Warm Amber
        Color(0xFF8B4513), // Saddle Brown
        Color(0xFFD27D2D), // Ochre Terracotta
        Color(0xFFE89A4B), // Radiant Gold
        Color(0xFF1E120A), // Deep Base
      ];
    }
    final list = List<Color>.from(raw);
    while (list.length < 5) {
      list.add(list.last);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final normColors = _normalizedColors(colors);
    final c0 = normColors[0];
    final c1 = normColors[1];
    final c3 = normColors[3];
    final c4 = normColors[4];

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Fully isolated GPU-cached background layer
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    c0.withValues(alpha: 0.95),
                    c3.withValues(alpha: 0.78),
                    c1.withValues(alpha: 0.72),
                    c4,
                  ],
                  stops: const [0.0, 0.32, 0.65, 1.0],
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.16),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.28),
                    ],
                    stops: const [0.0, 0.28, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ),

        // 2. Foreground interactive content (re-renders without invalidating the background GPU texture)
        Positioned.fill(
          child: child,
        ),
      ],
    );
  }
}
