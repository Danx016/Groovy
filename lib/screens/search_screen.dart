import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../services/youtube_service.dart';
import '../services/recent_searches_service.dart';
import '../theme/app_theme.dart';
import '../utils/navigation_helper.dart';
import '../widgets/widgets.dart';
import 'album_screen.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/song.dart';
import 'artist_screen.dart';
import '../widgets/now_playing/now_playing_more_menu.dart';

import '../l10n/app_localizations.dart';
import '../services/player_ui_settings_service.dart';

enum SearchCategoryFilter {
  all,
  songs,
  albums,
  artists,
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  SearchResult? _searchResult;
  SearchResult? _autocompleteSuggestions;
  bool _isSearching = false;
  bool _isLoadingSuggestions = false;
  bool _showSuggestions = false;
  String _query = '';
  Timer? _debounceTimer;
  bool _liveSearch = true;
  SearchCategoryFilter _selectedFilter = SearchCategoryFilter.all;

  @override
  void initState() {
    super.initState();
    _liveSearch = PlayerUiSettingsService().getLiveSearch();
    PlayerUiSettingsService().liveSearchNotifier.addListener(_onLiveSearchChanged);
  }

  void _onLiveSearchChanged() {
    setState(() {
      _liveSearch = PlayerUiSettingsService().liveSearchNotifier.value;
    });
  }

  @override
  void dispose() {
    PlayerUiSettingsService().liveSearchNotifier.removeListener(_onLiveSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAutocomplete(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _autocompleteSuggestions = null;
        _showSuggestions = false;
      });
      return;
    }

    setState(() {
      _isLoadingSuggestions = true;
      _showSuggestions = true;
    });

