enum GeminiErrorKind {
  missingKey,
  network,
  timeout,
  rateLimited,
  auth,
  modelUnavailable,
  badRequest,
  server,
  blocked,
  emptyOutput,
  invalidResponse,
}

/// A user-presentable Gemini failure. Never carries the API key or the
/// script contents.
class GeminiException implements Exception {
  const GeminiException(this.kind, {this.statusCode, this.detail});

  final GeminiErrorKind kind;
  final int? statusCode;

  /// Short, non-sensitive diagnostic (e.g. the API's error status).
  final String? detail;

  bool get isRetryable => switch (kind) {
    GeminiErrorKind.network ||
    GeminiErrorKind.timeout ||
    GeminiErrorKind.rateLimited ||
    GeminiErrorKind.server ||
    GeminiErrorKind.emptyOutput ||
    GeminiErrorKind.invalidResponse => true,
    _ => false,
  };

  String get title => switch (kind) {
    GeminiErrorKind.missingKey => 'Gemini is not configured',
    GeminiErrorKind.network => 'No connection',
    GeminiErrorKind.timeout => 'Request timed out',
    GeminiErrorKind.rateLimited => 'Rate limit reached',
    GeminiErrorKind.auth => 'API key rejected',
    GeminiErrorKind.modelUnavailable => 'Model unavailable',
    GeminiErrorKind.badRequest => 'Request not accepted',
    GeminiErrorKind.server => 'Gemini is having trouble',
    GeminiErrorKind.blocked => 'Content was blocked',
    GeminiErrorKind.emptyOutput => 'Empty response',
    GeminiErrorKind.invalidResponse => 'Unexpected response',
  };

  String get message => switch (kind) {
    GeminiErrorKind.missingKey =>
      'Run the app with --dart-define=GEMINI_API_KEY=YOUR_KEY to enable AI '
          'features. Your local scripts and teleprompter work without it.',
    GeminiErrorKind.network =>
      'Check your internet connection and try again. Saved scripts remain '
          'available offline.',
    GeminiErrorKind.timeout =>
      'Gemini took too long to respond. Try again, or shorten your notes.',
    GeminiErrorKind.rateLimited =>
      'Too many requests in a short time. Wait a moment, then retry.',
    GeminiErrorKind.auth =>
      'The configured API key is invalid or lacks access to this model. '
          'Check the key in Google AI Studio.',
    GeminiErrorKind.modelUnavailable =>
      'The configured model is not available. Set a current model with '
          '--dart-define=GEMINI_MODEL=<model-id>.',
    GeminiErrorKind.badRequest =>
      'Gemini could not process this request. Try rephrasing your notes.',
    GeminiErrorKind.server =>
      'The Gemini service returned an error. Try again shortly.',
    GeminiErrorKind.blocked =>
      'Gemini declined this request under its safety policies. Try '
          'rephrasing your notes.',
    GeminiErrorKind.emptyOutput =>
      'Gemini returned no text. Try again or adjust your notes.',
    GeminiErrorKind.invalidResponse =>
      'Gemini returned a response that could not be read as a script. '
          'Try again.',
  };

  @override
  String toString() =>
      'GeminiException(${kind.name}${statusCode == null ? '' : ', $statusCode'}'
      '${detail == null ? '' : ', $detail'})';
}
