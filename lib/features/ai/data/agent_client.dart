import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/generated_script.dart';
import 'gemini_exception.dart';

/// Client for the Glasses Speaker Cue Agent HTTP API (`POST /v1/script`).
///
/// The agent drafts a script, measures its speaking time with a tool and
/// revises it before replying, so a request takes longer than one Gemini
/// call. Its reply is a superset of the [GeneratedScript] JSON.
///
/// Errors surface as [GeminiException] so the existing error UI applies. The
/// token and the notes are never logged.
class AgentClient {
  AgentClient({
    required this._client,
    required this.baseUrl,
    required this._token,
    this.timeout = const Duration(seconds: 120),
  });

  final http.Client _client;
  final String baseUrl;
  final String _token;
  final Duration timeout;

  Future<GeneratedScript> generateScript(
    ScriptGenerationRequest request,
  ) async {
    final uri = Uri.parse(baseUrl.trim()).resolve('/v1/script');
    final body = jsonEncode({
      'notes': request.notes,
      'durationSeconds': request.durationSeconds,
      'language': request.language.code,
    });

    final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Agent-Token': _token,
            },
            body: body,
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const GeminiException(GeminiErrorKind.timeout, detail: 'agent');
    } on Exception catch (e) {
      // ClientException, SocketException etc.: usually the phone cannot
      // reach the laptop (different network, or the server is not running).
      throw GeminiException(
        GeminiErrorKind.network,
        detail: 'agent ${e.runtimeType}',
      );
    }

    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (response.statusCode != 200) {
      throw _httpError(response.statusCode, text);
    }
    try {
      return GeneratedScript.parse(
        text,
        format: request.format,
        tone: request.tone,
      );
    } on FormatException catch (e) {
      throw GeminiException(GeminiErrorKind.invalidResponse, detail: e.message);
    }
  }

  static GeminiException _httpError(int code, String body) {
    String? detail;
    try {
      final json = jsonDecode(body);
      if (json is Map<String, Object?> && json['error'] is String) {
        detail = json['error']! as String;
      }
    } on FormatException {
      // Non-JSON error body; fall back to the status code.
    }
    final kind = switch (code) {
      401 => GeminiErrorKind.auth,
      429 => GeminiErrorKind.rateLimited,
      408 || 504 => GeminiErrorKind.timeout,
      >= 500 => GeminiErrorKind.server,
      _ => GeminiErrorKind.badRequest,
    };
    return GeminiException(kind, statusCode: code, detail: detail);
  }
}
