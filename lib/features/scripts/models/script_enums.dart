import 'package:flutter/material.dart';

enum ScriptKind {
  script('Script'),
  note('Note');

  const ScriptKind(this.label);
  final String label;

  static ScriptKind fromName(String? name) =>
      values.firstWhere((v) => v.name == name, orElse: () => script);
}

enum ScriptFormat {
  instagramReel('Instagram Reel', Icons.movie_filter_outlined),
  youtube('YouTube video', Icons.smart_display_outlined),
  presentation('Presentation', Icons.co_present_outlined),
  podcast('Podcast', Icons.mic_none_rounded),
  meeting('Meeting', Icons.groups_outlined),
  custom('Custom', Icons.tune_rounded);

  const ScriptFormat(this.label, this.icon);
  final String label;
  final IconData icon;

  static ScriptFormat fromName(String? name) =>
      values.firstWhere((v) => v.name == name, orElse: () => custom);
}

enum ScriptTone {
  conversational('Conversational'),
  professional('Professional'),
  energetic('Energetic'),
  educational('Educational'),
  storytelling('Storytelling');

  const ScriptTone(this.label);
  final String label;

  static ScriptTone fromName(String? name) =>
      values.firstWhere((v) => v.name == name, orElse: () => conversational);
}

/// Output language. English only for now; add entries here to expand.
enum ScriptLanguage {
  english('en', 'English');

  const ScriptLanguage(this.code, this.label);
  final String code;
  final String label;
}
