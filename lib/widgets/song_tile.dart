import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../services/player_ui_settings_service.dart';
import '../services/offline_service.dart';
import '../theme/app_theme.dart';
import 'album_artwork.dart';
import 'animated_equalizer.dart';
import 'dolby_atmos_badge.dart';
import 'multi_artist_widget.dart';
import 'now_playing/now_playing_more_menu.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final List<Song>? playlist;
  final int? index;
  final bool showArtwork;
  final bool showArtist;
  final bool showAlbum;
  final bool showDuration;
  final bool showTrackNumber;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const SongTile({
    super.key,
    required this.song,
    this.playlist,
    this.index,
    this.showArtwork = true,
    this.showArtist = true,
    this.showAlbum = false,
    this.showDuration = true,
    this.showTrackNumber = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RepaintBoundary(
      child: Selector<PlayerProvider, String?>(
        selector: (_, provider) => provider.currentSong?.id,
        builder: (context, currentSongId, _) {
          final isCurrentSong = currentSongId == song.id;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: _buildLeading(context, isCurrentSong),
            title: Text(
              song.title,
              style: theme.textTheme.bodyLarge?.copyWith(
                color:
                    isCurrentSong ? Theme.of(context).colorScheme.primary : null,
                fontWeight: isCurrentSong ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle:
                showArtist || showAlbum ? _buildSubtitleWidget(theme) : null,
            trailing: _buildTrailing(context),
            onTap: onTap ?? () => _playSong(context),
            onLongPress: onLongPress ?? () => _showOptions(context),
          );
        },
      ),
    );
  }

  Widget? _buildLeading(BuildContext context, bool isCurrentSong) {
    if (showTrackNumber && !showArtwork) {
      return SizedBox(
        width: 30,
        child: Center(
          child: isCurrentSong
              ? Selector<PlayerProvider, bool>(
                  selector: (ctx, p) => p.isPlaying,
                  builder: (ctx, isPlaying, __) => AnimatedEqualizer(
                    color: Theme.of(context).colorScheme.primary,
                    isPlaying: isPlaying,
                  ),
                )
              : Text(
                  '${song.track ?? (index != null ? index! + 1 : 1)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.lightSecondaryText,
                      ),
                ),
        ),
      );
    }

    if (showArtwork) {
      final radius = PlayerUiSettingsService().getAlbumArtCornerRadius();
      return Stack(
        children: [
          AlbumArtwork(
            coverArt: (song.coverArt != null && song.coverArt!.isNotEmpty)
                ? song.coverArt
                : song.id,
            size: 50,
            preserveAspectRatio: true,
          ),
          if (isCurrentSong)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(radius),
                ),
                child: Center(
                  child: Selector<PlayerProvider, bool>(
                    selector: (ctx, p) => p.isPlaying,
                    builder: (ctx, isPlaying, __) => AnimatedEqualizer(
                      color: Colors.white,
                      isPlaying: isPlaying,
                    ),
                  ),
                ),
              ),
            ),
          Selector<LibraryProvider, bool>(
            selector: (_, lib) => lib.isSongStarred(song.id),
            builder: (context, isStarred, _) {
              final isFav = isStarred || (song.starred == true);
              if (!isFav) return const SizedBox.shrink();
              return Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.heart_fill,
                    size: 11,
                    color: Color(0xFFFA2D48),
                  ),
                ),
              );
            },
          ),
        ],
      );
    }

    return null;
  }

  Widget _buildSubtitleWidget(ThemeData theme) {
    if (showArtist) {
      if (showAlbum && song.album != null && song.album!.trim().isNotEmpty) {
        return Text(
          '${song.artist ?? ""}${song.album != null && song.album!.trim().isNotEmpty ? " â€¢ ${song.album}" : ""}',
          style: theme.textTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      }
      return MultiArtistWidget(
        artists: song.artistParticipants,
        artistFallback: song.artist,
        artistIdFallback: song.artistId,
        style: theme.textTheme.bodySmall,
      );
    }

    return Text(
      song.album ?? '',
      style: theme.textTheme.bodySmall,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildTrailing(BuildContext context) {
    return Selector<LibraryProvider, bool>(
      selector: (_, lib) => lib.isSongStarred(song.id),
      builder: (context, isStarred, _) {
        final isFav = isStarred || (song.starred == true);
        return ValueListenableBuilder<Set<String>>(
          valueListenable: OfflineService().downloadedSongIds,
          builder: (context, ids, _) {
            final isDownloaded = ids.contains(song.id);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isDownloaded)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(CupertinoIcons.arrow_down_circle_fill, size: 14, color: Colors.grey),
                  ),
                if (isFav)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      CupertinoIcons.heart_fill,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                    ),
                  ),
                if (song.hasDolbyAtmos == true)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: DolbyAtmosBadge(),
                  ),
                if (showDuration) ...[
                  Text(
                    song.formattedDuration,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 4),
                ],
                IconButton(
                  icon: const Icon(Icons.more_horiz),
                  iconSize: 20,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  onPressed: () => _showOptions(context),
                ),
              ],
            );
          },
        );
      },
    );
  }


  void _playSong(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    playerProvider.playSong(song, playlist: playlist, startIndex: index);
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) => NowPlayingMoreMenu(song: song),
    );
  }
}
