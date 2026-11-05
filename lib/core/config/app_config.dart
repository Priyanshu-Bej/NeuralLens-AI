/// Build-time configuration.
///
/// Values come from `--dart-define`. A key passed this way is compiled into
/// the binary, so it is suitable for local development only — never ship a
/// release build that embeds a privileged API key.
class AppConfig {
  const AppConfig({required this.geminiApiKey, required this.geminiModel});

  factory AppConfig.fromEnvironment() => const AppConfig(
    geminiApiKey: String.fromEnvironment('GEMINI_API_KEY'),
    geminiModel: String.fromEnvironment(
      'GEMINI_MODEL',
      defaultValue: defaultGeminiModel,
    ),
  );

  /// Recommended by ai.google.dev (Oct 2026) for fast, low-cost text work.
  static const defaultGeminiModel = 'gemini-3.5-flash-lite';

  final String geminiApiKey;
  final String geminiModel;

  bool get isGeminiConfigured => geminiApiKey.trim().isNotEmpty;
}
