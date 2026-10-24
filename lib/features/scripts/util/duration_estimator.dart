import 'dart:math' as math;

/// Speaking-time estimates based on words per minute.
abstract final class DurationEstimator {
  /// Typical conversational speaking rate.
  static const int defaultWpm = 150;

  // \p{M} keeps combining marks (Indic vowel signs, viramas) inside a word;
  // without it, "ಕನ್ನಡ" would count as several words.
  static final _word = RegExp(
    r"[\p{L}\p{N}][\p{L}\p{M}\p{N}'’\-]*",
    unicode: true,
  );

  static int wordCount(String text) => _word.allMatches(text).length;

  /// Estimated seconds to speak [text]. Returns 0 for empty text.
  static int estimateSeconds(String text, {int wpm = defaultWpm}) {
    final words = wordCount(text);
    if (words == 0) return 0;
    return math.max(1, (words * 60 / wpm).round());
  }

  /// Word budget that fits [seconds] of speech.
  static int targetWords(int seconds, {int wpm = defaultWpm}) =>
      math.max(1, (seconds * wpm / 60).round());

  /// Time a cue should stay up when auto-advancing, with a floor so very
  /// short cues remain readable.
  static Duration cueDuration(
    String text, {
    required int wpm,
    Duration minimum = const Duration(milliseconds: 1500),
  }) {
    final ms = (wordCount(text) * 60000 / wpm).round();
    return Duration(milliseconds: math.max(ms, minimum.inMilliseconds));
  }

  /// `45s`, `1:05`, `12:00`.
  static String format(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Human label such as `~45 sec` or `~2 min`.
  static String formatApprox(int seconds) {
    if (seconds <= 0) return '0 sec';
    if (seconds < 60) return '~$seconds sec';
    final minutes = seconds / 60;
    final rounded = minutes < 10
        ? (minutes * 2).round() / 2
        : minutes.round().toDouble();
    final label = rounded == rounded.roundToDouble()
        ? rounded.toInt().toString()
        : rounded.toStringAsFixed(1);
    return '~$label min';
  }
}
