import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neurallens/core/config/app_config.dart';
import 'package:neurallens/features/ai/data/agent_client.dart';
import 'package:neurallens/features/ai/data/gemini_exception.dart';
import 'package:neurallens/features/ai/data/gemini_service.dart';
import 'package:neurallens/features/ai/models/generated_script.dart';

const _request = ScriptGenerationRequest(
  notes: 'Why agents fail',
  durationSeconds: 60,
);

/// A real reply shape from the agent: GeneratedScript fields plus extras.
const _deck = {
  'title': 'Why agents fail',
  'estimatedDurationSeconds': 61,
  'targetSeconds': 60,
  'fitsTarget': true,
  'language': 'English',
  'sections': [
    {
      'heading': 'Hook',
      'spokenText': 'Most agents fail. Here is why.',
      'cueKeywords': ['fail'],
    },
  ],
  'cues': [
    {
      'index': 0,
      'sectionIndex': 0,
      'heading': 'Hook',
      'text': 'Most agents fail. Here is why.',
      'sayBy': 3,
      'sayByLabel': '3s',
      'flags': <String>[],
    },
  ],
  'qa': <Object>[],
  'warnings': <String>[],
};

AgentClient _client(MockClientHandler handler) => AgentClient(
  client: MockClient(handler),
  baseUrl: 'http://192.168.1.20:8080',
  token: 'secret-token',
  timeout: const Duration(seconds: 5),
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
  test('posts notes with the token and parses the agent deck', () async {
    late http.Request sent;
    final script = await _client((request) async {
      sent = request;
      return http.Response(jsonEncode(_deck), 200);
    }).generateScript(_request);

    expect(sent.url.toString(), 'http://192.168.1.20:8080/v1/script');
    expect(sent.headers['X-Agent-Token'], 'secret-token');
    expect(jsonDecode(sent.body), {
      'notes': 'Why agents fail',
      'durationSeconds': 60,
      'language': 'en',
    });
    expect(script.title, 'Why agents fail');
    expect(script.estimatedDurationSeconds, 61);
    expect(script.sections.single.cueKeywords, ['fail']);
  });

  test('maps agent errors to the existing error kinds', () async {
    Future<GeminiErrorKind> kindFor(int status) => _kindOf(
      _client(
        (_) async => http.Response(jsonEncode({'error': 'nope'}), status),
      ).generateScript(_request),
    );

    expect(await kindFor(401), GeminiErrorKind.auth);
    expect(await kindFor(422), GeminiErrorKind.badRequest);
    expect(await kindFor(429), GeminiErrorKind.rateLimited);
    expect(await kindFor(502), GeminiErrorKind.server);
  });

  test('unreachable server is a network error', () async {
    final kind = await _kindOf(
      _client(
        (_) async => throw http.ClientException('refused'),
      ).generateScript(_request),
    );
    expect(kind, GeminiErrorKind.network);
  });

  test('slow server is a timeout', () async {
    final kind = await _kindOf(
      AgentClient(
        client: MockClient((_) => Completer<http.Response>().future),
        baseUrl: 'http://192.168.1.20:8080',
        token: 't',
        timeout: const Duration(milliseconds: 10),
      ).generateScript(_request),
    );
    expect(kind, GeminiErrorKind.timeout);
  });

  test(
    'GeminiService routes generation to the agent when configured',
    () async {
      var geminiCalled = false;
      final service = GeminiService(
        client: MockClient((_) async {
          geminiCalled = true;
          return http.Response('{}', 500);
        }),
        config: const AppConfig(geminiApiKey: '', geminiModel: 'm'),
        agent: _client((_) async => http.Response(jsonEncode(_deck), 200)),
      );

      expect(service.isConfigured, isTrue);
      expect(service.usesAgent, isTrue);
      final script = await service.generateScript(_request);
      expect(script.title, 'Why agents fail');
      expect(geminiCalled, isFalse);
    },
  );
}
