import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/song.dart';
import '../services/recommendation_service.dart';
import '../services/storage_service.dart';
import '../services/groovy_api_service.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Song> _recentSongs = [];
  bool _isLoading = true;
  LibraryProvider? _libraryProvider;
  RecommendationService? _recommendationService;
  PlayerProvider? _playerProvider;
  String? _lastTrackedSongId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _libraryProvider = Provider.of<LibraryProvider>(
        context,
        listen: false,
      );
      _recommendationService = Provider.of<RecommendationService>(
        context,
        listen: false,
      );
      _playerProvider = Provider.of<PlayerProvider>(
        context,
        listen: false,
      );

      if (!mounted) return;

      _libraryProvider?.addListener(_onProvidersChanged);
      _recommendationService?.addListener(_onProvidersChanged);
      _playerProvider?.addListener(_onPlayerChanged);

      _loadHistory();
    });
  }

  @override
  void dispose() {
    _libraryProvider?.removeListener(_onProvidersChanged);
    _recommendationService?.removeListener(_onProvidersChanged);
    _playerProvider?.removeListener(_onPlayerChanged);
    super.dispose();
  }

  void _onProvidersChanged() {
    if (mounted) _loadHistory();
  }

  void _onPlayerChanged() {
    final currentId = _playerProvider?.currentSong?.id;
    if (currentId != null && currentId != _lastTrackedSongId) {
      _lastTrackedSongId = currentId;
      if (mounted) _loadHistory();
    }
  }

  Future<void> _loadHistory({bool forceRefresh = false}) async {
    try {
      // 0. Instant in-memory history from PlayerProvider for 0ms reactivity
      final inMemoryHistory = _playerProvider?.playbackHistory ?? [];
      if (inMemoryHistory.isNotEmpty && mounted) {
        setState(() {
          _recentSongs = inMemoryHistory;
          _isLoading = false;
        });
      }

      // 1. Fetch local persistent playback history from StorageService
      final localHistory = await StorageService().getPlaybackHistory();

      // If we got local items and this is initial load, update UI immediately for 0ms feel
      if (localHistory.isNotEmpty && _isLoading && mounted) {
        setState(() {
          _recentSongs = localHistory;
          _isLoading = false;
        });
      }

      // 2. Fetch cloud history if user is logged into Groovy
      List<Song> cloudHistory = [];
      try {
        final token = await StorageService().getUserToken();
        if (token != null && token.isNotEmpty) {
          cloudHistory = await GroovyApiService().getHistory(token, limit: 100);
        }
      } catch (e) {
        debugPrint('[HistoryScreen] cloud history fetch error: $e');
      }

      // 3. Recommendation profiles fallback (in case local storage is empty)
      List<Song> recommendationHistory = [];
      if (localHistory.isEmpty && inMemoryHistory.isEmpty && cloudHistory.isEmpty && _recommendationService != null) {
        final profiles = _recommendationService!.profiles;
        final songMap = _libraryProvider?.songsByIdMap ?? {};

        final profileEntries = profiles.entries
            .where((e) => e.value.playCount > 0)
            .toList();
        profileEntries.sort((a, b) => b.value.lastPlayed.compareTo(a.value.lastPlayed));

        for (final entry in profileEntries) {
          if (songMap.containsKey(entry.key)) {
            recommendationHistory.add(songMap[entry.key]!);
          } else {
            recommendationHistory.add(Song(
              id: entry.key,
              title: entry.value.title,
              artist: entry.value.artist,
              artistId: entry.value.artistId,
              albumId: entry.value.albumId,
              genre: entry.value.genre,
              duration: entry.value.duration,
            ));
          }
        }
      }

      // 4. Merge and deduplicate preserving chronological order
      final Set<String> seenIds = {};
      final List<Song> merged = [];

      void addIfNotPresent(Song s) {
        if (s.id.isNotEmpty && !seenIds.contains(s.id)) {
          seenIds.add(s.id);
          merged.add(s);
        } else if (s.id.isEmpty) {
          final key = '${s.title.toLowerCase()}_${s.artist?.toLowerCase()}';
          if (!seenIds.contains(key)) {
            seenIds.add(key);
            merged.add(s);
          }
        }
      }

      for (final s in inMemoryHistory) {
        addIfNotPresent(s);
      }
      for (final s in localHistory) {
        addIfNotPresent(s);
      }
      for (final s in cloudHistory) {
        addIfNotPresent(s);
      }
      for (final s in recommendationHistory) {
        addIfNotPresent(s);
      }

      if (mounted) {
        setState(() {
          _recentSongs = merged.take(150).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[HistoryScreen] error loading history: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _playAll({bool shuffle = false}) {
    if (_recentSongs.isEmpty) return;
    final player = Provider.of<PlayerProvider>(context, listen: false);
    final list = List<Song>.from(_recentSongs);
    if (shuffle) {
      list.shuffle();
    }
    player.playSong(list.first, playlist: list, startIndex: 0);
  }

  Future<void> _confirmClearHistory() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await GroovyConfirmDialog.show(
      context,
      title: l10n?.clearListeningHistory ?? 'Borrar historial de reproducción',
      message: l10n?.confirmClearHistory ?? '¿Estás seguro de que deseas borrar el historial?',
      confirmLabel: l10n?.delete ?? 'Eliminar',
      cancelLabel: l10n?.cancel ?? 'Cancelar',
      isDestructive: true,
      icon: Icons.history_toggle_off_rounded,
    );

    if (confirmed == true) {
      _playerProvider?.clearHistory();
      await StorageService().clearPlaybackHistory();
      if (!mounted) return;
      final recService = Provider.of<RecommendationService>(context, listen: false);
      await recService.clearData();
      if (!mounted) return;
      setState(() {
        _recentSongs = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.historyCleared ?? 'Historial de reproducción borrado'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    int totalDurationSeconds = 0;
    for (final song in _recentSongs) {
      if (song.duration != null && song.duration! > 0) {
        totalDurationSeconds += song.duration!;
      }
    }
    final hours = totalDurationSeconds ~/ 3600;
    final minutes = (totalDurationSeconds % 3600) ~/ 60;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : Colors.white,
      appBar: AppBar(
        title: Text(
          l10n?.listeningHistory ?? 'Historial de reproducción',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.4,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        backgroundColor: isDark ? AppTheme.darkBackground : Colors.white,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.back,
                    color: isDark ? Colors.white : Colors.black87,
                    size: 20,
                  ),
                ),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          if (_recentSongs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.trash,
                    size: 18,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                tooltip: l10n?.clearListeningHistory ?? 'Borrar historial',
                onPressed: _confirmClearHistory,
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CupertinoActivityIndicator(radius: 14),
            )
          : RefreshIndicator(
              color: AppTheme.appleMusicRed,
              onRefresh: () => _loadHistory(forceRefresh: true),
              child: _recentSongs.isEmpty
                  ? _buildEmptyState(context, isDark, l10n)
                  : CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Symmetrical Dual Pill Buttons: Play & Shuffle (Apple Music Style)
                                Row(
                                  children: [
                                    Expanded(
                                      child: _PlayButton(
                                        icon: CupertinoIcons.play_fill,
                                        label: l10n?.play ?? 'Reproducir',
                                        onTap: () => _playAll(shuffle: false),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _PlayButton(
                                        icon: CupertinoIcons.shuffle,
                                        label: l10n?.shuffle ?? 'Aleatorio',
                                        onTap: () => _playAll(shuffle: true),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Metadata capsules
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.06)
                                            : Colors.black.withValues(alpha: 0.04),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${_recentSongs.length} ${_recentSongs.length == 1 ? "canción" : "canciones"}',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white70 : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    if (totalDurationSeconds > 0) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        '•',
                                        style: TextStyle(
                                          color: isDark ? Colors.white38 : Colors.black38,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        hours > 0 ? '$hours h $minutes min' : '$minutes min',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? Colors.white54 : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Tracklist (fixed extent for silky-smooth 120fps scrolling)
                        SliverFixedExtentList(
                          itemExtent: 64.0,
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return SongTile(
                                song: _recentSongs[index],
                                playlist: _recentSongs,
                                index: index,
                                showAlbum: true,
                                showArtwork: true,
                              );
                            },
                            childCount: _recentSongs.length,
                          ),
                        ),

                        // Bottom Spacer to prevent mini player overlap
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 140),
                        ),
                      ],
                    ),
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark, AppLocalizations? l10n) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 60),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                ),
                child: const Icon(
                  CupertinoIcons.clock_fill,
                  size: 40,
                  color: AppTheme.appleMusicRed,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n?.noListeningHistory ?? 'Sin historial de reproducción',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n?.songsWillAppearHere ??
                    'Las canciones que reproduzcas aparecerán aquí para que puedas volver a escucharlas.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: isDark
                      ? AppTheme.darkSecondaryText
                      : AppTheme.lightSecondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PlayButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final btnBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);

    return Material(
      color: btnBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppTheme.appleMusicRed, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.appleMusicRed,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
