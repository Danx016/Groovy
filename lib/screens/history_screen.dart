import 'package:flutter/material.dart';
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
      if (localHistory.isEmpty && cloudHistory.isEmpty && _recommendationService != null) {
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.clearListeningHistory ?? 'Borrar historial de reproducción'),
        content: Text(l10n?.confirmClearHistory ?? '¿Estás seguro de que deseas borrar el historial?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n?.cancel ?? 'Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n?.delete ?? 'Eliminar',
              style: const TextStyle(color: Color(0xFFFF3B30)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.listeningHistory ?? 'Historial de reproducción'),
        actions: [
          if (_recentSongs.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.play_arrow_rounded),
              tooltip: 'Reproducir todo',
              onPressed: () => _playAll(shuffle: false),
            ),
            IconButton(
              icon: const Icon(Icons.shuffle_rounded),
              tooltip: 'Aleatorio',
              onPressed: () => _playAll(shuffle: true),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: l10n?.clearListeningHistory ?? 'Borrar historial',
              onPressed: _confirmClearHistory,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadHistory(forceRefresh: true),
              child: _recentSongs.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.7,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.history_rounded,
                                  size: 64,
                                  color: isDark
                                      ? AppTheme.darkSecondaryText
                                      : AppTheme.lightSecondaryText,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  l10n?.noListeningHistory ?? 'Sin historial de reproducción',
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    color: isDark
                                        ? AppTheme.darkSecondaryText
                                        : AppTheme.lightSecondaryText,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  l10n?.songsWillAppearHere ?? 'Las canciones que reproduzcas aparecerán aquí',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: isDark
                                        ? AppTheme.darkSecondaryText
                                        : AppTheme.lightSecondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _recentSongs.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Text(
                              '${_recentSongs.length} ${_recentSongs.length == 1 ? "canción" : "canciones"}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark
                                    ? AppTheme.darkSecondaryText
                                    : AppTheme.lightSecondaryText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }
                        final songIndex = index - 1;
                        return SongTile(
                          song: _recentSongs[songIndex],
                          playlist: _recentSongs,
                          index: songIndex,
                          showAlbum: true,
                        );
                      },
                    ),
            ),
    );
  }
}
