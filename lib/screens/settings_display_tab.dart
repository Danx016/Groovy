import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../services/recommendation_service.dart';
import '../services/player_ui_settings_service.dart';
import '../services/theme_service.dart';
import '../services/locale_service.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../widgets/settings/settings_section_card.dart';
import '../widgets/settings/settings_icon_badge.dart';
import '../utils/context_extensions.dart';

class SettingsDisplayTab extends StatefulWidget {
  const SettingsDisplayTab({super.key});

  @override
  State<SettingsDisplayTab> createState() => _SettingsDisplayTabState();
}

class _SettingsDisplayTabState extends State<SettingsDisplayTab> {
  final _playerUiSettings = PlayerUiSettingsService();
  bool _liveSearch = true;

  ThemeMode _themeMode = ThemeMode.system;
  AccentColor _accentColor = AccentColor.red;
  bool _liquidGlass = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _playerUiSettings.initialize();

    if (!mounted) return;
    final themeService = Provider.of<ThemeService>(context, listen: false);

    setState(() {
      _liveSearch = _playerUiSettings.getLiveSearch();
      _themeMode = themeService.themeMode;
      _accentColor = themeService.accentColor;
      _liquidGlass = themeService.liquidGlass;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        // 1. Apariencia
        SettingsSectionCard(
          title: AppLocalizations.of(context)!.appearanceSection.toUpperCase(),
          children: [_buildAppearanceEditor()],
        ),
        const SizedBox(height: 24),

        // 2. Idioma
        SettingsSectionCard(
          title: AppLocalizations.of(context)!.language.toUpperCase(),
          children: [
            _buildLanguageSelector(),
          ],
        ),
        const SizedBox(height: 24),

        // 3. Búsqueda en vivo
        SettingsSectionCard(
          title: AppLocalizations.of(context)!.liveSearchSection.toUpperCase(),
          children: [
            _buildLiveSearchToggle(),
          ],
        ),
        const SizedBox(height: 24),

        // 4. Recomendaciones inteligentes
        SettingsSectionCard(
          title: AppLocalizations.of(
            context,
          )!.smartRecommendations.toUpperCase(),
          children: [
            _buildRecommendationsToggle(),
            const SettingsDivider(),
            _buildRecommendationsStats(),
            const SettingsDivider(),
            _buildClearRecommendationsButton(),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildAppearanceEditor() {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final isDark = context.isDark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Theme Mode (System / Light / Dark)
          _ThemeModeSelector(
            value: _themeMode,
            isDark: isDark,
            onChanged: (mode) async {
              setState(() => _themeMode = mode);
              await themeService.setThemeMode(mode);
            },
          ),
          const SizedBox(height: 20),

          // Accent Color
          const Text(
            'Color de acento',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          _AccentColorPicker(
            selected: _accentColor,
            onChanged: (color) async {
              setState(() => _accentColor = color);
              await themeService.setAccentColor(color);
            },
          ),
          const SizedBox(height: 20),

          // Liquid Glass Toggle (Dark Mode only)
          if (isDark) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _liquidGlass
                      ? const Color(0xFF64D2FF).withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF64D2FF), Color(0xFF0A84FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          CupertinoIcons.sparkles,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Efecto Liquid Glass',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Fondo translúcido estilo cristal fluido en el reproductor',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.isDark
                                    ? AppTheme.darkSecondaryText
                                    : AppTheme.lightSecondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Spacer(),
                      CupertinoSwitch(
                        value: _liquidGlass,
                        activeTrackColor: const Color(0xFF64D2FF),
                        onChanged: (value) async {
                          setState(() => _liquidGlass = value);
                          await themeService.setLiquidGlass(value);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLiveSearchToggle() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: SettingsIconBadge(
        gradientColors: const [Color(0xFFFF9500), Color(0xFFFFCC00)],
        icon: CupertinoIcons.search,
      ),
      title: Text(
        AppLocalizations.of(context)!.liveSearch,
        style: const TextStyle(fontSize: 16),
      ),
      subtitle: Text(
        AppLocalizations.of(context)!.liveSearchSubtitle,
        style: TextStyle(
          fontSize: 13,
          color: context.isDark
              ? AppTheme.darkSecondaryText
              : AppTheme.lightSecondaryText,
        ),
      ),
      trailing: CupertinoSwitch(
        value: _liveSearch,
        activeTrackColor: Theme.of(context).colorScheme.primary,
        onChanged: (value) async {
          setState(() => _liveSearch = value);
          await _playerUiSettings.setLiveSearch(value);
        },
      ),
    );
  }

  Widget _buildRecommendationsToggle() {
    return Consumer<RecommendationService>(
      builder: (context, service, _) {
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: SettingsIconBadge(
            gradientColors: const [Color(0xFFFF2D55), Color(0xFFFF6B6B)],
            icon: CupertinoIcons.sparkles,
          ),
          title: Text(
            AppLocalizations.of(context)!.enableRecommendations,
            style: const TextStyle(fontSize: 16),
          ),
          subtitle: Text(
            AppLocalizations.of(context)!.enableRecommendationsSubtitle,
            style: TextStyle(
              fontSize: 13,
              color: context.isDark
                  ? AppTheme.darkSecondaryText
                  : AppTheme.lightSecondaryText,
            ),
          ),
          trailing: CupertinoSwitch(
            value: service.enabled,
            activeTrackColor: Theme.of(context).colorScheme.primary,
            onChanged: (value) => service.setEnabled(value),
          ),
        );
      },
    );
  }

  Widget _buildRecommendationsStats() {
    return Consumer<RecommendationService>(
      builder: (context, service, _) {
        final stats = service.getListeningStats();
        final uniqueSongs = stats['uniqueSongs'] ?? 0;
        final totalPlays = stats['totalPlays'] ?? 0;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          title: Text(
            AppLocalizations.of(context)!.listeningData,
            style: const TextStyle(fontSize: 16),
          ),
          subtitle: Text(
            AppLocalizations.of(context)!.totalPlays(totalPlays),
            style: TextStyle(
              fontSize: 13,
              color: context.isDark
                  ? AppTheme.darkSecondaryText
                  : AppTheme.lightSecondaryText,
            ),
          ),
          trailing: Text(
            AppLocalizations.of(context)!.songsCount(uniqueSongs),
            style: TextStyle(
              fontSize: 14,
              color: context.isDark
                  ? AppTheme.darkSecondaryText
                  : AppTheme.lightSecondaryText,
            ),
          ),
        );
      },
    );
  }

  Widget _buildClearRecommendationsButton() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        AppLocalizations.of(context)!.clearListeningHistory,
        style: const TextStyle(fontSize: 16, color: Color(0xFFFF3B30)),
      ),
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.clearListeningHistory),
            content: Text(AppLocalizations.of(context)!.confirmClearHistory),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Provider.of<RecommendationService>(
                    context,
                    listen: false,
                  ).clearData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(context)!.historyCleared,
                      ),
                    ),
                  );
                },
                child: Text(
                  AppLocalizations.of(context)!.delete,
                  style: const TextStyle(color: Color(0xFFFF3B30)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageSelector() {
    return Consumer<LocaleService>(
      builder: (context, localeService, _) {
        final currentLocale = localeService.currentLocale;
        final currentLanguageCode = currentLocale?.languageCode ?? 'en';
        final currentLanguageName =
            LocaleService.supportedLanguages[currentLanguageCode] ?? 'English';

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: SettingsIconBadge(
            gradientColors: const [Color(0xFF34C759), Color(0xFF30D158)],
            icon: CupertinoIcons.globe,
          ),
          title: Text(
            AppLocalizations.of(context)!.language,
            style: const TextStyle(fontSize: 16),
          ),
          subtitle: Text(
            currentLanguageName,
            style: TextStyle(
              fontSize: 13,
              color: context.isDark
                  ? AppTheme.darkSecondaryText
                  : AppTheme.lightSecondaryText,
            ),
          ),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => _showLanguagePicker(context, localeService),
        );
      },
    );
  }

  void _showLanguagePicker(BuildContext context, LocaleService localeService) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: context.isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.isDark ? Colors.grey[600] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.globe, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    AppLocalizations.of(context)!.selectLanguage,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(CupertinoIcons.device_phone_portrait),
              title: Text(AppLocalizations.of(context)!.systemDefault),
              trailing: localeService.currentLocale == null
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                localeService.setLocale(null);
                Navigator.pop(context);
              },
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: LocaleService.supportedLanguages.entries.map((entry) {
                  final isSelected =
                      localeService.currentLocale?.languageCode == entry.key;
                  return ListTile(
                    leading: Text(
                      _getFlagEmoji(entry.key),
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(entry.value),
                    trailing: isSelected
                        ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () {
                      localeService.setLocale(Locale(entry.key));
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFlagEmoji(String languageCode) {
    const Map<String, String> flagMap = {
      'en': '🇬🇧',
      'sq': '🇦🇱',
      'it': '🇮🇹',
      'bn': '🇧🇩',
      'zh': '🇨🇳',
      'da': '🇩🇰',
      'fi': '🇫🇮',
      'fr': '🇫🇷',
      'de': '🇩🇪',
      'el': '🇬🇷',
      'hi': '🇮🇳',
      'id': '🇮🇩',
      'ga': '🇮🇪',
      'no': '🇳🇴',
      'pl': '🇵🇱',
      'pt': '🇵🇹',
      'ro': '🇷🇴',
      'ru': '🇷🇺',
      'es': '🇪🇸',
      'sv': '🇸🇪',
      'te': '🇮🇳',
      'tr': '🇹🇷',
      'uk': '🇺🇦',
      'vi': '🇻🇳',
    };
    return flagMap[languageCode] ?? '🌐';
  }
}

class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector({
    required this.value,
    required this.isDark,
    required this.onChanged,
  });

  final ThemeMode value;
  final bool isDark;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = [
      (
        mode: ThemeMode.system,
        label: AppLocalizations.of(context)!.themeModeSystem,
        icon: CupertinoIcons.device_phone_portrait,
      ),
      (
        mode: ThemeMode.light,
        label: AppLocalizations.of(context)!.themeModeLight,
        icon: CupertinoIcons.sun_max_fill,
      ),
      (
        mode: ThemeMode.dark,
        label: AppLocalizations.of(context)!.themeModeDark,
        icon: CupertinoIcons.moon_fill,
      ),
    ];

    final accent = Theme.of(context).colorScheme.primary;

    return Row(
      children: options.map((opt) {
        final selected = value == opt.mode;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(opt.mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? accent
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    opt.icon,
                    size: 18,
                    color: selected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    opt.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _AccentColorPicker extends StatelessWidget {
  const _AccentColorPicker({
    required this.selected,
    required this.onChanged,
  });

  final AccentColor selected;
  final ValueChanged<AccentColor> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: AccentColor.values.map((color) {
        final isSelected = selected == color;
        return GestureDetector(
          onTap: () => onChanged(color),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.color.withValues(alpha: 0.6),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : null,
          ),
        );
      }).toList(),
    );
  }
}
