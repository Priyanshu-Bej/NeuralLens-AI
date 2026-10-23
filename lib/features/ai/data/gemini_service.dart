import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../scripts/models/script_enums.dart';
import '../models/generated_script.dart';
import 'gemini_exception.dart';
import 'prompts.dart';

/// Minimal Gemini REST client (`models.generateContent`, v1beta) with JSON
/// structured output.
///
/// Errors surface as [GeminiException]. The API key and prompt contents are
/// never logged.
class GeminiService {
  GeminiService({
    required this._client,
    required this._config,
    this.timeout = const Duration(seconds: 45),
  });

  final http.Client _client;
  final AppConfig _config;
  final Duration timeout;

  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';

  bool get isConfigured => _config.isGeminiConfigured;
  String get model => _config.geminiModel;

  Future<GeneratedScript> generateScript(
    ScriptGenerationRequest request,
  ) async {
    if (!request.isValid) {
      throw const GeminiException(
        GeminiErrorKind.badRequest,
        detail: 'invalid request',
      );
    }
    return _generate(
      Prompts.generate(request),
      format: request.format,
      tone: request.tone,
      temperature: 0.8,
    );
  }

  Future<GeneratedScript> rewriteScript({
    required String text,
    String instruction = '',
    required ScriptFormat format,
    required ScriptTone tone,
  }) => _generate(
    Prompts.rewrite(
      text: text,
      instruction: instruction,
      format: format,
      tone: tone,
    ),
    format: format,
    tone: tone,
    temperature: 0.7,
  );

  Future<GeneratedScript> generateCueSections({
    required String text,
    required ScriptFormat format,
    required ScriptTone tone,
  }) => _generate(
    Prompts.cueSections(text: text),
    format: format,
    tone: tone,
    temperature: 0.2,
  );

  Future<GeneratedScript> _generate(
    String prompt, {
    required ScriptFormat format,
    required ScriptTone tone,
    required double temperature,
  }) async {
    if (!isConfigured) {
      throw const GeminiException(GeminiErrorKind.missingKey);
    }

    final uri = Uri.parse(
      '$_baseUrl/models/${Uri.encodeComponent(model)}:generateContent',
    );
    final body = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': Prompts.system},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': temperature,
        'responseMimeType': 'application/json',
        'responseSchema': Prompts.responseSchema,
      },
    });

    final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': _config.geminiApiKey,
            },
            body: body,
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const GeminiException(GeminiErrorKind.timeout);
    } on http.ClientException catch (e) {
      throw GeminiException(
        GeminiErrorKind.network,
        detail: e.runtimeType.toString(),
      );
    } on Exception catch (e) {
      // SocketException / HandshakeException etc. (dart:io types are not
      // imported so this stays platform-neutral).
      throw GeminiException(
        GeminiErrorKind.network,
        detail: e.runtimeType.toString(),
      );
    }

    if (response.statusCode != 200) {
      throw _httpError(response);
    }

    // JSON is always UTF-8; don't rely on the charset header.
    final text = _extractText(
      utf8.decode(response.bodyBytes, allowMalformed: true),
    );
    try {
      return GeneratedScript.parse(text, format: format, tone: tone);
    } on FormatException catch (e) {
      throw GeminiException(GeminiErrorKind.invalidResponse, detail: e.message);
    }
  }

  GeminiException _httpError(http.Response response) {
    final code = response.statusCode;
    String? status;
    String? reason;
    try {
      final json = jsonDecode(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      if (json is Map<String, Object?> &&
          json['error'] is Map<String, Object?>) {
        final error = json['error']! as Map<String, Object?>;
        status = error['status'] as String?;
        final details = error['details'];
        if (details is List<Object?>) {
          reason = details
              .whereType<Map<String, Object?>>()
              .map((d) => d['reason'])
              .whereType<String>()
              .firstOrNull;
        }
      }
    } on FormatException {
      // Non-JSON error body; fall back to the status code.
    }

    final detail = reason ?? status;
    if (code == 429) {
      return GeminiException(
        GeminiErrorKind.rateLimited,
        statusCode: code,
        detail: detail,
      );
    }
    if (code == 401 ||
        code == 403 ||
        reason == 'API_KEY_INVALID' ||
        status == 'UNAUTHENTICATED' ||
        status == 'PERMISSION_DENIED') {
      return GeminiException(
        GeminiErrorKind.auth,
        statusCode: code,
        detail: detail,
      );
    }
    if (code == 404) {
      return GeminiException(
        GeminiErrorKind.modelUnavailable,
        statusCode: code,
        detail: detail,
      );
    }
    if (code == 408 || code == 504) {
      return GeminiException(
        GeminiErrorKind.timeout,
        statusCode: code,
        detail: detail,
      );
    }
    if (code >= 500) {
      return GeminiException(
        GeminiErrorKind.server,
        statusCode: code,
        detail: detail,
      );
    }
    return GeminiException(
      GeminiErrorKind.badRequest,
      statusCode: code,
      detail: detail,
    );
  }

  /// Pulls the model's text out of a generateContent response, mapping
  /// blocked or empty responses to typed errors.
  String _extractText(String responseBody) {
    final Object? json;
    try {
      json = jsonDecode(responseBody);
    } on FormatException {
      throw const GeminiException(
        GeminiErrorKind.invalidResponse,
        detail: 'non-JSON envelope',
      );
    }
    if (json is! Map<String, Object?>) {
      throw const GeminiException(GeminiErrorKind.invalidResponse);
    }

    final feedback = json['promptFeedback'];
    if (feedback is Map<String, Object?> && feedback['blockReason'] is String) {
      throw GeminiException(
        GeminiErrorKind.blocked,
        detail: feedback['blockReason']! as String,
      );
    }

    final candidates = json['candidates'];
    if (candidates is! List<Object?> || candidates.isEmpty) {
      throw const GeminiException(GeminiErrorKind.emptyOutput);
    }
    final first = candidates.first;
    if (first is! Map<String, Object?>) {
      throw const GeminiException(GeminiErrorKind.invalidResponse);
    }

    final finishReason = first['finishReason'] as String?;
    const blockedReasons = {
      'SAFETY',
      'RECITATION',
      'BLOCKLIST',
      'PROHIBITED_CONTENT',
      'SPII',
    };
    if (blockedReasons.contains(finishReason)) {
      throw GeminiException(GeminiErrorKind.blocked, detail: finishReason);
    }

    final content = first['content'];
    final parts = content is Map<String, Object?> ? content['parts'] : null;
    final text = parts is List<Object?>
        ? parts
              .whereType<Map<String, Object?>>()
              .where((p) => p['thought'] != true)
              .map((p) => p['text'])
              .whereType<String>()
              .join()
        : '';

    if (text.trim().isEmpty) {
      throw GeminiException(GeminiErrorKind.emptyOutput, detail: finishReason);
    }
    if (finishReason == 'MAX_TOKENS') {
      // Likely truncated JSON; let parsing decide, but flag it if it fails.
      try {
        jsonDecode(text.substring(text.indexOf('{')));
      } on Object {
        throw const GeminiException(
          GeminiErrorKind.invalidResponse,
          detail: 'MAX_TOKENS',
        );
      }
    }
    return text;
  }
}
