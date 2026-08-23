import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/settings/settings_section_card.dart';
import '../utils/context_extensions.dart';

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
              subtitle: '1.0.0',
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
        const SizedBox(height: 24),
        SettingsSectionCard(
          title: 'TECNOLOGÍA',
          children: [
            _buildInfoTile(
              context,
              icon: CupertinoIcons.cloud,
              iconColor: const Color(0xFF3861FB),
              title: 'Base de Datos',
              subtitle: 'MySQL 8.0',
            ),
            _buildDivider(context),
            _buildInfoTile(
              context,
              icon: CupertinoIcons.bolt,
              iconColor: const Color(0xFFFF9500),
              title: 'Framework',
              subtitle: 'Flutter',
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
