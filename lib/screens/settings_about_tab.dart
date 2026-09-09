import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../l10n/app_localizations.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import '../widgets/settings/settings_section_card.dart';
import '../utils/context_extensions.dart';
import 'main_screen.dart';

class SettingsAboutTab extends StatelessWidget {
  const SettingsAboutTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        SettingsSectionCard(
          title: 'INFORMACIÓN',
          children: [
            _buildInfoTile(
              context,
              icon: CupertinoIcons.music_note_2,
              iconColor: const Color(0xFF1DB954),
              title: 'App',
              subtitle: 'Groovy',
            ),
            _buildDivider(context),
            _buildInfoTile(
              context,
              icon: CupertinoIcons.info,
              iconColor: Theme.of(context).colorScheme.primary,
              title: AppLocalizations.of(context)!.aboutVersion,
              subtitle: UpdateService.currentVersion,
            ),
            _buildDivider(context),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFE50914).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  CupertinoIcons.arrow_2_circlepath_circle,
                  color: Color(0xFFE50914),
                  size: 18,
                ),
              ),
              title: const Text('Buscar actualizaciones', style: TextStyle(fontSize: 16)),
              subtitle: const Text('Comprobar si hay una versión más reciente', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Buscando actualizaciones...'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                await UpdateService.clearSnooze();
                final release = await UpdateService.checkForUpdate(force: true);
                if (!context.mounted) return;
                if (release != null) {
                  MainScreen.showUpdateDialog(context, release);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('¡Tienes la última versión instalada (v${UpdateService.currentVersionDisplay})!'),
                      backgroundColor: const Color(0xFF1DB954),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              },
            ),
            _buildDivider(context),
            _buildInfoTile(
              context,
              icon: CupertinoIcons.device_phone_portrait,
              iconColor: const Color(0xFF007AFF),
              title: AppLocalizations.of(context)!.aboutPlatform,
              subtitle: Theme.of(context).platform.name.toUpperCase(),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SettingsSectionCard(
          title: 'DESARROLLADOR',
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1DB954), Color(0xFF15883e)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(CupertinoIcons.person_fill, color: Colors.white, size: 18),
              ),
              title: const Text(
                'Groovy Team',
                style: TextStyle(fontSize: 16),
              ),
              subtitle: Text(
                'Hecho con ❤️ para ti',
                style: TextStyle(
                  fontSize: 13,
                  color: context.isDark
                      ? AppTheme.darkSecondaryText
                      : AppTheme.lightSecondaryText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 56),
      child: Container(
        height: 0.5,
        color: context.isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
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
      title: Text(title, style: const TextStyle(fontSize: 16)),
      trailing: Text(
        subtitle,
        style: TextStyle(
          fontSize: 16,
          color: context.isDark
              ? AppTheme.darkSecondaryText
              : AppTheme.lightSecondaryText,
        ),
      ),
    );
  }
}
