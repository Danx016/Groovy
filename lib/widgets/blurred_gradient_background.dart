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
        Color(0xFF16161E),
        Color(0xFF1E1E28),
        Color(0xFF121218),
        Color(0xFF242434),
        Color(0xFF09090D),
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
    final c2 = normColors[2];
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
                    c3.withValues(alpha: 0.80),
                    c2.withValues(alpha: 0.75),
                    c1.withValues(alpha: 0.70),
                    c4,
                  ],
                  stops: const [0.0, 0.28, 0.54, 0.78, 1.0],
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.0, -0.25),
                        radius: 0.95,
                        colors: [
                          c3.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 1.0],
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.14),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.32),
                        ],
                        stops: const [0.0, 0.30, 1.0],
                      ),
                    ),
                  ),
                ],
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
