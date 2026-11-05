import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neurallens/data/local/app_database.dart';
import 'package:neurallens/features/scripts/data/script_repository.dart';
import 'package:neurallens/features/scripts/logic/library_cubit.dart';
import 'package:neurallens/features/scripts/models/script_enums.dart';
import 'package:neurallens/features/scripts/models/script_section.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfiNoIsolate;

  late Directory dir;
  late String path;
  late Database db;
  late ScriptRepository repo;
  var now = DateTime(2026, 10, 1, 12);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('neurallens_test');
    path = '${dir.path}/test.db';
    db = await AppDatabase.open(factory: factory, path: path);
    repo = ScriptRepository(db, clock: () => now);
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  test('creates, reads and lists most recent first', () async {
    await repo.save(repo.draft(title: 'Older', body: 'a'));
    now = now.add(const Duration(minutes: 5));
    await repo.save(repo.draft(title: 'Newer', body: 'b'));

    final all = await repo.getAll();
    expect(all.map((s) => s.title), ['Newer', 'Older']);
  });

  test('editing updates content and timestamp but keeps createdAt', () async {
    final created = await repo.save(repo.draft(title: 'T', body: 'v1'));
    now = now.add(const Duration(hours: 1));
    final edited = await repo.save(created.copyWith(body: 'v2'));

    final loaded = await repo.getById(created.id);
    expect(loaded!.body, 'v2');
    expect(loaded.createdAt, created.createdAt);
    expect(loaded.updatedAt, edited.updatedAt);
    expect(loaded.updatedAt.isAfter(created.updatedAt), isTrue);
  });

  test('round-trips every field', () async {
    final draft = repo.draft(
      kind: ScriptKind.note,
      title: 'Full',
      body: '## A\nHi',
      sections: const [
        ScriptSection(
          id: 's1',
          heading: 'A',
          spokenText: 'Hi',
          cueKeywords: ['k'],
        ),
      ],
      format: ScriptFormat.podcast,
      tone: ScriptTone.storytelling,
      isAiGenerated: true,
      generationMeta: {'model': 'm', 'requestedDurationSeconds': 60},
    );
    await repo.save(draft.copyWith(tags: ['x', 'y'], isFavorite: true));

    final loaded = (await repo.getById(draft.id))!;
    expect(loaded.kind, ScriptKind.note);
    expect(loaded.sections.single.cueKeywords, ['k']);
    expect(loaded.format, ScriptFormat.podcast);
    expect(loaded.tone, ScriptTone.storytelling);
    expect(loaded.tags, ['x', 'y']);
    expect(loaded.isFavorite, isTrue);
    expect(loaded.isAiGenerated, isTrue);
    expect(loaded.generationMeta, {
      'model': 'm',
      'requestedDurationSeconds': 60,
    });
  });

  test('deletes', () async {
    final s = await repo.save(repo.draft(title: 'Gone'));
    await repo.delete(s.id);
    expect(await repo.getById(s.id), isNull);
    expect(await repo.getAll(), isEmpty);
  });

  test('duplicates with a new id and copy title', () async {
    final s = await repo.save(repo.draft(title: 'Talk', body: 'Words'));
    final copy = (await repo.duplicate(s.id))!;
    expect(copy.id, isNot(s.id));
    expect(copy.title, 'Talk (copy)');
    expect(copy.body, 'Words');
    expect(await repo.getAll(), hasLength(2));
    expect(await repo.duplicate('missing'), isNull);
  });

  test('favorite and position updates do not reorder the library', () async {
    final a = await repo.save(repo.draft(title: 'A'));
    now = now.add(const Duration(minutes: 1));
    await repo.save(repo.draft(title: 'B'));

    await repo.setFavorite(a.id, favorite: true);
    await repo.savePosition(a.id, 7);

    final all = await repo.getAll();
    expect(all.map((s) => s.title), ['B', 'A']);
    expect(all.last.isFavorite, isTrue);
    expect(all.last.lastPosition, 7);
  });

  test('data persists after reopening the database', () async {
    final s = await repo.save(
      repo.draft(title: 'Persistent', body: 'Still here'),
    );
    await db.close();

    db = await AppDatabase.open(factory: factory, path: path);
    repo = ScriptRepository(db);
    final loaded = await repo.getById(s.id);
    expect(loaded?.body, 'Still here');
  });

  test('emits change notifications on writes', () async {
    final events = <void>[];
    final sub = repo.changes.listen(events.add);
    final s = await repo.save(repo.draft(title: 'x'));
    await repo.setFavorite(s.id, favorite: true);
    await repo.delete(s.id);
    await Future<void>.delayed(Duration.zero);
    expect(events, hasLength(3));
    await sub.cancel();
  });

  test('library filter and search', () async {
    final talk = await repo.save(
      repo
          .draft(title: 'Keynote', body: 'Welcome everyone')
          .copyWith(tags: ['conf']),
    );
    await repo.save(
      repo.draft(kind: ScriptKind.note, title: 'Ideas', body: 'demo'),
    );
    await repo.setFavorite(talk.id, favorite: true);
    final all = await repo.getAll();

    expect(filterScripts(all, query: 'welcome').single.title, 'Keynote');
    expect(filterScripts(all, query: 'CONF').single.title, 'Keynote');
    expect(
      filterScripts(all, filter: LibraryFilter.notes).single.title,
      'Ideas',
    );
    expect(
      filterScripts(all, filter: LibraryFilter.scripts).single.title,
      'Keynote',
    );
    expect(
      filterScripts(all, filter: LibraryFilter.favorites).single.title,
      'Keynote',
    );
    expect(filterScripts(all, query: 'nothing'), isEmpty);
  });
}
