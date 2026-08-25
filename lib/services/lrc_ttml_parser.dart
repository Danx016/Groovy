import '../models/lyric_line.dart';
import '../models/lyric_word.dart';

class LrcParser {
  /// Parses standard & enhanced LRC content, handling multiple timestamps,
  /// offsets, word-by-word timing, and non-standard timecode formats.
  static List<LyricLine> parseLrc(String content) {
    if (content.trim().isEmpty) return [];

    final lines = content.split('\n');
    final List<LyricLine> parsedLines = [];
    int offsetMillis = 0;

    // Regex for time tags: [mm:ss.xx] or [h:mm:ss.xx] or [mm:ss:xx] or [mm:ss]
    final RegExp timeTagRegex = RegExp(r'\[(\d{1,2}):(\d{2})(?:(?:\.|\:)(\d{2,3}))?\]');
    // Regex for offset tag: [offset:+/-1000]
    final RegExp offsetRegex = RegExp(r'\[offset:\s*([+-]?\d+)\s*\]', caseSensitive: false);
    // Metadata tags: [ar:xxx], [ti:xxx], etc.
    final RegExp metadataRegex = RegExp(r'\[(?:ar|ti|al|by|length|re|ve|encoding):\s*.*?\]', caseSensitive: false);
    // Word-by-word timestamp regex: <mm:ss.xx>word or <mm:ss>word
    final RegExp wordTagRegex = RegExp(r'<(\d{1,2}):(\d{2})(?:(?:\.|\:)(\d{2,3}))?>');

    // 1. First pass: extract offset if present
    for (final line in lines) {
      final offMatch = offsetRegex.firstMatch(line.trim());
      if (offMatch != null) {
        offsetMillis = int.tryParse(offMatch.group(1)!) ?? 0;
        break;
      }
    }

    // 2. Parse lines
    final List<String> unparsedPlainLines = [];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Skip metadata tags
      if (offsetRegex.hasMatch(line) || metadataRegex.hasMatch(line)) {
        continue;
      }

      final matches = timeTagRegex.allMatches(line).toList();
      if (matches.isNotEmpty) {
        // Line can have multiple time tags, e.g.: [00:12.30][01:14.50]Hello
        final textWithoutTags = line.replaceAll(timeTagRegex, '').trim();

        // Check for word-by-word tags in the text
        List<LyricWord>? words;
        String cleanLineText = textWithoutTags;

        if (wordTagRegex.hasMatch(textWithoutTags)) {
          words = _parseWordTimestamps(textWithoutTags, offsetMillis);
          cleanLineText = textWithoutTags.replaceAll(wordTagRegex, '').trim();
        }

        if (cleanLineText.isNotEmpty) {
          for (final match in matches) {
            final duration = _parseTimestampMatch(match, offsetMillis);
            parsedLines.add(LyricLine(
              text: cleanLineText,
              startTime: duration,
              words: words,
            ));
          }
        }
      } else {
        // Collect as potential plain text if no timestamps in the whole file
        if (!metadataRegex.hasMatch(line)) {
          unparsedPlainLines.add(line);
        }
      }
    }

    // If no timestamps found at all, treat as unsynced plain text
    if (parsedLines.isEmpty) {
      for (final text in unparsedPlainLines) {
        parsedLines.add(LyricLine(
          text: text,
          startTime: Duration.zero,
        ));
      }
      return parsedLines;
    }

    // Sort chronologically by start time
    parsedLines.sort((a, b) => a.startTime.compareTo(b.startTime));

    // Calculate approximate end times for lines
    for (var i = 0; i < parsedLines.length - 1; i++) {
      final current = parsedLines[i];
      final next = parsedLines[i + 1];
      parsedLines[i] = LyricLine(
        text: current.text,
        startTime: current.startTime,
        endTime: next.startTime > current.startTime
            ? next.startTime - const Duration(milliseconds: 1)
            : current.startTime + const Duration(seconds: 4),
        words: current.words,
      );
    }

    // Assign a reasonable end time for the last line
    if (parsedLines.isNotEmpty) {
      final last = parsedLines.last;
      parsedLines[parsedLines.length - 1] = LyricLine(
        text: last.text,
        startTime: last.startTime,
        endTime: last.startTime + const Duration(seconds: 6),
        words: last.words,
      );
    }

    return parsedLines;
  }

  static Duration _parseTimestampMatch(Match match, int offsetMillis) {
    final minutes = int.parse(match.group(1)!);
    final seconds = int.parse(match.group(2)!);
    final fracStr = match.group(3);

    int milliseconds = 0;
    if (fracStr != null) {
      if (fracStr.length == 1) {
        milliseconds = int.parse(fracStr) * 100;
      } else if (fracStr.length == 2) {
        milliseconds = int.parse(fracStr) * 10;
      } else {
        milliseconds = int.parse(fracStr);
      }
    }

    final totalMillis = (minutes * 60000) + (seconds * 1000) + milliseconds + offsetMillis;
    return Duration(milliseconds: totalMillis > 0 ? totalMillis : 0);
  }

  static List<LyricWord>? _parseWordTimestamps(String textWithWordTags, int offsetMillis) {
    final List<LyricWord> words = [];
    final tagRegex = RegExp(r'<(\d{1,2}):(\d{2})(?:(?:\.|\:)(\d{2,3}))?>');
    final matches = tagRegex.allMatches(textWithWordTags).toList();

    for (int i = 0; i < matches.length; i++) {
      final match = matches[i];
      final startTime = _parseTimestampMatch(match, offsetMillis);

      final wordStart = match.end;
      final wordEnd = (i < matches.length - 1) ? matches[i + 1].start : textWithWordTags.length;
      final wordText = textWithWordTags.substring(wordStart, wordEnd).trim();

      final endTime = (i < matches.length - 1)
          ? _parseTimestampMatch(matches[i + 1], offsetMillis)
          : startTime + const Duration(milliseconds: 600);

      if (wordText.isNotEmpty) {
        words.add(LyricWord(
          text: wordText,
          startTime: startTime,
          endTime: endTime,
        ));
      }
    }

    return words.isNotEmpty ? words : null;
  }
}

