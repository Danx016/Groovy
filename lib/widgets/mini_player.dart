import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../models/radio_station.dart';
import '../providers/player_provider.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../services/youtube_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'album_artwork.dart';
import '../screens/now_playing_screen.dart';

class MiniPlayer extends StatelessWidget {
  final VoidCallback? onTap;

  const MiniPlayer({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
    if (isDesktop) return const SizedBox.shrink();

    return Selector<PlayerProvider, (Song?, RadioStation?, bool)>(
      selector: (_, p) =>
          (p.currentSong, p.currentRadioStation, p.isPlayingRadio),
      builder: (context, data, _) {
        final (currentSong, currentRadioStation, isPlayingRadio) = data;

        void handleTap() {
          if (onTap != null) {
            onTap!();
            return;
          }
          if (currentSong != null) {
            final youtubeService = Provider.of<YoutubeService>(context, listen: false);
            final coverUrl = currentSong.coverArt != null ? youtubeService.getCoverArtUrl(currentSong.coverArt, size: 600) : null;
            final imageProvider = coverUrl != null 
                ? CachedNetworkImageProvider(coverUrl) as ImageProvider
                : const AssetImage('assets/default_cover.png') as ImageProvider;
            final topPadding = MediaQuery.of(context).padding.top;    

            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useRootNavigator: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => NowPlayingScreen(
                topPadding: topPadding,
                image: imageProvider,
                title: currentSong.title,
                artist: (currentSong.artistParticipants?.isNotEmpty == true
                    ? currentSong.artistParticipants!.map((a) => a.name).join(', ')
                    : currentSong.artist) ?? '',
                heroTag: 'cover_${currentSong.id}',
                song: currentSong,
              ),
            );
          }
        }

        if (currentSong == null && !isPlayingRadio) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        final String title;
        final String? subtitle;
        final String? coverArt;

        if (isPlayingRadio && currentRadioStation != null) {
          title = currentRadioStation.name;
          subtitle = 'Internet Radio • LIVE';
          coverArt = null;
        } else if (currentSong != null) {
          title = currentSong.title;
          subtitle =
              currentSong.artistParticipants != null &&
                  currentSong.artistParticipants!.isNotEmpty
              ? currentSong.artistParticipants!.map((a) => a.name).join(', ')
              : currentSong.artist;
          coverArt = currentSong.coverArt;
        } else {
          return const SizedBox.shrink();
        }

        final bool isGlass = Provider.of<ThemeService>(context).liquidGlass;

        final Widget row = _MiniPlayerRow(
          title: title,
          subtitle: subtitle,
          coverArt: coverArt,
          isPlayingRadio: isPlayingRadio,
        );

        if (isGlass) {
          return RepaintBoundary(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: GestureDetector(
                onTap: handleTap,
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xF01C1C1E)
                        : const Color(0xF5FFFFFF),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.14)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 0.8,
                    ),
                  ),
                  child: row,
                ),
              ),
            ),
          );
        }

        return RepaintBoundary(
          child: GestureDetector(
            onTap: handleTap,
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.95),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? AppTheme.darkDivider
                        : AppTheme.lightDivider,
                    width: 0.5,
                  ),
                ),
              ),
              child: row,
            ),
          ),
        );
      },
    );
  }
}

class _MiniPlayerRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? coverArt;
  final bool isPlayingRadio;

  const _MiniPlayerRow({
    required this.title,
    required this.subtitle,
    required this.coverArt,
    required this.isPlayingRadio,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (isPlayingRadio)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF2D55), Color(0xFFFF6B35)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.radio, color: Colors.white, size: 24),
            )
          else
            AlbumArtwork(coverArt: coverArt, size: 44, borderRadius: 8),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _MiniPlayerControls(isRadio: isPlayingRadio),
        ],
      ),
    );
  }
}

class _MiniPlayerControls extends StatelessWidget {
  final bool isRadio;

  const _MiniPlayerControls({this.isRadio = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.white : Colors.black;

    return Selector<PlayerProvider, (bool, bool)>(
      selector: (_, p) => (p.isPlaying, p.hasNext),
      builder: (context, data, _) {
        final (isPlaying, hasNext) = data;
        final provider = context.read<PlayerProvider>();

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Play / Pause Button (Apple Music iconic solid symbol)
            IconButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                provider.togglePlayPause();
              },
              padding: const EdgeInsets.symmetric(horizontal: 8),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 34,
              ),
              color: color,
            ),

            // Next / Fast-Forward Button (Apple Music double arrow)
            IconButton(
              onPressed: hasNext
                  ? () {
                      HapticFeedback.lightImpact();
                      provider.skipNext();
                    }
                  : null,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: const Icon(
                Icons.fast_forward_rounded,
                size: 30,
              ),
              color: color,
            ),
          ],
        );
      },
    );
  }
}
