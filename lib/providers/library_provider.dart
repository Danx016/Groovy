import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../services/audio_handler.dart';
import '../services/local_music_service.dart';
import '../services/groovy_api_service.dart';

class LibraryProvider extends ChangeNotifier {
  final YoutubeService _youtubeService;
  final MuslyAudioHandler _audioHandler;

  bool _localOnlyMode = false;
  bool _serverOfflineMode = false;
  bool _mergeLocalLibrary = false;
  LocalMusicService? _localMusicService;
  final LibraryDatabaseService _db = LibraryDatabaseService();

  List<Artist> _artists = [];
  List<Album> _recentAlbums = [];
  List<Album> _frequentAlbums = [];
  List<Album> _newestAlbums = [];
  List<Album> _randomAlbums = [];
  List<Playlist> _playlists = [];
  List<Song> _randomSongs = [];
  List<String> _genres = [];
  List<Genre> _richGenres = [];
  SearchResult? _starred;

  List<Album> _cachedAllAlbums = [];
  List<Song> _cachedAllSongs = [];
  List<Playlist> _cachedPlaylists = [];
  DateTime? _lastCacheUpdate;

  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  static const String _playlistsCacheKey = 'cached_playlists';
  static const String _artistsCacheKey = 'cached_artists';
  static const String _lastUpdateKey = 'last_cache_update';

  LibraryProvider(this._youtubeService, this._audioHandler) {
    // Serve the Android Auto browse tree: audio_service pulls these lists on
    // demand, including from the headless engine when the car connects while
    // the app UI has never been opened.
    _audioHandler.onGetRecentSongs = _recentSongsForAuto;
    _audioHandler.onGetLibraryAlbums = _albumsForAuto;
    _audioHandler.onGetLibraryArtists = _artistsForAuto;
    _audioHandler.onGetLibraryPlaylists = _playlistsForAuto;
    // Tell the audio handler whether we are in YT Stream mode so it can
    // adapt the Android Auto root browse tree accordingly.
    _audioHandler.onIsYoutubeMode = () => _youtubeService.isYoutube;
  }
  YoutubeService get youtubeService => _youtubeService;
  LibraryDatabaseService get database => _db;

  void setLocalMusicService(LocalMusicService service,
      {bool mergeWithServer = false}) {
    _localMusicService?.removeListener(_onLocalMusicServiceChanged);
    _localMusicService = service;
    _localOnlyMode = !mergeWithServer;
    _mergeLocalLibrary = mergeWithServer;
    _isInitialized = false;
    service.addListener(_onLocalMusicServiceChanged);
    if (mergeWithServer) {
      _onLocalMusicServiceChanged();
    }
  }

  void _onLocalMusicServiceChanged() {
    if (_localMusicService == null || _localMusicService!.isScanning) return;

    if (_localOnlyMode) {
      // Local only mode - use only local library
      _cachedAllSongs = List.from(_localMusicService!.songs);
      _cachedAllAlbums = List.from(_localMusicService!.albums);
      _artists = List.from(_localMusicService!.artists);
      _randomSongs = _cachedAllSongs.take(50).toList();
      _recentAlbums = _cachedAllAlbums.take(20).toList();
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
    } else if (_mergeLocalLibrary) {
      // Merge mode - just notify that local library changed
      // The getters will handle the merging
      notifyListeners();
    }
  }

  /// Toggle merging local library with server library
  void setMergeLocalLibrary(bool enabled) {
    if (_mergeLocalLibrary == enabled) return;
    _mergeLocalLibrary = enabled;
    notifyListeners();
  }

  void setLocalOnlyMode(bool enabled) {
    if (!enabled && _localOnlyMode) {
      _localMusicService?.removeListener(_onLocalMusicServiceChanged);
      _localMusicService = null;
      _cachedAllSongs = [];
      _cachedAllAlbums = [];
      _artists = [];
      _randomSongs = [];
      _recentAlbums = [];
      _playlists = [];
      _cachedPlaylists = [];
    }
    _localOnlyMode = enabled;
    _isInitialized = false;
    notifyListeners();
  }

  bool get isLocalOnlyMode => _localOnlyMode;
  bool get isServerOfflineMode => _serverOfflineMode;
  bool get mergeLocalLibrary => _mergeLocalLibrary;

  void setServerOfflineMode(bool offline) {
    _serverOfflineMode = offline;
  }

  String getCoverArtUrl(String? coverArt) {
    return _youtubeService.getCoverArtUrl(coverArt, size: 300);
  }

  List<Album> get recentAlbums => _recentAlbums;
  List<Album> get frequentAlbums => _frequentAlbums;
  List<Album> get newestAlbums => _newestAlbums;
  List<Album> get randomAlbums => _randomAlbums;
  List<Playlist> get playlists => _playlists;
  List<Song> get randomSongs => _randomSongs;
  List<String> get genres => _genres;
  List<Genre> get richGenres => _richGenres;
  SearchResult? get starred => _starred;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;

