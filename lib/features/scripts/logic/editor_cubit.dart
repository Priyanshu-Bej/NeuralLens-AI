import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../ai/data/gemini_exception.dart';
import '../../ai/data/gemini_service.dart';
import '../../ai/models/generated_script.dart';
import '../data/script_repository.dart';
import '../models/script.dart';
import '../models/script_enums.dart';

enum EditorLoad { loading, ready, notFound }

enum SaveStatus { saved, unsaved, saving, failed }

enum AiTask {
  none,
  rewrite('AI revision'),
  cueSections('Split into cards');

  const AiTask([this.label = '']);
  final String label;
}

class EditorState extends Equatable {
  const EditorState({
    this.load = EditorLoad.loading,
    this.script,
    this.persisted = false,
    this.saveStatus = SaveStatus.saved,
    this.aiTask = AiTask.none,
    this.aiError,
    this.pendingRevision,
    this.pendingKind = AiTask.none,
    this.failedTask = AiTask.none,
    this.contentVersion = 0,
    this.deleted = false,
  });

  final EditorLoad load;
  final Script? script;

  /// Whether the script exists in the database yet. Empty drafts are never
  /// written.
  final bool persisted;
  final SaveStatus saveStatus;

  /// AI work in flight, if any.
  final AiTask aiTask;
  final GeminiException? aiError;

  /// AI output awaiting the user's confirmation before it replaces the text.
  final GeneratedScript? pendingRevision;
  final AiTask pendingKind;

  /// The task behind [aiError], for retry.
  final AiTask failedTask;

  /// Bumped when content changes from outside the text fields (load, accepted
  /// revision) so the UI can reset its controllers.
  final int contentVersion;
  final bool deleted;

  EditorState copyWith({
    EditorLoad? load,
    Script? script,
    bool? persisted,
    SaveStatus? saveStatus,
    AiTask? aiTask,
    GeminiException? Function()? aiError,
    GeneratedScript? Function()? pendingRevision,
    AiTask? pendingKind,
    AiTask? failedTask,
    int? contentVersion,
    bool? deleted,
  }) => EditorState(
    load: load ?? this.load,
    script: script ?? this.script,
    persisted: persisted ?? this.persisted,
    saveStatus: saveStatus ?? this.saveStatus,
    aiTask: aiTask ?? this.aiTask,
    aiError: aiError == null ? this.aiError : aiError(),
    pendingRevision: pendingRevision == null
        ? this.pendingRevision
        : pendingRevision(),
    pendingKind: pendingKind ?? this.pendingKind,
    failedTask: failedTask ?? this.failedTask,
    contentVersion: contentVersion ?? this.contentVersion,
    deleted: deleted ?? this.deleted,
  );

  @override
  List<Object?> get props => [
    load,
    script,
    persisted,
    saveStatus,
    aiTask,
    aiError,
    pendingRevision,
    pendingKind,
    failedTask,
    contentVersion,
    deleted,
  ];
}

/// Edits one script with debounced autosave. Pending edits are flushed on
/// [close], so navigating away never drops changes.
class EditorCubit extends Cubit<EditorState> {
  EditorCubit({
    required this._repository,
    required this._gemini,
    this.autosaveDelay = const Duration(milliseconds: 800),
  }) : super(const EditorState());

  final ScriptRepository _repository;
  final GeminiService _gemini;
  final Duration autosaveDelay;
  Timer? _debounce;
  Future<void>? _inFlightSave;
  int _aiRequest = 0;

  bool get geminiConfigured => _gemini.isConfigured;

  Future<void> open(String id) async {
    final script = await _repository.getById(id);
    if (isClosed) return;
    emit(
      script == null
          ? state.copyWith(load: EditorLoad.notFound)
          : state.copyWith(
              load: EditorLoad.ready,
              script: script,
              persisted: true,
              contentVersion: state.contentVersion + 1,
            ),
    );
  }

  void createNew(ScriptKind kind) {
    emit(
      state.copyWith(
        load: EditorLoad.ready,
        script: _repository.draft(kind: kind),
        contentVersion: state.contentVersion + 1,
      ),
    );
  }

  // ---- Edits --------------------------------------------------------------

  void updateTitle(String title) => _edit((s) => s.copyWith(title: title));

  /// Hand edits invalidate AI sections; cues are then derived from headings.
  void updateBody(String body) =>
      _edit((s) => s.copyWith(body: body, sections: const []));

  void setFormat(ScriptFormat format) =>
      _edit((s) => s.copyWith(format: format));

  void setTone(ScriptTone tone) => _edit((s) => s.copyWith(tone: tone));

  void setKind(ScriptKind kind) => _edit((s) => s.copyWith(kind: kind));

  void setTags(List<String> tags) => _edit((s) => s.copyWith(tags: tags));

  void toggleFavorite() => _edit((s) => s.copyWith(isFavorite: !s.isFavorite));

