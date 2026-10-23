import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../scripts/data/script_repository.dart';
import '../../scripts/models/script.dart';
import '../../scripts/models/script_enums.dart';
import '../data/gemini_exception.dart';
import '../data/gemini_service.dart';
import '../models/generated_script.dart';

enum StudioStatus { editing, generating, success, failure }

class StudioState extends Equatable {
  const StudioState({
    this.request = const ScriptGenerationRequest(notes: ''),
    this.status = StudioStatus.editing,
    this.result,
    this.error,
  });

  /// Preserved across generate/cancel/regenerate.
  final ScriptGenerationRequest request;
  final StudioStatus status;
  final GeneratedScript? result;
  final GeminiException? error;

  StudioState copyWith({
    ScriptGenerationRequest? request,
    StudioStatus? status,
    GeneratedScript? Function()? result,
    GeminiException? Function()? error,
  }) => StudioState(
    request: request ?? this.request,
    status: status ?? this.status,
    result: result == null ? this.result : result(),
    error: error == null ? this.error : error(),
  );

  @override
  List<Object?> get props => [request, status, result, error];
}

class StudioCubit extends Cubit<StudioState> {
  StudioCubit({required this._gemini, required this._repository})
    : super(const StudioState());

  final GeminiService _gemini;
  final ScriptRepository _repository;

  /// Incremented to invalidate in-flight requests (cancel / close).
  int _request = 0;

  bool get isConfigured => _gemini.isConfigured;
  String get model => _gemini.model;

  void updateRequest(ScriptGenerationRequest request) =>
      emit(state.copyWith(request: request));

  /// Generates only on explicit user action.
  Future<void> generate() async {
    if (!state.request.isValid || state.status == StudioStatus.generating) {
      return;
    }
    final id = ++_request;
    emit(state.copyWith(status: StudioStatus.generating, error: () => null));
    try {
      final result = await _gemini.generateScript(state.request);
      if (isClosed || id != _request) return;
      emit(state.copyWith(status: StudioStatus.success, result: () => result));
    } on GeminiException catch (e) {
      if (isClosed || id != _request) return;
      emit(state.copyWith(status: StudioStatus.failure, error: () => e));
    } catch (_) {
      if (isClosed || id != _request) return;
      emit(
        state.copyWith(
          status: StudioStatus.failure,
          error: () => const GeminiException(GeminiErrorKind.invalidResponse),
        ),
      );
    }
  }

  /// Abandons the in-flight request; the HTTP call completes in the
  /// background and its result is discarded.
  void cancel() {
    _request++;
    emit(
      state.copyWith(
        status: state.result == null
            ? StudioStatus.editing
            : StudioStatus.success,
      ),
    );
  }

  /// Back to the form with input intact.
  void editInput() => emit(state.copyWith(status: StudioStatus.editing));

  /// Saves the result as a new script; never overwrites an existing one.
  Future<Script?> saveResult() async {
    final result = state.result;
    if (result == null) return null;
    final r = state.request;
    final draft = _repository.draft(
      kind: ScriptKind.script,
      title: result.title,
      body: result.body,
      sections: result.sections,
      format: result.format,
      tone: result.tone,
      isAiGenerated: true,
      generationMeta: {
        'model': _gemini.model,
        'generatedAt': DateTime.now().toIso8601String(),
        'requestedDurationSeconds': r.durationSeconds,
        'estimatedDurationSeconds': result.estimatedDurationSeconds,
        'language': r.language.code,
        if (r.format == ScriptFormat.custom && r.customFormat.isNotEmpty)
          'customFormat': r.customFormat,
        'sourceNotes': r.notes,
      },
    );
    return _repository.save(draft);
  }

  @override
  Future<void> close() {
    _request++;
    return super.close();
  }
}
