import '../models/cue.dart';
import '../models/script.dart';
import '../models/script_section.dart';

/// Turns script text into sections and short presentation cues.
///
/// Body format: optional Markdown-style heading lines (`## Hook`) start a new
/// section. Without headings, each blank-line-separated paragraph becomes a
/// section.
abstract final class CueSegmenter {
  /// ~3 lines of ~30 characters: comfortable for a glanceable display.
  static const int defaultMaxCueChars = 90;

  static final _heading = RegExp(r'^\s{0,3}#{1,6}\s+(.*)$');
  // "।" (danda) ends sentences in Hindi, Marathi and Bengali.
  static final _sentenceBreak = RegExp(r'(?<=[.!?…।])\s+');
  static final _clauseBreak = RegExp(r'(?<=[,;:—–])\s+');
  static final _whitespace = RegExp(r'\s+');

  static List<ScriptSection> sectionsFromBody(String body) {
    final lines = body.replaceAll('\r\n', '\n').split('\n');
    final hasHeadings = lines.any(_heading.hasMatch);

    final sections = <ScriptSection>[];
    var heading = '';
    final paragraphs = <String>[];
    final current = <String>[];

    void endParagraph() {
      final text = current.join(' ').replaceAll(_whitespace, ' ').trim();
      if (text.isNotEmpty) paragraphs.add(text);
      current.clear();
    }

    void emit(String h, String text) {
      if (text.isEmpty) return;
      sections.add(
        ScriptSection(
          id: 'section-${sections.length + 1}',
          heading: h,
          spokenText: text,
        ),
      );
    }

    void endSection() {
      endParagraph();
      if (hasHeadings) {
        emit(heading, paragraphs.join('\n\n'));
      } else {
        for (final p in paragraphs) {
          emit('', p);
        }
      }
      paragraphs.clear();
    }

    for (final line in lines) {
      final match = _heading.firstMatch(line);
      if (match != null) {
        endSection();
        heading = match.group(1)!.trim();
      } else if (line.trim().isEmpty) {
        endParagraph();
      } else {
        current.add(line.trim());
      }
    }
    endSection();
    return sections;
  }

  /// Inverse of [sectionsFromBody] for AI-structured sections.
  static String bodyFromSections(List<ScriptSection> sections) => sections
      .map(
        (s) => s.heading.trim().isEmpty
            ? s.spokenText.trim()
            : '## ${s.heading.trim()}\n${s.spokenText.trim()}',
      )
      .join('\n\n');

  /// Splits sections into cues of at most [maxChars] characters, keeping
  /// sentences together where possible.
  static List<Cue> cues(
    List<ScriptSection> sections, {
    int maxChars = defaultMaxCueChars,
  }) {
    final cues = <Cue>[];
    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      final heading = section.heading.trim().isEmpty
          ? 'Part ${i + 1}'
          : section.heading.trim();
      for (final chunk in chunk(section.spokenText, maxChars: maxChars)) {
        cues.add(
          Cue(
            index: cues.length,
            sectionIndex: i,
            heading: heading,
            text: chunk,
            keywords: section.cueKeywords,
          ),
        );
      }
    }
    return cues;
  }

  /// Packs sentences into chunks of at most [maxChars]; over-long sentences
  /// are split on clause boundaries, then on words.
  static List<String> chunk(String text, {int maxChars = defaultMaxCueChars}) {
    final normalized = text.replaceAll(_whitespace, ' ').trim();
    if (normalized.isEmpty) return const [];

    final pieces = <String>[];
    for (final sentence in normalized.split(_sentenceBreak)) {
      if (sentence.length <= maxChars) {
        pieces.add(sentence);
        continue;
      }
      for (final clause in sentence.split(_clauseBreak)) {
        if (clause.length <= maxChars) {
          pieces.add(clause);
        } else {
          pieces.addAll(_packWords(clause.split(' '), maxChars));
        }
      }
    }
    return _packWords(pieces, maxChars);
  }

  /// Word-wraps [text] into lines of at most [width] characters (a single
  /// word longer than [width] gets its own line).
  static List<String> wrap(String text, {int width = 28}) =>
      _packWords(text.trim().split(_whitespace), width);

  static List<String> _packWords(List<String> parts, int max) {
    final out = <String>[];
    var line = '';
    for (final part in parts) {
      if (part.isEmpty) continue;
      if (line.isEmpty) {
        line = part;
      } else if (line.length + 1 + part.length <= max) {
        line = '$line $part';
      } else {
        out.add(line);
        line = part;
      }
    }
    if (line.isNotEmpty) out.add(line);
    return out;
  }
}

extension ScriptCuesX on Script {
  /// AI sections when available, otherwise sections parsed from the body.
  List<ScriptSection> get resolvedSections =>
      sections.isNotEmpty ? sections : CueSegmenter.sectionsFromBody(body);

  /// Text that will actually be spoken (headings excluded).
  String get spokenText =>
      resolvedSections.map((s) => s.spokenText).join('\n\n');
}
