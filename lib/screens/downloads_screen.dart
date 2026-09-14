import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../services/offline_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'album_screen.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<Song> _downloadedSongs = [];
  List<Album> _downloadedAlbums = [];
  bool _isLoading = true;
  int _selectedTab = 0; // 0: Canciones, 1: Álbumes
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    OfflineService().downloadedSongIds.addListener(_loadDownloads);
    _loadDownloads();
  }

  @override
  void dispose() {
    OfflineService().downloadedSongIds.removeListener(_loadDownloads);
    _searchController.dispose();
    super.dispose();
  }

  void _loadDownloads() {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final libraryProvider =
        Provider.of<LibraryProvider>(context, listen: false);
    final offlineService = OfflineService();
    final downloadedFromService = offlineService.getDownloadedSongs();
    final downloadedIds = offlineService.getDownloadedSongIds().toSet();

    final allSongs = libraryProvider.cachedAllSongs;
    final allAlbums = libraryProvider.cachedAllAlbums;

    final Map<String, Song> songMap = {};
    for (final song in downloadedFromService) {
      songMap[song.id] = song;
    }
    for (final song in allSongs) {
      if (downloadedIds.contains(song.id)) {
        songMap[song.id] = song;
      }
    }

    final List<Song> dSongs = songMap.values.toList();
    final Set<String> albumIds = {};
    for (final song in dSongs) {
      if (song.albumId != null) {
        albumIds.add(song.albumId!);
      }
    }

    dSongs.sort((a, b) =>
        a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    final List<Album> dAlbums =
        allAlbums.where((a) => albumIds.contains(a.id)).toList();
    dAlbums.sort((a, b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (mounted) {
      setState(() {
        _downloadedSongs = dSongs;
        _downloadedAlbums = dAlbums;
        _isLoading = false;
      });
    }
  }

  void _playAll({bool shuffle = false}) {
    if (_downloadedSongs.isEmpty) return;
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final songsToPlay = List<Song>.from(_downloadedSongs);
    if (shuffle) {
      songsToPlay.shuffle();
    }
    playerProvider.playSong(songsToPlay.first, playlist: songsToPlay);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredSongs = _downloadedSongs.where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return s.title.toLowerCase().contains(q) ||
          (s.artist?.toLowerCase().contains(q) ?? false);
    }).toList();

    final filteredAlbums = _downloadedAlbums.where((a) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return a.name.toLowerCase().contains(q) ||
          (a.artist?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
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
            actions: [
              if (_downloadedSongs.isNotEmpty && _selectedTab == 0)
                IconButton(
                  icon: const Icon(
                    CupertinoIcons.shuffle,
                    color: AppTheme.appleMusicRed,
                    size: 22,
                  ),
                  tooltip: 'Reproducción aleatoria',
                  onPressed: () => _playAll(shuffle: true),
                ),
              const SizedBox(width: 6),
            ],
          ),

          // 2. Large Apple Music Header ("Descargas")
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 14.0),
              child: Text(
                'Descargas',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),

          // 3. Apple Music Filter Tabs (Pills: Canciones / Álbumes)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  _AppleMusicPillTab(
                    title: 'Canciones',
                    count: _downloadedSongs.length,
                    isSelected: _selectedTab == 0,
                    isDark: isDark,
                    onTap: () => setState(() => _selectedTab = 0),
                  ),
                  const SizedBox(width: 10),
                  _AppleMusicPillTab(
                    title: 'Álbumes',
                    count: _downloadedAlbums.length,
                    isSelected: _selectedTab == 1,
                    isDark: isDark,
                    onTap: () => setState(() => _selectedTab = 1),
                  ),
                ],
              ),
            ),
          ),

          // 4. Search Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 8.0),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: _selectedTab == 0
                    ? 'Buscar en canciones descargadas'
                    : 'Buscar en álbumes descargados',
                style:
                    TextStyle(color: isDark ? Colors.white : Colors.black87),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
            ),
          ),

          // 5. Quick Action Play / Shuffle buttons (when tab is Canciones and has songs)
          if (_selectedTab == 0 && _downloadedSongs.isNotEmpty && _searchQuery.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 14.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _playAll(shuffle: false),
                        icon: const Icon(CupertinoIcons.play_fill, size: 18),
                        label: const Text(
                          'Reproducir',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? const Color(0xFF242426)
                              : const Color(0xFFF2F2F7),
                          foregroundColor: AppTheme.appleMusicRed,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _playAll(shuffle: true),
                        icon: const Icon(CupertinoIcons.shuffle, size: 18),
                        label: const Text(
                          'Aleatorio',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? const Color(0xFF242426)
                              : const Color(0xFFF2F2F7),
                          foregroundColor: AppTheme.appleMusicRed,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 6. Content Section
          if (_isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.appleMusicRed),
              ),
            )
          else if (_selectedTab == 0)
            _buildSongsSliver(filteredSongs, isDark)
          else
            _buildAlbumsSliver(filteredAlbums, isDark),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _buildSongsSliver(List<Song> songs, bool isDark) {
    if (songs.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.arrow_down_circle,
                  size: 64,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No se encontraron resultados'
                      : 'Sin canciones descargadas',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'Prueba buscando con otro término.'
                      : 'Las canciones que descargues para escuchar sin conexión aparecerán aquí.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final song = songs[index];
          return SongTile(
            song: song,
            playlist: songs,
            index: index,
            showArtwork: true,
            showArtist: true,
            showAlbum: true,
          );
        },
        childCount: songs.length,
      ),
    );
  }

  Widget _buildAlbumsSliver(List<Album> albums, bool isDark) {
    if (albums.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.square_stack_3d_down_right,
                  size: 64,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No se encontraron álbumes'
                      : 'Sin álbumes descargados',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'Prueba buscando con otro término.'
                      : 'Los álbumes completos que descargues aparecerán organizados aquí.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          childAspectRatio: 0.78,
          crossAxisSpacing: 16,
          mainAxisSpacing: 18,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final album = albums[index];
            return AlbumCard(
              album: album,
              size: double.infinity,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AlbumScreen(albumId: album.id, album: album),
                ),
              ),
            );
          },
          childCount: albums.length,
        ),
      ),
    );
  }
}

// ── APPLE MUSIC PILL TAB BUTTON ──────────────────────────────────────────────
class _AppleMusicPillTab extends StatelessWidget {
  final String title;
  final int count;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _AppleMusicPillTab({
    required this.title,
    required this.count,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.appleMusicRed
              : (isDark ? const Color(0xFF1E1E22) : const Color(0xFFE5E5EA)),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.appleMusicRed.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: -0.2,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : (isDark ? Colors.white12 : Colors.black12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white60 : Colors.black54),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
