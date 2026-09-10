import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../utils/album_sanitizer.dart';

/// Service that accurately resolves real album metadata, cover art, and playable tracks
/// using official YouTube Music and Deezer endpoints, preventing generic "Album"/"Artist"
/// placeholders and random track fallbacks.
class AlbumResolverService {
  static final AlbumResolverService _instance = AlbumResolverService._internal();
  factory AlbumResolverService() => _instance;
  AlbumResolverService._internal();

  static final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8);

  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Content-Type': 'application/json',
    'Origin': 'https://music.youtube.com',
    'Referer': 'https://music.youtube.com/',
  };

  /// Helper to normalize strings for comparisons
  String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[\(\[\{\)\|\-–—\]\}]'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9áéíóúñü\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Clean helper to check if a string is a dummy/placeholder
  bool _isPlaceholder(String? s) => AlbumSanitizer.isPlaceholder(s);

  /// Resolves the album and its tracklist from online sources
  Future<({Album album, List<Song> songs})?> resolveAlbum({
    required String albumId,
    Album? existingAlbum,
    Song? song,
  }) async {
    String? title = existingAlbum?.name ?? song?.album;
    String? artist = existingAlbum?.artist ?? song?.artist;
    String? coverArt = existingAlbum?.coverArt ?? song?.coverArt;

    if (_isPlaceholder(title)) title = null;
    if (_isPlaceholder(artist)) artist = null;

    if (title != null) {
      final cleaned = AlbumSanitizer.cleanTitle(title);
      if (cleaned.isNotEmpty) title = cleaned;
    }
    if (artist != null) {
      artist = AlbumSanitizer.cleanArtist(artist);
    }

    // If title is missing or albumId is a slug/name, clean it
    if (title == null &&
        !albumId.startsWith('MPREb_') &&
        !albumId.startsWith('OLAK') &&
        !albumId.startsWith('VLOLAK') &&
        !albumId.startsWith('PL')) {
      final cleaned = AlbumSanitizer.cleanTitle(albumId);
      if (cleaned.isNotEmpty) title = cleaned;
    }

    // Step 1: If albumId is already a YouTube Music browseId (MPREb_..., OLAK..., VLOLAK...), browse directly!
    final ytmBrowseId = albumId.startsWith('MPREb_')
        ? albumId
        : (albumId.startsWith('VLOLAK')
            ? albumId
            : (albumId.startsWith('OLAK')
                ? 'VL$albumId'
                : (albumId.startsWith('VLPL')
                    ? albumId
                    : (albumId.startsWith('PL') ? 'VL$albumId' : null))));
    if (ytmBrowseId != null) {
      final direct = await _browseYtmAlbum(ytmBrowseId, title ?? albumId, artist ?? '');
      if (direct != null && direct.songs.isNotEmpty) {
        return direct;
      }
    }

    // Step 2: If albumId is a Deezer album ID (from artist discography or search)
    final dzId = albumId.replaceFirst('dz_album_', '');
    if (RegExp(r'^\d+$').hasMatch(dzId)) {
      final dzRes = await _fetchDeezerAlbum(dzId, title, artist, coverArt);
      if (dzRes != null && dzRes.songs.isNotEmpty) {
        return dzRes;
      }
    }

    // Step 3: If title is still missing, resolve it from the song via Deezer
    if (title == null && song != null && song.title.isNotEmpty) {
      final resolved = await _resolveAlbumInfoFromSong(song.title, song.artist);
      if (resolved != null) {
        title = resolved.albumTitle;
        artist ??= resolved.artistName;
        coverArt ??= resolved.coverArt;
      }
    }

    // Step 4: If we have a title, search YouTube Music with the official Albums filter
    if (title != null && title.isNotEmpty) {
      final ytmRes = await _searchAndBrowseYtmAlbum(title, artist ?? '');
      if (ytmRes != null && ytmRes.songs.isNotEmpty) {
        return ytmRes;
      }
    }

    // Step 5: Deezer search fallback by title & artist
    if (title != null && title.isNotEmpty) {
      final dzSearchRes = await _searchDeezerAlbum(title, artist ?? '');
      if (dzSearchRes != null && dzSearchRes.songs.isNotEmpty) {
        return dzSearchRes;
      }
    }

    return null;
  }

  /// Resolves the album title, artist, and cover art for a track using Deezer Search API
  Future<({String albumTitle, String artistName, String? coverArt, String? albumId})?>
      _resolveAlbumInfoFromSong(String songTitle, String? artistName) async {
    try {
      final cleanArtist = (artistName != null && !_isPlaceholder(artistName)) ? artistName : '';
      final query = cleanArtist.isNotEmpty
          ? 'artist:"$cleanArtist" track:"$songTitle"'
          : songTitle;
      final url = 'https://api.deezer.com/search?q=${Uri.encodeComponent(query)}&limit=1';

      final req = await _client.getUrl(Uri.parse(url));
      req.headers.set('User-Agent', 'Mozilla/5.0');
      final resp = await req.close();
      final jsonStr = await resp.transform(utf8.decoder).join();
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final data = map['data'] as List<dynamic>?;
      if (data != null && data.isNotEmpty) {
        final first = data[0];
        final alb = first['album'];
        if (alb != null) {
          final albTitle = alb['title'] as String?;
          final artName = first['artist']?['name'] as String?;
          final cover = alb['cover_xl'] as String? ?? alb['cover_big'] as String?;
          final albId = alb['id']?.toString();
          if (albTitle != null && albTitle.isNotEmpty) {
            if (cleanArtist.isNotEmpty) {
              final normClean = cleanArtist.toLowerCase().trim();
              final normArt = (artName ?? '').toLowerCase().trim();
              if (normArt.isNotEmpty && !normArt.contains(normClean) && !normClean.contains(normArt)) {
                return null;
              }
            }
            return (
              albumTitle: albTitle,
              artistName: artName ?? cleanArtist,
              coverArt: cover,
              albumId: albId,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[AlbumResolver] Deezer track resolve error: $e');
    }
    return null;
  }

  /// Searches YouTube Music using the Albums filter (params: 'EgWKAQIBAW==')
  /// and browses the matching album browseId to return all native YouTube tracks.
  Future<({Album album, List<Song> songs})?> _searchAndBrowseYtmAlbum(
    String albumName,
    String artistName,
  ) async {
    try {
      final req = await _client.postUrl(
        Uri.parse('https://music.youtube.com/youtubei/v1/search?prettyPrint=false&key=AIzaSyC9XL3ZjWddXya6X74dJoCTL-KLET5YdU'),
      );
      _headers.forEach((k, v) => req.headers.set(k, v));

      final cleanArtist = !_isPlaceholder(artistName) ? artistName : '';
      final query = cleanArtist.isNotEmpty ? '$albumName $cleanArtist' : albumName;

      req.write(jsonEncode({
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20240918.01.00',
            'hl': 'es',
            'gl': 'CO',
          }
        },
        'query': query,
        'params': 'EgWKAQIBAW==',
      }));

      final resp = await req.close();
      final jsonStr = await resp.transform(utf8.decoder).join();
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      String? matchedBrowseId;
      String? matchedTitle;

      final normAlbum = _normalize(albumName);
      final normArtist = _normalize(cleanArtist);

      void scanForAlbum(dynamic obj) {
        if (obj is Map<String, dynamic>) {
          if (obj.containsKey('musicResponsiveListItemRenderer')) {
            final item = obj['musicResponsiveListItemRenderer'] as Map<String, dynamic>;
            final flex = item['flexColumns'] as List<dynamic>? ?? [];
            if (flex.isNotEmpty) {
              final runs = (flex[0]['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs']
                  as List<dynamic>?) ?? [];
              final t = runs.isNotEmpty ? runs[0]['text'] as String? : null;
              final nav = item['navigationEndpoint'] ??
                  (runs.isNotEmpty ? runs[0]['navigationEndpoint'] : null);
              final bId = nav?['browseEndpoint']?['browseId'] as String?;

              final isSupportedBrowseId = bId != null &&
                  (bId.startsWith('MPREb_') || bId.startsWith('OLAK') || bId.startsWith('VLOLAK'));
              if (isSupportedBrowseId && t != null && t.isNotEmpty) {
                final normT = _normalize(t);

                // Extract artist runs from secondary flex column if present
                String itemArtist = '';
                if (flex.length > 1) {
                  final col2Runs = (flex[1]['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs']
                      as List<dynamic>?) ?? [];
                  for (final r in col2Runs) {
                    final txt = r['text'] as String? ?? '';
                    if (txt != ' • ' && txt.toLowerCase() != 'album' && txt.toLowerCase() != 'álbum' && txt.toLowerCase() != 'ep' && txt.toLowerCase() != 'single') {
                      itemArtist = _normalize(txt);
                      break;
                    }
                  }
                }

                // Strict title and artist matching (prevents matching different artists)
                final bool isExactMatch = normT == normAlbum;
                final bool isTitleMatch = isExactMatch ||
                    (normAlbum.length >= 4 && (normT.startsWith(normAlbum) || normAlbum.startsWith(normT)));
                final bool artistMatches = normArtist.isEmpty ||
                    (itemArtist.isNotEmpty && (itemArtist.contains(normArtist) || normArtist.contains(itemArtist)));

                if (isTitleMatch && artistMatches) {
                  if (matchedBrowseId == null || isExactMatch) {
                    matchedBrowseId = bId;
                    matchedTitle = t;
                  }
                }
              }
            }
          }
          obj.forEach((k, v) => scanForAlbum(v));
        } else if (obj is List) {
          for (final it in obj) {
            scanForAlbum(it);
          }
        }
      }

      scanForAlbum(map);

      if (matchedBrowseId != null) {
        final result = await _browseYtmAlbum(
          matchedBrowseId!,
          matchedTitle ?? albumName,
          cleanArtist,
        );
        if (result != null && result.songs.isNotEmpty) {
          return result;
        }
      }
    } catch (e) {
      debugPrint('[AlbumResolver] YTM search & browse error: $e');
    }
    return null;
  }

  /// Browses a YouTube Music album by browseId ('MPREb_...') and parses all tracks.
  Future<({Album album, List<Song> songs})?> _browseYtmAlbum(
    String browseId,
    String fallbackTitle,
    String fallbackArtist,
  ) async {
    try {
      final req = await _client.postUrl(
        Uri.parse('https://music.youtube.com/youtubei/v1/browse?prettyPrint=false&key=AIzaSyC9XL3ZjWddXya6X74dJoCTL-KLET5YdU'),
      );
      _headers.forEach((k, v) => req.headers.set(k, v));

      req.write(jsonEncode({
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20240918.01.00',
            'hl': 'es',
            'gl': 'CO',
          }
        },
        'browseId': browseId,
      }));

      final resp = await req.close();
      final jsonStr = await resp.transform(utf8.decoder).join();
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      String title = fallbackTitle;
      String artist = fallbackArtist;
      String? coverUrl;
      int? year;

      final twoCol = map['contents']?['twoColumnBrowseResultsRenderer'];
      final header = twoCol?['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']
          ?['contents']?[0]?['musicResponsiveHeaderRenderer'];

      if (header != null) {
        final hTitle = header['title']?['runs']?[0]?['text'] as String?;
        if (hTitle != null && hTitle.isNotEmpty && !_isPlaceholder(hTitle)) {
          title = hTitle;
        }

        final straplineRuns = (header['straplineTextOne']?['runs'] as List<dynamic>?) ?? [];
        if (straplineRuns.isNotEmpty) {
          final aText = straplineRuns[0]['text'] as String?;
          if (aText != null && aText.isNotEmpty && !_isPlaceholder(aText)) {
            artist = aText;
          }
        }

        final subRuns = (header['subtitle']?['runs'] as List<dynamic>?) ?? [];
        for (final sr in subRuns) {
          final t = sr['text'] as String? ?? '';
          final yMatch = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(t);
          if (yMatch != null) {
            year = int.tryParse(yMatch.group(1)!);
          }
        }

        final thumbs =
            header['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] as List<dynamic>?;
        if (thumbs != null && thumbs.isNotEmpty) {
          coverUrl = thumbs.last['url'] as String?;
        }
      }

      // Extract tracks from secondaryContents or tabs[0] (supports both albums and playlists)
      List<dynamic> contents = [];
      final secList = twoCol?['secondaryContents']?['sectionListRenderer']?['contents'] as List<dynamic>?;
      if (secList != null) {
        for (final s in secList) {
          final shelf = s['musicShelfRenderer'] ?? s['musicPlaylistShelfRenderer'];
          if (shelf != null && shelf['contents'] != null) {
            contents = (shelf['contents'] as List<dynamic>?) ?? [];
            break;
          }
        }
      }

      if (contents.isEmpty) {
        final tabContents = twoCol?['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']?['contents'] as List<dynamic>?;
        if (tabContents != null) {
          for (final s in tabContents) {
            final shelf = s['musicShelfRenderer'] ?? s['musicPlaylistShelfRenderer'];
            if (shelf != null && shelf['contents'] != null) {
              contents = (shelf['contents'] as List<dynamic>?) ?? [];
              break;
            }
          }
        }
      }

      final songs = <Song>[];

      for (int i = 0; i < contents.length; i++) {
        final it = contents[i];
        final r = it['musicResponsiveListItemRenderer'];
        if (r == null) continue;

        final tTitle = r['flexColumns']?[0]?['musicResponsiveListItemFlexColumnRenderer']?['text']
            ?['runs']?[0]?['text'] as String? ?? 'Unknown Title';

        // Robust videoId extraction across YTM response variations
        String? videoId = r['playlistItemData']?['videoId'] as String?;
        videoId ??= r['overlay']?['musicItemThumbnailOverlayRenderer']?['content']
            ?['musicPlayButtonRenderer']?['playNavigationEndpoint']?['watchEndpoint']?['videoId'] as String?;
        videoId ??= r['flexColumns']?[0]?['musicResponsiveListItemFlexColumnRenderer']?['text']
            ?['runs']?[0]?['navigationEndpoint']?['watchEndpoint']?['videoId'] as String?;
        videoId ??= r['navigationEndpoint']?['watchEndpoint']?['videoId'] as String?;

        if (videoId != null) {
          videoId = videoId.replaceFirst('ytmusic://', '').replaceFirst('yt_', '');
        }
        if (videoId == null || !RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(videoId)) continue;

        int durationSec = 0;
        final fixedCols = r['fixedColumns'] as List<dynamic>?;
        if (fixedCols != null && fixedCols.isNotEmpty) {
          final dStr = fixedCols[0]['musicResponsiveListItemFixedColumnRenderer']?['text']?['runs']
              ?[0]?['text'] as String? ?? '';
          final parts = dStr.split(':');
          if (parts.length == 2) {
            durationSec = (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
          } else if (parts.length == 3) {
            durationSec = (int.tryParse(parts[0]) ?? 0) * 3600 +
                (int.tryParse(parts[1]) ?? 0) * 60 +
                (int.tryParse(parts[2]) ?? 0);
          }
        }

        songs.add(
          Song(
            id: videoId,
            title: tTitle,
            artist: artist,
            album: title,
            albumId: browseId,
            duration: durationSec,
            track: i + 1,
            year: year,
            coverArt: videoId,
          ),
        );
      }

      if (songs.isNotEmpty) {
        final album = Album(
          id: browseId,
          name: title,
          artist: artist,
          coverArt: coverUrl ?? songs.first.coverArt,
          songCount: songs.length,
          year: year,
        );
        return (album: album, songs: songs);
      }
    } catch (e) {
      debugPrint('[AlbumResolver] YTM browse error: $e');
    }
    return null;
  }

  /// Fetches an album directly from Deezer by ID
  Future<({Album album, List<Song> songs})?> _fetchDeezerAlbum(
    String dzId,
    String? fallbackTitle,
    String? fallbackArtist,
    String? fallbackCover,
  ) async {
    try {
      final url = 'https://api.deezer.com/album/$dzId';
      final req = await _client.getUrl(Uri.parse(url));
      req.headers.set('User-Agent', 'Mozilla/5.0');
      final resp = await req.close();
      final jsonStr = await resp.transform(utf8.decoder).join();
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      final title = map['title'] as String? ?? fallbackTitle ?? 'Álbum';
      final artist = map['artist']?['name'] as String? ?? fallbackArtist ?? 'Artista';
      final cover = map['cover_xl'] as String? ??
          map['cover_big'] as String? ??
          map['cover_medium'] as String? ??
          fallbackCover;
      final releaseDate = map['release_date'] as String?;
      int? year;
      if (releaseDate != null && releaseDate.length >= 4) {
        year = int.tryParse(releaseDate.substring(0, 4));
      }

      final trackList = (map['tracks']?['data'] as List<dynamic>?) ?? [];
      final songs = <Song>[];

      for (int i = 0; i < trackList.length; i++) {
        final t = trackList[i];
        final tTitle = t['title'] as String? ?? 'Track';
        final dur = t['duration'] as int? ?? 0;
        final trackPos = t['track_position'] as int? ?? (i + 1);

        songs.add(
          Song(
            id: 'dz_${t['id']}',
            title: tTitle,
            artist: t['artist']?['name'] as String? ?? artist,
            album: title,
            albumId: 'dz_album_$dzId',
            duration: dur,
            track: trackPos,
            coverArt: cover,
            year: year,
          ),
        );
      }

      if (songs.isNotEmpty) {
        final album = Album(
          id: 'dz_album_$dzId',
          name: title,
          artist: artist,
          coverArt: cover,
          songCount: songs.length,
          year: year,
        );
        return (album: album, songs: songs);
      }
    } catch (e) {
      debugPrint('[AlbumResolver] Deezer album error: $e');
    }
    return null;
  }

  /// Searches Deezer for an album by title and artist, then fetches its tracks
  Future<({Album album, List<Song> songs})?> _searchDeezerAlbum(
    String albumName,
    String artistName,
  ) async {
    try {
      final cleanArtist = !_isPlaceholder(artistName) ? artistName : '';
      final query = cleanArtist.isNotEmpty ? '$albumName $cleanArtist' : albumName;
      final url = 'https://api.deezer.com/search/album?q=${Uri.encodeComponent(query)}&limit=5';

      final req = await _client.getUrl(Uri.parse(url));
      req.headers.set('User-Agent', 'Mozilla/5.0');
      final resp = await req.close();
      final jsonStr = await resp.transform(utf8.decoder).join();
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final data = map['data'] as List<dynamic>?;

      if (data != null && data.isNotEmpty) {
        for (final item in data) {
          final itemTitle = item['title'] as String? ?? '';
          final itemArtist = (item['artist']?['name'] as String?) ?? '';
          final dzId = item['id']?.toString();
          if (dzId == null || dzId.isEmpty) continue;

          final normItemTitle = _normalize(itemTitle);
          final normAlbum = _normalize(albumName);
          final normItemArtist = _normalize(itemArtist);
          final normCleanArtist = _normalize(cleanArtist);

          // Verify that this album actually matches the requested album and artist!
          final bool titleMatches = normItemTitle == normAlbum ||
              (normAlbum.length >= 4 && (normItemTitle.startsWith(normAlbum) || normAlbum.startsWith(normItemTitle)));
          final bool artistMatches = normCleanArtist.isEmpty ||
              normItemArtist.contains(normCleanArtist) ||
              normCleanArtist.contains(normItemArtist);

          if (titleMatches && artistMatches) {
            return await _fetchDeezerAlbum(dzId, albumName, cleanArtist, null);
          }
        }
      }
    } catch (e) {
      debugPrint('[AlbumResolver] Deezer search error: $e');
    }
    return null;
  }
}
