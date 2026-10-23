import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../scripts/models/cue.dart';
import '../../scripts/models/script.dart';
import '../../scripts/util/cue_segmenter.dart';
import '../../scripts/util/duration_estimator.dart';
import '../../wearables/data/wearables_service.dart';
import '../../wearables/models/wearables_models.dart';
import '../models/presentation_settings.dart';

enum PlaybackStatus { ready, playing, paused, finished }

class PresentationState extends Equatable {
  const PresentationState({
    required this.script,
    required this.cues,
    required this.settings,
    this.cueIndex = 0,
    this.status = PlaybackStatus.ready,
    this.scrollProgress = 0,
    this.navigationSeq = 0,
  });

  final Script script;
  final List<Cue> cues;
  final PresentationSettings settings;
  final int cueIndex;
  final PlaybackStatus status;

  /// Phone mode only: scroll fraction reported by the UI.
  final double scrollProgress;

  /// Incremented on explicit navigation (next/previous/restart) so the phone
  /// view knows to scroll to [cueIndex] rather than follow the user's scroll.
  final int navigationSeq;

  bool get isEmpty => cues.isEmpty;
  bool get isPlaying => status == PlaybackStatus.playing;
  Cue? get currentCue => cues.isEmpty ? null : cues[cueIndex];
  Cue? get nextCue => cueIndex + 1 < cues.length ? cues[cueIndex + 1] : null;
  int get sectionCount => cues.isEmpty ? 0 : cues.last.sectionIndex + 1;

  double get progress {
    if (cues.isEmpty) return 0;
    if (status == PlaybackStatus.finished) return 1;
    return settings.mode == PresentationMode.phone
        ? scrollProgress
        : (cueIndex + 1) / cues.length;
  }

  PresentationState copyWith({
    PresentationSettings? settings,
    int? cueIndex,
    PlaybackStatus? status,
    double? scrollProgress,
    int? navigationSeq,
  }) => PresentationState(
    script: script,
    cues: cues,
    settings: settings ?? this.settings,
    cueIndex: cueIndex ?? this.cueIndex,
    status: status ?? this.status,
    scrollProgress: scrollProgress ?? this.scrollProgress,
    navigationSeq: navigationSeq ?? this.navigationSeq,
  );

  @override
  List<Object?> get props => [
    script.id,
    cues,
    settings,
    cueIndex,
    status,
    scrollProgress,
    navigationSeq,
  ];
}

/// Callbacks keep the cubit free of storage concerns and easy to test.
typedef PositionSaver = Future<void> Function(String scriptId, int cueIndex);
typedef SessionTracker = void Function(String? unfinishedScriptId);

/// Teleprompter state machine: ready → playing ⇄ paused → finished.
///
/// Glasses mode advances cues on [tick] using words-per-minute pacing.
/// Phone mode is scrolled by the UI, which reports progress back via
/// [syncFromScroll] and [markFinished].
class PresentationCubit extends Cubit<PresentationState> {
  PresentationCubit({
    required Script script,
    required PresentationSettings settings,
    this._wearables,
    this.onSettingsChanged,
    this.savePosition,
    this.trackSession,
    this.invertBandNavigation = false,
    this.bandSelectAction = BandSelectAction.pauseResume,
    this.glassesThrottle = const Duration(milliseconds: 400),
  }) : super(_initialState(script, settings)) {
    final wearables = _wearables;
    if (wearables != null) {
      _inputSub = wearables.inputs.listen(handleInput);
      _wearablesSub = wearables.states.listen((s) {
        if (s.canShowCues) _pushCue(force: true);
      });
    }
  }

  static PresentationState _initialState(
    Script script,
    PresentationSettings settings,
  ) {
    final cues = CueSegmenter.cues(script.resolvedSections);
    final resume = script.lastPosition.clamp(
      0,
      cues.isEmpty ? 0 : cues.length - 1,
    );
    return PresentationState(
      script: script,
      cues: cues,
      settings: settings,
      cueIndex: resume,
    );
  }

