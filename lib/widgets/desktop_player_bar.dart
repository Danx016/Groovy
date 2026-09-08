import 'dart:io';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../l10n/app_localizations.dart';
import '../models/song.dart';
import '../models/radio_station.dart';
import '../models/artist.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../services/youtube_service.dart';
import '../theme/app_theme.dart';
import '../screens/artist_screen.dart';
import '../screens/now_playing_screen.dart';

import 'album_artwork.dart';
import '../services/cast_service.dart';
import '../services/upnp_service.dart';
import '../services/groovy_connect_service.dart';
import 'connect/groovy_connect_icon.dart';
import 'connect/groovy_connect_modal.dart';


class DesktopPlayerBar extends StatefulWidget {
  final GlobalKey<NavigatorState>? navigatorKey;
  final VoidCallback? onToggleQueue;
  final VoidCallback? onToggleNowPlaying;
  final VoidCallback? onToggleLyrics;
  final bool isQueueOpen;
  final bool isNowPlayingOpen;
  final bool isLyricsOpen;

  const DesktopPlayerBar({
    super.key,
    this.navigatorKey,
    this.onToggleQueue,
    this.onToggleNowPlaying,
    this.onToggleLyrics,
    this.isQueueOpen = false,
    this.isNowPlayingOpen = false,
    this.isLyricsOpen = false,
  });

  @override
  State<DesktopPlayerBar> createState() => _DesktopPlayerBarState();
}

class _DesktopPlayerBarState extends State<DesktopPlayerBar> {

  void _navigateToArtist(BuildContext context, String artistId, {String? artistName, String? coverArt}) {
    final artistObj = (artistName != null && artistName.isNotEmpty)
        ? Artist(id: artistId, name: artistName, coverArt: coverArt)
        : null;

    if (widget.navigatorKey?.currentState != null) {
      widget.navigatorKey!.currentState!.push(
        MaterialPageRoute(
          builder: (context) => ArtistScreen(artistId: artistId, artist: artistObj),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ArtistScreen(artistId: artistId, artist: artistObj),
        ),
      );
    }
  }

