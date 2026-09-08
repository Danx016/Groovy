/// Utility to sanitize, clean, and match album and artist names, preventing
/// raw slug IDs (e.g. `album_mi_mejor_momento`) or placeholder values from
/// being displayed or causing resolution failures.
class AlbumSanitizer {
  static const _placeholders = {
    'album',
    'álbum',
    'unknown album',
    'desconocido',
    'unknown',
    'artist',
    'artista',
    'unknown artist',
  };

  /// Returns true if [text] is null, empty, or a generic placeholder.
  static bool isPlaceholder(String? text) {
    if (text == null) return true;
    final t = text.trim().toLowerCase();
    return t.isEmpty || _placeholders.contains(t);
  }

  /// Returns true if [text] is a placeholder or a technical slug ID.
  static bool isPlaceholderOrSlug(String? text) {
    if (isPlaceholder(text)) return true;
    final t = text!.trim().toLowerCase();
    return t.startsWith('album_') ||
        t.startsWith('local_album_') ||
        t.startsWith('dz_album_') ||
        t.startsWith('mpreb_') ||
        t.startsWith('olak') ||
        t.startsWith('vlolak') ||
        t.startsWith('pl');
  }

  /// Converts a raw album name or technical ID (e.g. `album_mi_mejor_momento`,
  /// `local_album_rock_classics`) into a human-readable, formatted title
  /// (e.g. `Mi Mejor Momento`, `Rock Classics`).
  static String cleanTitle(String? raw) {
    if (raw == null) return '';
    var s = raw.trim();
    if (s.isEmpty) return '';

    if (isPlaceholder(s)) return '';

    // Strip known technical prefixes
    if (s.toLowerCase().startsWith('local_album_')) {
      s = s.substring('local_album_'.length);
    } else if (s.toLowerCase().startsWith('album_')) {
      s = s.substring('album_'.length);
    } else if (s.toLowerCase().startsWith('dz_album_')) {
      s = s.substring('dz_album_'.length);
    }

    // Convert slug underscores to spaces
    if (s.contains('_')) {
      s = s.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    // Capitalize words if the string is all lowercase or all uppercase
    if (s.isNotEmpty && (s == s.toLowerCase() || s == s.toUpperCase())) {
      s = s
          .split(' ')
          .where((w) => w.isNotEmpty)
          .map((w) => w.length > 1
              ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}'
              : w.toUpperCase())
          .join(' ');
    }

    return s.trim();
  }

  /// Cleans artist name and returns null if it's a generic placeholder.
  static String? cleanArtist(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (isPlaceholder(s)) return null;
    return s;
  }

  /// Normalizes a string for fuzzy equality comparisons (strips prefixes, punctuation, spaces).
  static String normalize(String? text) {
    if (text == null) return '';
    var s = text.trim().toLowerCase();
    if (s.startsWith('local_album_')) s = s.substring('local_album_'.length);
    if (s.startsWith('album_')) s = s.substring('album_'.length);
    if (s.startsWith('dz_album_')) s = s.substring('dz_album_'.length);
    return s.replaceAll(RegExp(r'[^a-z0-9áéíóúñü]'), '');
  }

  /// Returns true if [albumA] and [albumB] refer to the same album name or ID.
  static bool matches(String? albumA, String? albumB) {
    if (albumA == null || albumB == null) return false;
    final a = normalize(albumA);
    final b = normalize(albumB);
    if (a.isEmpty || b.isEmpty) return false;
    return a == b;
  }
}
