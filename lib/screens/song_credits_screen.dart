import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/song_credits_service.dart';
import '../services/subsonic_service.dart';

class SongCreditsScreen extends StatefulWidget {
  final Song song;
  final ImageProvider? imageProvider;
  final VoidCallback? onNavigateToLyrics;

  const SongCreditsScreen({
    super.key,
    required this.song,
    this.imageProvider,
    this.onNavigateToLyrics,
  });

  @override
  State<SongCreditsScreen> createState() => _SongCreditsScreenState();
}

class _SongCreditsScreenState extends State<SongCreditsScreen> {
  SongCredits? _credits;
  bool _isLoading = true;

  static const Color _appleRed = Color(0xFFFA2D48);

  @override
  void initState() {
    super.initState();
    _loadCredits();
  }

  Future<void> _loadCredits() async {
    final credits = await SongCreditsService.getCredits(widget.song);
    if (mounted) {
      setState(() {
        _credits = credits;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF7F7F9);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subtitleColor = isDark ? Colors.white60 : Colors.black54;

    final subsonic = Provider.of<SubsonicService>(context, listen: false);
    final coverUrl = widget.song.coverArt != null
        ? subsonic.getCoverArtUrl(widget.song.coverArt, size: 600)
        : null;

    final ImageProvider effectiveImage = widget.imageProvider ??
        (coverUrl != null
            ? CachedNetworkImageProvider(coverUrl)
            : const AssetImage('assets/default_cover.png') as ImageProvider);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.arrow_left, color: _appleRed, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: _appleRed, size: 24),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _appleRed))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),

                  // 1. Large Album Artwork
                  Center(
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.18),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image(
                          image: effectiveImage,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[300],
                            child: const Icon(CupertinoIcons.music_note, size: 64, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // 2. Song Title
                  Text(
                    widget.song.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.4,
                      color: textColor,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // 3. Subtitle (Artist · Album · Release Date)
                  Text(
                    '${_credits?.artist ?? widget.song.artist} · ${_credits?.album ?? widget.song.album ?? ''}${_credits?.formattedReleaseDate.isNotEmpty == true ? ' · ${_credits!.formattedReleaseDate}' : ''}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: subtitleColor,
                      height: 1.35,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 4. "Reproducir" Pill Button
                  Consumer<PlayerProvider>(
                    builder: (context, player, _) {
                      final isPlayingCurrent = player.isPlaying && player.currentSong?.id == widget.song.id;
                      return Center(
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            if (player.currentSong?.id == widget.song.id) {
                              player.togglePlayPause();
                            } else {
                              player.playSong(widget.song);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF0F0F4),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isPlayingCurrent ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                                  color: _appleRed,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isPlayingCurrent ? 'Pausar' : 'Reproducir',
                                  style: const TextStyle(
                                    color: _appleRed,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // 5. "Ver letra" Card
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      if (widget.onNavigateToLyrics != null) {
                        widget.onNavigateToLyrics!();
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            CupertinoIcons.quote_bubble_fill,
                            color: _appleRed,
                            size: 24,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Ver letra',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: subtitleColor,
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // 6. ARTISTAS INTÉRPRETES Section
                  if (_credits?.performers.isNotEmpty == true) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'ARTISTAS INTÉRPRETES',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: subtitleColor,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _credits!.performers.length,
                        separatorBuilder: (_, __) => Divider(
                          indent: 68,
                          height: 1,
                          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                        ),
                        itemBuilder: (context, idx) {
                          final p = _credits!.performers[idx];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                // Round artist avatar
                                ClipOval(
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    color: isDark ? const Color(0xFF333336) : const Color(0xFFE5E5EA),
                                    child: p.imageUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl: p.imageUrl!,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) => _buildInitialsAvatar(p.initials),
                                          )
                                        : _buildInitialsAvatar(p.initials),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        p.role,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: subtitleColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 7. COMPOSICIÓN Y LETRA Section
                  if (_credits?.writers.isNotEmpty == true) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'COMPOSICIÓN Y LETRA',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: subtitleColor,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _credits!.writers.length,
                        separatorBuilder: (_, __) => Divider(
                          indent: 68,
                          height: 1,
                          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                        ),
                        itemBuilder: (context, idx) {
                          final w = _credits!.writers[idx];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                // Monogram / Initials circle
                                ClipOval(
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    color: const Color(0xFF8E8E93),
                                    child: Center(
                                      child: Text(
                                        w.initials,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        w.name,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        w.role,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: subtitleColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 8. AUDIO / CALIDAD Section (if available)
                  if (_credits?.audioQuality != null) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'CALIDAD DE AUDIO',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: subtitleColor,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _credits!.audioQuality!,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildInitialsAvatar(String initials) {
    return Container(
      color: const Color(0xFF636366),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
