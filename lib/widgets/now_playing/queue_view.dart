import 'package:flutter/cupertino.dart' hide RepeatMode;
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/youtube_service.dart';
import '../../models/song.dart';

class QueueView extends StatelessWidget {
  const QueueView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, provider, child) {
        final queue = provider.queue;
        final currentIndex = provider.currentIndex;
        final youtubeService = Provider.of<YoutubeService>(context, listen: false);

        if (queue.isEmpty) {
          return const Center(
            child: Text(
              "No hay canciones en la cola",
              style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w600),
            ),
          );
        }

        // Split into upcoming songs (from currentIndex + 1 onwards)
        final upcomingSongs = (currentIndex >= 0 && currentIndex < queue.length - 1)
            ? queue.sublist(currentIndex + 1)
            : <Song>[];

        return CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Action Pills: [ Shuffle ] [ Repeat ] [ Infinity ] (1:1 Apple Music video)
                    Row(
                      children: [
                        Expanded(
                          child: _AppleMusicQueuePill(
                            icon: CupertinoIcons.shuffle,
                            isActive: provider.shuffleEnabled,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              provider.toggleShuffle();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _AppleMusicQueuePill(
                            icon: provider.repeatMode == RepeatMode.one
                                ? CupertinoIcons.repeat_1
                                : CupertinoIcons.repeat,
                            isActive: provider.repeatMode != RepeatMode.off,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              provider.toggleRepeat();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _AppleMusicQueuePill(
                            icon: CupertinoIcons.infinite,
                            isActive: false,
                            onTap: () {
                              HapticFeedback.lightImpact();
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // 2. Section Header: "A continuación" / "Seguir reproduciendo"
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "A continuación",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                          ),
                        ),
                        if (upcomingSongs.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              provider.clearUpcomingQueue();
                            },
                            child: Text(
                              "Borrar",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.70),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Reproducir música de la lista de reproducción",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),

            // 3. Queue Track List
            if (upcomingSongs.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                  child: Center(
                    child: Text(
                      "Fin de la cola de reproducción",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 120),
                sliver: SliverReorderableList(
                  itemCount: upcomingSongs.length,
                  onReorder: (oldIndex, newIndex) {
                    final actualOldIndex = currentIndex + 1 + oldIndex;
                    var actualNewIndex = currentIndex + 1 + newIndex;
                    if (actualOldIndex < actualNewIndex) {
                      actualNewIndex -= 1;
                    }
                    provider.reorderQueue(actualOldIndex, actualNewIndex);
                  },
                  itemBuilder: (context, index) {
                    final song = upcomingSongs[index];
                    final queueIndex = currentIndex + 1 + index;

                    return ReorderableDelayedDragStartListener(
                      key: ValueKey('queue_${song.id}_$queueIndex'),
                      index: index,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              provider.skipToIndex(queueIndex);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6.0),
                              child: Row(
                                children: [
                                  // Album Artwork Thumbnail
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: song.coverArt != null
                                        ? CachedNetworkImage(
                                            imageUrl: youtubeService.getCoverArtUrl(song.coverArt, size: 120),
                                            memCacheWidth: 120,
                                            memCacheHeight: 120,
                                            width: 46,
                                            height: 46,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => Container(
                                              width: 46,
                                              height: 46,
                                              color: Colors.white.withValues(alpha: 0.12),
                                            ),
                                            errorWidget: (context, url, error) => Container(
                                              width: 46,
                                              height: 46,
                                              color: Colors.white.withValues(alpha: 0.12),
                                              child: const Icon(Icons.music_note, color: Colors.white70),
                                            ),
                                          )
                                        : Container(
                                            width: 46,
                                            height: 46,
                                            color: Colors.white.withValues(alpha: 0.12),
                                            child: const Icon(Icons.music_note, color: Colors.white70),
                                          ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Song Title & Artist
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          song.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: -0.2,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          song.artist ?? 'Artista desconocido',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.60),
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w400,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),

                                  // 3 Horizontal drag handle lines
                                  Padding(
                                    padding: const EdgeInsets.only(left: 10.0, right: 4.0),
                                    child: Icon(
                                      Icons.menu_rounded,
                                      color: Colors.white.withValues(alpha: 0.38),
                                      size: 22,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AppleMusicQueuePill extends StatefulWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _AppleMusicQueuePill({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_AppleMusicQueuePill> createState() => _AppleMusicQueuePillState();
}

class _AppleMusicQueuePillState extends State<_AppleMusicQueuePill> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: _isPressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: 46,
          decoration: BoxDecoration(
            color: widget.isActive
                ? const Color(0xFFF3E5D8)
                : Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(23),
          ),
          child: Center(
            child: Icon(
              widget.icon,
              size: 22,
              color: widget.isActive ? const Color(0xFF2A1C12) : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
