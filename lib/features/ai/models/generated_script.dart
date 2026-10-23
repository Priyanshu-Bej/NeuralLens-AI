import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../../scripts/models/script_enums.dart';
import '../../scripts/models/script_section.dart';
import '../../scripts/util/cue_segmenter.dart';
import '../../scripts/util/duration_estimator.dart';

/// Validated script returned by Gemini.
class GeneratedScript extends Equatable {
  const GeneratedScript({
    required this.title,
    required this.format,
    required this.tone,
    required this.estimatedDurationSeconds,
    required this.sections,
  });

  final String title;
  final ScriptFormat format;
  final ScriptTone tone;
  final int estimatedDurationSeconds;
  final List<ScriptSection> sections;

  String get body => CueSegmenter.bodyFromSections(sections);

  static const maxKeywordsPerSection = 5;

  /// Parses and validates raw model output.
  ///
  /// Tolerates Markdown code fences, surrounding prose and missing optional
  /// fields. Throws [FormatException] when no usable sections are present.
  static GeneratedScript parse(
    String raw, {
    required ScriptFormat format,
    required ScriptTone tone,
  }) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw const FormatException('Response did not contain a JSON object.');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(raw.substring(start, end + 1));
    } on FormatException {
      throw const FormatException('Response JSON was malformed.');
    }
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Response JSON was not an object.');
    }

    final rawSections = decoded['sections'];
    if (rawSections is! List<Object?>) {
      throw const FormatException('Response had no sections list.');
    }

    final sections = <ScriptSection>[];
    for (final item in rawSections.whereType<Map<String, Object?>>()) {
      final spoken = _string(item['spokenText']);
      if (spoken.isEmpty) continue;
      final heading = _string(item['heading']);
      final keywords = (item['cueKeywords'] is List<Object?>)
          ? (item['cueKeywords']! as List<Object?>)
                .map(_string)
                .where((k) => k.isNotEmpty)
                .take(maxKeywordsPerSection)
                .toList()
          : const <String>[];
      sections.add(
        ScriptSection(
          id: 'section-${sections.length + 1}',
          heading: heading.isEmpty ? 'Part ${sections.length + 1}' : heading,
          spokenText: spoken,
          cueKeywords: keywords,
        ),
      );
    }
    if (sections.isEmpty) {
      throw const FormatException('Response contained no spoken text.');
    }

    final title = _string(decoded['title']);
    final spoken = sections.map((s) => s.spokenText).join(' ');
    final estimate = switch (decoded['estimatedDurationSeconds']) {
      final num n when n > 0 => n.round(),
      final String s when int.tryParse(s) != null && int.parse(s) > 0 =>
        int.parse(s),
      _ => DurationEstimator.estimateSeconds(spoken),
    };

    return GeneratedScript(
      title: title.isEmpty ? 'Untitled script' : title,
      format: format,
      tone: tone,
      estimatedDurationSeconds: estimate,
      sections: sections,
    );
  }

  static String _string(Object? value) =>
      value is String ? value.trim() : (value?.toString().trim() ?? '');

  @override
  List<Object?> get props => [
    title,
    format,
    tone,
    estimatedDurationSeconds,
    sections,
  ];
}

/// User input for a new script.
class ScriptGenerationRequest extends Equatable {
  const ScriptGenerationRequest({
    required this.notes,
    this.format = ScriptFormat.youtube,
    this.customFormat = '',
    this.durationSeconds = 60,
    this.tone = ScriptTone.conversational,
    this.language = ScriptLanguage.english,
  });

  static const maxNotesLength = 4000;

  final String notes;
  final ScriptFormat format;

  /// Free-text description when [format] is [ScriptFormat.custom].
  final String customFormat;
  final int durationSeconds;
  final ScriptTone tone;
  final ScriptLanguage language;

  bool get isValid =>
      notes.trim().isNotEmpty &&
      notes.length <= maxNotesLength &&
      durationSeconds > 0;

  ScriptGenerationRequest copyWith({
    String? notes,
    ScriptFormat? format,
    String? customFormat,
    int? durationSeconds,
    ScriptTone? tone,
    ScriptLanguage? language,
  }) => ScriptGenerationRequest(
    notes: notes ?? this.notes,
    format: format ?? this.format,
    customFormat: customFormat ?? this.customFormat,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    tone: tone ?? this.tone,
    language: language ?? this.language,
  );

  @override
  List<Object?> get props => [
    notes,
    format,
    customFormat,
    durationSeconds,
    tone,
    language,
  ];
}