  void _openFullscreenNowPlaying(BuildContext context, Song song) {
    final youtubeService = Provider.of<YoutubeService>(context, listen: false);
    final coverUrl = song.coverArt != null
        ? youtubeService.getCoverArtUrl(song.coverArt, size: 600)
        : null;
    final ImageProvider imageProvider;
    if (coverUrl != null && coverUrl.isNotEmpty) {
      if (song.isLocal || isLocalFilePath(coverUrl)) {
        imageProvider = FileImage(File(coverUrl));
      } else {
        imageProvider = CachedNetworkImageProvider(coverUrl);
      }
    } else {
      imageProvider = const AssetImage('assets/default_cover.png');
    }

    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (ctx, anim, secondaryAnim) => NowPlayingScreen(
          image: imageProvider,
          title: song.title,
          artist: (song.artistParticipants?.isNotEmpty == true
                  ? song.artistParticipants!.map((a) => a.name).join(', ')
                  : song.artist) ??
              '',
          heroTag: 'desktop_bar_fs_${song.id}',
          song: song,
        ),
        transitionsBuilder: (ctx, anim, secondaryAnim, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Selector<PlayerProvider, (Song?, RadioStation?, bool)>(
      selector: (_, p) =>
          (p.currentSong, p.currentRadioStation, p.isPlayingRadio),
      builder: (context, data, _) {
        final (currentSong, radioStation, isPlayingRadio) = data;

        if (isPlayingRadio && radioStation != null) {
          return _buildRadioBar(context, theme, isDark, radioStation);
        }

        if (currentSong == null) return const SizedBox.shrink();

        return _buildSongBar(context, theme, isDark, currentSong);
      },
    );
  }

  Widget _buildRadioBar(BuildContext context, ThemeData theme, bool isDark,
      RadioStation station) {
    final barColor = isDark ? AppTheme.playerBarDark : AppTheme.playerBarLight;
    final borderColor =
        isDark ? AppTheme.playerBarBorder : const Color(0xFFDDDDDD);
    final iconColor =
        isDark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText;

    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: barColor,
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(Icons.radio_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.red.withValues(alpha: 0.5),
                                    blurRadius: 4)
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'LIVE',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Selector<PlayerProvider, bool>(
              selector: (_, p) => p.isPlaying,
              builder: (context, isPlaying, _) {
                final provider = context.read<PlayerProvider>();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 32,
                          color: Colors.black,
                        ),
                        onPressed: provider.togglePlayPause,
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon:
                          Icon(Icons.stop_rounded, size: 26, color: iconColor),
                      onPressed: provider.stop,
                      tooltip: 'Stop',
                    ),
                  ],
                );
              },
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.slideshow_rounded,
                    size: 20,
                    color: widget.isNowPlayingOpen
                        ? theme.colorScheme.primary
                        : iconColor,
                  ),
                  onPressed: widget.onToggleNowPlaying ?? widget.onToggleQueue,
                  tooltip: 'Vista que suena',
                ),
                Consumer3<CastService, UpnpService, GroovyConnectService>(
                  builder: (context, cs, us, gs, _) {
                    final isConn = cs.isConnected || us.isConnected || gs.isConnected;
                    return IconButton(
                      icon: GroovyConnectIcon(
                        size: 20,
                        color: isConn ? AppTheme.appleMusicRed : iconColor,
                        isConnected: isConn,
                        connectedColor: AppTheme.appleMusicRed,
                      ),
                      onPressed: () => GroovyConnectModal.show(context),
                      tooltip: 'Conectar a un dispositivo',
                    );
                  },
                ),
                const SizedBox(width: 8),
                const _VolumeControl(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongBar(
      BuildContext context, ThemeData theme, bool isDark, Song currentSong) {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.playerBarDark : AppTheme.playerBarLight,
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.playerBarBorder : const Color(0xFFDDDDDD),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => _openFullscreenNowPlaying(context, currentSong),
                    child: Consumer<LibraryProvider>(
                      builder: (context, lib, _) {
                        final isFav = lib.isSongStarred(currentSong.id) || currentSong.starred == true;
                        return Stack(
                          children: [
                            AlbumArtwork(
                              coverArt: currentSong.coverArt,
                              size: 56,
                              borderRadius: 4,
                            ),
                            if (isFav)
                              Positioned(
                                bottom: 2,
                                right: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(2.5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.75),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.favorite_rounded,
                                    size: 10,
                                    color: AppTheme.appleMusicRed,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentSong.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (currentSong.artist != null)
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              final id = currentSong.artistId ?? currentSong.artist!;
                              _navigateToArtist(
                                context,
                                id,
                                artistName: currentSong.artist,
                                coverArt: currentSong.coverArt,
                              );
                            },
                            child: Text(
                              currentSong.artist!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Consumer<LibraryProvider>(
                  builder: (context, lib, _) {
                    final isStarred = lib.isSongStarred(currentSong.id) || currentSong.starred == true;
                    return IconButton(
                      icon: Icon(
                        isStarred
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 20,
                        color: isStarred
                            ? AppTheme.appleMusicRed
                            : (isDark
                                ? const Color(0xFFB3B3B3)
                                : const Color(0xFF6B6B6B)),
                      ),
                      onPressed: () {
                        Provider.of<PlayerProvider>(context, listen: false)
                            .toggleFavorite();
                      },
                      tooltip: isStarred
                          ? AppLocalizations.of(context)!.removeFromFavorites
                          : AppLocalizations.of(context)!.addToFavorites,
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _PlayerControls(),
                const SizedBox(height: 4),
                const _ProgressBar(),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.slideshow_rounded,
                    size: 20,
                    color: widget.isNowPlayingOpen
                        ? theme.colorScheme.primary
                        : (isDark
                            ? const Color(0xFFB3B3B3)
                            : const Color(0xFF6B6B6B)),
                  ),
                  onPressed: widget.onToggleNowPlaying ?? widget.onToggleQueue,
                  tooltip: 'Vista que suena',
                ),
                IconButton(
                  icon: Icon(
                    Icons.mic_none_rounded,
                    size: 20,
                    color: widget.isLyricsOpen
                        ? theme.colorScheme.primary
                        : (isDark
                            ? const Color(0xFFB3B3B3)
                            : const Color(0xFF6B6B6B)),
                  ),
                  onPressed: widget.onToggleLyrics ?? widget.onToggleQueue,
                  tooltip: 'Letras',
                ),
                IconButton(
                  icon: Icon(
                    Icons.queue_music_rounded,
                    size: 20,
                    color: widget.isQueueOpen
                        ? theme.colorScheme.primary
                        : (isDark
                            ? const Color(0xFFB3B3B3)
                            : const Color(0xFF6B6B6B)),
                  ),
                  onPressed: widget.onToggleQueue,
                  tooltip: 'Cola de reproducción',
                ),
                Consumer3<CastService, UpnpService, GroovyConnectService>(
                  builder: (context, cs, us, gs, _) {
                    final isConn = cs.isConnected || us.isConnected || gs.isConnected;
                    return IconButton(
                      icon: GroovyConnectIcon(
                        size: 20,
                        color: isConn
                            ? AppTheme.appleMusicRed
                            : (isDark
                                ? const Color(0xFFB3B3B3)
                                : const Color(0xFF6B6B6B)),
                        isConnected: isConn,
                        connectedColor: AppTheme.appleMusicRed,
                      ),
                      onPressed: () => GroovyConnectModal.show(context),
                      tooltip: 'Conectar a un dispositivo',
                    );
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.open_in_full_rounded,
                    size: 18,
                    color: isDark
                        ? const Color(0xFFB3B3B3)
                        : const Color(0xFF6B6B6B),
                  ),
                  onPressed: () =>
                      _openFullscreenNowPlaying(context, currentSong),
                  tooltip: 'Pantalla completa',
                ),
                const SizedBox(width: 8),
                const _VolumeControl(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerControls extends StatelessWidget {
  const _PlayerControls();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = isDark ? Colors.white : Colors.black;
    final disabledColor = isDark ? Colors.grey[800] : Colors.grey[300];
    final activeAccent = theme.colorScheme.primary;

    return Selector<PlayerProvider, (bool, bool, bool, bool, RepeatMode)>(
      selector: (_, p) => (
        p.isPlaying,
        p.shuffleEnabled,
        p.hasPrevious,
        p.hasNext,
        p.repeatMode,
      ),
      builder: (context, data, _) {
        final (isPlaying, shuffleEnabled, hasPrevious, hasNext, repeatMode) =
            data;
        final provider = context.read<PlayerProvider>();

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(
                Icons.shuffle_rounded,
                size: 22,
                color: shuffleEnabled
                    ? activeAccent
                    : (isDark
                        ? const Color(0xFFB3B3B3)
                        : const Color(0xFF6B6B6B)),
              ),
              onPressed: provider.toggleShuffle,
              tooltip: AppLocalizations.of(context)?.enableShuffle ?? 'Aleatorio',
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.skip_previous_rounded, size: 28),
              onPressed: hasPrevious ? provider.skipPrevious : null,
              color: color,
              disabledColor: disabledColor,
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 32,
                  color: Colors.black,
                ),
                onPressed: provider.togglePlayPause,
                padding: const EdgeInsets.all(8),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.skip_next_rounded, size: 28),
              onPressed: hasNext ? provider.skipNext : null,
              color: color,
              disabledColor: disabledColor,
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                repeatMode == RepeatMode.one
                    ? Icons.repeat_one_rounded
                    : Icons.repeat_rounded,
                size: 22,
                color: repeatMode != RepeatMode.off
                    ? activeAccent
                    : (isDark
                        ? const Color(0xFFB3B3B3)
                        : const Color(0xFF6B6B6B)),
              ),
              onPressed: provider.toggleRepeat,
              tooltip: AppLocalizations.of(context)?.enableRepeat ?? 'Repetir',
            ),
          ],
        );
      },
    );
  }
}

class _ProgressBar extends StatefulWidget {
  const _ProgressBar();

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar> {
  bool _isDragging = false;
  double _dragValue = 0.0;

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '${duration.inMinutes}:$twoDigitSeconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeAccent = theme.colorScheme.primary;
    final timeStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: 11,
      color: isDark ? Colors.grey[400] : Colors.grey[600],
    );

    return Selector<PlayerProvider, (Duration, Duration)>(
      selector: (_, p) => (p.position, p.duration),
      builder: (context, data, _) {
        final (position, duration) = data;
        final provider = context.read<PlayerProvider>();
        final maxMs = duration.inMilliseconds.toDouble();
        final currentMs = _isDragging
            ? _dragValue
            : position.inMilliseconds.toDouble().clamp(0.0, maxMs > 0 ? maxMs : 0.0);
        final displayPos = _isDragging
            ? Duration(milliseconds: _dragValue.round())
            : position;

        return SizedBox(
          width: 400,
          child: Row(
            children: [
              Text(_formatDuration(displayPos), style: timeStyle),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 20,
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 5,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14,
                      ),
                      activeTrackColor: activeAccent,
                      inactiveTrackColor:
                          isDark ? const Color(0xFF3A3A3A) : Colors.grey[300],
                      thumbColor: Colors.white,
                      overlayColor: activeAccent.withValues(
                        alpha: 0.2,
                      ),
                    ),
                    child: Slider(
                      value: maxMs > 0 ? currentMs.clamp(0.0, maxMs) : 0.0,
                      min: 0.0,
                      max: maxMs > 0 ? maxMs : 1.0,
                      onChangeStart: (value) {
                        setState(() {
                          _isDragging = true;
                          _dragValue = value;
                        });
                      },
                      onChanged: maxMs > 0
                          ? (value) {
                              setState(() {
                                _dragValue = value;
                              });
                            }
                          : null,
                      onChangeEnd: (value) {
                        setState(() {
                          _isDragging = false;
                        });
                        provider.seek(Duration(milliseconds: value.round()));
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(_formatDuration(duration), style: timeStyle),
            ],
          ),
        );
      },
    );
  }
}

class _VolumeControl extends StatelessWidget {
  const _VolumeControl();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeAccent = theme.colorScheme.primary;
    
    return Selector<PlayerProvider, double>(
      selector: (_, p) => p.volume,
      builder: (context, volume, _) {
        final isMuted = volume == 0;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final provider = context.read<PlayerProvider>();

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isMuted
                    ? Icons.volume_off_rounded
                    : volume < 0.5
                        ? Icons.volume_down_rounded
                        : Icons.volume_up_rounded,
                size: 20,
              ),
              onPressed: () {
                provider.setVolume(isMuted ? 0.5 : 0.0);
              },
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            SizedBox(
              width: 100,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 5,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
                  activeTrackColor: activeAccent,
                  inactiveTrackColor:
                      isDark ? const Color(0xFF3A3A3A) : Colors.grey[300],
                  thumbColor: Colors.white,
                  overlayColor: activeAccent.withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: volume.clamp(0.0, 1.0),
                  min: 0.0,
                  max: 1.0,
                  onChanged: (value) {
                    provider.setVolume(value);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
