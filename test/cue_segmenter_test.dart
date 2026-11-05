import 'package:flutter_test/flutter_test.dart';
import 'package:neurallens/features/scripts/models/script_section.dart';
import 'package:neurallens/features/scripts/util/cue_segmenter.dart';

void main() {
  group('sectionsFromBody', () {
    test('splits on Markdown headings', () {
      final sections = CueSegmenter.sectionsFromBody(
        '## Hook\nFirst line.\nStill hook.\n\n## Close\nBye now.',
      );
      expect(sections, hasLength(2));
      expect(sections[0].heading, 'Hook');
      expect(sections[0].spokenText, 'First line. Still hook.');
      expect(sections[1].heading, 'Close');
      expect(sections[1].spokenText, 'Bye now.');
    });

    test('keeps text before the first heading as an untitled section', () {
      final sections = CueSegmenter.sectionsFromBody('Intro.\n\n# Main\nBody.');
      expect(sections.map((s) => s.heading), ['', 'Main']);
    });

    test('without headings, each paragraph becomes a section', () {
      final sections = CueSegmenter.sectionsFromBody(
        'One.\n\nTwo.\r\n\r\nThree.',
      );
      expect(sections.map((s) => s.spokenText), ['One.', 'Two.', 'Three.']);
      expect(sections.every((s) => s.heading.isEmpty), isTrue);
    });

    test('ignores empty headings and blank input', () {
      expect(CueSegmenter.sectionsFromBody(''), isEmpty);
      expect(
        CueSegmenter.sectionsFromBody('## Empty\n\n## Also empty'),
        isEmpty,
      );
    });

    test('round-trips with bodyFromSections', () {
      const original = [
        ScriptSection(id: 'a', heading: 'Hook', spokenText: 'Hello there.'),
        ScriptSection(id: 'b', heading: 'Close', spokenText: 'Thanks.'),
      ];
      final parsed = CueSegmenter.sectionsFromBody(
        CueSegmenter.bodyFromSections(original),
      );
      expect(parsed.map((s) => (s.heading, s.spokenText)), [
        ('Hook', 'Hello there.'),
        ('Close', 'Thanks.'),
      ]);
    });
  });

  group('chunk', () {
    test('packs short sentences together up to the limit', () {
      final chunks = CueSegmenter.chunk(
        'Hi. How are you? Great.',
        maxChars: 40,
      );
      expect(chunks, ['Hi. How are you? Great.']);
    });

    test('never exceeds the limit for normal words', () {
      const text =
          'This is a long sentence that goes on, and on, and keeps going well '
          'beyond any reasonable glanceable length for a display. Short one.';
      final chunks = CueSegmenter.chunk(text, maxChars: 30);
      expect(chunks, isNotEmpty);
      expect(chunks.every((c) => c.length <= 30), isTrue);
      expect(chunks.join(' ').replaceAll(RegExp(r'\s+'), ' '), text);
    });

    test('returns empty for whitespace', () {
      expect(CueSegmenter.chunk('   \n '), isEmpty);
    });
  });

  test('cues are indexed sequentially and carry section info', () {
    const sections = [
      ScriptSection(
        id: '1',
        heading: '',
        spokenText: 'First sentence here. Second sentence here.',
        cueKeywords: ['start'],
      ),
      ScriptSection(id: '2', heading: 'End', spokenText: 'Done.'),
    ];
    final cues = CueSegmenter.cues(sections, maxChars: 25);
    expect(cues.map((c) => c.index), List.generate(cues.length, (i) => i));
    expect(cues.first.heading, 'Part 1');
    expect(cues.first.keywords, ['start']);
    expect(cues.last.sectionIndex, 1);
    expect(cues.last.heading, 'End');
  });

  test('wrap splits into lines of bounded width', () {
    final lines = CueSegmenter.wrap(
      'Keep sentences short so they fit small displays',
      width: 16,
    );
    expect(lines.every((l) => l.length <= 16), isTrue);
    expect(lines.join(' '), 'Keep sentences short so they fit small displays');
  });
}