  void _edit(Script Function(Script) change) {
    final script = state.script;
    if (script == null || state.deleted) return;
    final next = change(script);
    if (next == script) return;
    emit(state.copyWith(script: next, saveStatus: SaveStatus.unsaved));
    _debounce?.cancel();
    _debounce = Timer(autosaveDelay, () => save().ignore());
  }

  // ---- Persistence --------------------------------------------------------

  /// Writes pending changes. Safe to call repeatedly.
  Future<void> save() async {
    _debounce?.cancel();
    if (_inFlightSave != null) await _inFlightSave;
    final script = state.script;
    if (script == null || state.deleted) return;
    if (state.saveStatus == SaveStatus.saved) return;
    if (!state.persisted && script.isEmpty) return;

    final future = _doSave(script);
    _inFlightSave = future;
    await future;
    _inFlightSave = null;
  }

  Future<void> _doSave(Script script) async {
    if (!isClosed) emit(state.copyWith(saveStatus: SaveStatus.saving));
    try {
      final saved = await _repository.save(script);
      if (isClosed) return;
      // Keep any edits made while the write was in flight.
      final current = state.script!;
      final unchanged = current.copyWith(updatedAt: saved.updatedAt) == saved;
      emit(
        state.copyWith(
          script: unchanged
              ? saved
              : current.copyWith(updatedAt: saved.updatedAt),
          persisted: true,
          saveStatus: unchanged ? SaveStatus.saved : SaveStatus.unsaved,
        ),
      );
      if (!unchanged) {
        _debounce = Timer(autosaveDelay, () => save().ignore());
      }
    } catch (_) {
      if (!isClosed) emit(state.copyWith(saveStatus: SaveStatus.failed));
    }
  }

  Future<Script?> duplicate() async {
    await save();
    final script = state.script;
    if (script == null || !state.persisted) return null;
    return _repository.duplicate(script.id);
  }

  Future<void> delete() async {
    _debounce?.cancel();
    final script = state.script;
    if (script != null && state.persisted) {
      await _repository.delete(script.id);
    }
    if (!isClosed) emit(state.copyWith(deleted: true));
  }

  // ---- AI -----------------------------------------------------------------

  Future<void> requestRewrite({String instruction = ''}) => _runAi(
    AiTask.rewrite,
    (s) => _gemini.rewriteScript(
      text: s.body,
      instruction: instruction,
      format: s.format,
      tone: s.tone,
    ),
  );

  Future<void> requestCueSections() => _runAi(
    AiTask.cueSections,
    (s) => _gemini.generateCueSections(
      text: s.body,
      format: s.format,
      tone: s.tone,
    ),
  );

  Future<void> _runAi(
    AiTask task,
    Future<GeneratedScript> Function(Script) call,
  ) async {
    final script = state.script;
    if (script == null || script.body.trim().isEmpty) return;
    final request = ++_aiRequest;
    emit(
      state.copyWith(
        aiTask: task,
        aiError: () => null,
        pendingRevision: () => null,
      ),
    );
    try {
      final result = await call(script);
      if (isClosed || request != _aiRequest) return;
      emit(
        state.copyWith(
          aiTask: AiTask.none,
          pendingRevision: () => result,
          pendingKind: task,
        ),
      );
    } on GeminiException catch (e) {
      if (isClosed || request != _aiRequest) return;
      emit(
        state.copyWith(aiTask: AiTask.none, aiError: () => e, failedTask: task),
      );
    } catch (_) {
      if (isClosed || request != _aiRequest) return;
      emit(
        state.copyWith(
          aiTask: AiTask.none,
          aiError: () => const GeminiException(GeminiErrorKind.invalidResponse),
          failedTask: task,
        ),
      );
    }
  }

  void cancelAi() {
    _aiRequest++;
    emit(state.copyWith(aiTask: AiTask.none));
  }

  void dismissAiError() => emit(state.copyWith(aiError: () => null));

  void discardRevision() => emit(
    state.copyWith(pendingRevision: () => null, pendingKind: AiTask.none),
  );

  /// Replaces the body with the confirmed AI revision.
  Future<void> acceptRevision() async {
    final revision = state.pendingRevision;
    final script = state.script;
    if (revision == null || script == null) return;
    emit(
      state.copyWith(
        script: script.copyWith(
          body: revision.body,
          sections: revision.sections,
          generationMeta: {
            ...?script.generationMeta,
            'model': _gemini.model,
            'lastAiEdit': state.pendingKind.name,
            'lastAiEditAt': DateTime.now().toIso8601String(),
          },
        ),
        pendingRevision: () => null,
        pendingKind: AiTask.none,
        saveStatus: SaveStatus.unsaved,
        contentVersion: state.contentVersion + 1,
      ),
    );
    await save();
  }

  @override
  Future<void> close() async {
    _debounce?.cancel();
    _aiRequest++;
    await save();
    return super.close();
  }
}