  List<Album> get cachedAllAlbums {
    if (!_mergeLocalLibrary ||
        _localMusicService == null ||
        _localMusicService!.isEmpty) {
      return _cachedAllAlbums;
    }
    // Merge server albums with local albums
    final localAlbums = _localMusicService!.albums;
    final merged = [..._cachedAllAlbums];
    for (final localAlbum in localAlbums) {
      // Avoid duplicates by checking ID
      if (!merged.any((a) => a.id == localAlbum.id)) {
        merged.add(localAlbum);
      }
    }
    return merged;
  }

  List<Song> get cachedAllSongs {
    if (!_mergeLocalLibrary ||
        _localMusicService == null ||
        _localMusicService!.isEmpty) {
      return _cachedAllSongs;
    }
    // Merge server songs with local songs
    final localSongs = _localMusicService!.songs;
    final merged = [..._cachedAllSongs];
    for (final localSong in localSongs) {
      // Avoid duplicates by checking ID
      if (!merged.any((s) => s.id == localSong.id)) {
        merged.add(localSong);
      }
    }
    return merged;
  }

  List<Artist> get artists {
    if (!_mergeLocalLibrary ||
        _localMusicService == null ||
        _localMusicService!.isEmpty) {
      return _artists;
    }
    // Merge server artists with local artists
    final localArtists = _localMusicService!.artists;
    final merged = [..._artists];
    for (final localArtist in localArtists) {
      // Avoid duplicates by checking ID
      if (!merged.any((a) => a.id == localArtist.id)) {
        merged.add(localArtist);
      }
    }
    return merged;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_localOnlyMode && _localMusicService != null) {
        _cachedAllSongs = List.from(_localMusicService!.songs);
        _cachedAllAlbums = List.from(_localMusicService!.albums);
        _artists = List.from(_localMusicService!.artists);
        _randomSongs = _cachedAllSongs.take(50).toList();
        _recentAlbums = _cachedAllAlbums.take(20).toList();
        _isInitialized = true;
        _isLoading = false;
        notifyListeners();
        return;
      }

      await _loadCachedData(loadFullLibrary: true);

      if (_recentAlbums.isEmpty && _cachedAllAlbums.isNotEmpty) {
        _recentAlbums = _cachedAllAlbums.take(20).toList();
      }
      if (_randomSongs.isEmpty && _cachedAllSongs.isNotEmpty) {
        _randomSongs = _cachedAllSongs.take(50).toList();
      }
      if (_playlists.isEmpty && _cachedPlaylists.isNotEmpty) {
        _playlists = _cachedPlaylists;
      }

      _audioHandler.notifyAutoChildrenChanged();

      try {
        await Future.wait([
          loadRecentAlbums(),
          loadRandomSongs(),
          loadPlaylists(),
          loadArtists(),
        ]);
      } catch (e) {
        debugPrint('Library initialization error: $e');
      }

