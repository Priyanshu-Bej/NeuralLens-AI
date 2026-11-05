import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neurallens/core/config/app_config.dart';
import 'package:neurallens/features/ai/data/gemini_exception.dart';
import 'package:neurallens/features/ai/data/gemini_service.dart';
import 'package:neurallens/features/ai/models/generated_script.dart';
import 'package:neurallens/features/scripts/models/script_enums.dart';

const _config = AppConfig(geminiApiKey: 'test-key', geminiModel: 'test-model');
const _request = ScriptGenerationRequest(notes: 'A product launch');

String _envelope(Object modelJson, {String finishReason = 'STOP'}) =>
    jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': modelJson is String ? modelJson : jsonEncode(modelJson)},
            ],
          },
          'finishReason': finishReason,
        },
      ],
    });

const _script = {
  'title': 'Launch',
  'estimatedDurationSeconds': 55,
  'sections': [
    {
      'heading': 'Hook',
      'spokenText': 'Big news today.',
      'cueKeywords': ['news'],
    },
  ],
};

GeminiService _service(
  MockClientHandler handler, {
  AppConfig config = _config,
  Duration timeout = const Duration(seconds: 5),
}) => GeminiService(
  client: MockClient(handler),
  config: config,
  timeout: timeout,
);

Future<GeminiErrorKind> _kindOf(Future<Object?> future) async {
  try {
    await future;
  } on GeminiException catch (e) {
    return e.kind;
  }
  fail('Expected a GeminiException');
}

