// ignore_for_file: experimental_member_use
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'library_database_service.dart';
import 'recommendation_service.dart';
import 'ytdlp_service.dart';
import 'album_resolver_service.dart';
import 'audio_cache_service.dart';
import 'offline_service.dart';

class PingResult {
  final bool success;
  final String? error;
  final String? serverType;
  final String? serverVersion;

  PingResult({
    required this.success,
    this.error,
    this.serverType,
    this.serverVersion,
  });
}

class SearchResult {
  final List<Artist> artists;
  final List<Album> albums;
  final List<Song> songs;
  final List<Song>? youtubeVideos;

  SearchResult({
    required this.artists,
    required this.albums,
    required this.songs,
    this.youtubeVideos,
  });

  bool get isEmpty =>
      artists.isEmpty &&
      albums.isEmpty &&
      songs.isEmpty &&
      (youtubeVideos == null || youtubeVideos!.isEmpty);
}


/// Proxies the YouTube audio stream via Dart's HttpClient to provide matching
/// headers (User-Agent, Range) and completely avoid HTTP 403 on ExoPlayer / Media3.
class _YoutubeStreamAudioSource extends StreamAudioSource {
  final String _videoId;
  final YtDlpService _ytdlp;

  _YoutubeStreamAudioSource(this._videoId, this._ytdlp) : super(tag: _videoId);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final cleanId = _videoId.replaceFirst('ytmusic://', '').replaceFirst('yt_', '').trim();
    final streamInfo = await _ytdlp.resolveStreamInfo(cleanId);

    final s = start ?? 0;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..idleTimeout = const Duration(seconds: 15)
      ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);

    void applyHeaders(HttpClientRequest req, Map<String, String> headers) {
      bool hasUserAgent = false;
      headers.forEach((key, value) {
        final lower = key.toLowerCase();
        if (lower == 'user-agent') hasUserAgent = true;
        if (lower != 'host' &&
            lower != 'content-length' &&
            lower != 'accept-encoding' &&
            lower != 'connection') {
          req.headers.set(key, value);
        }
      });
      if (!hasUserAgent) {
        req.headers.set(
          HttpHeaders.userAgentHeader,
          'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36',
        );
      }
      req.headers.set(HttpHeaders.acceptHeader, '*/*');
    }

    try {
      final req = await client.getUrl(Uri.parse(streamInfo.url));
      applyHeaders(req, streamInfo.headers);

      if (end != null) {
        req.headers.set('Range', 'bytes=$s-$end');
      } else {
        req.headers.set('Range', 'bytes=$s-');
      }

      final resp = await req.close();

      if (resp.statusCode == 403 || resp.statusCode == 410 || resp.statusCode == 429) {
        debugPrint('[YouTube] Stream rejected (${resp.statusCode}) for $cleanId, refreshing with forceRefresh...');
        await resp.drain<void>().catchError((_) {});
        _ytdlp.invalidateCache(cleanId);
        final freshInfo = await _ytdlp.resolveStreamInfo(cleanId, forceRefresh: true);
        final retryReq = await client.getUrl(Uri.parse(freshInfo.url));
        applyHeaders(retryReq, freshInfo.headers);
        if (end != null) {
          retryReq.headers.set('Range', 'bytes=$s-$end');
        } else {
          retryReq.headers.set('Range', 'bytes=$s-');
        }
        final retryResp = await retryReq.close();
        return _buildResponse(retryResp, s, freshInfo.ext, client);
      }

      if (resp.statusCode >= 400) {
        await resp.drain<void>().catchError((_) {});
        throw Exception('GoogleVideo stream error: HTTP ${resp.statusCode}');
      }

      return _buildResponse(resp, s, streamInfo.ext, client);
    } catch (e) {
      client.close(force: true);
      debugPrint('[YouTube] StreamAudioSource request error for $cleanId: $e');
      rethrow;
    }
  }

  StreamAudioResponse _buildResponse(
    HttpClientResponse resp,
    int start,
    String ext,
    HttpClient client,
  ) {
    int? sourceLength;
    final contentRange = resp.headers.value('content-range');
    if (contentRange != null) {
      final slashIndex = contentRange.lastIndexOf('/');
      if (slashIndex != -1) {
        final totalStr = contentRange.substring(slashIndex + 1).trim();
        sourceLength = int.tryParse(totalStr);
      }
    }
    sourceLength ??= resp.contentLength >= 0 ? resp.contentLength + start : null;

    final isWebm = (ext == 'webm' || ext == 'opus');
    final type = isWebm ? 'audio/webm' : 'audio/mp4';

    late StreamSubscription<List<int>> responseSubscription;
    late StreamController<List<int>> responseController;
    responseController = StreamController<List<int>>(
      sync: true,
      onListen: () {
        responseSubscription = resp.listen(
          responseController.add,
          onError: responseController.addError,
          onDone: () {
            client.close(force: false);
            responseController.close();
          },
        );
      },
      onCancel: () async {
        await responseSubscription.cancel();
        client.close(force: true);
      },
    );

    return StreamAudioResponse(
      sourceLength: sourceLength,
      contentLength: resp.contentLength >= 0 ? resp.contentLength : null,
      offset: start,
      stream: responseController.stream,
      contentType: type,
    );
  }
}

class YoutubeService {
  final YtDlpService _ytdlp = YtDlpService();
  final LibraryDatabaseService _db = LibraryDatabaseService();

  void dispose() {
    _ytdlp.dispose();
  }

