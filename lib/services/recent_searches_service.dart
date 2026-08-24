import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

enum RecentSearchType {
  artist,
  album,
  song,
}

class RecentSearchItem {
  final String id;
  final RecentSearchType type;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? extra;
  final Song? song;
  final Album? album;
  final Artist? artist;

  const RecentSearchItem({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.extra,
    this.song,
    this.album,
    this.artist,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'subtitle': subtitle,
    'imageUrl': imageUrl,
    'extra': extra,
    'song': song?.toJson(),
    'album': album != null
        ? {
            'id': album!.id,
            'name': album!.name,
            'artist': album!.artist,
            'coverArt': album!.coverArt,
            'songCount': album!.songCount,
          }
        : null,
    'artist': artist != null
        ? {
            'id': artist!.id,
            'name': artist!.name,
            'coverArt': artist!.coverArt,
          }
        : null,
  };

  factory RecentSearchItem.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'song';
    final type = RecentSearchType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => RecentSearchType.song,
    );

    Song? s;
    if (json['song'] != null) {
      try {
        s = Song.fromJson(json['song'] as Map<String, dynamic>);
      } catch (_) {}
    }

    Album? a;
    if (json['album'] != null) {
      try {
        final m = json['album'] as Map<String, dynamic>;
        a = Album(
          id: m['id'] as String,
          name: m['name'] as String,
          artist: m['artist'] as String?,
          coverArt: m['coverArt'] as String?,
          songCount: m['songCount'] as int?,
        );
      } catch (_) {}
    }

    Artist? art;
    if (json['artist'] != null) {
      try {
        final m = json['artist'] as Map<String, dynamic>;
        art = Artist(
          id: m['id'] as String,
          name: m['name'] as String,
          coverArt: m['coverArt'] as String?,
        );
      } catch (_) {}
    }

    return RecentSearchItem(
      id: json['id'] as String? ?? '',
      type: type,
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      imageUrl: json['imageUrl'] as String?,
      extra: json['extra'] as String?,
      song: s,
      album: a,
      artist: art,
    );
  }
}

class RecentSearchesService extends ChangeNotifier {
  static final RecentSearchesService _instance = RecentSearchesService._internal();
  factory RecentSearchesService() => _instance;
  RecentSearchesService._internal();

  static const String _storageKey = 'groovy_recent_searches';
  List<RecentSearchItem> _items = [];

  List<RecentSearchItem> get items => List.unmodifiable(_items);

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> list = jsonDecode(raw);
        _items = list
            .map((e) => RecentSearchItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('[RecentSearchesService] load error: $e');
    }
    notifyListeners();
  }

  Future<void> addItem(RecentSearchItem item) async {
    _items.removeWhere((i) => i.id == item.id && i.type == item.type);
    _items.insert(0, item);
    if (_items.length > 30) {
      _items = _items.sublist(0, 30);
    }
    notifyListeners();
    await _save();
  }

  Future<void> addSong(Song song, {String? lyrics}) async {
    await addItem(RecentSearchItem(
      id: song.id,
      type: RecentSearchType.song,
      title: song.title,
      subtitle: 'Canción • ${song.artist ?? "Desconocido"}',
      imageUrl: song.coverArt,
      extra: lyrics,
      song: song,
    ));
  }

  Future<void> addAlbum(Album album) async {
    await addItem(RecentSearchItem(
      id: album.id,
      type: RecentSearchType.album,
      title: album.name,
      subtitle: 'Álbum • ${album.artist ?? "Varios Artistas"}',
      imageUrl: album.coverArt,
      album: album,
    ));
  }

  Future<void> addArtist(Artist artist) async {
    await addItem(RecentSearchItem(
      id: artist.id,
      type: RecentSearchType.artist,
      title: artist.name,
      subtitle: 'Artista',
      imageUrl: artist.coverArt,
      artist: artist,
    ));
  }

  Future<void> removeItem(String id, RecentSearchType type) async {
    _items.removeWhere((i) => i.id == id && i.type == type);
    notifyListeners();
    await _save();
  }

  Future<void> clear() async {
    _items.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_items.map((i) => i.toJson()).toList());
      await prefs.setString(_storageKey, raw);
    } catch (e) {
      debugPrint('[RecentSearchesService] save error: $e');
    }
  }
}
