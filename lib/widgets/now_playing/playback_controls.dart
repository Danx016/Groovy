import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PlaybackControls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final bool isShuffleEnabled;
  final VoidCallback onShuffleToggle;
  final bool isRepeatEnabled;
  final VoidCallback onRepeatToggle;
  final Color accentColor;
  final bool showSecondaryControls;

  const PlaybackControls({
    super.key,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.isShuffleEnabled,
    required this.onShuffleToggle,
    required this.isRepeatEnabled,
    required this.onRepeatToggle,
    this.accentColor = Colors.white,
    this.showSecondaryControls = false,
  });

  @override
  Widget build(BuildContext context) {
    if (showSecondaryControls) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _SecondaryControlButton(
            icon: Icons.shuffle_rounded,
            isActive: isShuffleEnabled,
            activeColor: accentColor,
            onTap: onShuffleToggle,
          ),
          _MainControlButton(
            icon: Icons.fast_rewind_rounded,
            size: 46,
            onTap: onPrevious,
          ),
          _PlayPauseButton(
            isPlaying: isPlaying,
            onTap: onPlayPause,
            size: 70,
          ),
          _MainControlButton(
            icon: Icons.fast_forward_rounded,
            size: 46,
            onTap: onNext,
          ),
          _SecondaryControlButton(
            icon: Icons.repeat_rounded,
            isActive: isRepeatEnabled,
            activeColor: accentColor,
            onTap: onRepeatToggle,
          ),
        ],
      );
    }

    // Iconic Apple Music 3-button layout
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _MainControlButton(
          icon: Icons.fast_rewind_rounded,
          size: 48,
          onTap: onPrevious,
        ),
        _PlayPauseButton(
          isPlaying: isPlaying,
          onTap: onPlayPause,
          size: 72,
        ),
        _MainControlButton(
          icon: Icons.fast_forward_rounded,
          size: 48,
          onTap: onNext,
        ),
      ],
    );
  }
}

class _PlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onTap;
  final double size;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.onTap,
    this.size = 72,
  });

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() => _isPressed = true);
        HapticFeedback.mediumImpact();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.78 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: _isPressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: SizedBox(
          width: widget.size + 12,
          height: widget.size + 12,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: Icon(
                widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                key: ValueKey<bool>(widget.isPlaying),
                size: widget.size,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MainControlButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _MainControlButton({
    required this.icon,
    required this.onTap,
    this.size = 48,
  });

  @override
  State<_MainControlButton> createState() => _MainControlButtonState();
}

class _MainControlButtonState extends State<_MainControlButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() => _isPressed = true);
        HapticFeedback.mediumImpact();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.76 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: _isPressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: SizedBox(
          width: 64,
          height: 64,
          child: Center(
            child: Icon(
              widget.icon,
              size: widget.size,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryControlButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _SecondaryControlButton({
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            icon,
            color: isActive ? activeColor : Colors.white.withValues(alpha: 0.5),
            size: 24,
          ),
          if (isActive)
            Positioned(
              bottom: -6,
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: activeColor,
                ),
              ),
            ),
        ],
      ),
      onPressed: () {
        HapticFeedback.lightImpact();
        onTap();
      },
    );
  }
}


