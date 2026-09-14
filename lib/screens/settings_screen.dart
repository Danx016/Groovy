import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../l10n/app_localizations.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import 'settings_account_tab.dart';
import 'settings_playback_tab.dart';
import 'settings_display_tab.dart';
import 'settings_storage_tab.dart';
import 'settings_support_tab.dart';
import 'settings_about_tab.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final PageController _pageController;
  final ScrollController _tabsScrollController = ScrollController();
  int _selectedIndex = 0;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  bool get _isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tabsScrollController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    setState(() => _selectedIndex = index);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
    _scrollToTab(index);
  }

  void _scrollToTab(int index) {
    if (!_tabsScrollController.hasClients) return;
    final targetOffset = (index * 110.0) - 40.0;
    _tabsScrollController.animateTo(
      targetOffset.clamp(0.0, _tabsScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final tabs = [
      (
        icon: CupertinoIcons.person_crop_circle_fill,
        title: 'Cuenta',
        subtitle: 'Perfil, nombre y sesión',
        gradient: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
      ),
      (
        icon: CupertinoIcons.play_circle_fill,
        title: l10n.tabPlayback,
        subtitle: 'Audio, mezclas y AutoDJ',
        gradient: const [Color(0xFFFA243C), Color(0xFFE11D48)],
      ),
      (
        icon: CupertinoIcons.paintbrush_fill,
        title: l10n.tabDisplay,
        subtitle: 'Tema, colores e idioma',
        gradient: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
      ),
      (
        icon: CupertinoIcons.archivebox_fill,
        title: l10n.tabStorage,
        subtitle: 'Caché, descargas y datos',
        gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
      ),
      (
        icon: CupertinoIcons.heart_fill,
        title: 'Soporte',
        subtitle: 'Comunidad, Discord y donar',
        gradient: const [Color(0xFFEC4899), Color(0xFFDB2777)],
      ),
      (
        icon: CupertinoIcons.info_circle_fill,
        title: l10n.tabAbout,
        subtitle: 'Versión y novedades',
        gradient: const [Color(0xFF10B981), Color(0xFF059669)],
      ),
    ];

    final tabViews = const [
      SettingsAccountTab(),
      SettingsPlaybackTab(),
      SettingsDisplayTab(),
      SettingsStorageTab(),
      SettingsSupportTab(),
      SettingsAboutTab(),
    ];

    if (_isDesktop) {
      return _buildDesktopLayout(context, l10n, primaryColor, tabs, tabViews);
    }

    return _buildMobileLayout(context, l10n, primaryColor, tabs, tabViews);
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    AppLocalizations l10n,
    Color primaryColor,
    List<({IconData icon, String title, String subtitle, List<Color> gradient})> tabs,
    List<Widget> tabViews,
  ) {
    final sidebarBg = _isDark ? const Color(0xFF0C0D10) : const Color(0xFFF4F4F6);
    final borderColor = _isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);

    return Scaffold(
      backgroundColor: _isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      body: Row(
        children: [
          // Desktop Sidebar Panel
          Container(
            width: 290,
            decoration: BoxDecoration(
              color: sidebarBg,
              border: Border(right: BorderSide(color: borderColor, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header / Back navigation
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back Button
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.arrow_left,
                                size: 16,
                                color: _isDark ? Colors.white70 : Colors.black87,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Volver a Groovy',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Title
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF334B), Color(0xFFE50914)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE50914).withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              CupertinoIcons.slider_horizontal_3,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.settingsTitle,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: _isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                'Ajustes de la aplicación',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: _isDark ? Colors.white54 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Divider(height: 1, thickness: 1, color: borderColor),

                // Settings Tabs Navigation List
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    itemCount: tabs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final item = tabs[index];
                      final isSelected = _selectedIndex == index;

                      return InkWell(
                        onTap: () => setState(() => _selectedIndex = index),
                        borderRadius: BorderRadius.circular(14),
                        hoverColor: _isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.black.withValues(alpha: 0.03),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? primaryColor.withValues(alpha: _isDark ? 0.16 : 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? primaryColor.withValues(alpha: 0.3)
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Icon Badge
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: item.gradient,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: item.gradient.first.withValues(alpha: 0.4),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Icon(
                                  item.icon,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Title & Subtitle
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                        color: isSelected
                                            ? primaryColor
                                            : (_isDark ? Colors.white : Colors.black87),
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      item.subtitle,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _isDark ? Colors.white38 : Colors.black45,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Version Row
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'v${UpdateService.currentVersionDisplay}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: _isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Groovy Desktop',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: _isDark ? Colors.white38 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Tab View
          Expanded(
            child: Column(
              children: [
                // Top Tab Header
                Container(
                  padding: const EdgeInsets.fromLTRB(36, 24, 36, 16),
                  decoration: BoxDecoration(
                    color: _isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
                    border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        tabs[_selectedIndex].title,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: _isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          tabs[_selectedIndex].subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Tab Content with Animated Transition
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: KeyedSubtree(
                      key: ValueKey<int>(_selectedIndex),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 860),
                          child: tabViews[_selectedIndex],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    AppLocalizations l10n,
    Color primaryColor,
    List<({IconData icon, String title, String subtitle, List<Color> gradient})> tabs,
    List<Widget> tabViews,
  ) {
    return Scaffold(
      backgroundColor: _isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Icon(
                        CupertinoIcons.chevron_back,
                        size: 20,
                        color: _isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.settingsTitle,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: _isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'v${UpdateService.currentVersionDisplay}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Modern Horizontal Scrollable Pill Tab Bar
            SingleChildScrollView(
              controller: _tabsScrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: List.generate(tabs.length, (index) {
                  final item = tabs[index];
                  final isSelected = _selectedIndex == index;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _onTabSelected(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(
                                  colors: [
                                    primaryColor,
                                    primaryColor.withValues(alpha: 0.85),
                                  ],
                                )
                              : null,
                          color: isSelected
                              ? null
                              : (_isDark ? const Color(0xFF16171A) : Colors.white),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : (_isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.06)),
                            width: 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.icon,
                              size: 15,
                              color: isSelected
                                  ? Colors.white
                                  : (_isDark ? Colors.white70 : Colors.black54),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : (_isDark ? Colors.white : Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 6),

            // PageView for Smooth Tab Switching
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _selectedIndex = index);
                  _scrollToTab(index);
                },
                children: tabViews,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