    try {
      final libraryProvider = Provider.of<LibraryProvider>(
        context,
        listen: false,
      );
      final result = await libraryProvider.search(query, includeOnline: true);
      if (mounted && _searchController.text.trim() == query.trim()) {
        setState(() {
          _autocompleteSuggestions = result;
          _isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSuggestions = false;
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();

    if (value.trim().isEmpty) {
      setState(() {
        _searchResult = null;
        _autocompleteSuggestions = null;
        _showSuggestions = false;
        _query = '';
        _isSearching = false;
      });
      return;
    }

    // 1. Instant local match (0ms latency)
    final libraryProvider = Provider.of<LibraryProvider>(
      context,
      listen: false,
    );
    final instantLocal = libraryProvider.searchLocal(value);

    setState(() {
      _query = value;
      if (instantLocal.songs.isNotEmpty || instantLocal.artists.isNotEmpty || instantLocal.albums.isNotEmpty) {
        _searchResult = instantLocal;
      }
      _isSearching = true; // Immediate feedback that live search is working
    });

    // 2. Ultra-snappy debounced online search (180ms)
    _debounceTimer = Timer(const Duration(milliseconds: 180), () {
      if (!mounted || _searchController.text.trim() != value.trim()) return;
      if (_liveSearch) {
        _search(value);
      } else {
        _loadAutocomplete(value);
      }
    });
  }

  Future<void> _search(String query) async {
    final cleanQ = query.trim();
    if (cleanQ.isEmpty) {
      setState(() {
        _searchResult = null;
        _query = '';
        _showSuggestions = false;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _query = cleanQ;
      _showSuggestions = false;
    });

    try {
      final libraryProvider = Provider.of<LibraryProvider>(
        context,
        listen: false,
      );
      final result = await libraryProvider.search(cleanQ, includeOnline: true);
      if (mounted && _searchController.text.trim() == cleanQ) {
        setState(() {
          _searchResult = result;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final recentSearches = Provider.of<RecentSearchesService>(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                floating: true,
                expandedHeight: 116,
                elevation: 0,
                backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  title: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      'Buscar',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  titlePadding: const EdgeInsets.only(left: 16, right: 16, bottom: 58),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(60),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                        child: CupertinoSearchTextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          placeholder: 'Artistas, canciones, álbumes...',
                          placeholderStyle: TextStyle(
                            color: isDark ? const Color(0xFF9E9E9E) : const Color(0xFF6E6E73),
                            fontSize: 15,
                          ),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 15,
                          ),
                          prefixIcon: Icon(
                            CupertinoIcons.search,
                            color: primaryColor,
                            size: 20,
                          ),
                          backgroundColor: isDark
                              ? const Color(0xFF242424)
                              : const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(12),
                          onChanged: _onSearchChanged,
                          onSubmitted: (value) {
                            setState(() => _showSuggestions = false);
                            _search(value);
                          },
                        ),
                      ),
                      if (_isSearching)
                        LinearProgressIndicator(
                          minHeight: 2,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        )
                      else
                        const SizedBox(height: 2),
                    ],
                  ),
                ),
              ),

              // Filter Pills (Todo, Canciones, Álbumes, Artistas)
              if (_searchResult != null || _isSearching || _query.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildFilterPills(isDark, primaryColor),
                ),

              if (_searchResult != null && !_searchResult!.isEmpty)
                ..._buildSliverSearchResults(isDark, primaryColor)
              else if (_isSearching)
                SliverList.builder(
                  itemCount: 8,
                  itemBuilder: (_, __) => const SongTileShimmer(),
                )
              else if (_query.isNotEmpty && _searchResult?.isEmpty == true)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.search,
                          size: 64,
                          color: AppTheme.lightSecondaryText,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context)!.noResults,
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)!.tryDifferentSearch,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.lightSecondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                if (recentSearches.items.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildRecentSearchesSection(context, recentSearches, isDark, primaryColor),
                  ),
              ],
              const SliverToBoxAdapter(
                child: SizedBox(height: 120),
              ),
            ],
          ),
          
          if (_showSuggestions && _searchController.text.isNotEmpty)
            Positioned(
              top: 116 + 56 + 8,
              left: 16,
              right: 16,
              child: _buildAutocompleteOverlay(isDark, primaryColor),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterPills(bool isDark, Color primaryColor) {
    final filters = [
      {'filter': SearchCategoryFilter.all, 'label': 'Todo'},
      {'filter': SearchCategoryFilter.songs, 'label': 'Canciones'},
      {'filter': SearchCategoryFilter.albums, 'label': 'Álbumes'},
      {'filter': SearchCategoryFilter.artists, 'label': 'Artistas'},
    ];

    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = filters[index];
          final filter = item['filter'] as SearchCategoryFilter;
          final label = item['label'] as String;
          final isSelected = _selectedFilter == filter;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = filter;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryColor
                    : (isDark ? const Color(0xFF242424) : const Color(0xFFE5E5EA)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildSliverSearchResults(bool isDark, Color primaryColor) {
    final result = _searchResult!;
    final libraryProvider = Provider.of<LibraryProvider>(context);
    final player = Provider.of<PlayerProvider>(context, listen: false);

    // Combine all songs (already ranked by relevance) with strict deduplication
    final allSongs = <Song>[];
    final seenIds = <String>{};
    for (final s in result.songs) {
      if (seenIds.add(s.id)) allSongs.add(s);
    }
    if (result.youtubeVideos != null) {
      for (final s in result.youtubeVideos!) {
        if (seenIds.add(s.id)) allSongs.add(s);
      }
    }

    final slivers = <Widget>[];

    // Filter: ARTISTS ONLY
    if (_selectedFilter == SearchCategoryFilter.artists) {
      if (result.artists.isEmpty) {
        slivers.add(SliverToBoxAdapter(child: _buildEmptyCategoryMessage('No se encontraron artistas')));
      } else {
        slivers.add(
          SliverList.builder(
            itemCount: result.artists.length,
            itemBuilder: (ctx, index) {
              final artist = result.artists[index];
              return _buildSpotifyItemTile(
                title: artist.name,
                subtitle: 'Artista',
                imageUrl: artist.coverArt,
                isCircular: true,
                isDark: isDark,
                primaryColor: primaryColor,
                onTap: () {
                  RecentSearchesService().addArtist(artist);
                  NavigationHelper.push(
                    context,
                    ArtistScreen(artistId: artist.id, artist: artist),
                  );
                },
              );
            },
          ),
        );
      }
      return slivers;
    }

    // Filter: ALBUMS ONLY
    if (_selectedFilter == SearchCategoryFilter.albums) {
      if (result.albums.isEmpty) {
        slivers.add(SliverToBoxAdapter(child: _buildEmptyCategoryMessage('No se encontraron álbumes')));
      } else {
        slivers.add(
          SliverList.builder(
            itemCount: result.albums.length,
            itemBuilder: (ctx, index) {
              final album = result.albums[index];
              return _buildSpotifyItemTile(
                title: album.name,
                subtitle: 'Álbum • ${album.artist ?? "Varios Artistas"}${album.year != null ? " • ${album.year}" : ""}',
                imageUrl: album.coverArt,
                isCircular: false,
                isDark: isDark,
                primaryColor: primaryColor,
                onTap: () {
                  RecentSearchesService().addAlbum(album);
                  NavigationHelper.push(
                    context,
                    AlbumScreen(albumId: album.id, album: album),
                  );
                },
              );
            },
          ),
        );
      }
      return slivers;
    }

    // Filter: SONGS ONLY
    if (_selectedFilter == SearchCategoryFilter.songs) {
      if (allSongs.isEmpty) {
        slivers.add(SliverToBoxAdapter(child: _buildEmptyCategoryMessage('No se encontraron canciones')));
      } else {
        slivers.add(
          SliverList.builder(
            itemCount: allSongs.length,
            itemBuilder: (ctx, index) {
              final song = allSongs[index];
              final isStarred = libraryProvider.isSongStarred(song.id) || (song.starred ?? false);
              final isCurrentPlaying = player.currentSong?.id == song.id;

              return _buildSpotifyItemTile(
                title: song.title,
                subtitle: 'Canción • ${song.artist ?? "Desconocido"}',
                imageUrl: song.coverArt,
                isCircular: false,
                isDark: isDark,
                isStarred: isStarred,
                isPlaying: isCurrentPlaying,
                primaryColor: primaryColor,
                onStarredToggle: () {
                  libraryProvider.toggleStarSong(song);
                },
                onOptionsPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    useRootNavigator: true,
                    builder: (ctx) => NowPlayingMoreMenu(song: song),
                  );
                },
                onTap: () {
                  RecentSearchesService().addSong(song);
                  player.playSong(song, playlist: allSongs, startIndex: index);
                },
              );
            },
          ),
        );
      }
      return slivers;
    }

    // Filter: ALL ("Todo") - Unified Smart Stream
    if (_selectedFilter == SearchCategoryFilter.all) {
      final cleanQ = _query.toLowerCase().trim();
      final hasDirectArtistMatch = result.artists.isNotEmpty &&
          (result.artists.first.name.toLowerCase().trim() == cleanQ ||
              cleanQ.startsWith(result.artists.first.name.toLowerCase().trim()));

      // Helper to build artist items
      Widget buildArtistTile(Artist artist) {
        return _buildSpotifyItemTile(
          title: artist.name,
          subtitle: 'Artista',
          imageUrl: artist.coverArt,
          isCircular: true,
          isDark: isDark,
          primaryColor: primaryColor,
          onTap: () {
            RecentSearchesService().addArtist(artist);
            NavigationHelper.push(
              context,
              ArtistScreen(artistId: artist.id, artist: artist),
            );
          },
        );
      }

      // Helper to build album items
      Widget buildAlbumTile(Album album) {
        return _buildSpotifyItemTile(
          title: album.name,
          subtitle: 'Álbum • ${album.artist ?? "Varios Artistas"}',
          imageUrl: album.coverArt,
          isCircular: false,
          isDark: isDark,
          primaryColor: primaryColor,
          onTap: () {
            RecentSearchesService().addAlbum(album);
            NavigationHelper.push(
              context,
              AlbumScreen(albumId: album.id, album: album),
            );
          },
        );
      }

      // Helper to build song tile
      Widget buildSongTile(Song song, int index) {
        final isStarred = libraryProvider.isSongStarred(song.id) || (song.starred ?? false);
        final isCurrentPlaying = player.currentSong?.id == song.id;

        return _buildSpotifyItemTile(
          title: song.title,
          subtitle: 'Canción • ${song.artist ?? "Desconocido"}',
          imageUrl: song.coverArt,
          isCircular: false,
          isDark: isDark,
          isStarred: isStarred,
          isPlaying: isCurrentPlaying,
          primaryColor: primaryColor,
          onStarredToggle: () {
            libraryProvider.toggleStarSong(song);
          },
          onOptionsPressed: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              useRootNavigator: true,
              builder: (ctx) => NowPlayingMoreMenu(song: song),
            );
          },
          onTap: () {
            RecentSearchesService().addSong(song);
            player.playSong(song, playlist: allSongs, startIndex: index);
          },
        );
      }

      if (hasDirectArtistMatch) {
        // Query specifically matched artist (e.g. "Coldplay") -> show Artist at the top
        final topArtist = result.artists.first;
        slivers.add(
          SliverToBoxAdapter(
            child: buildArtistTile(topArtist),
          ),
        );

        // Then songs
        if (allSongs.isNotEmpty) {
          slivers.add(
            SliverList.builder(
              itemCount: allSongs.length,
              itemBuilder: (ctx, index) => buildSongTile(allSongs[index], index),
            ),
          );
        }

        // Then albums
        if (result.albums.isNotEmpty) {
          final topAlbums = result.albums.take(2).toList();
          slivers.add(
            SliverList.builder(
              itemCount: topAlbums.length,
              itemBuilder: (ctx, index) => buildAlbumTile(topAlbums[index]),
            ),
          );
        }
      } else {
        // Normal song / keyword search -> PRIORITIZE SONGS AT THE VERY TOP!
        if (allSongs.isNotEmpty) {
          slivers.add(
            SliverList.builder(
              itemCount: allSongs.length,
              itemBuilder: (ctx, index) => buildSongTile(allSongs[index], index),
            ),
          );
        }

        // Matching artists right after songs
        if (result.artists.isNotEmpty) {
          final topArtists = result.artists.take(2).toList();
          slivers.add(
            SliverList.builder(
              itemCount: topArtists.length,
              itemBuilder: (ctx, index) => buildArtistTile(topArtists[index]),
            ),
          );
        }

        // Matching albums
        if (result.albums.isNotEmpty) {
          final topAlbums = result.albums.take(2).toList();
          slivers.add(
            SliverList.builder(
              itemCount: topAlbums.length,
              itemBuilder: (ctx, index) => buildAlbumTile(topAlbums[index]),
            ),
          );
        }
      }
    }

    return slivers;
  }

  Widget _buildEmptyCategoryMessage(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(
            color: Color(0xFF9E9E9E),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSpotifyItemTile({
    required String title,
    required String subtitle,
    required String? imageUrl,
    required bool isCircular,
    required bool isDark,
    required Color primaryColor,
    bool? isStarred,
    bool isPlaying = false,
    VoidCallback? onStarredToggle,
    VoidCallback? onOptionsPressed,
    required VoidCallback onTap,
  }) {
    final youtubeService = Provider.of<YoutubeService>(context, listen: false);
    final coverUrl = imageUrl != null
        ? (isLocalFilePath(imageUrl)
            ? imageUrl
            : youtubeService.getCoverArtUrl(imageUrl, size: 160))
        : null;

    Widget imageWidget;
    if (isCircular) {
      imageWidget = ClipOval(
        child: SizedBox(
          width: 50,
          height: 50,
          child: coverUrl != null
              ? CachedNetworkImage(
                  imageUrl: coverUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: const Color(0xFF242424)),
                  errorWidget: (_, __, ___) => _defaultArtistAvatar(isDark),
                )
              : _defaultArtistAvatar(isDark),
        ),
      );
    } else {
      imageWidget = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 50,
          height: 50,
          child: coverUrl != null
              ? CachedNetworkImage(
                  imageUrl: coverUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: const Color(0xFF242424)),
                  errorWidget: (_, __, ___) => _defaultCover(isDark),
                )
              : _defaultCover(isDark),
        ),
      );
    }

    return RepaintBoundary(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              imageWidget,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: isPlaying
                            ? primaryColor
                            : (isDark ? Colors.white : const Color(0xFF121212)),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: isDark ? const Color(0xFFA7A7A7) : const Color(0xFF6E6E73),
                      ),
                    ),
                  ],
                ),
              ),
              if (onOptionsPressed != null) ...[
                IconButton(
                  icon: Icon(
                    CupertinoIcons.ellipsis_vertical,
                    size: 18,
                    color: isDark ? const Color(0xFFA7A7A7) : const Color(0xFF6E6E73),
                  ),
                  splashRadius: 20,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: onOptionsPressed,
                ),
              ],
              if (isStarred != null) ...[
                IconButton(
                  icon: Icon(
                    isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 22,
                    color: isStarred
                        ? const Color(0xFFFFD60A)
                        : (isDark ? const Color(0xFFA7A7A7) : const Color(0xFF8E8E93)),
                  ),
                  splashRadius: 20,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: onStarredToggle,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSearchesSection(
    BuildContext context,
    RecentSearchesService recentSearches,
    bool isDark,
    Color primaryColor,
  ) {
    final items = recentSearches.items;
    final libraryProvider = Provider.of<LibraryProvider>(context);
    final player = Provider.of<PlayerProvider>(context, listen: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Búsquedas recientes',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.4,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              TextButton(
                onPressed: () => recentSearches.clear(),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Borrar',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...items.map((item) {
          final isArtist = item.type == RecentSearchType.artist;
          final isAlbum = item.type == RecentSearchType.album;
          final isSong = item.type == RecentSearchType.song;

          final songObj = item.song ??
              (isSong
                  ? Song(
                      id: item.id,
                      title: item.title,
                      artist: item.subtitle?.replaceFirst('Canción • ', ''),
                      coverArt: item.imageUrl,
                    )
                  : null);

          final isStarred = songObj != null
              ? (libraryProvider.isSongStarred(songObj.id) || (songObj.starred ?? false))
              : null;

          return _buildSpotifyItemTile(
            title: item.title,
            subtitle: item.subtitle ??
                (isArtist
                    ? 'Artista'
                    : isAlbum
                        ? 'Álbum'
                        : 'Canción'),
            imageUrl: item.imageUrl,
            isCircular: isArtist,
            isDark: isDark,
            isStarred: isStarred,
            primaryColor: primaryColor,
            isPlaying: songObj != null && player.currentSong?.id == songObj.id,
            onStarredToggle: songObj != null
                ? () {
                    libraryProvider.toggleStarSong(songObj);
                  }
                : null,
            onOptionsPressed: songObj != null
                ? () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      useRootNavigator: true,
                      builder: (ctx) => NowPlayingMoreMenu(song: songObj),
                    );
                  }
                : null,
            onTap: () {
              recentSearches.addItem(item);
              if (isArtist) {
                NavigationHelper.push(
                  context,
                  ArtistScreen(
                    artistId: item.id,
                    artist: Artist(
                      id: item.id,
                      name: item.title,
                      coverArt: item.imageUrl,
                    ),
                  ),
                );
              } else if (isAlbum) {
                NavigationHelper.push(
                  context,
                  AlbumScreen(
                    albumId: item.id,
                    album: item.album ??
                        Album(
                          id: item.id,
                          name: item.title,
                          artist: item.subtitle,
                          coverArt: item.imageUrl,
                        ),
                  ),
                );
              } else if (isSong && songObj != null) {
                player.playSongWithRadio(songObj);
              }
            },
          );
        }),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _defaultArtistAvatar(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF242424) : Colors.grey[300],
      child: const Center(
        child: Icon(CupertinoIcons.person_fill, color: Colors.white38, size: 26),
      ),
    );
  }

  Widget _defaultCover(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF242424) : Colors.grey[300],
      child: const Center(
        child: Icon(CupertinoIcons.music_note, color: Colors.white38, size: 26),
      ),
    );
  }

  Widget _buildAutocompleteOverlay(bool isDark, Color primaryColor) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: isDark ? const Color(0xFF242424) : Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 400),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA),
            width: 1,
          ),
        ),
        child: _isLoadingSuggestions
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  ),
                ),
              )
            : _autocompleteSuggestions == null ||
                  _autocompleteSuggestions!.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    AppLocalizations.of(context)!.noSuggestions,
                    style: TextStyle(
                      color: AppTheme.lightSecondaryText,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_autocompleteSuggestions!.songs.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Text(
                          AppLocalizations.of(context)!.songs,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.lightSecondaryText,
                          ),
                        ),
                      ),
                      ..._autocompleteSuggestions!.songs.take(5).map(
                        (song) => ListTile(
                          dense: true,
                          leading: Icon(
                            CupertinoIcons.music_note,
                            size: 20,
                            color: primaryColor,
                          ),
                          title: Text(
                            song.title,
                            style: const TextStyle(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: song.artist != null
                              ? Text(
                                  song.artist!,
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          onTap: () {
                            RecentSearchesService().addSong(song);
                            setState(() => _showSuggestions = false);
                            final playerProvider = Provider.of<PlayerProvider>(
                              context,
                              listen: false,
                            );
                            playerProvider.playSong(
                              song,
                              playlist: _autocompleteSuggestions!.songs,
                              startIndex: _autocompleteSuggestions!.songs
                                  .indexOf(song),
                            );
                          },
                        ),
                      ),
                    ],
                    if (_autocompleteSuggestions!.artists.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Text(
                          AppLocalizations.of(context)!.artists,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.lightSecondaryText,
                          ),
                        ),
                      ),
                      ..._autocompleteSuggestions!.artists.take(3).map(
                        (artist) => ListTile(
                          dense: true,
                          leading: Icon(
                            CupertinoIcons.person,
                            size: 20,
                            color: primaryColor,
                          ),
                          title: Text(
                            artist.name,
                            style: const TextStyle(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            RecentSearchesService().addArtist(artist);
                            setState(() => _showSuggestions = false);
                            NavigationHelper.push(
                              context,
                              ArtistScreen(artistId: artist.id, artist: artist),
                            );
                          },
                        ),
                      ),
                    ],
                    if (_autocompleteSuggestions!.albums.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Text(
                          AppLocalizations.of(context)!.albums,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.lightSecondaryText,
                          ),
                        ),
                      ),
                      ..._autocompleteSuggestions!.albums.take(3).map(
                        (album) => ListTile(
                          dense: true,
                          leading: Icon(
                            CupertinoIcons.music_albums,
                            size: 20,
                            color: primaryColor,
                          ),
                          title: Text(
                            album.name,
                            style: const TextStyle(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: album.artist != null
                              ? Text(
                                  album.artist!,
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          onTap: () {
                            RecentSearchesService().addAlbum(album);
                            setState(() => _showSuggestions = false);
                            NavigationHelper.push(
                              context,
                              AlbumScreen(albumId: album.id, album: album),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
      ),
    );
  }
}




