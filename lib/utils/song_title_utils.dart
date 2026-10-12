/// Utility to normalize song titles and eliminate duplicate/repetitive
/// tracks (e.g. video vs audio vs lyric video vs live versions).
class SongTitleUtils {
  static final RegExp _multiSpaceRegex = RegExp(r'\s+');

  static final List<RegExp> _noisePatterns = [
    RegExp(
      r'\((?:official|music|video|audio|lyrics?|lyric video|visualizer|360° visualizer|hd|4k|remastered|live|explicit|clip|video oficial|clip officiel|en vivo|audio oficial|letra|letra / lyrics|karaoke|extended|slowed|reverb).*?\)',
      caseSensitive: false,
    ),
    RegExp(
      r'\[(?:official|music|video|audio|lyrics?|lyric video|visualizer|360° visualizer|hd|4k|remastered|live|explicit|clip|video oficial|clip officiel|en vivo|audio oficial|letra|letra / lyrics|karaoke|extended|slowed|reverb).*?\]',
      caseSensitive: false,
    ),
    RegExp(r'\((?:feat\.|ft\.|featuring).*?\)', caseSensitive: false),
    RegExp(r'\[(?:feat\.|ft\.|featuring).*?\]', caseSensitive: false),
    RegExp(r'(?:feat\.|ft\.|featuring).*$', caseSensitive: false),
    RegExp(r'\(prod\..*?\)', caseSensitive: false),
    RegExp(r'\[prod\..*?\]', caseSensitive: false),
    RegExp(
      r'\b(?:official music video|official video|video oficial|audio oficial|lyric video|video lyric|lyrics|letra|visualizer)\b',
      caseSensitive: false,
    ),
  ];

  static const _withDia =
      'ÀÁÂÃÄÅàáâãäåÒÓÔÕÖØòóôõöøÈÉÊËèéêëÌÍÎÏìíîïÙÚÛÜùúûüÝýÿÑñÇç';
  static const _withoutDia =
      'AAAAAAaaaaaaOOOOOOooooooEEEEeeeeIIIIiiiiUUUUuuuuYyyNnCc';

  static String removeDiacritics(String text) {
    var result = text;
    for (int i = 0; i < _withDia.length; i++) {
      result = result.replaceAll(_withDia[i], _withoutDia[i]);
    }
    return result;
  }

  /// Normalizes a song title to its canonical form for deduplication:
  /// - Strips leading artist prefix if formatted like "Artist - Title"
  /// - Strips common video / audio / lyrics tags in parentheses or brackets
  /// - Removes punctuation, diacritics, and excess spaces
  static String normalizeTitle(String? rawTitle) {
    if (rawTitle == null) return '';
    var title = rawTitle.trim();
    if (title.isEmpty) return '';

    // If formatted as "Artist - Title", extract title
    if (title.contains(' - ')) {
      final parts = title.split(' - ');
      if (parts.length >= 2) {
        title = parts.sublist(1).join(' - ');
      }
    }

    for (final pattern in _noisePatterns) {
      title = title.replaceAll(pattern, ' ');
    }

    // Remove quotes and punctuation
    title = title
        .replaceAll('"', '')
        .replaceAll("'", '')
        .replaceAll('`', '')
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ');

    final normalized = removeDiacritics(title)
        .toLowerCase()
        .replaceAll(_multiSpaceRegex, ' ')
        .trim();

    return normalized.isNotEmpty
        ? normalized
        : removeDiacritics(rawTitle.toLowerCase().trim());
  }

  /// Checks if two song titles refer to the same song (e.g. "Song" and "Song (Official Audio)").
  static bool areTitlesSame(String? titleA, String? titleB) {
    if (titleA == null || titleB == null) return false;
    final normA = normalizeTitle(titleA);
    final normB = normalizeTitle(titleB);
    if (normA.isEmpty || normB.isEmpty) return false;
    if (normA == normB) return true;

    // Check if one contains or starts with the other with a small length delta
    if (normA.length >= 4 && normB.length >= 4) {
      if (normA.startsWith(normB) || normB.startsWith(normA)) {
        final diff = (normA.length - normB.length).abs();
        if (diff <= 5) return true;
      }
    }

    return false;
  }
}
