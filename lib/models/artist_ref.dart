/// A lightweight artist reference representing contributing or featured artists.
class ArtistRef {
  final String id;
  final String name;
  /// Explicit cover art ID or URL from the API response.
  final String? coverArt;

  const ArtistRef({required this.id, required this.name, this.coverArt});

  /// Cover art ID for `getCoverArt`: explicit [coverArt] if set, otherwise [id].
  String? get effectiveCoverArt {
    if (coverArt != null && coverArt!.isNotEmpty) return coverArt;
    return id.isNotEmpty ? id : null;
  }

  factory ArtistRef.fromJson(Map<String, dynamic> json) {
    return ArtistRef(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      coverArt: json['coverArt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (coverArt != null) 'coverArt': coverArt,
  };

  static List<ArtistRef>? parseList(dynamic data) {
    if (data == null || data is! List) return null;
    final list = data
        .whereType<Map<String, dynamic>>()
        .map((e) => ArtistRef.fromJson(e))
        .where((a) => a.id.isNotEmpty || a.name.isNotEmpty)
        .toList();
    return list.isEmpty ? null : list;
  }
}
