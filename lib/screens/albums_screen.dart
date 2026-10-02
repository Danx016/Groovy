import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/album.dart';
import '../providers/library_provider.dart';
import '../services/offline_service.dart';
import '../theme/app_theme.dart';
import '../utils/navigation_helper.dart';
import '../widgets/album_artwork.dart';
import '../widgets/shimmer_loading.dart';
import 'album_screen.dart';

enum AlbumSortOrder { name, artist, year }
enum AlbumFilterType { all, downloaded }

class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  List<Album> _albums = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  AlbumSortOrder _sortOrder = AlbumSortOrder.name;
  AlbumFilterType _filterType = AlbumFilterType.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAlbums());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAlbums() async {
    final libraryProvider = Provider.of<LibraryProvider>(
      context,
      listen: false,
    );

    await libraryProvider.ensureLibraryLoaded();

    final db = libraryProvider.database;
    final localAlbums = await db.getAllAlbums();

    final map = <String, Album>{};
    for (final a in localAlbums) {
      map[a.id] = a;
    }
    for (final a in libraryProvider.cachedAllAlbums) {
      map[a.id] = a;
    }
    for (final a in OfflineService().getDownloadedAlbums()) {
      map[a.id] = a;
    }

    final list = map.values.toList();
    _applySort(list);

    if (mounted) {
      setState(() {
        _albums = list;
        _isLoading = false;
      });
    }
  }

  void _applySort(List<Album> list) {
    switch (_sortOrder) {
      case AlbumSortOrder.name:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case AlbumSortOrder.artist:
        list.sort((a, b) {
          final artA = a.artist?.toLowerCase() ?? '';
          final artB = b.artist?.toLowerCase() ?? '';
          return artA.compareTo(artB);
        });
        break;
      case AlbumSortOrder.year:
        list.sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
        break;
    }
  }

  List<Album> _getFilteredAlbums(Set<String> downloadedIds) {
    List<Album> result = _albums;

    // Search query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((a) {
        return a.name.toLowerCase().contains(q) ||
            (a.artist?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    // Filter type
    if (_filterType == AlbumFilterType.downloaded) {
      result = result.where((a) => downloadedIds.contains(a.id) || a.isLocal).toList();
    }

    _applySort(result);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<Set<String>>(
      valueListenable: OfflineService().downloadedPlaylistIds,
      builder: (context, downloadedIds, _) {
        final displayed = _getFilteredAlbums(downloadedIds);

        return Scaffold(
          backgroundColor: isDark ? AppTheme.darkBackground : Colors.white,
          appBar: AppBar(
            backgroundColor: isDark ? AppTheme.darkBackground : Colors.white,
            elevation: 0,
            scrolledUnderElevation: 1,
            toolbarHeight: 64,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.back,
                  color: isDark ? Colors.white : Colors.black,
                  size: 20,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Row(
              children: [
                Text(
                  'Álbumes',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(width: 8),
                if (!_isLoading)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.appleMusicRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${displayed.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.appleMusicRed,
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              PopupMenuButton<AlbumSortOrder>(
                icon: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.arrow_up_arrow_down,
                    color: isDark ? Colors.white70 : Colors.black87,
                    size: 18,
                  ),
                ),
                tooltip: 'Ordenar por',
                color: isDark ? const Color(0xFF24242A) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                onSelected: (order) {
                  setState(() {
                    _sortOrder = order;
                  });
                },
                itemBuilder: (context) => [
                  _buildSortMenuItem(
                    AlbumSortOrder.name,
                    'Nombre (A-Z)',
                    CupertinoIcons.textformat_abc,
                    isDark,
                  ),
                  _buildSortMenuItem(
                    AlbumSortOrder.artist,
                    'Artista',
                    CupertinoIcons.person_crop_circle,
                    isDark,
                  ),
                  _buildSortMenuItem(
                    AlbumSortOrder.year,
                    'Año (más reciente)',
                    CupertinoIcons.calendar,
                    isDark,
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              // Search & Filter Row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(
                  children: [
                    // Modern Search Box
                    Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.04),
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            CupertinoIcons.search,
                            color: isDark ? Colors.white54 : Colors.black45,
                            size: 18,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                  child: Icon(
                                    CupertinoIcons.clear_circled_solid,
                                    color: isDark ? Colors.white54 : Colors.black45,
                                    size: 18,
                                  ),
                                )
                              : null,
                          hintText: 'Buscar álbumes o artistas...',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Quick Filter Chips
                    Row(
                      children: [
                        _buildFilterChip(
                          label: 'Todos',
                          isSelected: _filterType == AlbumFilterType.all,
                          icon: CupertinoIcons.music_albums,
                          onTap: () {
                            setState(() {
                              _filterType = AlbumFilterType.all;
                            });
                          },
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Descargados',
                          isSelected: _filterType == AlbumFilterType.downloaded,
                          icon: CupertinoIcons.arrow_down_circle_fill,
                          onTap: () {
                            setState(() {
                              _filterType = AlbumFilterType.downloaded;
                            });
                          },
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Albums Content (Loading / Empty / Grid)
              Expanded(
                child: _isLoading
                    ? _buildLoadingGrid()
                    : displayed.isEmpty
                        ? _buildEmptyState(isDark)
                        : _buildAlbumsGrid(displayed, downloadedIds, isDark),
              ),
            ],
          ),
        );
      },
    );
  }

  PopupMenuItem<AlbumSortOrder> _buildSortMenuItem(
    AlbumSortOrder order,
    String label,
    IconData icon,
    bool isDark,
  ) {
    final isSelected = _sortOrder == order;
    return PopupMenuItem<AlbumSortOrder>(
      value: order,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? AppTheme.appleMusicRed : (isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected ? AppTheme.appleMusicRed : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ),
          if (isSelected)
            const Icon(
              CupertinoIcons.checkmark_alt,
              size: 16,
              color: AppTheme.appleMusicRed,
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.appleMusicRed
              : (isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.appleMusicRed
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = (width / 175).floor().clamp(2, 8);
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 18.0,
            crossAxisSpacing: 14.0,
            childAspectRatio: 0.73,
          ),
          itemCount: 8,
          itemBuilder: (_, __) => const AlbumCardShimmer(),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
              ),
              child: const Icon(
                CupertinoIcons.music_albums,
                size: 38,
                color: AppTheme.appleMusicRed,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No se encontraron resultados'
                  : 'No hay álbumes disponibles',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Intenta con otro término de búsqueda o limpia el filtro.'
                  : 'Los álbumes sincronizados con tu biblioteca aparecerán aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
            if (_searchQuery.isNotEmpty || _filterType != AlbumFilterType.all) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _filterType = AlbumFilterType.all;
                  });
                },
                icon: const Icon(CupertinoIcons.refresh, size: 16),
                label: const Text('Restablecer filtros'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.appleMusicRed,
                  side: const BorderSide(color: AppTheme.appleMusicRed),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumsGrid(
    List<Album> displayed,
    Set<String> downloadedIds,
    bool isDark,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = (width / 175).floor().clamp(2, 8);

        return GridView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8).copyWith(bottom: 140),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 18.0,
            crossAxisSpacing: 14.0,
            childAspectRatio: 0.72,
          ),
          itemCount: displayed.length,
          itemBuilder: (context, index) {
            final album = displayed[index];
            final isDownloaded = downloadedIds.contains(album.id) || album.isLocal;

            return _AlbumGridItem(
              album: album,
              isDownloaded: isDownloaded,
              isDark: isDark,
              onTap: () {
                NavigationHelper.push(
                  context,
                  AlbumScreen(albumId: album.id, album: album),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _AlbumGridItem extends StatefulWidget {
  final Album album;
  final bool isDownloaded;
  final bool isDark;
  final VoidCallback onTap;

  const _AlbumGridItem({
    required this.album,
    required this.isDownloaded,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_AlbumGridItem> createState() => _AlbumGridItemState();
}

class _AlbumGridItemState extends State<_AlbumGridItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final album = widget.album;
    final isDark = widget.isDark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Artwork Card with Elevation & Shadow
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : Colors.black.withValues(alpha: 0.05),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? (_isHovered ? 0.50 : 0.35) : (_isHovered ? 0.16 : 0.08)),
                        blurRadius: _isHovered ? 16 : 8,
                        offset: Offset(0, _isHovered ? 8 : 4),
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AlbumArtwork(
                          coverArt: album.coverArt,
                          size: double.infinity,
                          borderRadius: 13,
                        ),

                        // Offline / Downloaded Badge
                        if (widget.isDownloaded)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: (isDark ? const Color(0xFF1E1E24) : Colors.white)
                                    .withValues(alpha: 0.90),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                CupertinoIcons.checkmark_seal_fill,
                                color: Colors.greenAccent,
                                size: 14,
                              ),
                            ),
                          ),

                        // Year or Tracks Pill
                        if (album.year != null || (album.songCount != null && album.songCount! > 0))
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                album.year != null
                                    ? '${album.year}'
                                    : '${album.songCount} pistas',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Album Title
              Text(
                album.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),

              // Artist Name
              Text(
                album.artist ?? 'Varios Artistas',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
