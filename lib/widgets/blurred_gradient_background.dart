import 'package:flutter/material.dart';
import 'dart:math' as math;

class BlurredGradientBackground extends StatefulWidget {
  final List<Color> colors;
  final Widget child;

  const BlurredGradientBackground({
    super.key,
    required this.colors,
    required this.child,
  });

  @override
  State<BlurredGradientBackground> createState() => _BlurredGradientBackgroundState();
}

class _BlurredGradientBackgroundState extends State<BlurredGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
    
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If no colors provided, use a rich warm fallback
    final safeColors = widget.colors.isNotEmpty 
      ? List<Color>.from(widget.colors)
      : [const Color(0xFF7A5C38), const Color(0xFF9E7B4C), const Color(0xFF4A3520)];
      
    while (safeColors.length < 4) {
      safeColors.add(safeColors.last.withValues(alpha: 0.85));
    }

    final c1 = safeColors[0];
    final c2 = safeColors[1];
    final c3 = safeColors[2];
    final c4 = safeColors[3];

    return Stack(
      children: [
        // 1. Base vibrant gradient (never pitch black)
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  c1.withValues(alpha: 0.95),
                  c2.withValues(alpha: 0.85),
                  c3.withValues(alpha: 0.90),
                  c4.withValues(alpha: 0.95),
                ],
                stops: const [0.0, 0.35, 0.70, 1.0],
              ),
            ),
          ),
        ),
        
        // 2. Animated fluid radiant blobs
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                final value = _animation.value;
                final screenWidth = MediaQuery.of(context).size.width;
                final screenHeight = MediaQuery.of(context).size.height;

                return Stack(
                  children: [
                    // Blob 1 (Top / Center moving)
                    Positioned(
                      top: -150 + (120 * value),
                      left: -100 + (80 * math.sin(value * math.pi)),
                      width: screenWidth * 1.5,
                      height: screenWidth * 1.5,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              c2.withValues(alpha: 0.9),
                              c2.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Blob 2 (Bottom / Right moving)
                    Positioned(
                      bottom: -200 + (140 * (1 - value)),
                      right: -120 + (100 * math.cos(value * math.pi)),
                      width: screenWidth * 1.6,
                      height: screenWidth * 1.6,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              c1.withValues(alpha: 0.85),
                              c1.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Blob 3 (Center pulsating)
                    Positioned(
                      top: screenHeight * 0.3 + (80 * math.sin(value * math.pi * 2)),
                      left: screenWidth * 0.1 + (60 * math.cos(value * math.pi * 2)),
                      width: screenWidth * 1.3,
                      height: screenWidth * 1.3,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              c3.withValues(alpha: 0.8),
                              c3.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        // 3. Subtle overlay for Apple Music readability without destroying the vibrant glow
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.10),
                  Colors.black.withValues(alpha: 0.05),
                  Colors.black.withValues(alpha: 0.25),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),

        // 4. Content
        RepaintBoundary(
          child: widget.child,
        ),
      ],
    );
  }
}