  bool get isYoutube => true;
  bool get isConfigured => true;
  dynamic get config => null;

  Future<void> configure(dynamic config) async {}

  static final Map<String, String> _resolvedVideoIdCache = {};

  /// Public helper to resolve a valid 11-char YouTube video ID for any track (including Deezer dz_...)
  Future<String> resolveVideoIdForSong(Song song) => _resolvePlayableVideoId(song);

  Future<String> _resolvePlayableVideoId(Song song) async {
    final cleanId = song.id.replaceFirst('ytmusic://', '').replaceFirst('yt_', '');
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(cleanId)) {
      return cleanId;
    }

    if (_resolvedVideoIdCache.containsKey(song.id)) {
      return _resolvedVideoIdCache[song.id]!;
    }

    // Check persistent SQLite database first for 0ms lookup
    final dbResolved = await _db.getResolvedVideoId(song.id);
    if (dbResolved != null && dbResolved.isNotEmpty) {
      _resolvedVideoIdCache[song.id] = dbResolved;
      return dbResolved;
    }

    void cacheAndPersist(String id) {
      _resolvedVideoIdCache[song.id] = id;
      unawaited(_db.saveResolvedVideoId(song.id, id));
    }

    try {
      // 1. Clean title and artist to strip suffixes like (Remastered...), [Official Audio], etc.
      String cleanTitle = song.title
          .replaceAll(RegExp(r'\s*[\(\[](?:remaster(?:ed)?|deluxe|version|explicit|radio edit|bonus track|official|audio|video|feat\.?|ft\.?).*?[\)\]]', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (cleanTitle.isEmpty) cleanTitle = song.title;

      String cleanArtist = (song.artist != null && song.artist!.isNotEmpty && song.artist != 'Unknown Artist')
          ? song.artist!.replaceAll(RegExp(r'\s*[\(\[].*?[\)\]]'), '').trim()
          : '';

      final q = cleanArtist.isNotEmpty ? '$cleanTitle $cleanArtist' : cleanTitle;
      if (q.trim().isEmpty) return '';
      final dual = await _ytdlp.searchDual(q, limit: 5);
      final musicList = dual['music'] ?? [];
      for (final item in musicList) {
        final id = (item['id'] as String? ?? '').replaceFirst('ytmusic://', '').replaceFirst('yt_', '');
        if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(id)) {
          cacheAndPersist(id);
          return id;
        }
      }
      final ytList = dual['youtube'] ?? [];
      for (final item in ytList) {
        final id = (item['id'] as String? ?? '').replaceFirst('ytmusic://', '').replaceFirst('yt_', '');
        if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(id)) {
          cacheAndPersist(id);
          return id;
        }
      }

      // If initial search with cleaned query didn't match, fallback to raw query
      final rawQ = (song.artist != null && song.artist!.isNotEmpty)
          ? '${song.title} ${song.artist}'
          : song.title;
      if (rawQ.trim().isNotEmpty && rawQ.trim() != q.trim()) {
        final rawDual = await _ytdlp.searchDual(rawQ, limit: 5);
        for (final list in [rawDual['music'] ?? [], rawDual['youtube'] ?? []]) {
          for (final item in list) {
            final id = (item['id'] as String? ?? '').replaceFirst('ytmusic://', '').replaceFirst('yt_', '');
            if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(id)) {
              cacheAndPersist(id);
              return id;
            }
          }
        }
      }

      // If dual search did not match, try standard search fallback
      try {
        final directList = await _ytdlp.search(q, limit: 5);
        for (final item in directList) {
          final id = (item['id'] as String? ?? '').replaceFirst('ytmusic://', '').replaceFirst('yt_', '');
          if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(id)) {
            cacheAndPersist(id);
            return id;
          }
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('[YouTube] _resolvePlayableVideoId error for "${song.title}": $e');
    }

