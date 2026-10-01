import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/library_provider.dart';
import '../l10n/app_localizations.dart';
import '../widgets/widgets.dart';
import '../theme/app_theme.dart';
import 'album_screen.dart';

/// Screen displaying all liked/starred albums
class LikedAlbumsScreen extends StatefulWidget {
  const LikedAlbumsScreen({super.key});

  @override
  State<LikedAlbumsScreen> createState() => _LikedAlbumsScreenState();
}

class _LikedAlbumsScreenState extends State<LikedAlbumsScreen> {
  List<Album> _likedAlbums = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLikedAlbums();
  }

  Future<void> _loadLikedAlbums() async {
    setState(() => _isLoading = true);

    final libraryProvider = Provider.of<LibraryProvider>(
      context,
      listen: false,
    );
    final youtubeService = libraryProvider.youtubeService;

    try {
      final results = await Future.wait([
        youtubeService.getStarred().then((s) => s.albums).catchError((_) => <Album>[]),
        libraryProvider.database.getStarredAlbums().catchError((_) => <Album>[]),
      ]);
      final map = <String, Album>{};
      for (final a in results[0]) {
        map[a.id] = a;
      }
      for (final a in results[1]) {
        map[a.id] = a;
      }
      if (mounted) {
        setState(() {
          _likedAlbums = map.values.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.likedAlbums),
      ),
      body: _isLoading
          ? _buildLoadingGrid()
          : _likedAlbums.isEmpty
              ? _buildEmptyState(Theme.of(context).brightness == Brightness.dark)
              : _buildAlbumsGrid(),
    );
  }

  Widget _buildLoadingGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = (width / 180).floor().clamp(2, 8);
        return GridView.builder(
          padding: const EdgeInsets.all(16).copyWith(bottom: 150),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 20,
            crossAxisSpacing: 16,
            childAspectRatio: 0.76,
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
                gradient: LinearGradient(
                  colors: [
                    Colors.amber.withValues(alpha: 0.18),
                    AppTheme.appleMusicRed.withValues(alpha: 0.08),
                  ],
                ),
              ),
              child: const Icon(
                CupertinoIcons.star_fill,
                size: 38,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noLikedAlbums,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = (width / 180).floor().clamp(2, 8);
        return GridView.builder(
          padding: const EdgeInsets.all(16).copyWith(bottom: 150),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 20,
            crossAxisSpacing: 16,
            childAspectRatio: 0.76,
          ),
          itemCount: _likedAlbums.length,
          itemBuilder: (context, index) {
            final album = _likedAlbums[index];
            return AlbumCard(
              album: album,
              size: double.infinity,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AlbumScreen(albumId: album.id, album: album),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
