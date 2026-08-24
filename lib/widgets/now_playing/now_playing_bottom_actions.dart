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
      padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 1. Lyrics Button
          _ActionButton(
            icon: Icons.chat_bubble_outline_rounded,
            isActive: isLyricsActive,
            activeColor: Colors.white,
            onTap: onLyricsTap,
          ),

          // 2. Cast / AirPlay Button
          CastButton(
            iconSize: 22,
            iconColor: Colors.white.withValues(alpha: 0.6),
          ),

          // 3. Queue / Playlist Button
          _ActionButton(
            icon: Icons.format_list_bulleted_rounded,
            isActive: isQueueActive,
            activeColor: Colors.white,
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
  final Color activeColor;

  const _ActionButton({
    required this.icon,
    required this.onTap,
    this.isActive = false,
    this.activeColor = Colors.white,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(10.0),
          decoration: BoxDecoration(
            color: widget.isActive
                ? Colors.white.withValues(alpha: 0.22)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Icon(
            widget.icon,
            color: widget.isActive 
                ? widget.activeColor 
                : Colors.white.withValues(alpha: 0.6),
            size: 22,
          ),
        ),
      ),
    );
  }
}

