import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../ai/data/gemini_exception.dart';
import '../../ai/data/gemini_service.dart';
import '../../wearables/data/wearables_service.dart';
import '../../wearables/models/wearables_models.dart';
import '../models/question_answer.dart';

enum QuestionPhase {
  idle,
  openingCamera,
  preview,
  closingCamera,
  capturing,
  analyzing,
  delivering,
  ready,
  error,
}

class QuestionState {
  const QuestionState({
    this.phase = QuestionPhase.idle,
    this.photo,
    this.preview,
    this.zoom = 1,
    this.answer,
    this.message,
    this.shownOnGlasses = false,
  });

  final QuestionPhase phase;
  final Uint8List? photo;
  final CameraPreviewFrame? preview;
  final double zoom;
  final QuestionAnswer? answer;
  final String? message;
  final bool shownOnGlasses;
  bool get busy =>
      phase == QuestionPhase.openingCamera ||
      phase == QuestionPhase.closingCamera ||
      phase == QuestionPhase.capturing ||
      phase == QuestionPhase.analyzing ||
      phase == QuestionPhase.delivering;
}

/// Owns one capture/answer at a time. Late results after disconnect or exit are
/// discarded, so an old answer can never replace the next question.
class QuestionCubit extends Cubit<QuestionState> {
  QuestionCubit(this._wearables, this._gemini) : super(const QuestionState()) {
    _inputs = _wearables.inputs.listen((input) {
      if (!_active) return;
      switch (input) {
        case WearableInput.capture:
        case WearableInput.select:
          unawaited(
            state.phase == QuestionPhase.preview ? capture() : openPreview(),
          );
        case WearableInput.next:
          unawaited(openPreview());
        case WearableInput.back:
          if (state.phase == QuestionPhase.preview) unawaited(cancelPreview());
        case WearableInput.previous:
          break;
      }
    });
    _connection = _wearables.states.listen((connection) {
      if (_active &&
          const {
            WearablesStatus.disconnected,
            WearablesStatus.error,
            WearablesStatus.unregistered,
            WearablesStatus.unsupported,
          }.contains(connection.status)) {
        _generation++;
        unawaited(_stopPreview());
        emit(
          QuestionState(
            phase: QuestionPhase.error,
            photo: state.photo,
            answer: state.answer,
            message:
                'Glasses disconnected. Reconnect before taking another photo.',
          ),
        );
      }
    });
  }

  final WearablesService _wearables;
  final GeminiService _gemini;
  late final StreamSubscription<WearableInput> _inputs;
  late final StreamSubscription<WearablesState> _connection;
  int _generation = 0;
  bool _active = false;
  bool _closing = false;
  StreamSubscription<CameraPreviewFrame>? _cameraSub;
  Future<void> _cameraCleanup = Future.value();
  Timer? _frameTimeout;

  Future<void> start() async {
    if (_closing || isClosed) return;
    try {
      await _wearables.setQuestionMode(true);
      if (!isClosed && !_closing) _active = true;
    } on Object {
      if (!isClosed && !_closing) {
        emit(
          const QuestionState(
            phase: QuestionPhase.error,
            message:
                'Question Lens requires the Android Meta glasses integration.',
          ),
        );
      }
    }
  }

  Future<void> suspend() async {
    _active = false;
    _generation++;
    await _stopPreview();
    await _wearables.setQuestionMode(false);
  }

  bool _current(int id) => !isClosed && !_closing && id == _generation;

  Future<void> openPreview() async {
    if (isClosed ||
        _closing ||
        !_active ||
        state.busy ||
        state.phase == QuestionPhase.preview) {
      return;
    }
    if (!_gemini.isConfigured) {
      emit(
        const QuestionState(
          phase: QuestionPhase.error,
          message: 'Gemini setup is required before capturing a question.',
        ),
      );
      return;
    }
    if (!_wearables.state.isConnected) {
      emit(
        const QuestionState(
          phase: QuestionPhase.error,
          message: 'Connect your Meta Ray-Ban Display glasses first.',
        ),
      );
      return;
    }
    final id = ++_generation;
    emit(const QuestionState(phase: QuestionPhase.openingCamera));
    try {
      await _cameraCleanup;
      if (!_current(id)) return;
      await _wearables.clearDisplay();
      if (!_current(id)) return;
      _cameraSub = _wearables.cameraPreview.listen((frame) {
        if (!_current(id) ||
            (state.phase != QuestionPhase.openingCamera &&
                state.phase != QuestionPhase.preview)) {
          return;
        }
        emit(
          QuestionState(
            phase: QuestionPhase.preview,
            preview: frame,
            zoom: state.zoom,
          ),
        );
        _frameTimeout?.cancel();
        _frameTimeout = Timer(const Duration(seconds: 4), () {
          if (_current(id) && state.phase == QuestionPhase.preview) {
            _previewFailed(
              PlatformException(
                code: 'preview_stalled',
                message: 'Camera preview stopped updating. Reopen the camera.',
              ),
              id,
            );
          }
        });
      }, onError: (Object error) => _previewFailed(error, id));
      await _wearables.startCameraPreview();
    } on Object catch (error) {
      _previewFailed(error, id);
    }
  }

  void setZoom(double zoom) {
    if (state.phase != QuestionPhase.preview || !zoom.isFinite) return;
    emit(
      QuestionState(
        phase: QuestionPhase.preview,
        preview: state.preview,
        zoom: zoom.clamp(1.0, 3.0),
      ),
    );
  }

