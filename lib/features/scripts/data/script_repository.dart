import 'dart:async';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/script.dart';
import '../models/script_enums.dart';
import '../models/script_section.dart';

/// Local persistence for scripts and notes.
///
/// Emits on [changes] after every write so list views can refresh.
class ScriptRepository {
  ScriptRepository(this._db, {DateTime Function()? clock, Uuid? uuid})
    : _clock = clock ?? DateTime.now,
      _uuid = uuid ?? const Uuid();

  final Database _db;
  final DateTime Function() _clock;
  final Uuid _uuid;
  final _changes = StreamController<void>.broadcast();

  static const _table = 'scripts';

  Stream<void> get changes => _changes.stream;

  /// All scripts, most recently updated first.
  Future<List<Script>> getAll() async {
    final rows = await _db.query(_table, orderBy: 'updated_at DESC');
    return rows.map(Script.fromRow).toList();
  }

  Future<Script?> getById(String id) async {
    final rows = await _db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Script.fromRow(rows.first);
  }

  /// Builds an unsaved script with fresh id and timestamps.
  Script draft({
    ScriptKind kind = ScriptKind.script,
    String title = '',
    String body = '',
    List<ScriptSection> sections = const [],
    ScriptFormat format = ScriptFormat.custom,
    ScriptTone tone = ScriptTone.conversational,
    bool isAiGenerated = false,
    Map<String, Object?>? generationMeta,
  }) {
    final now = _clock();
    return Script(
      id: _uuid.v4(),
      kind: kind,
      title: title,
      body: body,
      sections: sections,
      format: format,
      tone: tone,
      isAiGenerated: isAiGenerated,
      generationMeta: generationMeta,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Inserts or replaces [script], stamping `updatedAt` with the current time.
  Future<Script> save(Script script) async {
    final saved = script.copyWith(updatedAt: _clock());
    await _db.insert(
      _table,
      saved.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _changes.add(null);
    return saved;
  }

  Future<void> delete(String id) async {
    await _db.delete(_table, where: 'id = ?', whereArgs: [id]);
    _changes.add(null);
  }

  Future<Script?> duplicate(String id) async {
    final original = await getById(id);
    if (original == null) return null;
    final now = _clock();
    final copy = Script(
      id: _uuid.v4(),
      kind: original.kind,
      title: '${original.displayTitle} (copy)',
      body: original.body,
      sections: original.sections,
      format: original.format,
      tone: original.tone,
      tags: original.tags,
      isAiGenerated: original.isAiGenerated,
      generationMeta: original.generationMeta,
      createdAt: now,
      updatedAt: now,
    );
    return save(copy);
  }

  Future<void> setFavorite(String id, {required bool favorite}) async {
    await _db.update(
      _table,
      {'is_favorite': favorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    _changes.add(null);
  }

  /// Stores the presentation position without bumping `updatedAt`, so
  /// presenting does not reorder the library.
  Future<void> savePosition(String id, int position) async {
    await _db.update(
      _table,
      {'last_position': position},
      where: 'id = ?',
      whereArgs: [id],
    );
    _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}