  final WearablesService? _wearables;
  final void Function(PresentationSettings)? onSettingsChanged;
  final PositionSaver? savePosition;
  final SessionTracker? trackSession;
  final bool invertBandNavigation;
  final BandSelectAction bandSelectAction;
  final Duration glassesThrottle;

  StreamSubscription<WearableInput>? _inputSub;
  StreamSubscription<WearablesState>? _wearablesSub;
  Duration _cueElapsed = Duration.zero;
  DateTime? _lastPush;
  Timer? _pushTimer;
  GlassesCue? _lastSentCue;

  // ---- Playback -----------------------------------------------------------

  void play() {
    if (state.isEmpty) return;
    if (state.status == PlaybackStatus.finished) {
      restart();
      return;
    }
    trackSession?.call(state.script.id);
    _emit(state.copyWith(status: PlaybackStatus.playing));
  }

  void pause() {
    if (state.status != PlaybackStatus.playing) return;
    _emit(state.copyWith(status: PlaybackStatus.paused));
    _persistPosition();
  }

  void togglePlay() => state.isPlaying ? pause() : play();

  void restart() {
    if (state.isEmpty) return;
    _cueElapsed = Duration.zero;
    trackSession?.call(state.script.id);
    _emit(
      state.copyWith(
        cueIndex: 0,
        scrollProgress: 0,
        status: PlaybackStatus.playing,
        navigationSeq: state.navigationSeq + 1,
      ),
    );
  }

  void markFinished() {
    if (state.status == PlaybackStatus.finished) return;
    _emit(
      state.copyWith(
        status: PlaybackStatus.finished,
        cueIndex: state.cues.isEmpty ? 0 : state.cues.length - 1,
      ),
    );
    trackSession?.call(null);
    savePosition?.call(state.script.id, 0).ignore();
  }

  // ---- Navigation ---------------------------------------------------------

  void nextCue() => _goTo(state.cueIndex + 1, finishPastEnd: true);

  void previousCue() => _goTo(state.cueIndex - 1);

  void nextSection() {
    final current = state.currentCue?.sectionIndex ?? 0;
    final target = state.cues.indexWhere((c) => c.sectionIndex > current);
    if (target >= 0) _goTo(target);
  }

  /// Goes to the start of the current section, or to the previous section
  /// when already at its start.
  void previousSection() {
    final cue = state.currentCue;
    if (cue == null) return;
    final sectionStart = state.cues.indexWhere(
      (c) => c.sectionIndex == cue.sectionIndex,
    );
    if (state.cueIndex > sectionStart) {
      _goTo(sectionStart);
    } else if (cue.sectionIndex > 0) {
      _goTo(
        state.cues.indexWhere((c) => c.sectionIndex == cue.sectionIndex - 1),
      );
    }
  }

  void _goTo(int index, {bool finishPastEnd = false}) {
    if (state.isEmpty) return;
    if (index >= state.cues.length) {
      if (finishPastEnd) markFinished();
      return;
    }
    final target = index.clamp(0, state.cues.length - 1);
    _cueElapsed = Duration.zero;
    _emit(
      state.copyWith(
        cueIndex: target,
        status: state.status == PlaybackStatus.finished
            ? PlaybackStatus.paused
            : null,
        navigationSeq: state.navigationSeq + 1,
      ),
    );
  }

  // ---- Clocks and UI sync -------------------------------------------------

  /// Advances glasses-mode pacing by [elapsed]. No-op in phone mode.
  void tick(Duration elapsed) {
    if (!state.isPlaying ||
        state.settings.mode != PresentationMode.glasses ||
        state.isEmpty) {
      return;
    }
    _cueElapsed += elapsed;
    final cue = state.currentCue!;
    final dwell = DurationEstimator.cueDuration(
      cue.text,
      wpm: state.settings.wordsPerMinute,
    );
    if (_cueElapsed < dwell) return;
    _cueElapsed = Duration.zero;
    if (state.cueIndex + 1 >= state.cues.length) {
      markFinished();
    } else {
      _emit(state.copyWith(cueIndex: state.cueIndex + 1));
    }
  }

