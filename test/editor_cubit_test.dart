import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neurallens/core/config/app_config.dart';
import 'package:neurallens/data/local/app_database.dart';
import 'package:neurallens/features/ai/data/gemini_exception.dart';
import 'package:neurallens/features/ai/data/gemini_service.dart';
import 'package:neurallens/features/scripts/data/script_repository.dart';
import 'package:neurallens/features/scripts/logic/editor_cubit.dart';
import 'package:neurallens/features/scripts/models/script_enums.dart';
import 'package:neurallens/features/scripts/models/script_section.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory dir;
  late Database db;
  late ScriptRepository repo;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('neurallens_editor');
    db = await AppDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      path: '${dir.path}/t.db',
    );
    repo = ScriptRepository(db);
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  GeminiService gemini({String key = '', MockClientHandler? handler}) =>
      GeminiService(
        client: MockClient(handler ?? (_) async => http.Response('', 500)),
        config: AppConfig(geminiApiKey: key, geminiModel: 'm'),
      );

  EditorCubit editor({GeminiService? ai}) => EditorCubit(
    repository: repo,
    gemini: ai ?? gemini(),
    autosaveDelay: const Duration(milliseconds: 10),
  );

  test('empty new drafts are never written', () async {
    final cubit = editor()..createNew(ScriptKind.script);
    await cubit.close();
    expect(await repo.getAll(), isEmpty);
  });

  test('debounced autosave persists edits', () async {
    final cubit = editor()
      ..createNew(ScriptKind.note)
      ..updateTitle('Ideas')
      ..updateBody('Talk about focus');
    expect(cubit.state.saveStatus, SaveStatus.unsaved);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(cubit.state.saveStatus, SaveStatus.saved);
    expect(cubit.state.persisted, isTrue);
    final saved = (await repo.getAll()).single;
    expect(saved.title, 'Ideas');
    expect(saved.kind, ScriptKind.note);
    await cubit.close();
  });

  test(
    'closing flushes pending edits (navigating away keeps changes)',
    () async {
      final original = await repo.save(repo.draft(title: 'T', body: 'before'));
      final cubit = editor();
      await cubit.open(original.id);
      cubit.updateBody('after');
      await cubit.close(); // before the debounce fires
      expect((await repo.getById(original.id))!.body, 'after');
    },
  );

  test('hand edits clear stale AI sections', () async {
    final s = await repo.save(
      repo.draft(
        body: '## A\nHi',
        sections: const [
          ScriptSection(id: '1', heading: 'A', spokenText: 'Hi'),
        ],
      ),
    );
    final cubit = editor();
    await cubit.open(s.id);
    cubit.updateBody('## A\nHello');
    expect(cubit.state.script!.sections, isEmpty);
    await cubit.close();
  });

  test('missing script reports not found', () async {
    final cubit = editor();
    await cubit.open('nope');
    expect(cubit.state.load, EditorLoad.notFound);
    await cubit.close();
  });

  test('delete removes the script', () async {
    final s = await repo.save(repo.draft(title: 'Bye'));
    final cubit = editor();
    await cubit.open(s.id);
    await cubit.delete();
    expect(cubit.state.deleted, isTrue);
    expect(await repo.getById(s.id), isNull);
    await cubit.close();
    expect(await repo.getAll(), isEmpty, reason: 'close must not resurrect it');
  });

  test('AI revision requires confirmation before replacing text', () async {
    final s = await repo.save(repo.draft(title: 'T', body: 'Original words.'));
    final ai = gemini(
      key: 'k',
      handler: (_) async => http.Response(
        jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text': jsonEncode({
                      'title': 'T',
                      'estimatedDurationSeconds': 5,
                      'sections': [
                        {
                          'heading': 'New',
                          'spokenText': 'Revised words.',
                          'cueKeywords': [],
                        },
                      ],
                    }),
                  },
                ],
              },
            },
          ],
        }),
        200,
      ),
    );
    final cubit = editor(ai: ai);
    await cubit.open(s.id);
    await cubit.requestRewrite();

    expect(cubit.state.pendingRevision, isNotNull);
    expect(
      cubit.state.script!.body,
      'Original words.',
      reason: 'not replaced yet',
    );

    cubit.discardRevision();
    expect(cubit.state.pendingRevision, isNull);
    expect(cubit.state.script!.body, 'Original words.');

    await cubit.requestCueSections();
    await cubit.acceptRevision();
    expect(cubit.state.script!.body, '## New\nRevised words.');
    expect((await repo.getById(s.id))!.body, '## New\nRevised words.');
    await cubit.close();
  });

  test('AI failures surface as typed errors without crashing', () async {
    final s = await repo.save(repo.draft(body: 'Some text'));
    final cubit = editor(ai: gemini(key: 'k'));
    await cubit.open(s.id);
    await cubit.requestRewrite();
    expect(cubit.state.aiError?.kind, GeminiErrorKind.server);
    expect(cubit.state.failedTask, AiTask.rewrite);
    expect(cubit.state.aiTask, AiTask.none);
    await cubit.close();
  });
}
