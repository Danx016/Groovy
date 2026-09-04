import 'package:flutter/material.dart';

class BlurredGradientBackground extends StatefulWidget {
  final List<Color> colors;
  final ImageProvider? image;
  final Widget child;

  const BlurredGradientBackground({
    super.key,
    required this.colors,
    this.image,
    required this.child,
  });

  @override
  State<BlurredGradientBackground> createState() => _BlurredGradientBackgroundState();
}

class _BlurredGradientBackgroundState extends State<BlurredGradientBackground> {
  List<Color> _normalizedColors(List<Color> raw) {
    if (raw.isEmpty) {
      return [
        const Color(0xFFB86B35), // Warm Amber
        const Color(0xFF8B4513), // Saddle Brown
        const Color(0xFFD27D2D), // Ochre Terracotta
        const Color(0xFFE89A4B), // Radiant Gold
        const Color(0xFF22140D), // Deep Base
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
    final colors = _normalizedColors(widget.colors);
    final c0 = colors[0];
    final c1 = colors[1];
    final c2 = colors[2];
    final c3 = colors[3];
    final c4 = colors[4];

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Base Chromatic Layer
        Positioned.fill(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeInOutCubic,
            color: c4,
          ),
        ),

        // 2. High-Performance Sweeping Liquid Gradient (0% CPU / 0% GPU Idle)
        Positioned.fill(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeInOutCubic,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  c0.withValues(alpha: 0.95),
                  c3.withValues(alpha: 0.85),
                  c1.withValues(alpha: 0.80),
                  c2.withValues(alpha: 0.70),
                ],
                stops: const [0.0, 0.35, 0.70, 1.0],
              ),
            ),
          ),
        ),

        // 3. Focal Radial Glow Layer
        Positioned.fill(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeInOutCubic,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.1, -0.2),
                radius: 1.1,
                colors: [
                  c3.withValues(alpha: 0.55),
                  c0.withValues(alpha: 0.20),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),

        // 4. Soft Atmospheric Vignette
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.12),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.06),
                    Colors.black.withValues(alpha: 0.24),
                  ],
                  stops: const [0.0, 0.30, 0.70, 1.0],
                ),
              ),
            ),
          ),
        ),

        // 5. Foreground Interactive Content
        Positioned.fill(
          child: widget.child,
        ),
      ],
    );
  }
}