    // Never return non-11-character cleanId (e.g. dz_12345), return empty string
    return '';
  }

  Future<AudioSource?> getYoutubeAudioSource(Song song) async {
    // 0. Check permanent offline downloads first (instant 0ms playback offline & online)
    final offlinePath = OfflineService().getLocalPath(song.id);
    if (offlinePath != null && File(offlinePath).existsSync()) {
      debugPrint('[YouTube] ⚡ Playing "${song.title}" (${song.id}) directly from offline downloads: $offlinePath');
      return AudioSource.file(
        offlinePath,
        tag: song.id,
      );
    }

    // 1. Check local audio cache next
    final cached = await AudioCacheService().getCachedSongFile(song.id);
    if (cached != null) {
      debugPrint('[YouTube] ⚡ Playing "${song.title}" (${song.id}) directly from local disk cache: ${cached.path}');
      return AudioSource.file(
        cached.path,
        tag: song.id,
      );
    }

    final videoId = await _resolvePlayableVideoId(song);
    if (videoId.isEmpty || !RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(videoId)) return null;

    // Check offline downloads with resolved videoId
    final offlinePathByVideoId = OfflineService().getLocalPath(videoId);
    if (offlinePathByVideoId != null && File(offlinePathByVideoId).existsSync()) {
      debugPrint('[YouTube] ⚡ Playing "${song.title}" ($videoId) directly from offline downloads: $offlinePathByVideoId');
      return AudioSource.file(
        offlinePathByVideoId,
        tag: song.id,
      );
    }

    // Check again with resolved videoId if song.id was a custom ID
    final cachedByVideoId = await AudioCacheService().getCachedSongFile(videoId);
    if (cachedByVideoId != null) {
      debugPrint('[YouTube] ⚡ Playing "${song.title}" ($videoId) directly from local disk cache: ${cachedByVideoId.path}');
      return AudioSource.file(
        cachedByVideoId.path,
        tag: song.id,
      );
    }

    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      // Desktop (Windows, Linux, macOS) uses libmpv via just_audio_media_kit.
      // Passing the stream URL with authentication headers directly to AudioSource.uri
      // allows libmpv's native C++ FFmpeg demuxer to stream directly from Google CDN
      // with full HTTP range support, avoiding loopback socket timeouts and demuxer truncation.
      try {
        final streamInfo = await _ytdlp.resolveStreamInfo(videoId);
        if (streamInfo.url.isNotEmpty) {
          debugPrint('[YouTube] Desktop: streaming directly via libmpv with headers for $videoId');
          return AudioSource.uri(
            Uri.parse(streamInfo.url),
            headers: streamInfo.headers,
            tag: song.id,
          );
        }
      } catch (e) {
        debugPrint('[YouTube] Desktop stream resolve error for $videoId: $e');
        // In case initial yt-dlp setup was just finishing in the background, retry once
        try {
          await Future.delayed(const Duration(milliseconds: 600));
          final retryInfo = await _ytdlp.resolveStreamInfo(videoId, forceRefresh: true);
          if (retryInfo.url.isNotEmpty) {
            debugPrint('[YouTube] Desktop: resolved on retry for $videoId');
            return AudioSource.uri(
              Uri.parse(retryInfo.url),
              headers: retryInfo.headers,
              tag: song.id,
            );
          }
        } catch (_) {}
      }
      try {
        debugPrint('[YouTube] Desktop: trying buildAudioSource fallback for $videoId');
        return await buildAudioSource(videoId);
      } catch (e) {
        debugPrint('[YouTube] Desktop buildAudioSource fallback error for $videoId: $e');
      }
      return null;
    }
    return buildAudioSource(videoId);
  }

  Future<String> resolveStreamUrlAsync(Song song) async {
    final videoId = await _resolvePlayableVideoId(song);
    if (videoId.isEmpty || !RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(videoId)) {
      throw Exception('No playable YouTube video found for "${song.title}" (${song.id})');
    }
    return _ytdlp.resolveStreamUrl(videoId);
  }

  Future<ArtistInfo?> getArtistInfo(String id) async => null;

  Future<Artist> getArtist(String id) async => Artist(id: id, name: id);

  Future<void> setRating(String id, int rating) async {}

  String getDownloadUrl(String songId) => getStreamUrl(songId);

  Future<Map<String, dynamic>?> getLyricsBySongId(String songId) async => null;

  Future<Map<String, dynamic>?> getLyrics({String? artist, String? title, int? duration}) async => null;

  // ── Connectivity ──────────────────────────────────────────────────────────

  Future<PingResult> pingWithError() async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final req = await client.getUrl(
        Uri.parse('https://music.youtube.com/'),
      );
      req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
      final res = await req.close();
      await res.drain<void>();
      client.close();
      return PingResult(
        success: true,
        serverType: 'YT Stream (yt-dlp)',
        serverVersion: '1.0',
      );
    } catch (_) {
      // Even if the web ping fails or is restricted, allow entering YT Stream mode
      return PingResult(
        success: true,
        serverType: 'YT Stream (yt-dlp)',
        serverVersion: '1.0',
      );
    }
  }

  // ── Cover art & stream ────────────────────────────────────────────────────

  String getCoverArtUrl(String? id, {int size = 800}) {
    if (id == null || id.isEmpty) return '';
    if (id.startsWith('file://') || id.startsWith('/') || (id.length > 2 && id[1] == ':')) {
      return id;
    }
    if (id.startsWith('http://') || id.startsWith('https://')) {
      var url = id;
      // Upgrade Google User Content / YouTube Music album artwork to 800x800 quality
      url = url.replaceAll(RegExp(r'=(w\d+-h\d+|s\d+)[^/]*'), '=w800-h800-l90-rj');
      // Ensure we use hqdefault.jpg which is guaranteed to exist on YouTube CDN
      // (sddefault.jpg 404s for many music tracks and video uploads)
      url = url.replaceAll('/sddefault.jpg', '/hqdefault.jpg');
      url = url.replaceAll('/mqdefault.jpg', '/hqdefault.jpg');
      url = url.replaceAll('/default.jpg', '/hqdefault.jpg');
      return url;
    }
    final cleanId = id.replaceFirst('ytmusic://', '').replaceFirst('yt_', '');
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(cleanId)) {
      return 'https://i.ytimg.com/vi/$cleanId/hqdefault.jpg';
    }
    return '';
  }

  /// Returns a lightweight valid stream URL synchronously.
  String getStreamUrl(String videoId, {int? maxBitRate, String? format}) {
    final cleanId = videoId.replaceFirst('ytmusic://', '').replaceFirst('yt_', '');
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(cleanId)) {
      return 'https://www.youtube.com/watch?v=$cleanId';
    }
    return '';
  }

  /// Resolves the actual direct audio stream URL via yt-dlp / Python process.
  Future<String> resolveStreamUrl(String videoId) async {
    final cleanId = videoId.replaceFirst('ytmusic://', '');
    return await _ytdlp.resolveStreamUrl(cleanId);
  }

  /// Builds a [StreamAudioSource] that proxies audio through Dart's HttpClient
  /// with standard browser headers to prevent HTTP 403 on ExoPlayer / Media3.
  Future<StreamAudioSource> buildAudioSource(String videoId) async {
    final cleanId = videoId.replaceFirst('ytmusic://', '').replaceFirst('yt_', '').trim();
    return _YoutubeStreamAudioSource(cleanId, _ytdlp);
  }

  // ── Model mappers ─────────────────────────────────────────────────────────

  Song _mapDictToSong(Map<String, dynamic> d) {
    final id = d['id']?.toString() ?? '';
    final thumb = d['thumbnailUrl']?.toString();
    var artistName = d['artist']?.toString() ?? 'Unknown Artist';
    // Clean up " - Topic" from official artist channels
    if (artistName.endsWith(' - Topic')) {
      artistName = artistName.substring(0, artistName.length - 8).trim();
    }
    final rawDuration = d['duration'];
    final duration = (rawDuration is num)
        ? rawDuration.toInt()
        : (rawDuration != null ? int.tryParse(rawDuration.toString()) : null);

    return Song(
      id: id,
      title: d['title']?.toString() ?? 'Unknown Title',
      artist: artistName,
      album: d['album']?.toString(),
      duration: duration,
      coverArt: (thumb != null && thumb.isNotEmpty) ? thumb : (d['coverArt']?.toString() ?? id),
    );
  }

  // ── Artists / Albums ──────────────────────────────────────────────────────

  Future<List<Artist>> getArtists() async {
    try {
      final songs = await _db.getAllSongs();
      final artistNames = <String>{};
      final artists = <Artist>[];

      for (final s in songs) {
        if (s.artist != null && s.artist!.isNotEmpty && !artistNames.contains(s.artist)) {
          artistNames.add(s.artist!);
          artists.add(Artist(
            id: s.artistId ?? s.artist!,
            name: s.artist!,
            coverArt: s.coverArt,
          ));
        }
      }
      return artists;
    } catch (e) {
      debugPrint('[YouTube] getArtists error: $e');
      return [];
    }
  }

  Future<List<Album>> getAlbumList({
    String type = 'recent',
    int size = 20,
    int offset = 0,
  }) async {
    try {
      final albums = await _db.getAllAlbums();
      if (albums.isNotEmpty) {
        return albums.skip(offset).take(size).toList();
      }

      // If local albums table is empty, generate album groupings from saved songs
      final songs = await _db.getAllSongs();
      final albumMap = <String, Album>{};
      for (final s in songs) {
        if (s.album != null && s.album!.isNotEmpty && !albumMap.containsKey(s.album)) {
          albumMap[s.album!] = Album(
            id: s.albumId ?? s.album!,
            name: s.album!,
            artist: s.artist,
            coverArt: s.coverArt,
          );
        }
      }
      return albumMap.values.skip(offset).take(size).toList();
    } catch (e) {
      debugPrint('[YouTube] getAlbumList error: $e');
      return [];
    }
  }

  Future<Album?> getAlbum(String playlistOrAlbumId) async {
    try {
      final songs = await getAlbumSongs(playlistOrAlbumId);
      if (songs.isNotEmpty) {
        final firstSong = songs.first;
        final cleanAlbum = (firstSong.album != null &&
                firstSong.album!.isNotEmpty &&
                firstSong.album != 'Album' &&
                firstSong.album != 'Álbum')
            ? firstSong.album!
            : playlistOrAlbumId;
        return Album(
          id: playlistOrAlbumId,
          name: cleanAlbum,
          artist: firstSong.artist,
          coverArt: firstSong.coverArt ?? playlistOrAlbumId,
          songCount: songs.length,
        );
      }
      return null;
    } catch (e) {
      debugPrint('[YouTube] getAlbum error: $e');
      return null;
    }
  }

  Future<List<Song>> getAlbumSongs(String albumId) async {
    try {
      // Check if it's a playlist or album in SQLite
      final songs = await _db.getAllSongs();
      final matching = songs.where((s) => s.albumId == albumId || s.album == albumId).toList();
      if (matching.isNotEmpty) return matching;

      // Try AlbumResolverService (which handles MPREb_, Deezer, and YTM browse endpoints)
      try {
        final resolved = await AlbumResolverService().resolveAlbum(albumId: albumId);
        if (resolved != null && resolved.songs.isNotEmpty) {
          return resolved.songs;
        }
      } catch (_) {}

      // Otherwise fetch online via yt-dlp
      final videos = await _ytdlp.getPlaylistVideos(albumId);
      return videos.map(_mapDictToSong).toList();
    } catch (e) {
      debugPrint('[YouTube] getAlbumSongs error: $e');
      return [];
    }
  }

  Future<List<Album>> getArtistAlbums(String channelOrArtistId) async {
    try {
      final songs = await _db.getAllSongs();
      final artistSongs = songs.where((s) => s.artistId == channelOrArtistId || s.artist == channelOrArtistId).toList();
      final albumMap = <String, Album>{};
      for (final s in artistSongs) {
        if (s.album != null && s.album!.isNotEmpty && !albumMap.containsKey(s.album)) {
          albumMap[s.album!] = Album(
            id: s.albumId ?? s.album!,
            name: s.album!,
            artist: s.artist,
            coverArt: s.coverArt,
          );
        }
      }
      if (albumMap.isNotEmpty) return albumMap.values.toList();

      // If no local albums, fetch official artist albums from YouTube Music Innertube
      final rawAlbums = await _ytdlp.searchYtAlbumsInnertube(channelOrArtistId, limit: 30);
      if (rawAlbums.isNotEmpty) {
        final cleanTarget = channelOrArtistId.toLowerCase().trim();
        final mapped = rawAlbums.map((a) => Album(
          id: a['id'] as String,
          name: a['title'] as String? ?? 'Álbum',
          artist: a['artist'] as String?,
          year: a['year'] as int?,
          coverArt: a['coverArt'] as String?,
        )).toList();

        // If an artist name was passed, filter to albums actually matching this artist
        if (!channelOrArtistId.startsWith('UC') && !channelOrArtistId.startsWith('FE')) {
          final filtered = mapped.where((alb) {
            final a = alb.artist?.toLowerCase().trim();
            if (a == null || a.isEmpty) return true;
            return a.contains(cleanTarget) || cleanTarget.contains(a);
          }).toList();
          return filtered.isNotEmpty ? filtered : mapped;
        }
        return mapped;
      }

      return [];
    } catch (e) {
      debugPrint('[YouTube] getArtistAlbums error: $e');
      return [];
    }
  }

  // ── Playlists (Locally Saved in SQLite) ───────────────────────────────────

  Future<List<Playlist>> getPlaylists() async {
    try {
      return await _db.getAllPlaylists();
    } catch (e) {
      debugPrint('[YouTube] getPlaylists error: $e');
      return [];
    }
  }

  Future<Playlist> getPlaylist(String id) async {
    try {
      final local = await _db.getPlaylist(id);
      if (local != null) return local;

      // Online YouTube playlist fallback
      final items = await _ytdlp.getPlaylistVideos(id);
      final songs = items.map(_mapDictToSong).toList();
      return Playlist(
        id: id,
        name: 'YouTube Playlist',
        songCount: songs.length,
        songs: songs,
      );
    } catch (e) {
      debugPrint('[YouTube] getPlaylist error: $e');
      return Playlist(id: id, name: 'Playlist');
    }
  }

  Future<void> createPlaylist({
    required String name,
    String? comment,
    List<String>? songIds,
  }) async {
    try {
      final newId = const Uuid().v4();
      List<Song>? songs;
      if (songIds != null && songIds.isNotEmpty) {
        songs = await _db.getSongs(songIds);
      }

      final playlist = Playlist(
        id: newId,
        name: name,
        comment: comment,
        owner: 'Local',
        songCount: songs?.length ?? songIds?.length ?? 0,
        created: DateTime.now(),
        changed: DateTime.now(),
        coverArt: songs?.isNotEmpty == true ? songs!.first.coverArt : null,
        songs: songs,
      );

      await _db.insertOrUpdatePlaylist(playlist);
      debugPrint('[YouTube] Created local playlist: $name (id: $newId)');
    } catch (e) {
      debugPrint('[YouTube] createPlaylist error: $e');
      rethrow;
    }
  }

  Future<void> updatePlaylist({
    required String playlistId,
    String? name,
    String? comment,
    List<String>? songIdsToAdd,
    List<int>? songIndexesToRemove,
  }) async {
    try {
      final existing = await _db.getPlaylist(playlistId);
      if (existing == null) {
        throw Exception('Playlist $playlistId not found in local library');
      }

      final currentSongs = List<Song>.from(existing.songs ?? []);

      // Remove songs by index if specified (descending order)
      if (songIndexesToRemove != null && songIndexesToRemove.isNotEmpty) {
        final sortedIndices = List<int>.from(songIndexesToRemove)..sort((a, b) => b.compareTo(a));
        for (final idx in sortedIndices) {
          if (idx >= 0 && idx < currentSongs.length) {
            currentSongs.removeAt(idx);
          }
        }
      }

      // Add songs if specified
      if (songIdsToAdd != null && songIdsToAdd.isNotEmpty) {
        for (final sid in songIdsToAdd) {
          final s = await _db.getSong(sid);
          if (s != null) {
            currentSongs.add(s);
          } else {
            // Fetch info online if not already in DB
            final info = await _ytdlp.getVideoInfo(sid);
            final newSong = info != null
                ? _mapDictToSong(info)
                : Song(id: sid, title: 'YouTube Track');
            await _db.insertOrUpdateSong(newSong);
            currentSongs.add(newSong);
          }
        }
      }

      final updated = existing.copyWith(
        name: name ?? existing.name,
        comment: comment ?? existing.comment,
        changed: DateTime.now(),
        songCount: currentSongs.length,
        coverArt: currentSongs.isNotEmpty ? currentSongs.first.coverArt : existing.coverArt,
        songs: currentSongs,
      );

      await _db.insertOrUpdatePlaylist(updated);
      debugPrint('[YouTube] Updated local playlist $playlistId (now ${currentSongs.length} songs)');
    } catch (e) {
      debugPrint('[YouTube] updatePlaylist error: $e');
      rethrow;
    }
  }

  Future<void> deletePlaylist(String id) async {
    try {
      await _db.deletePlaylist(id);
      debugPrint('[YouTube] Deleted local playlist: $id');
    } catch (e) {
      debugPrint('[YouTube] deletePlaylist error: $e');
      rethrow;
    }
  }

  // ── Search ────────────────────────────────────────────────────────────────

  static String _normalize(String input) {
    var s = input.toLowerCase().trim();
    s = s
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n');
    s = s.replaceAll(RegExp(r'[^\w\s]'), ' ');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _songFingerprint(Song song) {
    final cleanTitle = _normalize(
      song.title
          .replaceAll(RegExp(r'\((official|video|audio|lyrics|letra|videoclip|hd|4k)[^)]*\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\[(official|video|audio|lyrics|letra|videoclip|hd|4k)[^\]]*\]', caseSensitive: false), '')
          .replaceAll(RegExp(r'(\bft\.?|\bfeat\.?).*$', caseSensitive: false), ''),
    );
    final cleanArtist = _normalize(song.artist ?? '');
    return '$cleanTitle::$cleanArtist';
  }

  /// Calculates relevance score to prioritize original artist recordings, exact query matches, and official releases over covers and fan edits.
  int scoreSongRelevance(Song song, String query, {int originalIndex = 0}) {
    int score = 0;
    final qClean = _normalize(query);
    if (qClean.isEmpty) return 0;

    final titleClean = _normalize(song.title);
    final artistClean = _normalize(song.artist ?? '');
    final albumClean = _normalize(song.album ?? '');
    final combinedClean = '$titleClean $artistClean';

    final qWords = qClean.split(' ').where((w) => w.length > 1).toList();

    // 1. Exact or high-match Title scoring
    if (titleClean == qClean) {
      score += 420;
    } else if (titleClean.startsWith(qClean)) {
      score += 260;
    } else if (qClean.contains(titleClean) && titleClean.length >= 3) {
      score += 230;
    } else if (titleClean.contains(qClean)) {
      score += 180;
    }

    // 2. Query token matching across Title + Artist (e.g. "Coldplay Yellow" or "Feid Luna")
    if (qWords.isNotEmpty) {
      int matchedTokens = 0;
      for (final w in qWords) {
        if (combinedClean.contains(w)) {
          matchedTokens++;
        }
      }
      final ratio = matchedTokens / qWords.length;
      if (ratio == 1.0) {
        score += 320; // 100% of search terms match the title and/or artist
      } else if (ratio >= 0.7) {
        score += 190;
      } else if (ratio >= 0.5) {
        score += 100;
      }
    }

    // 3. Artist match with search query
    if (artistClean.isNotEmpty) {
      if (artistClean == qClean) {
        score += 220;
      } else if (qClean.contains(artistClean) && artistClean.length >= 3) {
        score += 170;
      } else if (artistClean.contains(qClean)) {
        score += 120;
      }
    }

    // 4. Position bonus from original YouTube search ranking (YouTube already ranks by popularity/views)
    if (originalIndex >= 0 && originalIndex < 30) {
      score += (30 - originalIndex) * 3; // #1 gets +90, #2 gets +87, etc.
    }

    // 5. Verified official album release (slight boost)
    if (song.album != null &&
        song.album!.trim().isNotEmpty &&
        albumClean != 'album' &&
        albumClean != 'álbum' &&
        albumClean != 'single') {
      score += 40;
    }

    // 6. Official artist channel / topic channel / official release tags
    if (artistClean.contains('topic') ||
        artistClean.contains('official') ||
        titleClean.contains('official audio') ||
        titleClean.contains('official video') ||
        titleClean.contains('audio oficial') ||
        titleClean.contains('video oficial')) {
      score += 40;
    }

    // 7. Demote unofficial / fan content (covers, karaoke, slowed+reverb, 8D audio, tributes)
    const penalties = [
      'cover',
      'tributo',
      'tribute',
      'karaoke',
      'instrumental',
      'parodia',
      'parody',
      'slowed',
      'reverb',
      '8d audio',
      '8d',
      'nightcore',
      'tutorial',
      'como tocar',
      'reaccion',
      'reaction',
      'clase',
      'guitar lesson',
      'bass boosted',
      '10 hours',
      '1 hour',
    ];

    for (final penalty in penalties) {
      if (!qClean.contains(penalty)) {
        if (titleClean.contains(penalty)) score -= 150;
        if (artistClean.contains(penalty)) score -= 150;
      }
    }

    // 8. Normal studio song duration reward (1:30 to 7:00) vs extremes (sample / long loops)
    if (song.duration != null && song.duration! > 0) {
      if (song.duration! < 45 || song.duration! > 900) {
        score -= 90;
      } else if (song.duration! >= 90 && song.duration! <= 420) {
        score += 25;
      }
    }

    return score;
  }

  // In-memory LRU search cache for instant (0ms) response on repeated / typing queries
  final Map<String, SearchResult> _searchResultCache = {};

  // ── Search ────────────────────────────────────────────────────────────────

  Future<SearchResult> search(
    String query, {
    int artistCount = 30,
    int albumCount = 30,
    int songCount = 100,
  }) async {
    final cleanQuery = query.trim().toLowerCase();
    if (_searchResultCache.containsKey(cleanQuery)) {
      return _searchResultCache[cleanQuery]!;
    }

    try {
      // 1. Concurrently query songs, official albums, and official artists via YouTube Music Innertube
      final futures = await Future.wait([
        _ytdlp.searchDual(query, limit: songCount),
        _ytdlp.searchYtAlbumsInnertube(query, limit: albumCount),
        _ytdlp.searchYtArtistsInnertube(query, limit: artistCount),
      ]);

      final dualResults = futures[0] as Map<String, List<Map<String, dynamic>>>;
      final rawAlbums = futures[1] as List<Map<String, dynamic>>;
      final rawArtists = futures[2] as List<Map<String, dynamic>>;

      final musicSongs = (dualResults['music'] ?? []).map(_mapDictToSong).toList();
      final youtubeVideos = (dualResults['youtube'] ?? []).map(_mapDictToSong).toList();

      // 2. Query local matching songs
      final localSongs = await _db.searchSongs(query, limit: songCount);

      // 3. Intelligently merge and deduplicate YouTube Music, YouTube Video, and local songs
      final candidateSongs = <Song>[];
      final seenIds = <String>{};
      final seenFingerprints = <String>{};

      // Local matches added first to check
      for (final ls in localSongs) {
        if (seenIds.add(ls.id)) {
          final fp = _songFingerprint(ls);
          if (fp.isNotEmpty) seenFingerprints.add(fp);
          candidateSongs.add(ls);
        }
      }

      // Interleave music and youtube results so both are considered with their initial ranks
      final maxLen = musicSongs.length > youtubeVideos.length ? musicSongs.length : youtubeVideos.length;
      for (int i = 0; i < maxLen; i++) {
        if (i < musicSongs.length) {
          final s = musicSongs[i];
          final fp = _songFingerprint(s);
          if (seenIds.add(s.id) && (fp.isEmpty || seenFingerprints.add(fp))) {
            candidateSongs.add(s);
          }
        }
        if (i < youtubeVideos.length) {
          final s = youtubeVideos[i];
          final fp = _songFingerprint(s);
          if (seenIds.add(s.id) && (fp.isEmpty || seenFingerprints.add(fp))) {
            candidateSongs.add(s);
          }
        }
      }

      // 4. Process official YouTube Music artists and albums
      final artists = <Artist>[];
      final albums = <Album>[];
      final seenArtists = <String>{};
      final seenAlbums = <String>{};

      for (final art in rawArtists) {
        final name = art['name'] as String? ?? '';
        final id = art['id'] as String? ?? name;
        if (name.isNotEmpty && !seenArtists.contains(name.toLowerCase())) {
          seenArtists.add(name.toLowerCase());
          artists.add(Artist(
            id: id,
            name: name,
            coverArt: art['coverArt'] as String?,
            artistImageUrl: art['artistImageUrl'] as String?,
          ));
        }
      }

      for (final alb in rawAlbums) {
        final title = alb['title']?.toString() ?? '';
        final id = alb['id']?.toString() ?? title;
        final rawYear = alb['year'];
        final year = (rawYear is num)
            ? rawYear.toInt()
            : (rawYear != null ? int.tryParse(rawYear.toString()) : null);
        if (title.isNotEmpty && !seenAlbums.contains(title.toLowerCase())) {
          seenAlbums.add(title.toLowerCase());
          albums.add(Album(
            id: id,
            name: title,
            artist: alb['artist']?.toString(),
            year: year,
            coverArt: alb['coverArt']?.toString(),
          ));
        }
      }

      // 5. Supplement with any additional unique artists and albums from candidate song metadata
      for (final s in candidateSongs) {
        final artistName = s.artist?.trim();
        if (artistName != null &&
            artistName.isNotEmpty &&
            !seenArtists.contains(artistName.toLowerCase()) &&
            !artistName.toLowerCase().endsWith('vevo') &&
            !artistName.toLowerCase().contains('topic')) {
          seenArtists.add(artistName.toLowerCase());
          artists.add(Artist(
            id: s.artistId ?? artistName,
            name: artistName,
            coverArt: s.coverArt,
          ));
        }
        final albumName = s.album?.trim();
        if (albumName != null &&
            albumName.isNotEmpty &&
            !seenAlbums.contains(albumName.toLowerCase()) &&
            albumName.toLowerCase() != 'album' &&
            albumName.toLowerCase() != 'álbum') {
          seenAlbums.add(albumName.toLowerCase());
          albums.add(Album(
            id: s.albumId ?? albumName,
            name: albumName,
            artist: s.artist,
            coverArt: s.coverArt,
          ));
        }
      }

      // 6. Rank candidate songs by comprehensive relevance score
      final songScoreMap = <String, int>{};
      for (int i = 0; i < candidateSongs.length; i++) {
        final s = candidateSongs[i];
        songScoreMap[s.id] = scoreSongRelevance(s, query, originalIndex: i);
      }

      candidateSongs.sort((a, b) {
        final scoreA = songScoreMap[a.id] ?? 0;
        final scoreB = songScoreMap[b.id] ?? 0;
        return scoreB.compareTo(scoreA);
      });

      final finalSongs = candidateSongs.take(songCount).toList();

      final res = SearchResult(
        artists: artists.take(artistCount).toList(),
        albums: albums.take(albumCount).toList(),
        songs: finalSongs,
        youtubeVideos: finalSongs,
      );

      if (cleanQuery.isNotEmpty && finalSongs.isNotEmpty) {
        if (_searchResultCache.length > 80) {
          _searchResultCache.remove(_searchResultCache.keys.first);
        }
        _searchResultCache[cleanQuery] = res;
      }

      return res;
    } catch (e) {
      debugPrint('[YouTube] search error: $e');
      return SearchResult(artists: [], albums: [], songs: []);
    }
  }

  // ── Random / Trending songs ───────────────────────────────────────────────

  Future<List<Song>> getRandomSongs({int size = 20, String? genre}) async {
    try {
      String query;
      if (genre != null && genre.isNotEmpty) {
        query = '$genre canciones exitos';
      } else {
        final topArtists = RecommendationService().getTopArtists(3);
        if (topArtists.isNotEmpty) {
          query = '${topArtists.first} mix canciones';
        } else {
          query = 'grandes exitos musica latina';
        }
      }
      final rawResults = await _ytdlp.search(query, limit: size);
      final songs = rawResults.map(_mapDictToSong).toList();
      return songs;
    } catch (e) {
      debugPrint('[YouTube] getRandomSongs error: $e');
      return [];
    }
  }

  // ── Favorites (Saved in SQLite) ───────────────────────────────────────────

  Future<void> star({String? id, String? albumId, String? artistId}) async {
    try {
      if (id != null) {
        await _db.setSongStarred(id, true);
        final existing = await _db.getSong(id);
        if (existing == null) {
          final info = await _ytdlp.getVideoInfo(id);
          if (info != null) {
            await _db.insertOrUpdateSong(_mapDictToSong(info).copyWith(starred: true));
          }
        }
        debugPrint('[YouTube] Starred song $id locally');
      }
      if (albumId != null) {
        await _db.setAlbumStarred(albumId, true);
      }
    } catch (e) {
      debugPrint('[YouTube] star error: $e');
    }
  }

  Future<void> unstar({String? id, String? albumId, String? artistId}) async {
    try {
      if (id != null) {
        await _db.setSongStarred(id, false);
        debugPrint('[YouTube] Unstarred song $id locally');
      }
      if (albumId != null) {
        await _db.setAlbumStarred(albumId, false);
      }
    } catch (e) {
      debugPrint('[YouTube] unstar error: $e');
    }
  }

  Future<void> scrobble(String id, {bool submission = true}) async {
    // Record to local playback history
    debugPrint('[YouTube] Scrobble song $id (submission=$submission)');
  }

  Future<SearchResult> getStarred() async {
    try {
      final songs = await _db.getStarredSongs();
      final albums = await _db.getStarredAlbums();
      return SearchResult(artists: [], albums: albums, songs: songs);
    } catch (e) {
      debugPrint('[YouTube] getStarred error: $e');
      return SearchResult(artists: [], albums: [], songs: []);
    }
  }

  // ── Genres ────────────────────────────────────────────────────────────────

  Future<List<Genre>> getGenres() async {
    return [
      Genre(value: 'Pop', songCount: 50, albumCount: 10),
      Genre(value: 'Rock', songCount: 50, albumCount: 10),
      Genre(value: 'Hip-Hop / Rap', songCount: 50, albumCount: 10),
      Genre(value: 'R&B / Soul', songCount: 50, albumCount: 10),
      Genre(value: 'Electronic / Dance', songCount: 50, albumCount: 10),
      Genre(value: 'Indie / Alternative', songCount: 50, albumCount: 10),
      Genre(value: 'Classical', songCount: 50, albumCount: 10),
      Genre(value: 'Jazz', songCount: 50, albumCount: 10),
      Genre(value: 'Italian / Sanremo', songCount: 50, albumCount: 10),
      Genre(value: 'Acoustic / Lo-Fi', songCount: 50, albumCount: 10),
    ];
  }

  Future<List<Song>> getSongsByGenre(
    String genre, {
    int? size,
    int? count,
    int offset = 0,
  }) async {
    final limit = count ?? size ?? 50;
    try {
      final rawResults = await _ytdlp.search('$genre music hits', limit: limit + offset);
      final songs = rawResults.map(_mapDictToSong).toList();
      return songs.skip(offset).take(limit).toList();
    } catch (e) {
      debugPrint('[YouTube] getSongsByGenre error: $e');
      return [];
    }
  }

  Future<List<Album>> getAlbumsByGenre(
    String genre, {
    int? size,
    int? count,
    int offset = 0,
  }) async =>
      [];

  // ── Related / Top songs ───────────────────────────────────────────────────

  Future<List<Song>> getSimilarSongs(String videoId, {int count = 50}) async {
    try {
      final radioRaw = await _ytdlp.getRadioTracks(videoId, limit: count);
      if (radioRaw.isNotEmpty) {
        return radioRaw.map(_mapDictToSong).toList();
      }

      final info = await _ytdlp.getVideoInfo(videoId);
      final query = info != null
          ? '${info['artist'] ?? ''} ${info['title'] ?? ''} audio'
          : 'recommended music';
      final rawResults = await _ytdlp.search(query, limit: count);
      return rawResults.map(_mapDictToSong).toList();
    } catch (e) {
      debugPrint('[YouTube] getSimilarSongs error: $e');
      return [];
    }
  }

  Future<List<Song>> getArtistTopSongs(
    String channelIdOrArtistName, {
    int count = 50,
  }) async {
    try {
      final isChannelId = channelIdOrArtistName.startsWith('UC') || channelIdOrArtistName.startsWith('FE');
      final query = isChannelId ? channelIdOrArtistName : '$channelIdOrArtistName top songs';
      final rawResults = await _ytdlp.search(query, limit: count);
      final songs = rawResults.map(_mapDictToSong).toList();

      if (!isChannelId) {
        final cleanTarget = channelIdOrArtistName.toLowerCase().trim();
        final filtered = songs.where((s) {
          final a = s.artist?.toLowerCase().trim();
          if (a == null || a.isEmpty) return false;
          return a.contains(cleanTarget) || cleanTarget.contains(a);
        }).toList();
        return filtered.isNotEmpty ? filtered : songs;
      }
      return songs;
    } catch (e) {
      debugPrint('[YouTube] getArtistTopSongs error: $e');
      return [];
    }
  }
}
