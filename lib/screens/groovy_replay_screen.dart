import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../services/recommendation_service.dart';
import '../theme/app_theme.dart';
import '../widgets/album_artwork.dart';

class GroovyReplayScreen extends StatefulWidget {
  const GroovyReplayScreen({super.key});

  @override
  State<GroovyReplayScreen> createState() => _GroovyReplayScreenState();
}

class _GroovyReplayScreenState extends State<GroovyReplayScreen> {
  final GlobalKey _shareCardKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _shareReplayCard(String topArtist, String topSong, int totalMinutes) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final boundary =
          _shareCardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final buffer = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/groovy_replay_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(buffer);

      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '🎧 ¡Mi resumen en Groovy Music!\n'
              '⏱️ $totalMinutes minutos de música\n'
              '👑 Artista Top: $topArtist\n'
              '🎵 Canción Top: $topSong\n'
              '#GroovyReplay #Music',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir Replay: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final rec = Provider.of<RecommendationService>(context);
    final lib = Provider.of<LibraryProvider>(context);
    final player = Provider.of<PlayerProvider>(context);

    // Calculate Stats
    final profiles = rec.profiles;
    int totalMinutes = 0;
    for (final p in profiles.values) {
      totalMinutes += (p.playCount * 3.5).round();
    }
    if (totalMinutes == 0 && player.playbackHistory.isNotEmpty) {
      totalMinutes = player.playbackHistory.length * 3;
    }

    // Top Songs
    final sortedProfiles = profiles.entries.toList()
      ..sort((a, b) => b.value.playCount.compareTo(a.value.playCount));

    final topSongs = <Song>[];
    for (final entry in sortedProfiles.take(5)) {
      final cached = lib.songsByIdMap[entry.key];
      if (cached != null) {
        topSongs.add(cached);
      }
    }
    if (topSongs.isEmpty && player.playbackHistory.isNotEmpty) {
      topSongs.addAll(player.playbackHistory.take(5));
    }

    // Top Artists
    final topArtists = rec.getTopArtists(5);
    final topArtist = topArtists.isNotEmpty ? topArtists.first : 'Groovy Explorer';
    final topSongTitle = topSongs.isNotEmpty ? topSongs.first.title : 'Tu música favorita';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0A10) : const Color(0xFFF6F6F9),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 140,
            backgroundColor: isDark ? const Color(0xFF0C0A10) : Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
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
            actions: [
              IconButton(
                tooltip: 'Compartir Replay',
                icon: _isSharing
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.appleMusicRed),
                      )
                    : Icon(CupertinoIcons.share, color: AppTheme.appleMusicRed),
                onPressed: () => _shareReplayCard(topArtist, topSongTitle, totalMinutes),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFA2D48), Color(0xFFAF52DE)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'REPLAY',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Tu Resumen',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),

                  // 1. Hero Shareable Card
                  RepaintBoundary(
                    key: _shareCardKey,
                    child: _buildHeroCard(
                      totalMinutes: totalMinutes,
                      topArtist: topArtist,
                      topSong: topSongTitle,
                      topSongCover: topSongs.isNotEmpty ? topSongs.first.coverArt : null,
                      isDark: isDark,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // 2. Metrics Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatBadge(
                          title: 'Minutos',
                          value: '$totalMinutes',
                          subtitle: 'Escuchados en total',
                          icon: CupertinoIcons.stopwatch_fill,
                          color: const Color(0xFFFA2D48),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildStatBadge(
                          title: 'Artistas',
                          value: '${topArtists.length}',
                          subtitle: 'En rotación frecuente',
                          icon: CupertinoIcons.person_2_fill,
                          color: const Color(0xFF5856D6),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // 3. Top Canciones
                  Text(
                    'TUS CANCIONES TOP',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (topSongs.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text('Continúa escuchando canciones para generar tu top'),
                      ),
                    )
                  else
                    ...topSongs.asMap().entries.map((entry) {
                      final rank = entry.key + 1;
                      final song = entry.value;
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF19181D) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.04),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 24,
                                child: Text(
                                  '$rank',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: rank == 1 ? AppTheme.appleMusicRed : (isDark ? Colors.white54 : Colors.black45),
                                  ),
                                ),
                              ),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: AlbumArtwork(
                                  coverArt: song.coverArt,
                                  size: 46,
                                  borderRadius: 8,
                                ),
                              ),
                            ],
                          ),
                          title: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            song.artist ?? 'Groovy',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                          ),
                          trailing: Icon(
                            CupertinoIcons.play_circle_fill,
                            color: AppTheme.appleMusicRed.withValues(alpha: 0.8),
                            size: 28,
                          ),
                          onTap: () {
                            player.playSong(song);
                          },
                        ),
                      );
                    }),

                  const SizedBox(height: 28),

                  // 4. Top Artistas
                  Text(
                    'TUS ARTISTAS TOP',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (topArtists.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text('Tus artistas más escuchados aparecerán aquí'),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: topArtists.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final name = entry.value;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: idx == 0
                                  ? AppTheme.appleMusicRed.withValues(alpha: 0.5)
                                  : (isDark ? Colors.white12 : Colors.black12),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '#${idx + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: idx == 0 ? AppTheme.appleMusicRed : Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard({
    required int totalMinutes,
    required String topArtist,
    required String topSong,
    required String? topSongCover,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFA2D48),
            Color(0xFF9B113B),
            Color(0xFF380826),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFA2D48).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'GROOVY REPLAY',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: Colors.white70,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${DateTime.now().year}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Tu artista número uno',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            topArtist,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.8,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (topSongCover != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AlbumArtwork(coverArt: topSongCover, size: 44, borderRadius: 8),
                ),
              if (topSongCover != null) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Canción preferida:',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    Text(
                      topSong,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF19181D) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