  void _previewFailed(Object error, int id) {
    if (!_current(id)) return;
    _fail(error, id);
    _generation++;
    unawaited(_stopPreview());
  }

  Future<void> cancelPreview() async {
    if (_closing ||
        isClosed ||
        (state.phase != QuestionPhase.preview &&
            state.phase != QuestionPhase.openingCamera &&
            state.phase != QuestionPhase.capturing)) {
      return;
    }
    final id = ++_generation;
    emit(const QuestionState(phase: QuestionPhase.closingCamera));
    await _stopPreview();
    if (_current(id)) emit(const QuestionState());
  }

  /// Close the camera when the app goes into the background. Opening is excluded
  /// because the initial Meta AI camera-permission dialog switches apps.
  void pauseCamera() {
    if (state.phase == QuestionPhase.preview ||
        state.phase == QuestionPhase.capturing) {
      unawaited(cancelPreview());
    }
  }

  Future<void> _stopPreview() {
    _frameTimeout?.cancel();
    final sub = _cameraSub;
    _cameraSub = null;
    return _cameraCleanup = _cameraCleanup.then((_) async {
      try {
        await _wearables.stopCameraPreview();
      } on Object {
        /* Already disconnected. */
      }
      await sub?.cancel();
    });
  }

  Future<void> capture() async {
    // No route, gesture or button can bypass preview and trigger an auto-capture.
    if (isClosed ||
        _closing ||
        !_active ||
        state.phase != QuestionPhase.preview ||
        state.preview == null) {
      return;
    }
    final zoom = state.zoom;
    final id = ++_generation;
    _frameTimeout?.cancel();
    emit(const QuestionState(phase: QuestionPhase.capturing));
    try {
      final photo = await _wearables.capturePhoto(zoom: zoom);
      if (!_current(id)) return;
      await _stopPreview();
      if (!_current(id)) return;
      await _analyze(photo, id);
    } on Object catch (e) {
      if (_current(id)) {
        await _stopPreview();
        _fail(e, id);
      }
    }
  }

  Future<void> retry() async {
    final photo = state.photo;
    if (isClosed ||
        state.busy ||
        photo == null ||
        !_wearables.state.isConnected) {
      return;
    }
    final id = ++_generation;
    try {
      await _analyze(photo, id);
    } on Object catch (e) {
      _fail(e, id);
    }
  }

  Future<void> _analyze(Uint8List photo, int id) async {
    emit(QuestionState(phase: QuestionPhase.analyzing, photo: photo));
    final answer = await _gemini.answerQuestion(photo);
    if (!_current(id)) return;
    emit(
      QuestionState(
        phase: QuestionPhase.delivering,
        photo: photo,
        answer: answer,
      ),
    );
    await _deliver(id);
  }

  Future<void> showAgain() async {
    if (isClosed || state.busy || state.answer == null) return;
    final id = ++_generation;
    emit(
      QuestionState(
        phase: QuestionPhase.delivering,
        photo: state.photo,
        answer: state.answer,
      ),
    );
    await _deliver(id);
  }

  Future<void> _deliver(int id) async {
    final answer = state.answer!;
    final photo = state.photo;
    var shown = false;
    try {
      shown = await _wearables.showCue(
        GlassesCue(
          heading: answer.heading,
          lines: compactLines(answer.glassesText),
          position: 1,
          total: 1,
          next: 'Next: open camera on phone',
        ),
      );
    } on Object {
      // Keep the answer on the phone if Bluetooth delivery fails.
    }
    if (!_current(id)) return;
    emit(
      QuestionState(
        phase: QuestionPhase.ready,
        photo: photo,
        answer: answer,
        shownOnGlasses: shown,
        message: shown
            ? null
            : 'Answer is on your phone. Glasses display delivery failed.',
      ),
    );
  }

  /// Hard bounds also handle long unbroken formulas/words on the small display.
  static List<String> compactLines(String text) {
    var remaining = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final lines = <String>[];
    while (remaining.isNotEmpty && lines.length < 4) {
      if (remaining.length <= 28) {
        lines.add(remaining);
        break;
      }
      if (lines.length == 3) {
        lines.add('${remaining.substring(0, 27)}…');
        break;
      }
      final space = remaining.lastIndexOf(' ', 28);
      final end = space > 0 ? space : 28;
      lines.add(remaining.substring(0, end));
      remaining = remaining.substring(end).trimLeft();
    }
    return lines;
  }

  void _fail(Object error, int id) {
    if (!_current(id)) return;
    final message = switch (error) {
      GeminiException(kind: GeminiErrorKind.invalidResponse) =>
        'The answer could not be read. Retry or take a clearer photo.',
      GeminiException(kind: GeminiErrorKind.timeout) =>
        'The answer timed out. Check your connection and retry.',
      final GeminiException e => e.message,
      final PlatformException e =>
        e.message ?? 'Camera unavailable. Try again.',
      _ => 'Could not process this photo. Please try again.',
    };
    emit(
      QuestionState(
        phase: QuestionPhase.error,
        photo: state.photo,
        message: message,
      ),
    );
  }

  @override
  Future<void> close() async {
    _closing = true;
    _active = false;
    _generation++;
    await _inputs.cancel();
    await _connection.cancel();
    await _stopPreview();
    try {
      await _wearables.setQuestionMode(false);
      await _wearables.clearDisplay();
    } on Object {
      // The device may already have disconnected.
    }
    await super.close();
  }
}