void main() {
  test('sends a structured-output request with the key in a header', () async {
    late http.Request captured;
    final service = _service((req) async {
      captured = req;
      return http.Response(_envelope(_script), 200);
    });

    final result = await service.generateScript(_request);

    expect(result.title, 'Launch');
    expect(result.sections.single.cueKeywords, ['news']);
    expect(
      captured.url.toString(),
      'https://generativelanguage.googleapis.com/v1beta/models/test-model:generateContent',
    );
    expect(captured.headers['x-goog-api-key'], 'test-key');
    expect(
      captured.url.queryParameters,
      isEmpty,
      reason: 'key must not be in the URL',
    );
    final body = jsonDecode(captured.body) as Map<String, Object?>;
    final config = body['generationConfig']! as Map<String, Object?>;
    expect(config['responseMimeType'], 'application/json');
    expect(config['responseSchema'], isA<Map<String, Object?>>());
  });

  test('rewrite and cue sections return typed scripts', () async {
    final service = _service(
      (_) async => http.Response(_envelope(_script), 200),
    );
    final rewrite = await service.rewriteScript(
      text: 'Old text',
      format: ScriptFormat.meeting,
      tone: ScriptTone.professional,
    );
    expect(rewrite.format, ScriptFormat.meeting);
    final cues = await service.generateCueSections(
      text: 'Old text',
      format: ScriptFormat.podcast,
      tone: ScriptTone.storytelling,
    );
    expect(cues.tone, ScriptTone.storytelling);
  });

  test('missing key fails fast without a network call', () async {
    var called = false;
    final service = _service((_) async {
      called = true;
      return http.Response('', 200);
    }, config: const AppConfig(geminiApiKey: ' ', geminiModel: 'm'));
    expect(service.isConfigured, isFalse);
    expect(
      await _kindOf(service.generateScript(_request)),
      GeminiErrorKind.missingKey,
    );
    expect(called, isFalse);
  });

  group('HTTP errors', () {
    Future<GeminiErrorKind> status(int code, [Map<String, Object?>? error]) =>
        _kindOf(
          _service(
            (_) async => http.Response(jsonEncode({'error': ?error}), code),
          ).generateScript(_request),
        );

    test('429 → rate limited', () async {
      expect(await status(429), GeminiErrorKind.rateLimited);
    });
    test('401/403 → auth', () async {
      expect(await status(401), GeminiErrorKind.auth);
      expect(await status(403), GeminiErrorKind.auth);
    });
    test('400 API_KEY_INVALID → auth', () async {
      expect(
        await status(400, {
          'status': 'INVALID_ARGUMENT',
          'details': [
            {'reason': 'API_KEY_INVALID'},
          ],
        }),
        GeminiErrorKind.auth,
      );
    });
    test('404 → model unavailable', () async {
      expect(await status(404), GeminiErrorKind.modelUnavailable);
    });
    test('500/503 → server', () async {
      expect(await status(500), GeminiErrorKind.server);
      expect(await status(503), GeminiErrorKind.server);
    });
    test('504 → timeout', () async {
      expect(await status(504), GeminiErrorKind.timeout);
    });
    test('other 400 → bad request', () async {
      expect(await status(400), GeminiErrorKind.badRequest);
    });
    test('non-JSON error body is handled', () async {
      final kind = await _kindOf(
        _service(
          (_) async => http.Response('<html>oops</html>', 502),
        ).generateScript(_request),
      );
      expect(kind, GeminiErrorKind.server);
    });
  });

  test('timeout → timeout', () async {
    final service = _service(
      (_) => Completer<http.Response>().future,
      timeout: const Duration(milliseconds: 20),
    );
    expect(
      await _kindOf(service.generateScript(_request)),
      GeminiErrorKind.timeout,
    );
  });

  test('socket and client errors → network', () async {
    expect(
      await _kindOf(
        _service(
          (_) => throw const SocketException('down'),
        ).generateScript(_request),
      ),
      GeminiErrorKind.network,
    );
    expect(
      await _kindOf(
        _service(
          (_) => throw http.ClientException('reset'),
        ).generateScript(_request),
      ),
      GeminiErrorKind.network,
    );
  });

  test('blocked prompt → blocked', () async {
    final service = _service(
      (_) async => http.Response(
        jsonEncode({
          'promptFeedback': {'blockReason': 'SAFETY'},
        }),
        200,
      ),
    );
    expect(
      await _kindOf(service.generateScript(_request)),
      GeminiErrorKind.blocked,
    );
  });

  test('safety finish reason → blocked', () async {
    final service = _service(
      (_) async => http.Response(_envelope('', finishReason: 'SAFETY'), 200),
    );
    expect(
      await _kindOf(service.generateScript(_request)),
      GeminiErrorKind.blocked,
    );
  });

  test('no candidates or empty text → empty output', () async {
    expect(
      await _kindOf(
        _service(
          (_) async => http.Response('{"candidates": []}', 200),
        ).generateScript(_request),
      ),
      GeminiErrorKind.emptyOutput,
    );
    expect(
      await _kindOf(
        _service(
          (_) async => http.Response(_envelope('  '), 200),
        ).generateScript(_request),
      ),
      GeminiErrorKind.emptyOutput,
    );
  });

  test('malformed model JSON → invalid response', () async {
    final service = _service(
      (_) async =>
          http.Response(_envelope('{"title": "x", "sections": [}'), 200),
    );
    expect(
      await _kindOf(service.generateScript(_request)),
      GeminiErrorKind.invalidResponse,
    );
  });

  test('truncated output (MAX_TOKENS) → invalid response', () async {
    final service = _service(
      (_) async => http.Response(
        _envelope(
          '{"title": "x", "sections": [{"spokenText": "cut',
          finishReason: 'MAX_TOKENS',
        ),
        200,
      ),
    );
    expect(
      await _kindOf(service.generateScript(_request)),
      GeminiErrorKind.invalidResponse,
    );
  });

  test('non-JSON envelope → invalid response', () async {
    final service = _service((_) async => http.Response('not json', 200));
    expect(
      await _kindOf(service.generateScript(_request)),
      GeminiErrorKind.invalidResponse,
    );
  });

  test('thought parts are ignored', () async {
    final service = _service(
      (_) async => http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'thinking…', 'thought': true},
                    {'text': jsonEncode(_script)},
                  ],
                },
                'finishReason': 'STOP',
              },
            ],
          }),
        ),
        200,
      ),
    );
    expect((await service.generateScript(_request)).title, 'Launch');
  });

  test('exception text never contains the API key', () async {
    try {
      await _service(
        (_) async => http.Response('{}', 401),
      ).generateScript(_request);
    } on GeminiException catch (e) {
      expect(e.toString(), isNot(contains('test-key')));
      expect(e.message, isNot(contains('test-key')));
    }
  });
}
