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
  late TextEditingController _usernameController;
  String? _avatarUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    _nameController = TextEditingController(text: user?.name ?? '');
    _usernameController = TextEditingController(
      text: (user?.name ?? '').toLowerCase().replaceAll(' ', '_'),
    );
    _avatarUrl = user?.avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
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

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El nombre no puede estar vacío'),
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
          content: Text('¡Perfil actualizado con éxito!'),
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

  Widget _buildAvatarWidget() {
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      // 1. Base64 Image
      if (_avatarUrl!.startsWith('data:image')) {
        try {
          final commaIndex = _avatarUrl!.indexOf(',');
          if (commaIndex != -1) {
            final base64Data = _avatarUrl!.substring(commaIndex + 1);
            final bytes = base64Decode(base64Data);
            return Stack(
              alignment: Alignment.center,
              children: [
                ClipOval(
                  child: Image.memory(
                    bytes,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Cambiar',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ],
            );
          }
        } catch (_) {}
      }

      // 2. Remote URL
      if (_avatarUrl!.startsWith('http://') || _avatarUrl!.startsWith('https://')) {
        return Stack(
          alignment: Alignment.center,
          children: [
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: _avatarUrl!,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Cambiar',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ],
        );
      }
    }

    // Default Apple Music "Agregar foto" grey circle with camera icon
    return Container(
      width: 120,
      height: 120,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF8E939D),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.camera,
            size: 34,
            color: Colors.white,
          ),
          SizedBox(height: 6),
          Text(
            'Agregar foto',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkBackground : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            CupertinoIcons.arrow_left,
            color: AppTheme.appleMusicRed,
            size: 24,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Large Apple Music Title
                    Text(
                      'Ayuda a otros a\nencontrarte',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        height: 1.15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Centered Circular Avatar
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: _buildAvatarWidget(),
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Field 1: Nombre
                    Text(
                      'Nombre',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    TextField(
                      controller: _nameController,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      cursorColor: AppTheme.appleMusicRed,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.only(top: 4, bottom: 8),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: isDark ? Colors.white24 : Colors.black26,
                            width: 1.0,
                          ),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: AppTheme.appleMusicRed,
                            width: 1.8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Field 2: Nombre de usuario
                    Text(
                      'Nombre de usuario',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    TextField(
                      controller: _usernameController,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      cursorColor: AppTheme.appleMusicRed,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.only(top: 4, bottom: 8),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: isDark ? Colors.white24 : Colors.black26,
                            width: 1.0,
                          ),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: AppTheme.appleMusicRed,
                            width: 1.8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Section: Clean "Continuar" button with no dolls/fine print
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEBEBF0),
                    foregroundColor: isDark ? Colors.white : Colors.black87,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.appleMusicRed,
                          ),
                        )
                      : const Text(
                          'Continuar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
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
