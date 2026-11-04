import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import '../models/models.dart';
import '../providers/library_provider.dart';
import 'youtube_service.dart';

class ImportedTrack {
  final String title;
  final String artist;
  final String? album;

  const ImportedTrack({
    required this.title,
    required this.artist,
    this.album,
  });

  String get searchQuery => '$title $artist'.trim();
}

class ImportedPlaylistResult {
  final String name;
  final List<ImportedTrack> tracks;
  final String source;

  const ImportedPlaylistResult({
    required this.name,
    required this.tracks,
    required this.source,
  });
}

class ImportProgress {
  final int current;
  final int total;
  final String currentTrackName;
  final bool isDone;
  final String? playlistId;

  const ImportProgress({
    required this.current,
    required this.total,
    required this.currentTrackName,
    this.isDone = false,
    this.playlistId,
  });

  double get percent => total == 0 ? 0.0 : (current / total).clamp(0.0, 1.0);
}

class PlaylistImporterService {
  static final PlaylistImporterService _instance = PlaylistImporterService._internal();
  factory PlaylistImporterService() => _instance;
  PlaylistImporterService._internal();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
    ),
  );

  /// Parse a playlist from a web link (Spotify or YouTube)
  Future<ImportedPlaylistResult> parseUrl(String rawUrl) async {
    final cleanUrl = rawUrl.trim();

    // 1. Spotify Playlist
    if (cleanUrl.contains('spotify.com') || cleanUrl.contains('spotify.link')) {
      return await _parseSpotifyPlaylist(cleanUrl);
    }

    // 2. YouTube / YouTube Music Playlist
    if (cleanUrl.contains('youtube.com') || cleanUrl.contains('youtu.be')) {
      return await _parseYouTubePlaylist(cleanUrl);
    }

    throw Exception('Enlace no reconocido. Pega un enlace de Spotify o YouTube.');
  }

  Future<ImportedPlaylistResult> _parseSpotifyPlaylist(String url) async {
    String? playlistId;
    final idMatch = RegExp(r'playlist[/:]([a-zA-Z0-9]+)').firstMatch(url);
    if (idMatch != null) {
      playlistId = idMatch.group(1);
    }

    if (playlistId == null || playlistId.isEmpty) {
      throw Exception('No se pudo extraer el ID de la playlist de Spotify.');
    }

    final embedUrl = 'https://open.spotify.com/embed/playlist/$playlistId';
    final response = await _dio.get(embedUrl);
    final html = response.data.toString();

    final nextDataMatch = RegExp(r'id="__NEXT_DATA__"[^>]*>(.*?)</script>', dotAll: true).firstMatch(html);
    if (nextDataMatch == null) {
      throw Exception('No se pudo acceder a los datos públicos de la playlist de Spotify.');
    }

    final jsonData = jsonDecode(nextDataMatch.group(1)!);
    final entity = jsonData['props']?['pageProps']?['state']?['data']?['entity'];
    if (entity == null) {
      throw Exception('Estructura de playlist no encontrada en Spotify.');
    }

    final playlistName = entity['name']?.toString() ?? 'Playlist de Spotify';
    final rawTrackList = entity['trackList'] as List? ?? [];

    final tracks = <ImportedTrack>[];
    for (final item in rawTrackList) {
      final title = item['title']?.toString().trim() ?? '';
      final artist = item['subtitle']?.toString().trim() ?? '';
      if (title.isNotEmpty) {
        tracks.add(ImportedTrack(title: title, artist: artist));
      }
    }

    if (tracks.isEmpty) {
      throw Exception('La playlist de Spotify parece estar vacía o es privada.');
    }

    return ImportedPlaylistResult(
      name: playlistName,
      tracks: tracks,
      source: 'Spotify',
    );
  }

  Future<ImportedPlaylistResult> _parseYouTubePlaylist(String url) async {
    final idMatch = RegExp(r'[?&]list=([a-zA-Z0-9_-]+)').firstMatch(url);
    final playlistId = idMatch?.group(1);
    if (playlistId == null) {
      throw Exception('No se encontró el parámetro "list=" en el enlace de YouTube.');
    }

    final ytExplode = yt.YoutubeExplode();
    try {
      final ytPlaylist = await ytExplode.playlists.get(playlistId);
      final tracks = <ImportedTrack>[];

      await for (final video in ytExplode.playlists.getVideos(playlistId)) {
        // Clean artist/title if title has "-"
        String title = video.title;
        String artist = video.author;
        if (title.contains(' - ')) {
          final parts = title.split(' - ');
          artist = parts[0].trim();
          title = parts.sublist(1).join(' - ').trim();
        }

        tracks.add(ImportedTrack(
          title: title,
          artist: artist,
        ));
      }

      return ImportedPlaylistResult(
        name: ytPlaylist.title,
        tracks: tracks,
        source: 'YouTube',
      );
    } finally {
      ytExplode.close();
    }
  }

  /// Parse M3U / M3U8 or CSV file
  Future<ImportedPlaylistResult> parseFile(File file) async {
    final lines = await file.readAsLines();
    final fileName = file.uri.pathSegments.last.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
    final tracks = <ImportedTrack>[];

    final isCsv = file.path.toLowerCase().endsWith('.csv');

    if (isCsv) {
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final parts = line.split(',');
        if (parts.length >= 2) {
          final t = parts[0].replaceAll('"', '').trim();
          final a = parts[1].replaceAll('"', '').trim();
          // Skip header row if present
          if (i == 0 && (t.toLowerCase() == 'title' || t.toLowerCase() == 'track')) continue;
          if (t.isNotEmpty) {
            tracks.add(ImportedTrack(title: t, artist: a));
          }
        }
      }
    } else {
      // M3U / M3U8 parser
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('#EXTINF:')) {
          // #EXTINF:123,Artist - Title
          final commaIdx = trimmed.indexOf(',');
          if (commaIdx != -1) {
            final info = trimmed.substring(commaIdx + 1).trim();
            if (info.contains(' - ')) {
              final split = info.split(' - ');
              tracks.add(ImportedTrack(
                artist: split[0].trim(),
                title: split.sublist(1).join(' - ').trim(),
              ));
            } else {
              tracks.add(ImportedTrack(title: info, artist: ''));
            }
          }
        } else if (!trimmed.startsWith('#') && trimmed.isNotEmpty) {
          // Fallback simple line
          if (trimmed.contains(' - ')) {
            final split = trimmed.split(' - ');
            tracks.add(ImportedTrack(
              artist: split[0].trim(),
              title: split.sublist(1).join(' - ').trim(),
            ));
          }
        }
      }
    }

    if (tracks.isEmpty) {
      throw Exception('No se detectaron pistas válidas en el archivo seleccionado.');
    }

    return ImportedPlaylistResult(
      name: fileName,
      tracks: tracks,
      source: isCsv ? 'CSV' : 'M3U',
    );
  }

  /// Parse plain raw text with one track per line (e.g. "Artista - Título")
  ImportedPlaylistResult parseRawText(String text, String playlistName) {
    final lines = text.split('\n');
    final tracks = <ImportedTrack>[];

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.contains(' - ')) {
        final parts = line.split(' - ');
        tracks.add(ImportedTrack(
          artist: parts[0].trim(),
          title: parts.sublist(1).join(' - ').trim(),
        ));
      } else {
        tracks.add(ImportedTrack(title: line, artist: ''));
      }
    }

    return ImportedPlaylistResult(
      name: playlistName.trim().isNotEmpty ? playlistName.trim() : 'Playlist Importada',
      tracks: tracks,
      source: 'Texto',
    );
  }

  /// Searches and matches all tracks in the library/YouTube and creates the playlist
  Stream<ImportProgress> importPlaylistStream({
    required ImportedPlaylistResult importedPlaylist,
    required LibraryProvider libraryProvider,
    required YoutubeService youtubeService,
  }) async* {
    final total = importedPlaylist.tracks.length;
    final matchedSongIds = <String>[];

    // Create the playlist in Groovy first
    await libraryProvider.createPlaylist(importedPlaylist.name);
    await libraryProvider.loadPlaylists();
    final createdPlaylist = libraryProvider.playlists.firstWhere(
      (p) => p.name == importedPlaylist.name,
      orElse: () => libraryProvider.playlists.first,
    );

    for (int i = 0; i < total; i++) {
      final track = importedPlaylist.tracks[i];
      yield ImportProgress(
        current: i + 1,
        total: total,
        currentTrackName: '${track.title} - ${track.artist}',
      );

      try {
        // 1. Search in local library cache first for instant match
        final localMatch = libraryProvider.cachedAllSongs.firstWhere(
          (s) =>
              s.title.toLowerCase().contains(track.title.toLowerCase()) &&
              (track.artist.isEmpty || (s.artist?.toLowerCase().contains(track.artist.toLowerCase()) ?? false)),
          orElse: () => Song(id: '', title: ''),
        );

        if (localMatch.id.isNotEmpty) {
          matchedSongIds.add(localMatch.id);
          await libraryProvider.addSongToPlaylist(createdPlaylist.id, localMatch.id);
          continue;
        }

        // 2. Search online via YouTube Service
        final searchResults = await youtubeService.search(track.searchQuery);
        final candidates = [
          ...searchResults.songs,
          if (searchResults.youtubeVideos != null) ...searchResults.youtubeVideos!,
        ];
        if (candidates.isNotEmpty) {
          final topHit = candidates.first;
          matchedSongIds.add(topHit.id);
          await libraryProvider.addSongToPlaylist(createdPlaylist.id, topHit.id);
        }
      } catch (_) {}

      // Gentle pause to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 100));
    }

    await libraryProvider.loadPlaylists();

    yield ImportProgress(
      current: total,
      total: total,
      currentTrackName: '¡Completado!',
      isDone: true,
      playlistId: createdPlaylist.id,
    );
  }
}
