import 'package:flutter_test/flutter_test.dart';
import 'package:neurallens/features/ai/models/generated_script.dart';
import 'package:neurallens/features/scripts/models/script_enums.dart';

GeneratedScript parse(String raw) => GeneratedScript.parse(
  raw,
  format: ScriptFormat.youtube,
  tone: ScriptTone.energetic,
);

void main() {
  const valid = '''
{
  "title": "Launch day",
  "estimatedDurationSeconds": 58,
  "sections": [
    {"heading": "Hook", "spokenText": "Ready for something new?", "cueKeywords": ["new", "ready"]},
    {"heading": "Close", "spokenText": "Try it today.", "cueKeywords": []}
  ]
}''';

  test('parses a valid response into typed models', () {
    final script = parse(valid);
    expect(script.title, 'Launch day');
    expect(script.format, ScriptFormat.youtube);
    expect(script.tone, ScriptTone.energetic);
    expect(script.estimatedDurationSeconds, 58);
    expect(script.sections, hasLength(2));
    expect(script.sections.first.id, 'section-1');
    expect(script.sections.first.cueKeywords, ['new', 'ready']);
    expect(
      script.body,
      '## Hook\nReady for something new?\n\n## Close\nTry it today.',
    );
  });

  test('tolerates code fences and surrounding prose', () {
    final script = parse('Here you go:\n```json\n$valid\n```\nEnjoy!');
    expect(script.title, 'Launch day');
  });

  test('fills missing optional fields', () {
    final script = parse('{"sections": [{"spokenText": "Just words here."}]}');
    expect(script.title, 'Untitled script');
    expect(script.sections.single.heading, 'Part 1');
    expect(script.sections.single.cueKeywords, isEmpty);
    expect(script.estimatedDurationSeconds, greaterThan(0));
  });

  test('accepts numeric strings and caps keywords', () {
    final script = parse(
      '{"estimatedDurationSeconds": "90", "sections": [{"heading": "A", '
      '"spokenText": "x", "cueKeywords": ["1","2","3","4","5","6","7"]}]}',
    );
    expect(script.estimatedDurationSeconds, 90);
    expect(script.sections.single.cueKeywords, hasLength(5));
  });

  test('drops empty sections but keeps the rest', () {
    final script = parse(
      '{"sections": [{"heading": "A", "spokenText": "  "}, '
      '{"heading": "B", "spokenText": "Real"}, "junk", 42]}',
    );
    expect(script.sections.map((s) => s.heading), ['B']);
    expect(script.sections.single.id, 'section-1');
  });

  group('rejects unusable output', () {
    for (final (name, raw) in [
      ('plain text', 'Sorry, I cannot help.'),
      ('malformed JSON', '{"title": "x", "sections": [}'),
      ('array root', '[1, 2]'),
      ('no sections', '{"title": "x"}'),
      ('sections not a list', '{"sections": "nope"}'),
      ('only empty sections', '{"sections": [{"spokenText": ""}]}'),
    ]) {
      test(name, () => expect(() => parse(raw), throwsFormatException));
    }
  });

  test('generation request validation', () {
    expect(const ScriptGenerationRequest(notes: '  ').isValid, isFalse);
    expect(const ScriptGenerationRequest(notes: 'Topic').isValid, isTrue);
    expect(
      ScriptGenerationRequest(
        notes: 'x' * (ScriptGenerationRequest.maxNotesLength + 1),
      ).isValid,
      isFalse,
    );
  });
}
