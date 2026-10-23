import 'dart:convert';

import 'package:equatable/equatable.dart';

import 'script_enums.dart';
import 'script_section.dart';

/// A saved script or note.
///
/// [body] is the editable source of truth. [sections] holds AI-structured
/// sections (with cue keywords) and is cleared whenever the body is edited by
/// hand, after which cues are derived from the body's `## headings`.
class Script extends Equatable {
  const Script({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.sections = const [],
    this.format = ScriptFormat.custom,
    this.tone = ScriptTone.conversational,
    this.tags = const [],
    this.isFavorite = false,
    this.isAiGenerated = false,
    this.generationMeta,
    this.lastPosition = 0,
  });

  final String id;
  final ScriptKind kind;
  final String title;
  final String body;
  final List<ScriptSection> sections;
  final ScriptFormat format;
  final ScriptTone tone;
  final List<String> tags;
  final bool isFavorite;
  final bool isAiGenerated;

  /// Model name, prompt summary and similar; never contains secrets.
  final Map<String, Object?>? generationMeta;

  /// Last presented cue index, restored when presenting again.
  final int lastPosition;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayTitle => title.trim().isEmpty ? 'Untitled' : title.trim();

  bool get isEmpty => title.trim().isEmpty && body.trim().isEmpty;

  /// Body text without heading markers, for previews.
  String get preview => body
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('#'))
      .join(' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Script copyWith({
    ScriptKind? kind,
    String? title,
    String? body,
    List<ScriptSection>? sections,
    ScriptFormat? format,
    ScriptTone? tone,
    List<String>? tags,
    bool? isFavorite,
    bool? isAiGenerated,
    Map<String, Object?>? generationMeta,
    int? lastPosition,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Script(
    id: id,
    kind: kind ?? this.kind,
    title: title ?? this.title,
    body: body ?? this.body,
    sections: sections ?? this.sections,
    format: format ?? this.format,
    tone: tone ?? this.tone,
    tags: tags ?? this.tags,
    isFavorite: isFavorite ?? this.isFavorite,
    isAiGenerated: isAiGenerated ?? this.isAiGenerated,
    generationMeta: generationMeta ?? this.generationMeta,
    lastPosition: lastPosition ?? this.lastPosition,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'body': body,
    'sections_json': sections.isEmpty
        ? null
        : jsonEncode(sections.map((s) => s.toJson()).toList()),
    'format': format.name,
    'tone': tone.name,
    'tags': tags.join(','),
    'is_favorite': isFavorite ? 1 : 0,
    'is_ai_generated': isAiGenerated ? 1 : 0,
    'generation_meta_json': generationMeta == null
        ? null
        : jsonEncode(generationMeta),
    'last_position': lastPosition,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };

  factory Script.fromRow(Map<String, Object?> row) {
    final sectionsJson = row['sections_json'] as String?;
    final metaJson = row['generation_meta_json'] as String?;
    final tags = (row['tags'] as String? ?? '')
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    return Script(
      id: row['id']! as String,
      kind: ScriptKind.fromName(row['kind'] as String?),
      title: row['title'] as String? ?? '',
      body: row['body'] as String? ?? '',
      sections: sectionsJson == null
          ? const []
          : (jsonDecode(sectionsJson) as List<Object?>)
                .whereType<Map<String, Object?>>()
                .map(ScriptSection.fromJson)
                .toList(),
      format: ScriptFormat.fromName(row['format'] as String?),
      tone: ScriptTone.fromName(row['tone'] as String?),
      tags: tags,
      isFavorite: row['is_favorite'] == 1,
      isAiGenerated: row['is_ai_generated'] == 1,
      generationMeta: metaJson == null
          ? null
          : (jsonDecode(metaJson) as Map<String, Object?>),
      lastPosition: row['last_position'] as int? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at']! as int),
    );
  }

  @override
  List<Object?> get props => [
    id,
    kind,
    title,
    body,
    sections,
    format,
    tone,
    tags,
    isFavorite,
    isAiGenerated,
    generationMeta,
    lastPosition,
    createdAt,
    updatedAt,
  ];
}
