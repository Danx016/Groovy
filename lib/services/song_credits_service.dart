import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/song.dart';

class SongCreditItem {
  final String name;
  final String role;
  final String? imageUrl;
  final String initials;

  SongCreditItem({
    required this.name,
    required this.role,
    this.imageUrl,
    String? initials,
  }) : initials = initials ?? _generateInitials(name);

  static String _generateInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class SongCredits {
  final String title;
  final String artist;
  final String album;
  final String formattedReleaseDate;
  final String? genre;
  final String? artworkUrl;
  final List<SongCreditItem> performers;
  final List<SongCreditItem> writers;
  final List<SongCreditItem> production;
  final String? audioQuality;

  SongCredits({
    required this.title,
    required this.artist,
    required this.album,
    required this.formattedReleaseDate,
    this.genre,
    this.artworkUrl,
    required this.performers,
    required this.writers,
    required this.production,
    this.audioQuality,
  });
}

class SongCreditsService {
  static final Map<String, SongCredits> _cache = {};
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  static Future<SongCredits> getCredits(Song song) async {
    final cacheKey = '${song.id}_${song.title}_${song.artist}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    String formattedDate = '';
    String? genre = song.genre;
    String? itunesArtwork;
    String? composerName;
    String? artistImageUrl;

    // Format local/song year or date
    if (song.year != null && song.year! > 0) {
      formattedDate = '${song.year}';
    } else if (song.created != null) {
      formattedDate = '${song.created!.year}';
    }

    try {
      // 1. Fetch real release date, collection info, artwork, and composer from iTunes Search API
      final searchUrl = 'https://itunes.apple.com/search?term=${Uri.encodeComponent('${song.artist ?? ''} ${song.title}')}&entity=song&limit=1';
      final itunesRes = await _dio.get(searchUrl);
      if (itunesRes.statusCode == 200 && itunesRes.data != null) {
        final Map<String, dynamic> data = itunesRes.data is String
            ? jsonDecode(itunesRes.data as String)
            : (itunesRes.data as Map<String, dynamic>);
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          final first = results.first as Map<String, dynamic>;
          final releaseDateStr = first['releaseDate'] as String?;
          if (releaseDateStr != null) {
            final dt = DateTime.tryParse(releaseDateStr);
            if (dt != null) {
              formattedDate = _formatSpanishDate(dt);
            }
          }
          genre ??= first['primaryGenreName'] as String?;
          final art100 = first['artworkUrl100'] as String?;
          if (art100 != null) {
            itunesArtwork = art100.replaceAll('100x100bb', '600x600bb');
          }
          if (first['composerName'] != null) {
            composerName = first['composerName'] as String?;
          }
        }
      }
    } catch (e) {
      debugPrint('iTunes credits lookup failed: $e');
    }

    // 2. Query Deezer API for artist profile picture and contributors
    try {
      final deezerUrl = 'https://api.deezer.com/search?q=${Uri.encodeComponent('${song.artist ?? ''} ${song.title}')}';
      final deezerRes = await _dio.get(deezerUrl);
      if (deezerRes.statusCode == 200 && deezerRes.data != null) {
        final Map<String, dynamic> data = deezerRes.data is String
            ? jsonDecode(deezerRes.data as String)
            : (deezerRes.data as Map<String, dynamic>);
        final list = data['data'] as List?;
        if (list != null && list.isNotEmpty) {
          final first = list.first as Map<String, dynamic>;
          final artistData = first['artist'] as Map<String, dynamic>?;
          artistImageUrl = artistData?['picture_medium'] as String? ?? artistData?['picture_big'] as String?;
        }
      }
    } catch (e) {
      debugPrint('Deezer credits lookup failed: $e');
    }

    // 3. Build Performers List
    final performers = <SongCreditItem>[];
    final mainArtistName = song.artist ?? 'Artista desconocido';

    performers.add(SongCreditItem(
      name: mainArtistName,
      role: 'Voz principal',
      imageUrl: artistImageUrl,
    ));

    if (song.artistParticipants != null) {
      for (final p in song.artistParticipants!) {
        if (p.name.isNotEmpty && p.name.toLowerCase() != mainArtistName.toLowerCase()) {
          performers.add(SongCreditItem(
            name: p.name,
            role: 'Intérprete asociado',
          ));
        }
      }
    }

    // 4. Build Writers List (Composition & Lyrics)
    final writers = <SongCreditItem>[];
    if (composerName != null && composerName.isNotEmpty) {
      final names = composerName.split(RegExp(r'[,;/]'));
      for (final n in names) {
        final clean = n.trim();
        if (clean.isNotEmpty) {
          writers.add(SongCreditItem(name: clean, role: 'Autoría'));
        }
      }
    }

    // If no composer found via iTunes, check song's artist or participants
    if (writers.isEmpty) {
      writers.add(SongCreditItem(
        name: mainArtistName,
        role: 'Autoría y Composición',
      ));
    }

    // 5. Audio Quality info
    String? audioQuality;
    if (song.bitRate != null && song.bitRate! > 0) {
      final kbps = song.bitRate!;
      final format = (song.suffix ?? song.contentType ?? 'AAC').toUpperCase();
      audioQuality = '$format • $kbps kbps';
    }

    final credits = SongCredits(
      title: song.title,
      artist: mainArtistName,
      album: song.album ?? 'Álbum desconocido',
      formattedReleaseDate: formattedDate.isNotEmpty ? formattedDate : 'Fecha desconocida',
      genre: genre,
      artworkUrl: itunesArtwork,
      performers: performers,
      writers: writers,
      production: [],
      audioQuality: audioQuality,
    );

    _cache[cacheKey] = credits;
    return credits;
  }

  static String _formatSpanishDate(DateTime dt) {
    const months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    return '${dt.day} de ${months[dt.month - 1]} de ${dt.year}';
  }
}