  /// Phone mode: the UI reports which cue is at the reading line.
  void syncFromScroll({required int cueIndex, required double progress}) {
    if (state.isEmpty) return;
    final index = cueIndex.clamp(0, state.cues.length - 1);
    if (index == state.cueIndex &&
        (progress - state.scrollProgress).abs() < 0.002) {
      return;
    }
    emit(state.copyWith(cueIndex: index, scrollProgress: progress.clamp(0, 1)));
  }

  // ---- Settings -----------------------------------------------------------

  void updateSettings(PresentationSettings settings) {
    if (settings == state.settings) return;
    final modeChanged = settings.mode != state.settings.mode;
    // A speed change keeps the time already spent on the current card, so
    // adjusting pace mid-read doesn't restart it.
    if (modeChanged) _cueElapsed = Duration.zero;
    _emit(
      state.copyWith(
        settings: settings,
        navigationSeq: modeChanged ? state.navigationSeq + 1 : null,
      ),
    );
    onSettingsChanged?.call(settings);
  }

  /// Sets the autoplay speed (clamped to the supported range).
  void setSpeed(int speed) =>
      updateSettings(state.settings.copyWith(speed: speed));

  void faster() => setSpeed(state.settings.speed + 1);

  void slower() => setSpeed(state.settings.speed - 1);

  // ---- Wearable input -----------------------------------------------------

  void handleInput(WearableInput input) {
    switch (input) {
      case WearableInput.next:
        invertBandNavigation ? previousCue() : nextCue();
      case WearableInput.previous:
        invertBandNavigation ? nextCue() : previousCue();
      case WearableInput.select:
        bandSelectAction == BandSelectAction.pauseResume
            ? togglePlay()
            : nextCue();
      case WearableInput.back:
        pause();
    }
  }

  // ---- Glasses output -----------------------------------------------------

  static const glassesLineWidth = 28;
  static const glassesMaxLines = 4;

  /// The compact payload for the current state; also drives the simulator.
  GlassesCue? glassesCueFor(PresentationState s) {
    final cue = s.currentCue;
    if (cue == null) return null;
    final lines = CueSegmenter.wrap(cue.text, width: glassesLineWidth);
    return GlassesCue(
      heading: cue.heading,
      lines: lines.take(glassesMaxLines).toList(),
      position: s.cueIndex + 1,
      total: s.cues.length,
      next: s.nextCue?.text,
      paused: s.status != PlaybackStatus.playing,
    );
  }

  void _emit(PresentationState next) {
    emit(next);
    _pushCue();
  }

  /// Sends the current cue to real glasses when connected, at most once per
  /// [glassesThrottle], and only when the content actually changed.
  void _pushCue({bool force = false}) {
    final wearables = _wearables;
    if (wearables == null ||
        !wearables.state.canShowCues ||
        state.settings.mode != PresentationMode.glasses) {
      return;
    }
    final cue = glassesCueFor(state);
    if (cue == null || (!force && cue == _lastSentCue)) return;

    final now = DateTime.now();
    final since = _lastPush == null ? null : now.difference(_lastPush!);
    if (since != null && since < glassesThrottle) {
      _pushTimer?.cancel();
      _pushTimer = Timer(glassesThrottle - since, () {
        if (!isClosed) _pushCue();
      });
      return;
    }
    _lastPush = now;
    _lastSentCue = cue;
    wearables.showCue(cue).ignore();
  }

  void _persistPosition() =>
      savePosition?.call(state.script.id, state.cueIndex).ignore();

  @override
  Future<void> close() async {
    _pushTimer?.cancel();
    await _inputSub?.cancel();
    await _wearablesSub?.cancel();
    if (state.status != PlaybackStatus.finished) _persistPosition();
    final wearables = _wearables;
    if (wearables != null && wearables.state.canShowCues) {
      wearables.clearDisplay().ignore();
    }
    return super.close();
  }
}
