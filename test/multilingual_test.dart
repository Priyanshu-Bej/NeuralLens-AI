import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neurallens/features/ai/data/agent_client.dart';
import 'package:neurallens/features/ai/models/generated_script.dart';
import 'package:neurallens/features/scripts/models/script_enums.dart';
import 'package:neurallens/features/scripts/util/cue_segmenter.dart';
import 'package:neurallens/features/scripts/util/duration_estimator.dart';

void main() {
  test('Indic words with vowel signs count as one word each', () {
    expect(DurationEstimator.wordCount('ಇದು ಕನ್ನಡ ವಾಕ್ಯ'), 3);
    expect(DurationEstimator.wordCount('यह हिंदी वाक्य है'), 4);
    expect(DurationEstimator.wordCount("It's well-known, isn't it?"), 4);
  });

  test('danda ends a sentence when splitting cues', () {
    expect(CueSegmenter.chunk('पहला वाक्य। दूसरा वाक्य।', maxChars: 15), [
      'पहला वाक्य।',
      'दूसरा वाक्य।',
    ]);
  });

  test('language codes match the agent and are unique', () {
    final codes = ScriptLanguage.values.map((l) => l.code).toList();
    expect(codes.toSet(), {
      'en', 'hi', 'kn', 'ta', 'te', 'ml', 'mr', 'bn', 'es', 'fr', 'de', //
    });
    expect(codes.toSet().length, codes.length);
  });

  test('selected language is sent to the agent', () async {
    late Map<String, Object?> body;
    await AgentClient(
      client: MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, Object?>;
        // UTF-8 bytes, as the real server sends them.
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'title': 'ಶೀರ್ಷಿಕೆ',
              'estimatedDurationSeconds': 60,
              'sections': [
                {
                  'heading': 'ಪರಿಚಯ',
                  'spokenText': 'ನಮಸ್ಕಾರ.',
                  'cueKeywords': [],
                },
              ],
            }),
          ),
          200,
        );
      }),
      baseUrl: 'http://192.168.1.20:8080',
      token: 't',
    ).generateScript(
      const ScriptGenerationRequest(
        notes: 'notes',
        language: ScriptLanguage.kannada,
      ),
    );
    expect(body['language'], 'kn');
  });
}
