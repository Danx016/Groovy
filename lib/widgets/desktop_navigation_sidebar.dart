import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../models/playlist.dart';
import '../screens/playlist_screen.dart';
import '../screens/playlists_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/history_screen.dart';
import '../screens/artists_screen.dart';
import '../screens/albums_screen.dart';
import '../screens/all_songs_screen.dart';
import '../screens/account_screen.dart';

class DesktopNavigationSidebar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final GlobalKey<NavigatorState>? navigatorKey;

  const DesktopNavigationSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.navigatorKey,
  });

  @override
  State<DesktopNavigationSidebar> createState() =>
      _DesktopNavigationSidebarState();
}

class _DesktopNavigationSidebarState extends State<DesktopNavigationSidebar> {
  bool _isCollapsed = false;
  bool _isPushing = false;

  // Section collapse states (expanded by default)
  bool _isLibraryExpanded = true;
  bool _isPlaylistsExpanded = true;

  void _toggleCollapse() => setState(() => _isCollapsed = !_isCollapsed);

  void _navigateToPlaylist(Playlist playlist) {
    _push(MaterialPageRoute(
      builder: (_) => PlaylistScreen(
        playlistId: playlist.id,
        playlistName: playlist.name,
      ),
    ));
  }

  void _navigateToPlaylists() {
    _push(MaterialPageRoute(builder: (_) => const PlaylistsScreen()));
  }

  void _navigateToFavorites() {
    _push(MaterialPageRoute(builder: (_) => const FavoritesScreen()));
  }

  void _navigateToHistory() {
    _push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
  }

  void _navigateToArtists() {
    _push(MaterialPageRoute(builder: (_) => const ArtistsScreen()));
  }

  void _navigateToAlbums() {
    _push(MaterialPageRoute(builder: (_) => const AlbumsScreen()));
  }

  void _navigateToSongs() {
    _push(MaterialPageRoute(builder: (_) => const AllSongsScreen()));
  }

  void _navigateToAccount() {
    _push(MaterialPageRoute(builder: (_) => const AccountScreen()));
  }

