import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/update_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';
import '../utils/navigation_helper.dart';
import 'main_screen.dart';
import 'account_screen.dart';
import 'settings_display_tab.dart';
import 'settings_support_tab.dart';
import 'settings_about_tab.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  bool get _isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  void _navigateToSubScreen(BuildContext context, String title, Widget child) {
    NavigationHelper.push(
      context,
      _AppleMusicSettingsSubScreen(
        title: title,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    final userName =
        user?.name.isNotEmpty == true ? user!.name : 'Usuario Groovy';
    final userEmail =
        user?.email.isNotEmpty == true ? user!.email : 'No has iniciado sesión';

    final themeService = Provider.of<ThemeService>(context);
    String themeName = 'Sistema';
    if (themeService.themeMode == ThemeMode.dark) {
      themeName = 'Oscuro';
    } else if (themeService.themeMode == ThemeMode.light) {
      themeName = 'Claro';
    }

    final content = CustomScrollView(
      physics:
          const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        // 1. Top App Bar with Red Back Chevron
        SliverAppBar(
          pinned: true,
          floating: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor:
              isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
          leading: IconButton(
            icon: const Icon(
              CupertinoIcons.chevron_back,
              color: AppTheme.appleMusicRed,
              size: 28,
            ),
            tooltip: 'Atrás',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),

        // 2. Large Apple Music Header ("Configuración")
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 16.0),
            child: Text(
              'Configuración',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),

        // 3. Apple ID Style Profile / Account Card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _AppleMusicGroupedCard(
              isDark: isDark,
              children: [
                InkWell(
                  onTap: () =>
                      NavigationHelper.push(context, const AccountScreen()),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 14.0),
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
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                userEmail,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.black54,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          CupertinoIcons.chevron_forward,
                          size: 18,
                          color: isDark ? Colors.white30 : Colors.black26,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 4. Section: PREFERENCIAS (Apariencia)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(title: 'PREFERENCIAS', isDark: isDark),
                _AppleMusicGroupedCard(
                  isDark: isDark,
                  children: [
                    _AppleMusicSettingsTile(
                      isDark: isDark,
                      icon: CupertinoIcons.paintbrush_fill,
                      iconColor: const Color(0xFF5856D6),
                      title: 'Apariencia',
                      trailingText: themeName,
                      isLast: true,
                      onTap: () => _navigateToSubScreen(
                        context,
                        'Apariencia',
                        const SettingsDisplayTab(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // 5. Section: INFORMACIÓN & AYUDA
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(title: 'INFORMACIÓN', isDark: isDark),
                _AppleMusicGroupedCard(
                  isDark: isDark,
                  children: [
                    _AppleMusicSettingsTile(
                      isDark: isDark,
                      icon: CupertinoIcons.heart_fill,
                      iconColor: const Color(0xFFFF2D55),
                      title: 'Soporte y Comunidad',
                      subtitle: 'Discord, colaborar y reporte de fallos',
                      onTap: () => _navigateToSubScreen(
                        context,
                        'Soporte y Comunidad',
                        const SettingsSupportTab(),
                      ),
                    ),
                    _AppleMusicSettingsTile(
                      isDark: isDark,
                      icon: CupertinoIcons.info_circle_fill,
                      iconColor: const Color(0xFF8E8E93),
                      title: 'Acerca de Groovy',
                      trailingText: 'v${UpdateService.currentVersion}',
                      onTap: () => _navigateToSubScreen(
                        context,
                        'Acerca de Groovy',
                        const SettingsAboutTab(),
                      ),
                    ),
                    _AppleMusicSettingsTile(
                      isDark: isDark,
                      icon: CupertinoIcons.arrow_2_circlepath,
                      iconColor: const Color(0xFF007AFF),
                      title: 'Buscar actualizaciones',
                      subtitle: 'Comprobar si hay una versión nueva',
                      isLast: true,
                      onTap: () async {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Buscando actualizaciones...'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        await UpdateService.clearSnooze();
                        final release =
                            await UpdateService.checkForUpdate(force: true);
                        if (!context.mounted) return;
                        if (release != null) {
                          MainScreen.showUpdateDialog(context, release);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '¡Tienes la última versión instalada (v${UpdateService.currentVersionDisplay})!'),
                              backgroundColor: const Color(0xFF1DB954),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // 6. Apple Music Footer
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 36.0, bottom: 48.0),
            child: Column(
              children: [
                Text(
                  'Groovy Music',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Versión ${UpdateService.currentVersion} • Hecho con 💙 en El Carmen de Bolívar',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      body: _isDesktop
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: content,
              ),
            )
          : content,
    );
  }
}

// ── APPLE MUSIC SECTION TITLE ────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  final bool isDark;

  const _SectionTitle({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, top: 24.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: isDark ? Colors.white54 : Colors.black45,
        ),
      ),
    );
  }
}

// ── APPLE MUSIC GROUPED CARD CONTAINER ───────────────────────────────────────
class _AppleMusicGroupedCard extends StatelessWidget {
  final List<Widget> children;
  final bool isDark;

  const _AppleMusicGroupedCard({
    required this.children,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

// ── APPLE MUSIC SETTINGS TILE ────────────────────────────────────────────────
class _AppleMusicSettingsTile extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final bool isLast;
  final VoidCallback onTap;

  const _AppleMusicSettingsTile({
    required this.isDark,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.isLast = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.06);

    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                // iOS Styled App Icon Badge
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),

                // Title and optional subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.3,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Trailing text (e.g. current theme or version)
                if (trailingText != null) ...[
                  Text(
                    trailingText!,
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

                // iOS Chevron
                Icon(
                  CupertinoIcons.chevron_forward,
                  size: 16,
                  color: isDark ? Colors.white30 : Colors.black26,
                ),
              ],
            ),
          ),
          if (!isLast)
            Divider(
              height: 0.5,
              thickness: 0.5,
              color: dividerColor,
              indent: 62,
            ),
        ],
      ),
    );
  }
}

// ── APPLE MUSIC SUB-SCREEN WRAPPER ───────────────────────────────────────────
class _AppleMusicSettingsSubScreen extends StatelessWidget {
  final String title;
  final Widget child;

  const _AppleMusicSettingsSubScreen({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        backgroundColor:
            isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            CupertinoIcons.chevron_back,
            color: AppTheme.appleMusicRed,
            size: 28,
          ),
          tooltip: 'Atrás',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: child,
    );
  }
}
