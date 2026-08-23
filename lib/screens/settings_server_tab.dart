import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/settings/settings_section_card.dart';
import '../widgets/user_avatar.dart';
import '../utils/context_extensions.dart';
import '../utils/navigation_helper.dart';
import 'edit_profile_screen.dart';

class SettingsServerTab extends StatefulWidget {
  const SettingsServerTab({super.key});

  @override
  State<SettingsServerTab> createState() => _SettingsServerTabState();
}

class _SettingsServerTabState extends State<SettingsServerTab> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    final userName = user?.name.isNotEmpty == true ? user!.name : 'Usuario Groovy';
    final userEmail = user?.email.isNotEmpty == true ? user!.email : 'No autenticado';

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        // User Profile Card
        SettingsSectionCard(
          title: 'Tu Cuenta',
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  UserAvatar(
                    name: userName,
                    avatarUrl: user?.avatarUrl,
                    size: 56,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userEmail,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.isDark
                                ? AppTheme.darkSecondaryText
                                : AppTheme.lightSecondaryText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1DB954).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Groovy Cloud • Activo',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1DB954),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      CupertinoIcons.pencil_circle_fill,
                      color: AppTheme.appleMusicRed,
                      size: 30,
                    ),
                    tooltip: 'Editar Perfil',
                    onPressed: () {
                      NavigationHelper.push(context, const EditProfileScreen());
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Cloud Storage / Database Status
        SettingsSectionCard(
          title: 'Servicios en la Nube',
          children: [
            _buildInfoTile(
              icon: CupertinoIcons.circle_grid_hex,
              iconColor: const Color(0xFF3861FB),
              title: 'Base de Datos',
              subtitle: 'MySQL 8.0 (Groovy Cloud Server)',
            ),
            const SettingsDivider(),
            _buildInfoTile(
              icon: CupertinoIcons.cloud_upload,
              iconColor: const Color(0xFF1DB954),
              title: 'Sincronización Automática',
              subtitle: 'Favoritos, listas de reproducción e historial',
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Logout
        SettingsSectionCard(
          title: 'Sesión',
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(CupertinoIcons.square_arrow_right, color: Colors.redAccent, size: 18),
              ),
              title: const Text(
                'Cerrar Sesión',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Cierra tu sesión en este dispositivo',
                style: TextStyle(
                  fontSize: 13,
                  color: context.isDark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText,
                ),
              ),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Cerrar Sesión'),
                    content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                        child: const Text('Cerrar Sesión'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  await authProvider.logout();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: context.isDark
              ? AppTheme.darkSecondaryText
              : AppTheme.lightSecondaryText,
        ),
      ),
    );
  }
}