  void _push(Route<dynamic> route) {
    if (_isPushing) return;
    _isPushing = true;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _isPushing = false;
    });
    if (widget.navigatorKey?.currentState != null) {
      widget.navigatorKey!.currentState!.push(route);
    } else {
      Navigator.of(context).push(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final width = _isCollapsed ? 72.0 : 280.0;
    final sidebarBg = isDark ? const Color(0xFF0C0D10) : const Color(0xFFF2F2F7);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: width,
      color: sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LogoRow(isCollapsed: _isCollapsed),
          const SizedBox(height: 4),
          _NavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: l10n.home,
            isSelected: widget.selectedIndex == 0,
            isCollapsed: _isCollapsed,
            onTap: () => widget.onDestinationSelected(0),
          ),
          _NavItem(
            icon: Icons.search_rounded,
            activeIcon: Icons.search_rounded,
            label: l10n.search,
            isSelected: widget.selectedIndex == 2,
            isCollapsed: _isCollapsed,
            onTap: () => widget.onDestinationSelected(2),
          ),
          const SizedBox(height: 10),

          // Expandable Scrollable Navigation Area
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: _isCollapsed ? 4 : 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── BIBLIOTECA SECTION ──────────────────────────────────
                  _SectionHeader(
                    icon: Icons.library_music_outlined,
                    title: 'Biblioteca',
                    isCollapsed: _isCollapsed,
                    isExpanded: _isLibraryExpanded,
                    onToggle: () => setState(
                        () => _isLibraryExpanded = !_isLibraryExpanded),
                    onHeaderTap: () => widget.onDestinationSelected(1),
                  ),
                  if (!_isCollapsed && _isLibraryExpanded) ...[
                    _SidebarSubItem(
                      icon: Icons.access_time_rounded,
                      label: 'Agregado recientemente',
                      onTap: _navigateToHistory,
                    ),
                    _SidebarSubItem(
                      icon: Icons.mic_none_rounded,
                      label: 'Artistas',
                      onTap: _navigateToArtists,
                    ),
                    _SidebarSubItem(
                      icon: Icons.album_outlined,
                      label: 'Álbumes',
                      onTap: _navigateToAlbums,
                    ),
                    _SidebarSubItem(
                      icon: Icons.music_note_rounded,
                      label: 'Canciones',
                      onTap: _navigateToSongs,
                    ),
                  ],

                  const SizedBox(height: 14),

                  // ── PLAYLISTS SECTION ───────────────────────────────────
                  _SectionHeader(
                    icon: Icons.queue_music_rounded,
                    title: 'Playlists',
                    isCollapsed: _isCollapsed,
                    isExpanded: _isPlaylistsExpanded,
                    trailingAction: Icons.add_rounded,
                    onTrailingAction: () => _showCreatePlaylist(context),
                    onToggle: () => setState(
                        () => _isPlaylistsExpanded = !_isPlaylistsExpanded),
                    onHeaderTap: _navigateToPlaylists,
                  ),
                  if (!_isCollapsed && _isPlaylistsExpanded) ...[
                    _SidebarSubItem(
                      icon: Icons.grid_view_rounded,
                      label: 'Todas las playlists',
                      onTap: _navigateToPlaylists,
                    ),
                    _SidebarSubItem(
                      icon: Icons.star_rounded,
                      label: 'Canciones favoritas',
                      onTap: _navigateToFavorites,
                    ),
                    // User created playlists
                    Consumer<LibraryProvider>(
                      builder: (context, libraryProvider, _) {
                        final playlists = libraryProvider.playlists;
                        if (playlists.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: playlists.map((pl) {
                            return _SidebarSubItem(
                              icon: Icons.playlist_play_rounded,
                              label: pl.name,
                              onTap: () => _navigateToPlaylist(pl),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── BOTTOM CONTROLS & PROFILE ─────────────────────────────────────
          const SizedBox(height: 4),
          _CollapseButton(
            isCollapsed: _isCollapsed,
            onTap: _toggleCollapse,
            label: l10n.collapse,
            expandLabel: l10n.expand,
          ),

          const Divider(height: 1, thickness: 0.5, color: Colors.white12),

          _UserProfileBottomRow(
            isCollapsed: _isCollapsed,
            onTap: _navigateToAccount,
          ),
        ],
      ),
    );
  }

  Future<void> _showCreatePlaylist(BuildContext context) async {
    final libraryProvider = Provider.of<LibraryProvider>(
      context,
      listen: false,
    );
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController();
    bool isCreating = false;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF282828) : Colors.white,
          title: Text(l10n.newPlaylist),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.playlistName,
              filled: true,
              fillColor:
                  isDark ? const Color(0xFF383838) : const Color(0xFFF2F2F7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            onSubmitted: (_) async {
              if (isCreating) return;
              setState(() => isCreating = true);
              await _doCreate(ctx, controller, libraryProvider, l10n);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: isCreating
                  ? null
                  : () async {
                      setState(() => isCreating = true);
                      await _doCreate(ctx, controller, libraryProvider, l10n);
                    },
              child: Text(l10n.create),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _doCreate(
    BuildContext ctx,
    TextEditingController ctrl,
    LibraryProvider provider,
    AppLocalizations l10n,
  ) async {
    final name = ctrl.text.trim();
    if (name.isEmpty) return;
    try {
      await provider.createPlaylist(name);
      if (ctx.mounted) {
        Navigator.pop(ctx);
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(l10n.playlistCreated(name)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }
}

// ── HEADER ROW WITH LOGO & TITLE ─────────────────────────────────────────────

class _LogoRow extends StatelessWidget {
  final bool isCollapsed;
  const _LogoRow({required this.isCollapsed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isCollapsed ? 0 : 20,
        20,
        isCollapsed ? 0 : 16,
        12,
      ),
      child: isCollapsed
          ? Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset('assets/app_icon.png', width: 32, height: 32),
              ),
            )
          : Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset('assets/app_icon.png', width: 32, height: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Groovy',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );
  }
}

// ── MAIN NAV ITEM ────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final bool isCollapsed;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.isCollapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isSelected
        ? (isDark ? Colors.white : Colors.black)
        : (isDark ? const Color(0xFFB3B3B3) : const Color(0xFF6B6B6B));
    final hoverBg = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.06);

    return Tooltip(
      message: isCollapsed ? label : '',
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: hoverBg,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          height: 42,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 0 : 12),
          alignment: isCollapsed ? Alignment.center : Alignment.centerLeft,
          child: isCollapsed
              ? Icon(isSelected ? activeIcon : icon, color: textColor, size: 24)
              : Row(
                  children: [
                    Icon(
                      isSelected ? activeIcon : icon,
                      color: textColor,
                      size: 24,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── SECTION HEADER (BIBLIOTECA / PLAYLISTS) ───────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isCollapsed;
  final bool isExpanded;
  final IconData? trailingAction;
  final VoidCallback? onTrailingAction;
  final VoidCallback onToggle;
  final VoidCallback? onHeaderTap;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.isCollapsed,
    required this.isExpanded,
    this.trailingAction,
    this.onTrailingAction,
    required this.onToggle,
    this.onHeaderTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerColor = isDark ? Colors.white : Colors.black87;
    final iconColor = isDark ? const Color(0xFFB3B3B3) : const Color(0xFF6B6B6B);
    final hoverBg = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.06);

    if (isCollapsed) {
      return Tooltip(
        message: title,
        waitDuration: const Duration(milliseconds: 400),
        child: InkWell(
          onTap: onHeaderTap ?? onToggle,
          borderRadius: BorderRadius.circular(8),
          hoverColor: hoverBg,
          child: Container(
            height: 42,
            margin: const EdgeInsets.symmetric(vertical: 2),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 24),
          ),
        ),
      );
    }

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      hoverColor: hoverBg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 6),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: headerColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (trailingAction != null)
              InkWell(
                onTap: onTrailingAction,
                borderRadius: BorderRadius.circular(50),
                hoverColor: hoverBg,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(trailingAction, size: 20, color: iconColor),
                ),
              ),
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(50),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: iconColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── SIDEBAR SUB ITEM ─────────────────────────────────────────────────────────

class _SidebarSubItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SidebarSubItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFD4D4D8) : const Color(0xFF4B5563);
    final hoverBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      hoverColor: hoverBg,
      child: Container(
        height: 38,
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.only(left: 36, right: 12),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(icon, size: 19, color: textColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── BOTTOM USER PROFILE ROW ──────────────────────────────────────────────────

class _UserProfileBottomRow extends StatelessWidget {
  final bool isCollapsed;
  final VoidCallback onTap;

  const _UserProfileBottomRow({
    required this.isCollapsed,
    required this.onTap,
  });

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'U';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    final displayName = (user?.name != null && user!.name.isNotEmpty)
        ? user.name
        : (user?.email != null && user!.email.isNotEmpty)
            ? user.email.split('@').first
            : 'Leidy Francisco';

    final initials = _getInitials(displayName);
    final hoverBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    if (isCollapsed) {
      return Tooltip(
        message: displayName,
        child: InkWell(
          onTap: onTap,
          hoverColor: hoverBg,
          child: Container(
            height: 56,
            alignment: Alignment.center,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF2A2B30),
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      hoverColor: hoverBg,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF2A2B30),
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                displayName,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── COLLAPSE BUTTON ──────────────────────────────────────────────────────────

class _CollapseButton extends StatelessWidget {
  final bool isCollapsed;
  final VoidCallback onTap;
  final String label;
  final String expandLabel;

  const _CollapseButton({
    required this.isCollapsed,
    required this.onTap,
    required this.label,
    required this.expandLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFFB3B3B3) : const Color(0xFF6B6B6B);
    final hoverBg = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.06);

    return Tooltip(
      message: isCollapsed ? expandLabel : '',
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: hoverBg,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 0 : 12),
          alignment: isCollapsed ? Alignment.center : Alignment.centerLeft,
          child: isCollapsed
              ? Icon(Icons.keyboard_double_arrow_right_rounded,
                  color: color, size: 22)
              : Row(
                  children: [
                    Icon(
                      Icons.keyboard_double_arrow_left_rounded,
                      color: color,
                      size: 22,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
