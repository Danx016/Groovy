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
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 6),
    headers: {
      'User-Agent': 'GroovyMusicApp/1.0.0 (https://github.com/groovy)',
    },
  ));

  static String cleanSongTitle(String title) {
    var clean = title;
    // 1. Remove bracketed text like (Official Video), [2011 Remaster], (feat. ...), etc.
    clean = clean.replaceAll(
      RegExp(
        r'\s*[\(\[][^\)\]]*(official|video|audio|remaster|live|vivo|version|feat\.|ft\.|lyric)[^\)\]]*[\)\]]',
        caseSensitive: false,
      ),
      '',
    );
    // 2. Remove unbracketed "feat. ..." or "ft. ..." at the end
    clean = clean.replaceAll(RegExp(r'\s+(feat\.|ft\.|featuring)\s+.*$', caseSensitive: false), '');
    // 3. Remove "Artist - " prefix if present
    if (clean.contains(' - ')) {
      final parts = clean.split(' - ');
      if (parts.length >= 2) {
        clean = parts.sublist(1).join(' - ');
      }
    }
    // 4. Remove leftover extra parentheses/brackets and quotes
    clean = clean.replaceAll(RegExp(r'["\\]'), '').trim();
    return clean.isNotEmpty ? clean : title;
  }

  static String cleanArtistName(String? artist) {
    if (artist == null || artist.isEmpty) return '';
    var clean = artist;
    clean = clean.replaceAll(RegExp(r'\s+(feat\.|ft\.|featuring).*$', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'\s*-\s*Topic', caseSensitive: false), '');
    return clean.trim();
  }

  static Future<SongCredits> getCredits(Song song) async {
    final cacheKey = '${song.id}_${song.title}_${song.artist}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final cleanTitle = cleanSongTitle(song.title);
    final cleanArtist = cleanArtistName(song.artist);

    String formattedDate = '';
    String? genre = song.genre;
    String? itunesArtwork;
    String? composerName;
    String? artistImageUrl;
    String? isrc;

    final writersMap = <String, Set<String>>{};
    final productionMap = <String, Set<String>>{};
    final performersMap = <String, String>{};

    void addWriter(String name, String role) {
      final clean = name.trim();
      if (clean.isEmpty) return;
      writersMap.putIfAbsent(clean, () => <String>{}).add(role.toLowerCase());
    }

    void addProduction(String name, String role) {
      final clean = name.trim();
      if (clean.isEmpty) return;
      productionMap.putIfAbsent(clean, () => <String>{}).add(role.toLowerCase());
    }

    void addPerformer(String name, String role) {
      final clean = name.trim();
      if (clean.isEmpty) return;
      performersMap.putIfAbsent(clean, () => role);
    }

    void setReleaseDate(String dateStr) {
      if (formattedDate.isNotEmpty) return;
      final dt = DateTime.tryParse(dateStr);
      if (dt != null) {
        formattedDate = _formatSpanishDate(dt);
      } else if (dateStr.isNotEmpty) {
        formattedDate = dateStr;
      }
    }

    // Format local/song year or date
    if (song.year != null && song.year! > 0) {
      formattedDate = '${song.year}';
    } else if (song.created != null) {
      formattedDate = '${song.created!.year}';
    }

    // 1. Parallel search on YouTube (Official Track Description), Deezer & iTunes
    await Future.wait([
      // A. Official YouTube Music Track Credits (highest accuracy for Latin, Vallenato, & streaming)
      _extractYoutubeMusicTrackCredits(
        song,
        cleanArtist,
        cleanTitle,
        addWriter,
        addProduction,
        addPerformer,
        setReleaseDate,
      ),

      // B. iTunes Search API (release date, genre, artwork, composer)
      () async {
        try {
          final searchUrl =
              'https://itunes.apple.com/search?term=${Uri.encodeComponent('$cleanArtist $cleanTitle')}&entity=song&limit=1';
          final res = await _dio.get(searchUrl);
          if (res.statusCode == 200 && res.data != null) {
            final Map<String, dynamic> data = res.data is String
                ? jsonDecode(res.data as String)
                : (res.data as Map<String, dynamic>);
            final results = data['results'] as List?;
            if (results != null && results.isNotEmpty) {
              final first = results.first as Map<String, dynamic>;
              final releaseDateStr = first['releaseDate'] as String?;
              if (releaseDateStr != null && formattedDate.isEmpty) {
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
                if (composerName != null && composerName!.isNotEmpty) {
                  for (final n in composerName!.split(RegExp(r'[,;/]'))) {
                    addWriter(n, 'composer');
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('iTunes credits lookup failed: $e');
        }
      }(),

      // C. Deezer Search API (artist image, ISRC, contributors)
      () async {
        try {
          final deezerUrl =
              'https://api.deezer.com/search?q=${Uri.encodeComponent('$cleanArtist $cleanTitle')}&limit=1';
          final res = await _dio.get(deezerUrl);
          if (res.statusCode == 200 && res.data != null) {
            final Map<String, dynamic> data = res.data is String
                ? jsonDecode(res.data as String)
                : (res.data as Map<String, dynamic>);
            final list = data['data'] as List?;
            if (list != null && list.isNotEmpty) {
              final first = list.first as Map<String, dynamic>;
              final artistData = first['artist'] as Map<String, dynamic>?;
              artistImageUrl =
                  artistData?['picture_medium'] as String? ?? artistData?['picture_big'] as String?;

              final trackId = first['id'];
              if (trackId != null) {
                final trackRes = await _dio.get('https://api.deezer.com/track/$trackId');
                if (trackRes.statusCode == 200 && trackRes.data != null) {
                  final tData = trackRes.data is String
                      ? jsonDecode(trackRes.data as String)
                      : (trackRes.data as Map<String, dynamic>);
                  isrc = tData['isrc'] as String?;
                  final contribs = tData['contributors'] as List?;
                  if (contribs != null) {
                    for (final c in contribs) {
                      final role = (c['role'] as String?)?.toLowerCase() ?? '';
                      final cName = c['name'] as String?;
                      if (cName != null && cName.isNotEmpty) {
                        if (role.contains('author') ||
                            role.contains('composer') ||
                            role.contains('writer') ||
                            role.contains('lyricist')) {
                          addWriter(cName, role);
                        } else if (role.contains('producer') ||
                            role.contains('mixer') ||
                            role.contains('arranger')) {
                          addProduction(cName, role);
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Deezer credits lookup failed: $e');
        }
      }(),
    ]);

    // 2. Query MusicBrainz with ISRC if available and writers are still needed
    if (writersMap.isEmpty && isrc != null && isrc!.isNotEmpty) {
      try {
        final mbRes = await _dio.get('https://musicbrainz.org/ws/2/isrc/$isrc?fmt=json');
        if (mbRes.statusCode == 200 && mbRes.data != null) {
          final data = mbRes.data is String
              ? jsonDecode(mbRes.data as String)
              : (mbRes.data as Map<String, dynamic>);
          final recs = data['recordings'] as List? ?? [];
          if (recs.isNotEmpty) {
            final recId = recs[0]['id'];
            await _extractMusicBrainzRecordingWriters(recId, addWriter, addProduction);
          }
        }
      } catch (e) {
        debugPrint('MusicBrainz ISRC lookup note: $e');
      }
    }

    // 3. Query MusicBrainz Work directly if writers are still empty
    if (writersMap.isEmpty) {
      try {
        final mbWorkRes = await _dio.get(
          'https://musicbrainz.org/ws/2/work?query=work:%22${Uri.encodeComponent(cleanTitle)}%22%20AND%20artist:%22${Uri.encodeComponent(cleanArtist)}%22&fmt=json&limit=2',
        );
        if (mbWorkRes.statusCode == 200 && mbWorkRes.data != null) {
          final data = mbWorkRes.data is String
              ? jsonDecode(mbWorkRes.data as String)
              : (mbWorkRes.data as Map<String, dynamic>);
          final works = data['works'] as List? ?? [];
          for (final w in works) {
            final workId = w['id'] as String?;
            if (workId != null) {
              await _extractMusicBrainzWorkWriters(workId, addWriter);
              if (writersMap.isNotEmpty) break;
            }
          }
        }
      } catch (e) {
        debugPrint('MusicBrainz Work lookup note: $e');
      }
    }

    // 4. Query MusicBrainz Recording directly if writers are still empty
    if (writersMap.isEmpty) {
      try {
        final mbRecRes = await _dio.get(
          'https://musicbrainz.org/ws/2/recording?query=recording:%22${Uri.encodeComponent(cleanTitle)}%22%20AND%20artist:%22${Uri.encodeComponent(cleanArtist)}%22&fmt=json&limit=2',
        );
        if (mbRecRes.statusCode == 200 && mbRecRes.data != null) {
          final data = mbRecRes.data is String
              ? jsonDecode(mbRecRes.data as String)
              : (mbRecRes.data as Map<String, dynamic>);
          final recs = data['recordings'] as List? ?? [];
          for (final r in recs) {
            final recId = r['id'] as String?;
            if (recId != null) {
              await _extractMusicBrainzRecordingWriters(recId, addWriter, addProduction);
              if (writersMap.isNotEmpty) break;
            }
          }
        }
      } catch (e) {
        debugPrint('MusicBrainz Recording lookup note: $e');
      }
    }

    // 5. Build Performers List
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

    performersMap.forEach((pName, pRole) {
      if (pName.toLowerCase() != mainArtistName.toLowerCase() &&
          !performers.any((p) => p.name.toLowerCase() == pName.toLowerCase())) {
        performers.add(SongCreditItem(
          name: pName,
          role: pRole,
        ));
      }
    });

    // 6. Build Writers List (Composition & Lyrics) with REAL verified composers only
    final writers = <SongCreditItem>[];
    writersMap.forEach((name, roles) {
      final isComp = roles.contains('composer') || roles.contains('composer,lyricist');
      final isLyr = roles.contains('lyricist') || roles.contains('composer,lyricist') || roles.contains('author');
      final isWrit = roles.contains('writer');

      String roleLabel;
      if (roles.contains('composer,lyricist') || (isComp && isLyr)) {
        roleLabel = 'Composición y letra';
      } else if (isComp) {
        roleLabel = 'Composición';
      } else if (isLyr) {
        roleLabel = 'Letra';
      } else if (isWrit) {
        roleLabel = 'Composición y letra';
      } else {
        roleLabel = 'Composición';
      }

      writers.add(SongCreditItem(name: name, role: roleLabel));
    });

    // Note: If writers is empty, DO NOT fall back to the singer!
    // The UI handles empty writers gracefully by indicating that composer data is not available.

    // 7. Build Production List
    final production = <SongCreditItem>[];
    productionMap.forEach((name, roles) {
      String roleLabel = 'Producción';
      if (roles.contains('mixer')) {
        roleLabel = 'Mezcla y masterización';
      } else if (roles.contains('arranger')) {
        roleLabel = 'Arreglos';
      }
      production.add(SongCreditItem(name: name, role: roleLabel));
    });

    // 8. Audio Quality info
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
      production: production,
      audioQuality: audioQuality,
    );

    _cache[cacheKey] = credits;
    return credits;
  }

  /// Extracts official record label metadata and real composers directly from
  /// YouTube Music's official track credits (MPTC) endpoint.
  static Future<void> _extractYoutubeMusicTrackCredits(
    Song song,
    String cleanArtist,
    String cleanTitle,
    void Function(String name, String role) addWriter,
    void Function(String name, String role) addProduction,
    void Function(String name, String role) addPerformer,
    void Function(String date) setReleaseDate,
  ) async {
    final candidateVids = <String>[];

    // 1. If song.id is directly an 11-char YouTube ID, test it first
    final cleanId = song.id
        .replaceFirst('ytmusic://', '')
        .replaceFirst('yt_', '')
        .trim();
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(cleanId)) {
      candidateVids.add(cleanId);
    }

    // 2. Query YouTube Music search API for official audio tracks
    try {
      final searchRes = await _dio.post<Map<String, dynamic>>(
        'https://music.youtube.com/youtubei/v1/search?prettyPrint=false',
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Content-Type': 'application/json',
            'Origin': 'https://music.youtube.com',
            'Referer': 'https://music.youtube.com/',
          },
        ),
        data: {
          'context': {
            'client': {
              'clientName': 'WEB_REMIX',
              'clientVersion': '1.20240101.01.00',
              'hl': 'es',
              'gl': 'CO',
            }
          },
          'query': '$cleanArtist $cleanTitle',
        },
      );

      final searchData = searchRes.data ?? {};
      final rawStr = jsonEncode(searchData);
      final vidMatches = RegExp(r'"videoId":\s*"([a-zA-Z0-9_-]{11})"').allMatches(rawStr);
      for (final m in vidMatches) {
        final vid = m.group(1)!;
        if (!candidateVids.contains(vid)) {
          candidateVids.add(vid);
          if (candidateVids.length >= 6) break;
        }
      }
    } catch (e) {
      debugPrint('[SongCreditsService] YouTube Music search error: $e');
    }

    // 3. For candidate video IDs, call the official MPTC browse endpoint
    for (final vid in candidateVids) {
      try {
        final browseRes = await _dio.post<Map<String, dynamic>>(
          'https://music.youtube.com/youtubei/v1/browse?prettyPrint=false',
          options: Options(
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Content-Type': 'application/json',
              'Origin': 'https://music.youtube.com',
              'Referer': 'https://music.youtube.com/',
            },
          ),
          data: {
            'context': {
              'client': {
                'clientName': 'WEB_REMIX',
                'clientVersion': '1.20240101.01.00',
                'hl': 'es',
                'gl': 'CO',
              }
            },
            'browseId': 'MPTC$vid',
          },
        );

        if (browseRes.statusCode == 200 && browseRes.data != null) {
          final data = browseRes.data!;
          final actions = data['onResponseReceivedActions'] as List?;
          if (actions == null || actions.isEmpty) continue;

          final firstAction = actions[0] as Map<String, dynamic>?;
          final popup = firstAction?['openPopupAction']?['popup'] as Map<String, dynamic>?;
          final dialog = popup?['dismissableDialogRenderer'] as Map<String, dynamic>?;
          if (dialog == null) continue;

          final sections = dialog['sections'] as List?;
          if (sections == null || sections.isEmpty) continue;

          bool foundWriter = false;

          for (final sec in sections) {
            final sRend = (sec as Map<String, dynamic>)['dismissableDialogContentSectionRenderer'] as Map<String, dynamic>?;
            if (sRend == null) continue;

            final titleRuns = sRend['title']?['runs'] as List?;
            final sectionTitle = titleRuns != null && titleRuns.isNotEmpty
                ? (titleRuns[0]['text'] as String? ?? '').toLowerCase()
                : '';

            final subtitleRuns = sRend['subtitle']?['runs'] as List?;
            if (subtitleRuns == null || subtitleRuns.isEmpty) continue;

            final rawSubtitle = subtitleRuns
                .map((r) => r['text'] as String? ?? '')
                .join('')
                .trim();

            final names = rawSubtitle
                .split(RegExp(r'[\n\r]+|,\s*'))
                .map((n) => n.trim())
                .where((n) => n.isNotEmpty && n.length > 1 && n != 'Unknown' && n != 'Desconocido')
                .toList();

            if (sectionTitle.contains('escrita') ||
                sectionTitle.contains('written') ||
                sectionTitle.contains('compos') ||
                sectionTitle.contains('autor')) {
              for (final name in names) {
                addWriter(name, 'composer,lyricist');
                foundWriter = true;
              }
            } else if (sectionTitle.contains('producida') ||
                sectionTitle.contains('produced') ||
                sectionTitle.contains('producc')) {
              for (final name in names) {
                addProduction(name, 'producer');
              }
            } else if (sectionTitle.contains('interpretada') ||
                sectionTitle.contains('performed') ||
                sectionTitle.contains('artistas')) {
              for (final name in names) {
                addPerformer(name, 'Intérprete asociado');
              }
            }
          }

          final meta = dialog['metadata']?['musicMultiRowListItemRenderer'] as Map<String, dynamic>?;
          final secondTitleRuns = meta?['secondTitle']?['runs'] as List?;
          if (secondTitleRuns != null) {
            for (final r in secondTitleRuns) {
              final text = r['text'] as String? ?? '';
              final yearMatch = RegExp(r'\b(19\d{2}|20\d{2})\b').firstMatch(text);
              if (yearMatch != null) {
                setReleaseDate(yearMatch.group(0)!);
                break;
              }
            }
          }

          if (foundWriter) {
            break;
          }
        }
      } catch (e) {
        debugPrint('[SongCreditsService] MPTC browse error for $vid: $e');
      }
    }
  }

  static Future<void> _extractMusicBrainzWorkWriters(
    String workId,
    void Function(String name, String role) addWriter,
  ) async {
    try {
      final res = await _dio.get('https://musicbrainz.org/ws/2/work/$workId?inc=artist-rels&fmt=json');
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data is String
            ? jsonDecode(res.data as String)
            : (res.data as Map<String, dynamic>);
        final rels = data['relations'] as List? ?? [];
        for (final r in rels) {
          final type = r['type'] as String?;
          final name = r['artist']?['name'] as String?;
          if (name != null &&
              name.isNotEmpty &&
              (type == 'composer' || type == 'lyricist' || type == 'writer')) {
            addWriter(name, type!);
          }
        }
      }
    } catch (_) {}
  }

  static Future<void> _extractMusicBrainzRecordingWriters(
    String recId,
    void Function(String name, String role) addWriter,
    void Function(String name, String role) addProduction,
  ) async {
    try {
      final res = await _dio.get(
        'https://musicbrainz.org/ws/2/recording/$recId?inc=work-rels+artist-rels&fmt=json',
      );
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data is String
            ? jsonDecode(res.data as String)
            : (res.data as Map<String, dynamic>);
        final rels = data['relations'] as List? ?? [];
        for (final r in rels) {
          final type = r['type'] as String?;
          final name = r['artist']?['name'] as String?;
          if (name != null && name.isNotEmpty) {
            if (type == 'composer' || type == 'lyricist' || type == 'writer') {
              addWriter(name, type!);
            } else if (type == 'producer' || type == 'mix' || type == 'arranger') {
              addProduction(name, type!);
            }
          }
          if (r['work'] != null) {
            final workId = r['work']['id'] as String?;
            if (workId != null) {
              await _extractMusicBrainzWorkWriters(workId, addWriter);
            }
          }
        }
      }
    } catch (_) {}
  }

  static String _formatSpanishDate(DateTime dt) {
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre'
    ];
    return '${dt.day} de ${months[dt.month - 1]} de ${dt.year}';
  }
}
