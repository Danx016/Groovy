import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../cast_button.dart';

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 1. Lyrics Button (Speech bubble with quote)
          _ActionButton(
            icon: Icons.chat_bubble_outline_rounded,
            isActive: isLyricsActive,
            onTap: onLyricsTap,
          ),

          // 2. AirPlay / Cast Button
          CastButton(
            iconSize: 23,
            iconColor: Colors.white.withValues(alpha: 0.58),
          ),

          // 3. Queue / Playlist Button (3-item list)
          _ActionButton(
            icon: Icons.format_list_bulleted_rounded,
            isActive: isQueueActive,
            onTap: onQueueTap,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;

  const _ActionButton({
    required this.icon,
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
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: widget.isActive
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9.0),
          ),
          child: Icon(
            widget.icon,
            color: widget.isActive 
                ? Colors.white 
                : Colors.white.withValues(alpha: 0.58),
            size: 23,
          ),
        ),
      ),
    );
  }
}


