import '../../scripts/models/script_enums.dart';
import '../../scripts/util/duration_estimator.dart';
import '../models/generated_script.dart';

/// Prompt text for Gemini. Kept separate from transport so it is easy to
/// review and tune.
abstract final class Prompts {
  static const system =
      '''
You are NeuralLens, a scriptwriter for people who read from a teleprompter or smart-glasses display while speaking.

Rules:
- Write natural, spoken language: contractions, short sentences, plain words. No stage directions, emojis, hashtags or Markdown.
- Open with a strong first line that earns attention.
- Keep sentences short (ideally under 18 words) so they fit on small displays.
- Split the script into clearly separated sections with short headings (1–4 words).
- End with a concise closing or call to action.
- Respect the requested tone and target duration (about ${DurationEstimator.defaultWpm} spoken words per minute).
- Do not invent statistics, quotes, names, dates or other factual claims that are not in the user's notes. If a fact is needed but missing, phrase it generally.
- cueKeywords: 1–4 short words per section that remind the speaker what comes next.
- Return only JSON matching the provided schema.''';

  /// Gemini `responseSchema` (OpenAPI subset).
  static const Map<String, Object?> responseSchema = {
    'type': 'OBJECT',
    'properties': {
      'title': {'type': 'STRING'},
      'estimatedDurationSeconds': {'type': 'INTEGER'},
      'sections': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'heading': {'type': 'STRING'},
            'spokenText': {'type': 'STRING'},
            'cueKeywords': {
              'type': 'ARRAY',
              'items': {'type': 'STRING'},
            },
          },
          'required': ['heading', 'spokenText', 'cueKeywords'],
        },
      },
    },
    'required': ['title', 'estimatedDurationSeconds', 'sections'],
  };

  static String generate(ScriptGenerationRequest r) {
    final format =
        r.format == ScriptFormat.custom && r.customFormat.trim().isNotEmpty
        ? r.customFormat.trim()
        : r.format.label;
    final words = DurationEstimator.targetWords(r.durationSeconds);
    return '''
Write a new script.
Format: $format
Tone: ${r.tone.label}
Language: ${r.language.label}
Target duration: ${r.durationSeconds} seconds (about $words spoken words)

Topic or rough notes:
"""
${r.notes.trim()}
"""''';
  }

  static String rewrite({
    required String text,
    required String instruction,
    required ScriptFormat format,
    required ScriptTone tone,
  }) {
    final seconds = DurationEstimator.estimateSeconds(text);
    return '''
Revise the script below. Keep its meaning and any facts exactly as given; do not add new factual claims.
Format: ${format.label}
Tone: ${tone.label}
Keep roughly the same length (about $seconds seconds) unless the instruction says otherwise.
Instruction: ${instruction.trim().isEmpty ? 'Make it clearer, tighter and more natural to say out loud.' : instruction.trim()}

Script:
"""
${text.trim()}
"""''';
  }

  static String cueSections({required String text}) =>
      '''
Split the script below into teleprompter sections. Keep the wording as close to the original as possible: only fix line breaks and split long sentences. Give each section a short heading and 1–4 cue keywords.

Script:
"""
${text.trim()}
"""''';
}
