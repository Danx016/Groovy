import 'package:flutter/cupertino.dart' hide RepeatMode;
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:provider/provider.dart';
import '../../models/song.dart';
import '../../providers/player_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/subsonic_service.dart';

class QueueView extends StatelessWidget {
  const QueueView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, provider, child) {
        final queue = provider.queue;
        final currentIndex = provider.currentIndex;
        final currentSong = provider.currentSong;
        final subsonic = Provider.of<SubsonicService>(context, listen: false);

        if (queue.isEmpty) {
          return const Center(
            child: Text(
              "No hay canciones en la cola",
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          children: [
            // 1. Current Song Mini Card (Apple Music header)
            if (currentSong != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: currentSong.coverArt != null
                          ? CachedNetworkImage(
                              imageUrl: subsonic.getCoverArtUrl(currentSong.coverArt, size: 100),
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(color: Colors.white12),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.white12,
                                child: const Icon(Icons.music_note, color: Colors.white70),
                              ),
                            )
                          : Container(
                              width: 48,
                              height: 48,
                              color: Colors.white12,
                              child: const Icon(Icons.music_note, color: Colors.white70),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentSong.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentSong.artist ?? 'Artista desconocido',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.graphic_eq_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ],
                ),
              ),

            // 2. Action Chips (Shuffle, Repeat, Autoplay)
            Row(
              children: [
                Expanded(
                  child: _AppleMusicQueueChip(
                    icon: CupertinoIcons.shuffle,
                    label: 'Aleatorio',
                    isActive: provider.shuffleEnabled,
                    onTap: () => provider.toggleShuffle(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AppleMusicQueueChip(
                    icon: CupertinoIcons.repeat,
                    label: 'Repetir',
                    isActive: provider.repeatMode != RepeatMode.off,
                    onTap: () => provider.toggleRepeat(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AppleMusicQueueChip(
                    icon: CupertinoIcons.infinite,
                    label: 'Automático',
                    isActive: false,
                    onTap: () {},
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 3. Section Title: "A continuación"
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
              child: Text(
                "A continuación",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
            ),

            // 4. Songs List
            ...List.generate(queue.length, (index) {
              final song = queue[index];
              final isPlaying = index == currentIndex;
              final isPast = index < currentIndex;

              final coverUrl = song.coverArt != null
                  ? subsonic.getCoverArtUrl(song.coverArt, size: 100)
                  : null;

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: isPlaying ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: coverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: coverUrl,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: Colors.white12),
                            errorWidget: (context, url, error) => Container(
                              width: 44,
                              height: 44,
                              color: Colors.white12,
                              child: const Icon(Icons.music_note, color: Colors.white54, size: 20),
                            ),
                          )
                        : Container(
                            width: 44,
                            height: 44,
                            color: Colors.white12,
                            child: const Icon(Icons.music_note, color: Colors.white54, size: 20),
                          ),
                  ),
                  title: Text(
                    song.title,
                    style: TextStyle(
                      color: isPast ? Colors.white38 : Colors.white,
                      fontWeight: isPlaying ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    song.artist ?? 'Artista desconocido',
                    style: TextStyle(
                      color: isPast ? Colors.white24 : Colors.white60,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: isPlaying
                      ? const Icon(Icons.equalizer_rounded, color: Colors.white, size: 20)
                      : Icon(
                          Icons.drag_handle_rounded,
                          color: Colors.white.withValues(alpha: 0.25),
                          size: 20,
                        ),
                  onTap: () {
                    provider.skipToIndex(index);
                  },
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _AppleMusicQueueChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _AppleMusicQueueChip({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive 
              ? Colors.white.withValues(alpha: 0.28) 
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive 
                ? Colors.white.withValues(alpha: 0.4) 
                : Colors.white.withValues(alpha: 0.08),
            width: 0.8,
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            color: isActive ? Colors.white : Colors.white70,
            size: 20,
          ),
        ),
      ),
    );
  }
}
