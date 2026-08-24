import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../models/models.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../services/subsonic_service.dart';
import '../services/recent_searches_service.dart';
import '../theme/app_theme.dart';
import '../utils/navigation_helper.dart';
import '../widgets/widgets.dart';
import 'album_screen.dart';
import 'artist_screen.dart';
import 'genres_screen.dart';
import 'new_releases_screen.dart';
import 'made_for_you_screen.dart';
import 'top_rated_screen.dart';
import 'favorites_screen.dart';
import 'radio_screen.dart';
import '../l10n/app_localizations.dart';
import '../services/player_ui_settings_service.dart';

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
      final result = await libraryProvider.search(query);
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

    if (value.isEmpty) {
      setState(() {
        _searchResult = null;
        _autocompleteSuggestions = null;
        _showSuggestions = false;
        _query = '';
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 450), () {
      if (_liveSearch) {
        _search(value);
      } else {
        _loadAutocomplete(value);
      }
    });
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResult = null;
        _query = '';
        _showSuggestions = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _query = query;
      _showSuggestions = false;
    });

    try {
      final libraryProvider = Provider.of<LibraryProvider>(
        context,
        listen: false,
      );
      final result = await libraryProvider.search(query);
      if (mounted && _query == query) {
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

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                floating: true,
                expandedHeight: 120,
                elevation: 0,
                backgroundColor: isDark ? AppTheme.darkBackground : Colors.white,
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
                  preferredSize: const Size.fromHeight(56),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: CupertinoSearchTextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      placeholder: 'Artistas, canciones, letras y...',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 16,
                      ),
                      prefixIcon: const Icon(
                        CupertinoIcons.search,
                        color: AppTheme.appleMusicRed,
                        size: 20,
                      ),
                      backgroundColor: isDark
                          ? const Color(0xFF2C2C2E)
                          : const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(12),
                      onChanged: _onSearchChanged,
                      onSubmitted: (value) {
                        setState(() => _showSuggestions = false);
                        _search(value);
                      },
                    ),
                  ),
                ),
              ),
              if (_isSearching)
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          AppLocalizations.of(context)!.albums,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 12),
                      HorizontalShimmerList(
                        count: 3,
                        child: const AlbumCardShimmer(size: 150),
                      ),
                      const SizedBox(height: 24),
                      ...List.generate(5, (_) => const SongTileShimmer()),
                    ],
                  ),
                )
              else if (_searchResult != null && !_searchResult!.isEmpty)
                SliverToBoxAdapter(child: _buildSearchResults())
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
                    child: _buildRecentSearchesSection(context, recentSearches, isDark),
                  ),
                SliverToBoxAdapter(child: _buildBrowseCategories()),
              ],
            ],
          ),
          
          if (_showSuggestions && _searchController.text.isNotEmpty)
            Positioned(
              top: 120 + 56 + 8,
              left: 16,
              right: 16,
              child: _buildAutocompleteOverlay(isDark),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentSearchesSection(
    BuildContext context,
    RecentSearchesService recentSearches,
    bool isDark,
  ) {
    final items = recentSearches.items;
    final subsonic = Provider.of<SubsonicService>(context, listen: false);
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
                  fontSize: 22,
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
                child: const Text(
                  'Borrar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.appleMusicRed,
                  ),
                ),
              ),
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          itemCount: items.length,
          separatorBuilder: (ctx, i) => Divider(
            height: 1,
            thickness: 0.5,
            indent: 68,
            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
          ),
          itemBuilder: (ctx, index) {
            final item = items[index];
            final coverUrl = item.imageUrl != null
                ? (isLocalFilePath(item.imageUrl)
                    ? item.imageUrl!
                    : subsonic.getCoverArtUrl(item.imageUrl!, size: 150))
                : null;

            Widget leadingWidget;
            if (item.type == RecentSearchType.artist) {
              leadingWidget = ClipOval(
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: coverUrl != null
                      ? CachedNetworkImage(
                          imageUrl: coverUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: Colors.grey[800]),
                          errorWidget: (_, __, ___) => _defaultArtistAvatar(isDark),
                        )
                      : _defaultArtistAvatar(isDark),
                ),
              );
            } else {
              leadingWidget = ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: coverUrl != null
                      ? CachedNetworkImage(
                          imageUrl: coverUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: Colors.grey[800]),
                          errorWidget: (_, __, ___) => _defaultCover(isDark),
                        )
                      : _defaultCover(isDark),
                ),
              );
            }

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              leading: leadingWidget,
              title: Text(
                item.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle ?? (item.type == RecentSearchType.artist ? 'Artista' : 'Música'),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.extra != null && item.extra!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Letra: "${item.extra}"',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[500] : Colors.grey[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
              trailing: item.type == RecentSearchType.song
                  ? const Icon(
                      CupertinoIcons.ellipsis_vertical,
                      size: 18,
                      color: Colors.grey,
                    )
                  : null,
              onTap: () {
                if (item.type == RecentSearchType.artist) {
                  NavigationHelper.push(context, ArtistScreen(artistId: item.id));
                } else if (item.type == RecentSearchType.album) {
                  NavigationHelper.push(context, AlbumScreen(albumId: item.id));
                } else if (item.type == RecentSearchType.song && item.song != null) {
                  player.playSongWithRadio(item.song!);
                }
              },
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _defaultArtistAvatar(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[300],
      child: const Center(
        child: Icon(CupertinoIcons.person_fill, color: Colors.white38, size: 26),
      ),
    );
  }

  Widget _defaultCover(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[300],
      child: const Center(
        child: Icon(CupertinoIcons.music_note, color: Colors.white38, size: 26),
      ),
    );
  }

  Widget _buildSearchResults() {
    final result = _searchResult!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result.artists.isNotEmpty) ...[
          SectionHeader(title: AppLocalizations.of(context)!.artists),
          ...result.artists
              .take(5)
              .map(
                (artist) => ArtistTile(
                  artist: artist,
                  onTap: () {
                    RecentSearchesService().addArtist(artist);
                    NavigationHelper.push(
                      context,
                      ArtistScreen(artistId: artist.id),
                    );
                  },
                ),
              ),
          const SizedBox(height: 16),
        ],

        if (result.albums.isNotEmpty) ...[
          HorizontalScrollSection(
            title: AppLocalizations.of(context)!.albums,
            children: result.albums
                .take(10)
                .map(
                  (album) => AlbumCard(
                    album: album,
                    size: 150,
                    onTap: () {
                      RecentSearchesService().addAlbum(album);
                      NavigationHelper.push(
                        context,
                        AlbumScreen(albumId: album.id),
                      );
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
        ],

        if (result.songs.isNotEmpty) ...[
          SectionHeader(
            title: (result.youtubeVideos != null && result.youtubeVideos!.isNotEmpty)
                ? 'YT Stream'
                : AppLocalizations.of(context)!.songs,
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemExtent: 68.0,
            cacheExtent: 300,
            itemCount: result.songs.length,
            itemBuilder: (context, index) {
              final song = result.songs[index];
              return SongTile(
                song: song,
                index: index,
                showArtist: true,
                showAlbum: true,
                onTap: () {
                  RecentSearchesService().addSong(song);
                  final player = Provider.of<PlayerProvider>(context, listen: false);
                  player.playSongWithRadio(song);
                },
              );
            },
          ),
          const SizedBox(height: 16),
        ],

        if (result.youtubeVideos != null && result.youtubeVideos!.isNotEmpty) ...[
          const SectionHeader(title: 'YouTube'),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemExtent: 68.0,
            cacheExtent: 300,
            itemCount: result.youtubeVideos!.length,
            itemBuilder: (context, index) {
              final song = result.youtubeVideos![index];
              return SongTile(
                song: song,
                index: index,
                showArtist: true,
                showAlbum: true,
                onTap: () {
                  RecentSearchesService().addSong(song);
                  final player = Provider.of<PlayerProvider>(context, listen: false);
                  player.playSongWithRadio(song);
                },
              );
            },
          ),
          const SizedBox(height: 16),
        ],

        const SizedBox(height: 150),
      ],
    );
  }

  Widget _buildBrowseCategories() {
    final categories = [
      _CategoryItem(
        AppLocalizations.of(context)!.categoryMadeForYou,
        Icons.person_outline_rounded,
        [Colors.purple, Colors.pink],
        () => NavigationHelper.push(context, const MadeForYouScreen()),
      ),
      _CategoryItem(
        AppLocalizations.of(context)!.categoryNewReleases,
        Icons.album_rounded,
        [Colors.orange, Colors.red],
        () => NavigationHelper.push(context, const NewReleasesScreen()),
      ),
      _CategoryItem(
        AppLocalizations.of(context)!.categoryTopRated,
        Icons.star_rounded,
        [Colors.amber, Colors.orange],
        () => NavigationHelper.push(context, const TopRatedScreen()),
      ),
      _CategoryItem(
        AppLocalizations.of(context)!.categoryGenres,
        Icons.library_music_rounded,
        [Colors.green, Colors.teal],
        () => NavigationHelper.push(context, const GenresScreen()),
      ),
      _CategoryItem(
        AppLocalizations.of(context)!.categoryFavorites,
        Icons.favorite_rounded,
        [Colors.red, Colors.pink],
        () => NavigationHelper.push(context, const FavoritesScreen()),
      ),
      if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux)
        _CategoryItem(
          AppLocalizations.of(context)!.categoryRadio,
          Icons.radio_rounded,
          [Colors.blue, Colors.indigo],
          () => NavigationHelper.push(context, const RadioScreen()),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: AppLocalizations.of(context)!.browseCategories),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return _CategoryCard(category: category);
            },
          ),
        ),
        const SizedBox(height: 150),
      ],
    );
  }

  Widget _buildAutocompleteOverlay(bool isDark) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: isDark ? AppTheme.darkCard : Colors.white,
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
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
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
                      ..._autocompleteSuggestions!.artists.map(
                        (artist) => ListTile(
                          dense: true,
                          leading: Icon(
                            CupertinoIcons.person,
                            size: 20,
                            color: AppTheme.appleMusicRed,
                          ),
                          title: Text(
                            artist.name,
                            style: const TextStyle(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            setState(() => _showSuggestions = false);
                            NavigationHelper.push(
                              context,
                              ArtistScreen(artistId: artist.id),
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
                      ..._autocompleteSuggestions!.albums.map(
                        (album) => ListTile(
                          dense: true,
                          leading: Icon(
                            CupertinoIcons.music_albums,
                            size: 20,
                            color: AppTheme.appleMusicRed,
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
                            setState(() => _showSuggestions = false);
                            NavigationHelper.push(
                              context,
                              AlbumScreen(albumId: album.id),
                            );
                          },
                        ),
                      ),
                    ],
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
                      ..._autocompleteSuggestions!.songs.map(
                        (song) => ListTile(
                          dense: true,
                          leading: Icon(
                            CupertinoIcons.music_note,
                            size: 20,
                            color: AppTheme.appleMusicRed,
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
                    const SizedBox(height: 8),
                  ],
                ),
              ),
      ),
    );
  }
}

class _CategoryItem {
  final String title;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  _CategoryItem(this.title, this.icon, this.colors, this.onTap);
}

class _CategoryCard extends StatelessWidget {
  final _CategoryItem category;

  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: category.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: category.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(category.icon, color: Colors.white, size: 24),
                const Spacer(),
                Text(
                  category.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
