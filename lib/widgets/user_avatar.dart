import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double size;

  const UserAvatar({
    super.key,
    this.avatarUrl,
    required this.name,
    this.size = 48,
  });

  static final List<Map<String, dynamic>> _presetAvatars = [
    {
      'id': 'preset_1',
      'colors': [Color(0xFFE50914), Color(0xFFFF416C)],
      'icon': CupertinoIcons.music_note_2,
    },
    {
      'id': 'preset_2',
      'colors': [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
      'icon': CupertinoIcons.circle_grid_hex_fill,
    },
    {
      'id': 'preset_3',
      'colors': [Color(0xFF00C9FF), Color(0xFF92FE9D)],
      'icon': CupertinoIcons.headphones,
    },
    {
      'id': 'preset_4',
      'colors': [Color(0xFFF7971E), Color(0xFFFFD200)],
      'icon': CupertinoIcons.waveform,
    },
    {
      'id': 'preset_5',
      'colors': [Color(0xFF232526), Color(0xFF414345)],
      'icon': CupertinoIcons.speaker_3_fill,
    },
    {
      'id': 'preset_6',
      'colors': [Color(0xFF654ea3), Color(0xFFeaafc8)],
      'icon': CupertinoIcons.mic_fill,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'G';

    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      // 1. Preset Avatar
      if (avatarUrl!.startsWith('preset:')) {
        final presetId = avatarUrl!.replaceFirst('preset:', '');
        final preset = _presetAvatars.firstWhere(
          (p) => p['id'] == presetId,
          orElse: () => _presetAvatars[0],
        );
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: preset['colors'] as List<Color>,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Icon(
            preset['icon'] as IconData,
            color: Colors.white,
            size: size * 0.48,
          ),
        );
      }

      // 2. Base64 image
      if (avatarUrl!.startsWith('data:image')) {
        try {
          final commaIndex = avatarUrl!.indexOf(',');
          if (commaIndex != -1) {
            final base64Data = avatarUrl!.substring(commaIndex + 1);
            final bytes = base64Decode(base64Data);
            return ClipOval(
              child: Image.memory(
                bytes,
                width: size,
                height: size,
                fit: BoxFit.cover,
              ),
            );
          }
        } catch (_) {}
      }

      // 3. Remote URL
      if (avatarUrl!.startsWith('http://') || avatarUrl!.startsWith('https://')) {
        return ClipOval(
          child: CachedNetworkImage(
            imageUrl: avatarUrl!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _buildDefault(initial),
          ),
        );
      }
    }

    return _buildDefault(initial);
  }

  Widget _buildDefault(String initial) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF1DB954), Color(0xFF15883e)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