      _isInitialized = true;
      _preloadCoverArt();
      _scheduleBackgroundRefresh();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> ensureLibraryLoaded() async {
    if (_cachedAllSongs.isNotEmpty) return;

    if (_localOnlyMode && _localMusicService != null) {
      _cachedAllSongs = List.from(_localMusicService!.songs);
      _cachedAllAlbums = List.from(_localMusicService!.albums);
      _artists = List.from(_localMusicService!.artists);
      _randomSongs = _cachedAllSongs.take(50).toList();
      _recentAlbums = _cachedAllAlbums.take(20).toList();
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    await _loadCachedData(loadFullLibrary: true);

    if (_cachedAllSongs.isEmpty) {
      await _refreshAllDataInBackground();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadCachedData({bool loadFullLibrary = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clean up any unrequested media from SQLite DB
      await _db.cleanupUnsavedLibraryData();
      await prefs.remove(_artistsCacheKey);

      // 1. Load playlists from DB (fallback to SharedPreferences)
      try {
        final dbPlaylists = await _db.getAllPlaylists();
        if (dbPlaylists.isNotEmpty) {
          _cachedPlaylists = dbPlaylists;
          _playlists = _cachedPlaylists;
        } else {
          final playlistsJson = prefs.getString(_playlistsCacheKey);
          if (playlistsJson != null) {
            final List<dynamic> playlistsList = json.decode(playlistsJson);
            _cachedPlaylists = playlistsList
                .map((p) => Playlist.fromJson(p as Map<String, dynamic>))
                .toList();
            _playlists = _cachedPlaylists;
          }
        }
      } catch (e) {
        debugPrint('Error loading playlists from DB: $e');
      }

      // 2. Load artists from DB
      try {
        _artists = await _db.getAllArtists();
      } catch (e) {
        debugPrint('Error loading artists from DB: $e');
      }

      // 3. Always load all albums and songs from DB
      try {
        _cachedAllAlbums = await _db.getAllAlbums();
        _cachedAllSongs = await _db.getAllSongs();

        // If artists list is still empty but we have songs, populate artists
        if (_artists.isEmpty && _cachedAllSongs.isNotEmpty) {
          final seen = <String>{};
          for (final s in _cachedAllSongs) {
            if (s.artist != null && s.artist!.trim().isNotEmpty && seen.add(s.artist!.trim().toLowerCase())) {
              final a = Artist(
                id: s.artistId ?? 'artist_${s.artist!.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
                name: s.artist!.trim(),
                coverArt: s.coverArt,
                albumCount: 1,
              );
              _artists.add(a);
              _db.insertOrUpdateArtist(a).catchError((_) {});
            }
          }
        }

        // If albums list is still empty but we have songs, populate albums
        if (_cachedAllAlbums.isEmpty && _cachedAllSongs.isNotEmpty) {
          final seen = <String>{};
          for (final s in _cachedAllSongs) {
            final albName = (s.album != null && s.album!.trim().isNotEmpty) ? s.album!.trim() : s.title.trim();
            if (seen.add(albName.toLowerCase())) {
              final alb = Album(
                id: s.albumId ?? 'album_${albName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
                name: albName,
                artist: s.artist,
                artistId: s.artistId,
                coverArt: s.coverArt,
                songCount: 1,
                year: s.year,
                created: s.created ?? DateTime.now(),
              );
              _cachedAllAlbums.add(alb);
              _db.insertOrUpdateAlbum(alb).catchError((_) {});
            }
          }
        }

        // Ensure _recentAlbums contains the most recently created albums
        if (_cachedAllAlbums.isNotEmpty) {
          final sortedAlbums = List<Album>.from(_cachedAllAlbums);
          sortedAlbums.sort((a, b) {
            final aDate = a.created ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.created ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });
          _recentAlbums = sortedAlbums.take(20).toList();
        }
      } catch (e) {
        debugPrint('Error loading library from DB: $e');
      }

      final lastUpdate = prefs.getInt(_lastUpdateKey);
      if (lastUpdate != null) {
        _lastCacheUpdate = DateTime.fromMillisecondsSinceEpoch(lastUpdate);
      }
    } catch (e) {
      debugPrint('Error loading cached data: $e');
    }
  }

  void _scheduleBackgroundRefresh() {
    final shouldRefresh = _cachedAllSongs.isEmpty ||
        _lastCacheUpdate == null ||
        DateTime.now().difference(_lastCacheUpdate!) > const Duration(hours: 1);

    if (shouldRefresh) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _refreshAllDataInBackground();
      });
    }
  }

  Future<void> _refreshAllDataInBackground() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('[LibraryProvider] Refreshing library and syncing user data...');

      // Clean up any unrequested media
      await _db.cleanupUnsavedLibraryData();

      // Sync with Groovy Cloud MySQL backend if authenticated
      try {
        final token = await StorageService().getUserToken();
        if (token != null && token.isNotEmpty) {
          final cloudFavs = await GroovyApiService().getFavorites(token);
          for (final s in cloudFavs) {
            final songToAdd = s.copyWith(starred: true, created: s.created ?? DateTime.now());
            await _db.insertOrUpdateSong(songToAdd);
          }
        }
      } catch (e) {
        debugPrint('[LibraryProvider] Cloud sync note: $e');
      }

      _cachedAllSongs = await _db.getAllSongs();
      _cachedAllAlbums = await _db.getAllAlbums();
      _artists = await _db.getAllArtists();
      _lastCacheUpdate = DateTime.now();

