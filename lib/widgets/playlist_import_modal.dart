import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../screens/playlist_screen.dart';
import '../services/playlist_importer_service.dart';
import '../services/youtube_service.dart';
import '../theme/app_theme.dart';
import '../utils/navigation_helper.dart';

class PlaylistImportModal extends StatefulWidget {
  const PlaylistImportModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PlaylistImportModal(),
    );
  }

  @override
  State<PlaylistImportModal> createState() => _PlaylistImportModalState();
}

class _PlaylistImportModalState extends State<PlaylistImportModal> {
  final _importer = PlaylistImporterService();
  final _urlController = TextEditingController();
  final _textController = TextEditingController();
  final _nameController = TextEditingController(text: 'Mi Playlist Importada');

  int _selectedTabIndex = 0; // 0: Enlace, 1: Archivo, 2: Texto
  bool _isLoading = false;
  ImportedPlaylistResult? _parsedResult;
  ImportProgress? _importProgress;

  @override
  void dispose() {
    _urlController.dispose();
    _textController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _processUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final res = await _importer.parseUrl(url);
      setState(() {
        _parsedResult = res;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['m3u', 'm3u8', 'csv', 'txt'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _isLoading = true);
        final file = File(result.files.single.path!);
        final res = await _importer.parseFile(file);
        setState(() {
          _parsedResult = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al leer archivo: $e')),
        );
      }
    }
  }

  void _processRawText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final name = _nameController.text.trim();
    final res = _importer.parseRawText(text, name);
    setState(() {
      _parsedResult = res;
    });
  }

  void _startImport() {
    if (_parsedResult == null) return;

    final lib = Provider.of<LibraryProvider>(context, listen: false);
    final ytService = Provider.of<YoutubeService>(context, listen: false);

    _importer
        .importPlaylistStream(
          importedPlaylist: _parsedResult!,
          libraryProvider: lib,
          youtubeService: ytService,
        )
        .listen((progress) {
      if (mounted) {
        setState(() {
          _importProgress = progress;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subtitleColor = isDark ? Colors.white60 : Colors.black54;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
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

              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.appleMusicRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      CupertinoIcons.square_arrow_down_fill,
                      color: AppTheme.appleMusicRed,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Importador de Playlists',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Progress View during import
              if (_importProgress != null)
                Expanded(child: _buildProgressView(isDark, textColor, subtitleColor))
              // Preview parsed result view
              else if (_parsedResult != null)
                Expanded(child: _buildPreviewView(isDark, textColor, subtitleColor))
              // Input Selector View
              else
                Expanded(child: _buildInputView(isDark, textColor, subtitleColor)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputView(bool isDark, Color textColor, Color subtitleColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tabs
        CupertinoSlidingSegmentedControl<int>(
          groupValue: _selectedTabIndex,
          children: const {
            0: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Enlace Web')),
            1: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Archivo M3U/CSV')),
            2: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Texto')),
          },
          onValueChanged: (val) {
            if (val != null) setState(() => _selectedTabIndex = val);
          },
        ),
        const SizedBox(height: 20),

        if (_selectedTabIndex == 0) ...[
          Text(
            'Pega un enlace de playlist de Spotify o YouTube:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              hintText: 'https://open.spotify.com/playlist/...',
              prefixIcon: const Icon(CupertinoIcons.link),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.appleMusicRed,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isLoading ? null : _processUrl,
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Analizar y Cargar Playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ] else if (_selectedTabIndex == 1) ...[
          Text(
            'Importa desde un archivo local (.m3u, .m3u8 o .csv):',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(CupertinoIcons.folder_badge_plus, size: 24),
              label: const Text('Seleccionar archivo de playlist', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _isLoading ? null : _pickFile,
            ),
          ),
        ] else ...[
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Nombre de la lista',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: _textController,
              maxLines: null,
              expands: true,
              decoration: InputDecoration(
                hintText: 'Pega una lista de canciones (una por línea):\nArtista 1 - Canción 1\nArtista 2 - Canción 2',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.appleMusicRed,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _processRawText,
              child: const Text('Continuar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPreviewView(bool isDark, Color textColor, Color subtitleColor) {
    final res = _parsedResult!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF252528) : Colors.grey[100],
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.appleMusicRed.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(CupertinoIcons.music_albums, color: AppTheme.appleMusicRed),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      res.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${res.tracks.length} canciones encontradas • Fuente: ${res.source}',
                      style: TextStyle(fontSize: 13, color: subtitleColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'VISTA PREVIA DE PISTAS',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: subtitleColor),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: ListView.builder(
            itemCount: res.tracks.length,
            itemBuilder: (context, idx) {
              final t = res.tracks[idx];
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Text('#${idx + 1}', style: TextStyle(color: subtitleColor, fontWeight: FontWeight.bold)),
                title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
              );
            },
          ),
        ),

        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _parsedResult = null),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.appleMusicRed,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(CupertinoIcons.cloud_download, color: Colors.white),
                label: const Text('Importar a Groovy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: _startImport,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressView(bool isDark, Color textColor, Color subtitleColor) {
    final p = _importProgress!;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (p.isDone) ...[
          const Icon(CupertinoIcons.checkmark_circle_fill, color: Color(0xFF34C759), size: 70),
          const SizedBox(height: 18),
          const Text(
            '¡Playlist Importada con Éxito!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Se importaron ${p.total} temas a tu biblioteca',
            style: TextStyle(color: subtitleColor),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.appleMusicRed,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(CupertinoIcons.play_fill, color: Colors.white),
              label: const Text('Abrir Playlist Ahora', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).pop();
                if (p.playlistId != null) {
                  final targetCtx = NavigationHelper.navigatorKey.currentContext ?? context;
                  NavigationHelper.push(
                    targetCtx,
                    PlaylistScreen(playlistId: p.playlistId!, playlistName: _parsedResult?.name),
                  );
                }
              },
            ),
          ),
        ] else ...[
          const SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 24),
          Text(
            'Importando canción ${p.current} de ${p.total}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            p.currentTrackName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: subtitleColor),
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: p.percent,
              minHeight: 8,
              backgroundColor: isDark ? Colors.white12 : Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.appleMusicRed),
            ),
          ),
        ],
      ],
    );
  }
}
