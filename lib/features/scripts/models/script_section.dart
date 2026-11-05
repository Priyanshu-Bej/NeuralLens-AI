import 'package:equatable/equatable.dart';

/// A spoken section of a script, optionally with short cue keywords.
class ScriptSection extends Equatable {
  const ScriptSection({
    required this.id,
    required this.heading,
    required this.spokenText,
    this.cueKeywords = const [],
  });

  final String id;
  final String heading;
  final String spokenText;
  final List<String> cueKeywords;

  Map<String, Object?> toJson() => {
    'id': id,
    'heading': heading,
    'spokenText': spokenText,
    'cueKeywords': cueKeywords,
  };

  factory ScriptSection.fromJson(Map<String, Object?> json) => ScriptSection(
    id: json['id'] as String? ?? '',
    heading: json['heading'] as String? ?? '',
    spokenText: json['spokenText'] as String? ?? '',
    cueKeywords: (json['cueKeywords'] as List<Object?>? ?? const [])
        .whereType<String>()
        .toList(),
  );

  @override
  List<Object?> get props => [id, heading, spokenText, cueKeywords];
}
