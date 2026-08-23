import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../providers/auth_provider.dart';
import '../theme/theme.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  String? _avatarUrl;
  bool _isLoading = false;

  // Preset music-themed avatars (using stylish SVG/Icon combinations or Web URLs)
  final List<Map<String, dynamic>> _presetAvatars = [
    {
      'id': 'preset_1',
      'name': 'Groovy Neon',
      'colors': [Color(0xFFE50914), Color(0xFFFF416C)],
      'icon': CupertinoIcons.music_note_2,
    },
    {
      'id': 'preset_2',
      'name': 'Vinyl Retro',
      'colors': [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
      'icon': CupertinoIcons.circle_grid_hex_fill,
    },
    {
      'id': 'preset_3',
      'name': 'DJ Vibes',
      'colors': [Color(0xFF00C9FF), Color(0xFF92FE9D)],
      'icon': CupertinoIcons.headphones,
    },
    {
      'id': 'preset_4',
      'name': 'Electric Wave',
      'colors': [Color(0xFFF7971E), Color(0xFFFFD200)],
      'icon': CupertinoIcons.waveform,
    },
    {
      'id': 'preset_5',
      'name': 'Dark Techno',
      'colors': [Color(0xFF232526), Color(0xFF414345)],
      'icon': CupertinoIcons.speaker_3_fill,
    },
    {
      'id': 'preset_6',
      'name': 'Midnight Jam',
      'colors': [Color(0xFF654ea3), Color(0xFFeaafc8)],
      'icon': CupertinoIcons.mic_fill,
    },
  ];

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    _nameController = TextEditingController(text: user?.name ?? '');
    _avatarUrl = user?.avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          // Convert to Base64 Data URL
          final base64String = base64Encode(file.bytes!);
          final ext = file.extension?.toLowerCase() ?? 'jpeg';
          final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
          setState(() {
            _avatarUrl = 'data:$mime;base64,$base64String';
          });
        } else if (file.path != null) {
          final bytes = await File(file.path!).readAsBytes();
          final base64String = base64Encode(bytes);
          final ext = file.extension?.toLowerCase() ?? 'jpeg';
          final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
          setState(() {
            _avatarUrl = 'data:$mime;base64,$base64String';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _selectPreset(String presetId) {
    setState(() {
      _avatarUrl = 'preset:$presetId';
    });
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El nombre de usuario no puede estar vacío'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.updateUserProfile(
      name: name,
      avatarUrl: _avatarUrl,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Perfil actualizado con éxito! 🎉'),
          backgroundColor: Color(0xFF1DB954),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? 'Error al guardar los cambios.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildAvatarPreview(String initial) {
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      // 1. Preset Avatar
      if (_avatarUrl!.startsWith('preset:')) {
        final presetId = _avatarUrl!.replaceFirst('preset:', '');
        final preset = _presetAvatars.firstWhere(
          (p) => p['id'] == presetId,
          orElse: () => _presetAvatars[0],
        );
        return Container(
          width: 110,
          height: 110,
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
            size: 50,
          ),
        );
      }

      // 2. Base64 Image
      if (_avatarUrl!.startsWith('data:image')) {
        try {
          final commaIndex = _avatarUrl!.indexOf(',');
          if (commaIndex != -1) {
            final base64Data = _avatarUrl!.substring(commaIndex + 1);
            final bytes = base64Decode(base64Data);
            return ClipOval(
              child: Image.memory(
                bytes,
                width: 110,
                height: 110,
                fit: BoxFit.cover,
              ),
            );
          }
        } catch (_) {}
      }

      // 3. Remote URL
      if (_avatarUrl!.startsWith('http://') || _avatarUrl!.startsWith('https://')) {
        return ClipOval(
          child: CachedNetworkImage(
            imageUrl: _avatarUrl!,
            width: 110,
            height: 110,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _buildDefaultAvatar(initial),
          ),
        );
      }
    }

    return _buildDefaultAvatar(initial);
  }

  Widget _buildDefaultAvatar(String initial) {
    return Container(
      width: 110,
      height: 110,
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
        style: const TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    final initial = _nameController.text.isNotEmpty
        ? _nameController.text[0].toUpperCase()
        : (user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'G');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Guardar',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.appleMusicRed,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar with camera button
            Center(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: _buildAvatarPreview(initial),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.appleMusicRed,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                            width: 3,
                          ),
                        ),
                        child: const Icon(
                          CupertinoIcons.camera_fill,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _pickImage,
              icon: const Icon(CupertinoIcons.photo, size: 18),
              label: const Text('Elegir foto de la galería'),
              style: TextButton.styleFrom(
                foregroundColor: isDark ? Colors.white70 : Colors.black87,
              ),
            ),

            const SizedBox(height: 24),

            // Preset Avatars Section
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'O ELIGE UN AVATAR DE GROOVY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _presetAvatars.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (ctx, i) {
                  final preset = _presetAvatars[i];
                  final isSelected = _avatarUrl == 'preset:${preset['id']}';

                  return GestureDetector(
                    onTap: () => _selectPreset(preset['id'] as String),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: preset['colors'] as List<Color>,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [
                                const BoxShadow(
                                  color: AppTheme.appleMusicRed,
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                      child: Icon(
                        preset['icon'] as IconData,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 32),

            // Form Inputs
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'INFORMACIÓN DEL PERFIL',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Name Field
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : AppTheme.lightBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppTheme.darkDivider.withValues(alpha: 0.3) : AppTheme.lightDivider,
                  width: 0.5,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _nameController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Nombre de usuario',
                  border: InputBorder.none,
                  prefixIcon: Icon(CupertinoIcons.person),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Email Field (Read Only)
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkCard.withValues(alpha: 0.5)
                    : AppTheme.lightBackground.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppTheme.darkDivider.withValues(alpha: 0.2) : AppTheme.lightDivider,
                  width: 0.5,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.mail, color: Colors.grey),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Correo Electrónico (No editable)',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email.isNotEmpty == true ? user!.email : 'No registrado',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(CupertinoIcons.lock_fill, size: 16, color: Colors.grey),
                ],
              ),
            ),

            const SizedBox(height: 36),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.appleMusicRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Guardar Cambios',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