      await _saveCachedData();
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing all data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveCachedData() async {
    try {
      // Persist large collections (songs/albums) to SQLite instead of
      // SharedPreferences JSON to avoid OutOfMemoryError with 100k+ tracks.
      await _db.insertAlbumsBatch(_cachedAllAlbums);
      await _db.insertSongsBatch(_cachedAllSongs);

      final prefs = await SharedPreferences.getInstance();

      // Playlists and artists are small enough to keep in SharedPreferences
      final playlistsJson = json.encode(
        _cachedPlaylists.map((p) => p.toJson()).toList(),
      );
      await prefs.setString(_playlistsCacheKey, playlistsJson);

      if (_artists.isNotEmpty) {
        final artistsJson = json.encode(
          _artists.map((a) => a.toJson()).toList(),
        );
        await prefs.setString(_artistsCacheKey, artistsJson);
      }

      await prefs.setInt(
        _lastUpdateKey,
        _lastCacheUpdate?.millisecondsSinceEpoch ??
            DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('Error saving cached data: $e');
    }
  }

  /// Make sure the library is loaded before serving Android Auto browse
  /// requests (the headless engine starts with an empty provider).
  Future<void> _ensureInitializedForAuto() async {
    if (_isInitialized) return;
    if (!_isLoading) {
      try {
        await initialize();
      } catch (e) {
        debugPrint('LibraryProvider: initialize for Android Auto failed: $e');
      }
      return;
    }
    // Another initialize() is already in flight; wait for it (bounded).
    for (var i = 0; i < 100 && _isLoading && !_isInitialized; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<Set<String>> _downloadedSongIdsForAuto() async {
    final offlineService = OfflineService();
    await offlineService.initialize();
    return offlineService.getDownloadedSongIds().toSet();
  }

  Future<List<Map<String, dynamic>>> _recentSongsForAuto() async {
    await _ensureInitializedForAuto();
    // In YT Stream mode there is no classic "recent albums" concept;
    // use the locally cached songs from the SQLite DB (populated by previous
    // sessions) as the "Recent" section so the browse tree is not empty.
    var songs = _youtubeService.isYoutube
        ? (_cachedAllSongs.isNotEmpty ? _cachedAllSongs : _randomSongs)
        : _randomSongs;
    if (_serverOfflineMode) {
      final downloadedIds = await _downloadedSongIdsForAuto();
      songs =
          _cachedAllSongs.where((s) => downloadedIds.contains(s.id)).toList();
    }
    return songs
        .take(50)
        .map(
          (song) => {
            'id': song.id,
            'title': song.title,
            'artist': song.artist,
            'album': song.album,
            'duration': song.duration,
            'artworkUrl': getCoverArtUrl(song.coverArt),
          },
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> _albumsForAuto() async {
    await _ensureInitializedForAuto();
    var albums = _cachedAllAlbums.isNotEmpty ? _cachedAllAlbums : _recentAlbums;
    if (_serverOfflineMode) {
      final downloadedIds = await _downloadedSongIdsForAuto();
      final offlineAlbumIds = _cachedAllSongs
          .where((s) => downloadedIds.contains(s.id))
          .map((s) => s.albumId)
          .whereType<String>()
          .toSet();
      albums = albums.where((a) => offlineAlbumIds.contains(a.id)).toList();
    }
    return albums
        .take(50)
        .map(
          (album) => {
            'id': album.id,
            'title': album.name,
            'artist': album.artist,
            'songCount': album.songCount,
            'artworkUrl': getCoverArtUrl(album.coverArt),
          },
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> _artistsForAuto() async {
    await _ensureInitializedForAuto();
    var artists = _artists;
    if (_serverOfflineMode) {
      final downloadedIds = await _downloadedSongIdsForAuto();
      final offlineArtistIds = _cachedAllSongs
          .where((s) => downloadedIds.contains(s.id))
          .map((s) => s.artistId)
          .whereType<String>()
          .toSet();
      artists = artists.where((a) => offlineArtistIds.contains(a.id)).toList();
    }
    return artists
        .take(50)
        .map(
          (artist) => {
            'id': artist.id,
            'name': artist.name,
            'albumCount': artist.albumCount,
            'artworkUrl': getCoverArtUrl(artist.coverArt),
          },
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> _playlistsForAuto() async {
    await _ensureInitializedForAuto();
    return _playlists
        .take(50)
        .map(
          (playlist) => {
            'id': playlist.id,
            'title': playlist.name,
            'songCount': playlist.songCount,
            'artworkUrl': getCoverArtUrl(playlist.coverArt),
          },
        )
        .toList();
  }

  void _preloadCoverArt() {
    Future.microtask(() async {
      final allAlbums = [..._recentAlbums, ..._randomAlbums, ..._frequentAlbums, ..._newestAlbums];
      for (final album in allAlbums.take(50)) {
        if (album.coverArt != null) {
          try {
            final url = _youtubeService.getCoverArtUrl(
              album.coverArt,
              size: 300,
            );
            if (url.isNotEmpty) {
              CachedNetworkImageProvider(url).resolve(ImageConfiguration.empty);
            }
          } catch (_) {}
        }
      }
    });
  }

  Future<void> refresh() async {
    _isInitialized = false;
    _lastCacheUpdate = null; // force full re-sync
    await initialize();

    // Force immediate full background refresh if server is reachable.
    if (!_serverOfflineMode && !_localOnlyMode) {
      _refreshAllDataInBackground();
    }
  }

  Future<void> loadArtists() async {
    try {
      final localArtists = await _db.getAllArtists();

      final map = <String, Artist>{};
      for (final a in localArtists) {
        map[a.id] = a;
      }

      if (map.isEmpty && _cachedAllSongs.isNotEmpty) {
        for (final s in _cachedAllSongs) {
          if (s.artist != null && s.artist!.trim().isNotEmpty) {
            final aName = s.artist!.trim();
            final aId = s.artistId ?? 'artist_${aName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
            if (!map.containsKey(aId)) {
              final art = Artist(id: aId, name: aName, coverArt: s.coverArt, albumCount: 1);
              map[aId] = art;
              _db.insertOrUpdateArtist(art).catchError((_) {});
            }
          }
        }
      }

      _artists = map.values.toList();
      _artists.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      notifyListeners();
      _audioHandler.notifyAutoChildrenChanged([MuslyAudioHandler.mediaIdArtists]);
      _saveCachedData();
    } catch (e) {
      debugPrint('Error loading artists: $e');
    }
  }

  Future<void> updateArtistCoverArt(String artistId, String coverArt, {String? artistName}) async {
    try {
      bool updated = false;
      for (int i = 0; i < _artists.length; i++) {
        final a = _artists[i];
        if (a.id == artistId || (artistName != null && a.name.toLowerCase() == artistName.toLowerCase())) {
          _artists[i] = Artist(
            id: a.id,
            name: a.name,
            coverArt: coverArt,
            albumCount: a.albumCount,
            artistImageUrl: coverArt,
            isLocal: a.isLocal,
          );
          updated = true;
          _db.insertOrUpdateArtist(_artists[i]).catchError((_) {});
          break;
        }
      }
      if (updated) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[Library] updateArtistCoverArt error: $e');
    }
  }

  Future<void> loadRecentAlbums() async {
    try {
      List<Album> fetched = [];
      if (!_serverOfflineMode) {
        try {
          fetched = await _youtubeService.getAlbumList(type: 'recent', size: 20);
        } catch (_) {}
      }

      if (fetched.isNotEmpty) {
        _recentAlbums = fetched;
      } else {
        final albums = List<Album>.from(_cachedAllAlbums);
        albums.sort((a, b) {
          final aDate = a.created ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.created ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });
        _recentAlbums = albums.take(20).toList();
      }

      notifyListeners();
      _audioHandler.notifyAutoChildrenChanged([MuslyAudioHandler.mediaIdAlbums]);
    } catch (e) {
      debugPrint('Error loading recent albums: $e');
    }
  }

  Future<void> loadFrequentAlbums() async {
    if (_serverOfflineMode) return;
    try {
      _frequentAlbums = await _youtubeService.getAlbumList(
        type: 'frequent',
        size: 20,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading frequent albums: $e');
    }
  }

  Future<void> loadNewestAlbums() async {
    if (_serverOfflineMode) return;
    try {
      _newestAlbums = await _youtubeService.getAlbumList(
        type: 'newest',
        size: 20,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading newest albums: $e');
    }
  }

  Future<void> loadRandomAlbums() async {
    if (_serverOfflineMode) return;
    try {
      _randomAlbums = await _youtubeService.getAlbumList(
        type: 'random',
        size: 20,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading random albums: $e');
    }
  }

  Future<void> loadPlaylists() async {
    try {
      List<Playlist> serverPlaylists = [];
      if (!_serverOfflineMode) {
        try {
          serverPlaylists = await _youtubeService.getPlaylists();
        } catch (_) {}
      }
      final localPlaylists = await _db.getAllPlaylists();

      final map = <String, Playlist>{};
      for (final p in serverPlaylists) {
        map[p.id] = p;
      }
      for (final p in localPlaylists) {
        map[p.id] = p;
      }

      _playlists = map.values.toList();
      _cachedPlaylists = _playlists;
      _saveCachedData();
      notifyListeners();
      _audioHandler
          .notifyAutoChildrenChanged([MuslyAudioHandler.mediaIdPlaylists]);
    } catch (e) {
      debugPrint('Error loading playlists: $e');
      if (_playlists.isEmpty && _cachedPlaylists.isNotEmpty) {
        _playlists = _cachedPlaylists;
        notifyListeners();
      }
    }
  }

  Future<void> loadRandomSongs() async {
    if (_serverOfflineMode) return;
    try {
      _randomSongs = await _youtubeService.getRandomSongs(size: 50);
      notifyListeners();
      _audioHandler
          .notifyAutoChildrenChanged([MuslyAudioHandler.mediaIdRecent]);
    } catch (e) {
      debugPrint('Error loading random songs: $e');
    }
  }

  Future<void> loadGenres() async {
    if (_serverOfflineMode) return;
    try {
      _richGenres = await _youtubeService.getGenres();
      _genres = _richGenres.map((g) => g.value).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading genres: $e');
    }
  }

  Future<void> loadStarred() async {
    if (_serverOfflineMode) return;
    try {
      _starred = await _youtubeService.getStarred();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading starred: $e');
    }
  }

  Future<List<Album>> getArtistAlbums(String artistId) async {
    if (_localOnlyMode && _localMusicService != null) {
      return _localMusicService!.getAlbumsByArtist(artistId);
    }
    try {
      final albums = await _youtubeService.getArtistAlbums(artistId);
      if (albums.isNotEmpty) return albums;
    } catch (e) {
      debugPrint('Error loading artist albums: $e');
    }

    final localAlbums = _cachedAllAlbums.where((a) => a.artistId == artistId || (a.artist != null && a.artist!.toLowerCase() == artistId.toLowerCase())).toList();
    if (localAlbums.isNotEmpty) return localAlbums;

    final dbAlbums = await _db.getAllAlbums();
    return dbAlbums.where((a) => a.artistId == artistId || (a.artist != null && a.artist!.toLowerCase() == artistId.toLowerCase())).toList();
  }

  Future<List<Song>> getAlbumSongs(String albumId) async {
    if (_localOnlyMode && _localMusicService != null) {
      return _localMusicService!.getSongsByAlbum(albumId);
    }
    try {
      final songs = await _youtubeService.getAlbumSongs(albumId);
      if (songs.isNotEmpty) return songs;
    } catch (e) {
      debugPrint('Error loading album songs: $e');
    }

    final localSongs = _cachedAllSongs.where((s) => s.albumId == albumId || (s.album != null && s.album!.toLowerCase() == albumId.toLowerCase())).toList();
    if (localSongs.isNotEmpty) return localSongs;

    final dbSongs = await _db.getAllSongs();
    return dbSongs.where((s) => s.albumId == albumId || (s.album != null && s.album!.toLowerCase() == albumId.toLowerCase())).toList();
  }

  Future<Playlist> getPlaylist(String playlistId) async {
    if (_serverOfflineMode) {
      final cached = _playlists.firstWhere(
        (p) => p.id == playlistId,
        orElse: () => _cachedPlaylists.firstWhere(
          (p) => p.id == playlistId,
          orElse: () => throw Exception('Playlist not available offline'),
        ),
      );
      return cached;
    }

    try {
      final playlist = await _youtubeService.getPlaylist(playlistId);

      final index = _playlists.indexWhere((p) => p.id == playlistId);
      if (index != -1) {
        _playlists[index] = playlist;
      } else {
        _playlists.add(playlist);
      }

      _cachedPlaylists = List.from(_playlists);
      _saveCachedData();
      notifyListeners();

      return playlist;
    } catch (e) {
      debugPrint('Error loading playlist details: $e');

      final cachedPlaylist = _playlists.firstWhere(
        (p) => p.id == playlistId,
        orElse: () => throw e,
      );

      if (cachedPlaylist.songs != null && cachedPlaylist.songs!.isNotEmpty) {
        return cachedPlaylist;
      }

      rethrow;
    }
  }

  Future<void> createPlaylist(String name, {List<String>? songIds}) async {
    try {
      await _youtubeService.createPlaylist(name: name, songIds: songIds);
    } catch (e) {
      debugPrint('[Library] createPlaylist error, using fallback: $e');
      final newId = 'pl_${DateTime.now().millisecondsSinceEpoch}';
      final playlist = Playlist(
        id: newId,
        name: name,
        songCount: songIds?.length ?? 0,
        created: DateTime.now(),
        changed: DateTime.now(),
      );
      await _db.insertOrUpdatePlaylist(playlist);
    }

    // Sync with Groovy Cloud MySQL backend if authenticated
    try {
      final token = await StorageService().getUserToken();
      if (token != null && token.isNotEmpty) {
        GroovyApiService().createPlaylist(token, name).catchError((_) => null);
      }
    } catch (e) {
      debugPrint('[Library] Cloud playlist sync note: $e');
    }

    await loadPlaylists();
  }

  Future<void> deletePlaylist(String playlistId) async {
    try {
      await _youtubeService.deletePlaylist(playlistId);
    } catch (_) {}
    await _db.deletePlaylist(playlistId);
    await loadPlaylists();
  }

  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    await _youtubeService.updatePlaylist(
      playlistId: playlistId,
      songIdsToAdd: [songId],
    );
  }

  SearchResult searchLocal(String query) => _searchLocal(query);

  Future<SearchResult> search(String query, {bool includeOnline = true}) async {
    final localResult = _searchLocal(query);
    if (!includeOnline || _localOnlyMode) {
      return localResult;
    }

    try {
      final ytResults = await _youtubeService.search(query, songCount: 20);

      final existingIds = localResult.songs.map((s) => s.id).toSet();
      final extraSongs = ytResults.songs
          .where((s) => !existingIds.contains(s.id))
          .toList();

      return SearchResult(
        artists: ytResults.artists.isNotEmpty
            ? ytResults.artists
            : localResult.artists,
        albums: ytResults.albums.isNotEmpty
            ? ytResults.albums
            : localResult.albums,
        songs: [
          ...localResult.songs,
          ...extraSongs,
        ],
        youtubeVideos: ytResults.youtubeVideos,
      );
    } catch (e) {
      debugPrint('[Search] YouTube search error: $e');
      return localResult;
    }
  }

  SearchResult _searchLocal(String query) {
    final q = query.toLowerCase();
    final songs = _cachedAllSongs
        .where(
          (s) =>
              s.title.toLowerCase().contains(q) ||
              (s.artist?.toLowerCase().contains(q) ?? false) ||
              (s.album?.toLowerCase().contains(q) ?? false),
        )
        .take(50)
        .toList();
    final artists = _artists
        .where((a) => a.name.toLowerCase().contains(q))
        .take(20)
        .toList();
    final albums = _cachedAllAlbums
        .where(
          (a) =>
              a.name.toLowerCase().contains(q) ||
              (a.artist?.toLowerCase().contains(q) ?? false),
        )
        .take(20)
        .toList();
    return SearchResult(songs: songs, artists: artists, albums: albums);
  }

  Future<void> addSongToLibrary(Song song) async {
    final songToAdd = (song.created != null)
        ? song
        : song.copyWith(created: DateTime.now());

    final index = _cachedAllSongs.indexWhere((s) => s.id == songToAdd.id);
    if (index != -1) {
      _cachedAllSongs[index] = songToAdd;
    } else {
      _cachedAllSongs.insert(0, songToAdd);
    }
    await _db.insertOrUpdateSong(songToAdd);

    // Ensure artist exists in library
    if (songToAdd.artist != null && songToAdd.artist!.trim().isNotEmpty) {
      final artistName = songToAdd.artist!.trim();
      final artistId = songToAdd.artistId ?? 'artist_${artistName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
      final existingArtistIndex = _artists.indexWhere(
        (a) => a.id == artistId || a.name.trim().toLowerCase() == artistName.toLowerCase(),
      );
      if (existingArtistIndex == -1) {
        final newArtist = Artist(
          id: artistId,
          name: artistName,
          coverArt: songToAdd.coverArt,
          albumCount: 1,
        );
        _artists.insert(0, newArtist);
        await _db.insertOrUpdateArtist(newArtist);
      }
    }

    // Ensure album exists in library
    final albumName = (songToAdd.album != null && songToAdd.album!.trim().isNotEmpty)
        ? songToAdd.album!.trim()
        : '${songToAdd.title.trim()} - Single';
    final albumId = songToAdd.albumId ?? 'album_${albumName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
    final existingAlbumIndex = _cachedAllAlbums.indexWhere(
      (a) => a.id == albumId || a.name.trim().toLowerCase() == albumName.toLowerCase(),
    );
    final Album targetAlbum;
    if (existingAlbumIndex == -1) {
      final newAlbum = Album(
        id: albumId,
        name: albumName,
        artist: songToAdd.artist,
        artistId: songToAdd.artistId,
        coverArt: songToAdd.coverArt,
        songCount: 1,
        year: songToAdd.year,
        created: DateTime.now(),
      );
      _cachedAllAlbums.insert(0, newAlbum);
      await _db.insertOrUpdateAlbum(newAlbum);
      targetAlbum = newAlbum;
    } else {
      targetAlbum = _cachedAllAlbums[existingAlbumIndex];
    }

    _recentAlbums.removeWhere((a) => a.id == targetAlbum.id);
    _recentAlbums.insert(0, targetAlbum);

    notifyListeners();
  }

  Future<void> removeSongFromLibrary(Song song) async {
    _cachedAllSongs.removeWhere((s) => s.id == song.id);
    await _db.deleteSong(song.id);

    // If no other song has this album, remove album
    final otherWithAlbum = _cachedAllSongs.any(
      (s) => (s.albumId != null && s.albumId == song.albumId) ||
             (s.album != null && s.album == song.album),
    );
    if (!otherWithAlbum) {
      _cachedAllAlbums.removeWhere((a) => a.id == song.albumId || a.name == song.album);
      _recentAlbums.removeWhere((a) => a.id == song.albumId || a.name == song.album);
      if (song.albumId != null) {
        await _db.deleteAlbum(song.albumId!);
      }
    }

    // If no other song has this artist, remove artist
    final otherWithArtist = _cachedAllSongs.any(
      (s) => (s.artistId != null && s.artistId == song.artistId) ||
             (s.artist != null && s.artist == song.artist),
    );
    if (!otherWithArtist) {
      _artists.removeWhere((a) => a.id == song.artistId || a.name == song.artist);
      if (song.artistId != null) {
        await _db.deleteArtist(song.artistId!);
      }
    }

    notifyListeners();
  }

  bool isSongStarred(String songId) {
    if (songId.isEmpty) return false;
    if (_starred != null && _starred!.songs.any((s) => s.id == songId)) {
      return true;
    }
    final inCache = _cachedAllSongs.firstWhere(
      (s) => s.id == songId,
      orElse: () => Song(id: '', title: ''),
    );
    if (inCache.id.isNotEmpty && inCache.starred == true) {
      return true;
    }
    return false;
  }

  Future<bool> toggleStarSong(Song song) async {
    final bool currentStarred = isSongStarred(song.id) || (song.starred ?? false);
    final bool newStarred = !currentStarred;
    final updatedSong = song.copyWith(starred: newStarred);

    // Update in cached songs
    final idx = _cachedAllSongs.indexWhere((s) => s.id == song.id);
    if (idx >= 0) {
      _cachedAllSongs[idx] = updatedSong;
    } else if (newStarred) {
      _cachedAllSongs.insert(0, updatedSong);
    }

    // Update in _starred object if initialized
    if (_starred != null) {
      final currentSongs = List<Song>.from(_starred!.songs);
      if (newStarred) {
        if (!currentSongs.any((s) => s.id == song.id)) {
          currentSongs.insert(0, updatedSong);
        }
      } else {
        currentSongs.removeWhere((s) => s.id == song.id);
      }
      _starred = SearchResult(
        artists: _starred!.artists,
        albums: _starred!.albums,
        songs: currentSongs,
        youtubeVideos: _starred!.youtubeVideos,
      );
    }

    await addSongToLibrary(updatedSong);
    await _db.setSongStarred(song.id, newStarred);

    // Sync with Groovy Cloud MySQL backend
    try {
      final token = await StorageService().getUserToken();
      if (token != null && token.isNotEmpty) {
        if (newStarred) {
          GroovyApiService().addFavorite(token, updatedSong).catchError((_) => false);
        } else {
          GroovyApiService().removeFavorite(token, song.id).catchError((_) => false);
        }
      }
    } catch (e) {
      debugPrint('[Library] Groovy Cloud sync note: $e');
    }

    final isYt = song.id.startsWith('yt_') || song.id.startsWith('ytmusic://') || (song.path?.contains('youtube') ?? false);
    if (!isYt && song.isLocal != true) {
      try {
        if (newStarred) {
          await _youtubeService.star(id: song.id);
        } else {
          await _youtubeService.unstar(id: song.id);
        }
      } catch (e) {
        debugPrint('[Library] Server star sync error: $e');
      }
    }

    await loadStarred();
    notifyListeners();
    return newStarred;
  }

  Future<List<Song>> getStarredSongs() async {
    final dbSongs = await _db.getStarredSongs();
    final starredMap = <String, Song>{};
    for (final s in dbSongs) {
      starredMap[s.id] = s;
    }

    // Fetch from Groovy MySQL Cloud backend if authenticated
    try {
      final token = await StorageService().getUserToken();
      if (token != null && token.isNotEmpty) {
        final cloudFavs = await GroovyApiService().getFavorites(token);
        for (final s in cloudFavs) {
          starredMap[s.id] = s;
          _db.insertOrUpdateSong(s).catchError((_) {});
          _db.setSongStarred(s.id, true).catchError((_) {});
        }
      }
    } catch (e) {
      debugPrint('[Library] Cloud favorites sync note: $e');
    }

    if (_starred != null && _starred!.songs.isNotEmpty) {
      for (final s in _starred!.songs) {
        starredMap[s.id] = s;
      }
    }
    for (final s in _cachedAllSongs) {
      if (s.starred == true) {
        starredMap[s.id] = s;
      }
    }
    return starredMap.values.toList();
  }

  Future<void> star({String? songId, String? albumId, String? artistId}) async {
    await _youtubeService.star(
      id: songId,
      albumId: albumId,
      artistId: artistId,
    );
    await loadStarred();
  }

  bool isAlbumStarred(String albumId) {
    if (_starred?.albums.any((a) => a.id == albumId) == true) return true;
    if (_cachedAllAlbums.any((a) => a.id == albumId && a.starred == true)) return true;
    return false;
  }

  Future<void> unstar({
    String? songId,
    String? albumId,
    String? artistId,
  }) async {
    await _youtubeService.unstar(
      id: songId,
      albumId: albumId,
      artistId: artistId,
    );
    await loadStarred();
  }

  Future<List<Song>> getSongsByGenre(String genre) async {
    try {
      return await _youtubeService.getSongsByGenre(genre);
    } catch (e) {
      debugPrint('Error loading songs by genre: $e');
      return [];
    }
  }

  Future<List<Album>> getAlbumsByGenre(String genre) async {
    try {
      return await _youtubeService.getAlbumsByGenre(genre);
    } catch (e) {
      debugPrint('Error loading albums by genre: $e');
      return [];
    }
  }

  Future<List<Song>> getAllSongs() async {
    try {
      final allArtists = await _youtubeService.getArtists();

      final List<Song> allSongs = [];

      for (final artist in allArtists) {
        try {
          final artistAlbums = await _youtubeService.getArtistAlbums(
            artist.id,
          );
          for (final album in artistAlbums) {
            try {
              final songs = await _youtubeService.getAlbumSongs(album.id);
              allSongs.addAll(songs);
            } catch (e) {
              debugPrint('Error loading album ${album.id}: $e');
            }
          }
        } catch (e) {
          debugPrint('Error loading albums for artist ${artist.name}: $e');
        }
      }

      return allSongs;
    } catch (e) {
      debugPrint('Error loading all songs: $e');
      return [];
    }
  }

  Future<List<Album>> getAllAlbums() async {
    try {
      final allArtists = await _youtubeService.getArtists();

      final List<Album> allAlbums = [];

      for (final artist in allArtists) {
        try {
          final artistAlbums = await _youtubeService.getArtistAlbums(
            artist.id,
          );
          allAlbums.addAll(artistAlbums);
        } catch (e) {
          debugPrint('Error loading albums for artist ${artist.name}: $e');
        }
      }

      return allAlbums;
    } catch (e) {
      debugPrint('Error loading all albums: $e');
      return [];
    }
  }

  @override
  void dispose() {
    _localMusicService?.removeListener(_onLocalMusicServiceChanged);
    super.dispose();
  }
}
