import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import '../utils/navigation_helper.dart';
import '../widgets/user_avatar.dart';
import 'edit_profile_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    final userName = user?.name.isNotEmpty == true ? user!.name : 'Nombre';
    final userEmail = user?.email.isNotEmpty == true ? user!.email : 'correo@ejemplo.com';

    final dividerColor = isDark ? Colors.white12 : Colors.black12;

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
        title: Text(
          'Cuenta',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // 1. Profile Header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                UserAvatar(
                  name: userName,
                  avatarUrl: user?.avatarUrl,
                  size: 54,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    userName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _showEditNameDialog(context, authProvider);
                  },
                  child: const Text(
                    'Editar',
                    style: TextStyle(
                      color: AppTheme.appleMusicRed,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Text(
              'Tu nombre y foto serán visibles para los colaboradores de las playlists y de las sesiones de escucha conjunta.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.black54,
                height: 1.35,
              ),
            ),
          ),
          Divider(color: dividerColor, height: 24),

          // 2. Configura tu perfil
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Configura tu perfil',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Configura tu perfil para compartir tu música y ver lo que están escuchando tus amigos.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                  height: 1.3,
                ),
              ),
            ),
            onTap: () {
              NavigationHelper.push(context, const EditProfileScreen());
            },
          ),
          Divider(color: dividerColor, height: 24),

          // 3. Suscripción
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: const Text(
              'Suscripción',
              style: TextStyle(
                color: AppTheme.appleMusicRed,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Administrar familia',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Plan familiar activo')),
              );
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Canjear código',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            onTap: () {
              _showRedeemCodeDialog(context);
            },
          ),
          Divider(color: dividerColor, height: 24),

          // 4. Notificaciones
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: const Text(
              'Notificaciones',
              style: TextStyle(
                color: AppTheme.appleMusicRed,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Groovy asocia los datos de interacción y revisión de notificaciones con tu cuenta de Groovy.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.black54,
                height: 1.35,
              ),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Administrar notificaciones',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notificaciones habilitadas')),
              );
            },
          ),
          Divider(color: dividerColor, height: 24),

          // 5. Apps con acceso & Cerrar sesión
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Apps con acceso',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            onTap: () {},
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Cerrar sesión',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.redAccent,
              ),
            ),
            subtitle: Text(
              userEmail,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            onTap: () => _confirmLogout(context),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showRedeemCodeDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Canjear código'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Introduce el código de promoción',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Código aplicado con éxito')),
              );
            },
            child: const Text('Canjear'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await playerProvider.stop();
      await authProvider.logout();
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  void _showEditNameDialog(BuildContext context, AuthProvider authProvider) {
    final user = authProvider.currentUser;
    final controller = TextEditingController(text: user?.name ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Close button X
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.close,
                      size: 22,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 16),
                  // Avatar + Name Input
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      UserAvatar(
                        name: controller.text.isNotEmpty ? controller.text : (user?.name ?? 'Usuario'),
                        avatarUrl: user?.avatarUrl,
                        size: 52,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          autofocus: true,
                          cursorColor: AppTheme.appleMusicRed,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Nombre',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 18,
                              fontWeight: FontWeight.normal,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 6),
                            enabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: AppTheme.appleMusicRed, width: 1.5),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: AppTheme.appleMusicRed, width: 2.0),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Continuar button in red
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () async {
                        final newName = controller.text.trim();
                        if (newName.isNotEmpty) {
                          await authProvider.updateUserProfile(
                            name: newName,
                            avatarUrl: user?.avatarUrl,
                          );
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minimumSize: Size.zero,
                      ),
                      child: const Text(
                        'Continuar',
                        style: TextStyle(
                          color: AppTheme.appleMusicRed,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
