import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/library_provider.dart';
import '../theme/app_theme.dart';

class PlaylistCoverDesignerSheet extends StatelessWidget {
  final Playlist playlist;

  const PlaylistCoverDesignerSheet({super.key, required this.playlist});

  static Future<void> show(BuildContext context, Playlist playlist) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PlaylistCoverDesignerSheet(playlist: playlist),
    );
  }

  static final List<List<Color>> presetGradients = [
    [const Color(0xFFFA2D48), const Color(0xFF5856D6)],
    [const Color(0xFFFF5E3A), const Color(0xFFFF2A68)],
    [const Color(0xFF34C759), const Color(0xFF007AFF)],
    [const Color(0xFF5856D6), const Color(0xFFAF52DE)],
    [const Color(0xFFFF9500), const Color(0xFFFF2D55)],
    [const Color(0xFF1D2671), const Color(0xFFC33764)],
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final library = Provider.of<LibraryProvider>(context, listen: false);

    final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Personalizar portada de la lista',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Elige un diseño visual o estilo de mosaico para "${playlist.name}"',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 20),

              // Option 1: Auto Mosaic
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.appleMusicRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(CupertinoIcons.square_grid_2x2_fill, color: AppTheme.appleMusicRed),
                ),
                title: const Text('Mosaico automático 2×2', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Combina las carátulas de las canciones añadidas'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await library.updatePlaylistCover(
                    playlist.id,
                    '',
                  );
                },
              ),
              const Divider(height: 24),

              Text(
                'Estilos de gradientes',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 12),

              // Gradient picker row
              SizedBox(
                height: 58,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: presetGradients.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, idx) {
                    final colors = presetGradients[idx];
                    return GestureDetector(
                      onTap: () async {
                        Navigator.of(context).pop();
                        await library.updatePlaylistCover(
                          playlist.id,
                          'gradient:$idx',
                        );
                      },
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: colors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.first.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(CupertinoIcons.music_note, color: Colors.white, size: 22),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
