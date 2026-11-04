import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/song.dart';
import '../../models/lyric_line.dart';
import '../../theme/app_theme.dart';
import '../album_artwork.dart';

enum ShareCardFormat { story, square }

class ShareLyricsSheet extends StatefulWidget {
  final Song song;
  final ImageProvider? imageProvider;
  final List<LyricLine> lyrics;
  final int initialSelectedIndex;

  const ShareLyricsSheet({
    super.key,
    required this.song,
    this.imageProvider,
    required this.lyrics,
    this.initialSelectedIndex = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required Song song,
    ImageProvider? imageProvider,
    required List<LyricLine> lyrics,
    int initialSelectedIndex = 0,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ShareLyricsSheet(
        song: song,
        imageProvider: imageProvider,
        lyrics: lyrics,
        initialSelectedIndex: initialSelectedIndex,
      ),
    );
  }

  @override
  State<ShareLyricsSheet> createState() => _ShareLyricsSheetState();
}

class _ShareLyricsSheetState extends State<ShareLyricsSheet> {
  final GlobalKey _previewKey = GlobalKey();
  final Set<int> _selectedIndices = {};
  ShareCardFormat _cardFormat = ShareCardFormat.story;
  bool _isSharing = false;

  static const int _maxSelection = 5;

  @override
  void initState() {
    super.initState();
    if (widget.lyrics.isNotEmpty) {
      final validIdx = widget.initialSelectedIndex.clamp(0, widget.lyrics.length - 1);
      _selectedIndices.add(validIdx);
    }
  }

  void _toggleIndex(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIndices.contains(index)) {
        if (_selectedIndices.length > 1) {
          _selectedIndices.remove(index);
        }
      } else {
        if (_selectedIndices.length < _maxSelection) {
          _selectedIndices.add(index);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Puedes seleccionar un máximo de 5 líneas'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    });
  }

  Future<void> _shareCard() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final boundary =
          _previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Render boundary not found');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to encode image to PNG');
      }

      final buffer = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final fileName = 'groovy_lyrics_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(buffer);

      if (!mounted) return;
      Navigator.of(context).pop();

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '🎶 "${widget.song.title}" - ${widget.song.artist ?? "Groovy"}\nEscuchando en Groovy Music',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir letra: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sortedIndices = _selectedIndices.toList()..sort();
    final selectedLines = sortedIndices
        .where((i) => i >= 0 && i < widget.lyrics.length)
        .map((i) => widget.lyrics[i])
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Drag handle
            Container(
              width: 38,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 12),

            // Top Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Text(
                    'Compartir letra',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const Spacer(),
                  // Format toggle
                  IconButton(
                    tooltip: _cardFormat == ShareCardFormat.story
                        ? 'Formato: Historia (9:16)'
                        : 'Formato: Cuadrado (1:1)',
                    icon: Icon(
                      _cardFormat == ShareCardFormat.story
                          ? CupertinoIcons.rectangle_grid_1x2
                          : CupertinoIcons.square,
                      color: AppTheme.appleMusicRed,
                    ),
                    onPressed: () {
                      setState(() {
                        _cardFormat = _cardFormat == ShareCardFormat.story
                            ? ShareCardFormat.square
                            : ShareCardFormat.story;
                      });
                    },
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Preview Section
            Expanded(
              flex: 5,
              child: Container(
                color: isDark ? const Color(0xFF0F0F10) : const Color(0xFFF2F2F7),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: RepaintBoundary(
                    key: _previewKey,
                    child: _buildLyricCard(selectedLines),
                  ),
                ),
              ),
            ),

            const Divider(height: 1),

            // Selection Section (Select up to 5 lines)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Selecciona líneas (${_selectedIndices.length}/$_maxSelection)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  Text(
                    _cardFormat == ShareCardFormat.story ? 'Historia 9:16' : 'Cuadrado 1:1',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.appleMusicRed,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              flex: 4,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: widget.lyrics.length,
                itemBuilder: (context, index) {
                  final line = widget.lyrics[index];
                  final isSelected = _selectedIndices.contains(index);

                  return InkWell(
                    onTap: () => _toggleIndex(index),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.appleMusicRed.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.appleMusicRed.withValues(alpha: 0.4)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? CupertinoIcons.checkmark_circle_fill
                                : CupertinoIcons.circle,
                            color: isSelected
                                ? AppTheme.appleMusicRed
                                : (isDark ? Colors.white24 : Colors.black26),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              line.text,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Share CTA Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSharing ? null : _shareCard,
                  icon: _isSharing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(CupertinoIcons.share, color: Colors.white),
                  label: Text(
                    _isSharing ? 'Generando tarjeta...' : 'Compartir tarjeta',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.appleMusicRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLyricCard(List<LyricLine> lines) {
    final isStory = _cardFormat == ShareCardFormat.story;
    final width = 360.0;
    final height = isStory ? 640.0 : 360.0;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2C0B12),
            Color(0xFF13091B),
            Color(0xFF090B14),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Ambient blurred cover effect
          if (widget.imageProvider != null)
            Positioned.fill(
              child: Opacity(
                opacity: 0.28,
                child: Image(
                  image: widget.imageProvider!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.42),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Artwork + Song Info)
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: widget.imageProvider != null
                            ? Image(
                                image: widget.imageProvider!,
                                fit: BoxFit.cover,
                              )
                            : AlbumArtwork(
                                coverArt: widget.song.coverArt,
                                size: 50,
                                borderRadius: 10,
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.song.artist ?? 'Groovy Music',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Lyrics Content
                ...lines.map((l) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Text(
                      l.text,
                      style: TextStyle(
                        fontSize: isStory ? 24 : 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                        height: 1.25,
                      ),
                    ),
                  );
                }),

                const Spacer(),

                // Bottom Branding
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppTheme.appleMusicRed,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.music_note,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Groovy Music',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
