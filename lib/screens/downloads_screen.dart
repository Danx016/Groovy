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
    dSongs.sort((a, b) =>
        a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    // ── INDEX KNOWN ALBUMS ────────────────────────────────────────────────
    final Map<String, Album> knownAlbumsById = {};
    final Map<String, Album> knownAlbumsByName = {};

    void registerKnownAlbum(Album a) {
      if (a.id.isNotEmpty) knownAlbumsById[a.id] = a;
      final cleanName = a.name.trim().toLowerCase();
      if (cleanName.isNotEmpty) knownAlbumsByName[cleanName] = a;
    }

    // 1. Explicitly saved albums from OfflineService
    for (final album in offlineService.getDownloadedAlbums()) {
      registerKnownAlbum(album);
    }

    // 2. Library cached albums
    for (final album in allAlbums) {
      registerKnownAlbum(album);
    }

    // 3. Group downloaded songs by album
    final Map<String, List<Song>> albumGroups = {};
    for (final song in dSongs) {
      final albName = song.album?.trim();
      final albId = song.albumId?.trim();
      if ((albName == null || albName.isEmpty) && (albId == null || albId.isEmpty)) {
        continue;
      }

      final groupKey = (albId != null && albId.isNotEmpty)
          ? albId
          : 'name_${albName!.toLowerCase()}_${(song.artist ?? '').trim().toLowerCase()}';
      albumGroups.putIfAbsent(groupKey, () => []).add(song);
    }

    final List<Album> dAlbums = [];
    final Set<String> processedAlbumKeys = {};

    for (final entry in albumGroups.entries) {
      final key = entry.key;
      final songsForAlbum = entry.value;
      final firstSong = songsForAlbum.first;
      final albumName = (firstSong.album != null && firstSong.album!.trim().isNotEmpty)
          ? firstSong.album!.trim()
          : firstSong.title;

      // Match against known albums
      Album? matched;
      if (firstSong.albumId != null && knownAlbumsById.containsKey(firstSong.albumId)) {
        matched = knownAlbumsById[firstSong.albumId];
      } else if (knownAlbumsById.containsKey(key)) {
        matched = knownAlbumsById[key];
      } else if (knownAlbumsByName.containsKey(albumName.toLowerCase())) {
        matched = knownAlbumsByName[albumName.toLowerCase()];
      }

      final effectiveId = matched?.id ?? firstSong.albumId ?? 'offline_album_${albumName.hashCode.abs()}';
      if (processedAlbumKeys.contains(effectiveId)) continue;
      processedAlbumKeys.add(effectiveId);

      // Best cover art
      String? bestCover = matched?.coverArt;
      if (bestCover == null || bestCover.isEmpty) {
        for (final s in songsForAlbum) {
          if (s.coverArt != null && s.coverArt!.isNotEmpty) {
            bestCover = s.coverArt;
            break;
          }
        }
      }

      // Best artist
      final effectiveArtist = (matched?.artist != null && matched!.artist!.isNotEmpty)
          ? matched.artist
          : firstSong.artist;

      // Best year
      final effectiveYear = matched?.year ?? firstSong.year;

      dAlbums.add(Album(
        id: effectiveId,
        name: (matched != null && matched.name.isNotEmpty) ? matched.name : albumName,
        artist: effectiveArtist,
        artistId: matched?.artistId ?? firstSong.artistId,
        coverArt: bestCover,
        songCount: songsForAlbum.length,
        duration: matched?.duration ?? songsForAlbum.fold<int>(0, (sum, s) => sum + (s.duration ?? 0)),
        year: effectiveYear,
        genre: matched?.genre ?? firstSong.genre,
        created: matched?.created,
        isLocal: matched?.isLocal ?? false,
      ));
    }

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
          // 1. Top App Bar with consistent circular back button
          SliverAppBar(
            pinned: true,
            floating: false,
            toolbarHeight: 64,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor:
                isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: isDark ? Colors.white : Colors.black,
                  size: 20,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Descargas',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.4,
                color: isDark ? Colors.white : Colors.black,
              ),
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
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
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
