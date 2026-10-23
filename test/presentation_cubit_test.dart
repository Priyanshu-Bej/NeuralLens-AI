import 'package:flutter_test/flutter_test.dart';
import 'package:neurallens/features/presentation/logic/presentation_cubit.dart';
import 'package:neurallens/features/presentation/models/presentation_settings.dart';
import 'package:neurallens/features/scripts/util/duration_estimator.dart';
import 'package:neurallens/features/wearables/models/wearables_models.dart';

import 'helpers/fakes.dart';

void main() {
  const glasses = PresentationSettings(mode: PresentationMode.glasses);

  PresentationCubit build({
    PresentationSettings settings = const PresentationSettings(),
    FakeWearablesService? wearables,
    int lastPosition = 0,
    List<(String, int)>? saved,
    List<String?>? sessions,
    bool invert = false,
    BandSelectAction select = BandSelectAction.pauseResume,
  }) => PresentationCubit(
    script: testScript(lastPosition: lastPosition),
    settings: settings,
    wearables: wearables,
    savePosition: (id, i) async => saved?.add((id, i)),
    trackSession: sessions?.add,
    invertBandNavigation: invert,
    bandSelectAction: select,
    glassesThrottle: Duration.zero,
  );

  test('starts ready at the first cue with cues derived from the body', () {
    final cubit = build();
    expect(cubit.state.status, PlaybackStatus.ready);
    expect(cubit.state.cueIndex, 0);
    expect(cubit.state.cues.length, greaterThanOrEqualTo(4));
    expect(cubit.state.sectionCount, 3);
    expect(cubit.state.currentCue!.heading, 'Intro');
  });

  test('resumes from the saved position, clamped to range', () {
    expect(build(lastPosition: 2).state.cueIndex, 2);
    final cubit = build(lastPosition: 999);
    expect(cubit.state.cueIndex, cubit.state.cues.length - 1);
  });

  test('play / pause / resume, tracking the session and saving position', () {
    final saved = <(String, int)>[];
    final sessions = <String?>[];
    final cubit = build(saved: saved, sessions: sessions)..play();
    expect(cubit.state.status, PlaybackStatus.playing);
    expect(sessions, ['script-1']);

    cubit
      ..nextCue()
      ..pause();
    expect(cubit.state.status, PlaybackStatus.paused);
    expect(saved.last, ('script-1', 1));

    cubit.togglePlay();
    expect(cubit.state.status, PlaybackStatus.playing);
  });

  test('pause is a no-op unless playing', () {
    final cubit = build()..pause();
    expect(cubit.state.status, PlaybackStatus.ready);
  });

  test('cue navigation is bounded; next past the end finishes', () {
    final saved = <(String, int)>[];
    final sessions = <String?>[];
    final cubit = build(saved: saved, sessions: sessions)..previousCue();
    expect(cubit.state.cueIndex, 0);

    final last = cubit.state.cues.length - 1;
    for (var i = 0; i < last; i++) {
      cubit.nextCue();
    }
    expect(cubit.state.cueIndex, last);
    cubit.nextCue();
    expect(cubit.state.status, PlaybackStatus.finished);
    expect(cubit.state.progress, 1);
    expect(sessions.last, isNull, reason: 'finished sessions are cleared');
    expect(saved.last, ('script-1', 0));
  });

  test('navigation bumps navigationSeq for the phone view', () {
    final cubit = build();
    final before = cubit.state.navigationSeq;
    cubit.nextCue();
    expect(cubit.state.navigationSeq, before + 1);
  });

  test('section navigation', () {
    final cubit = build();
    final middle = cubit.state.cues.indexWhere((c) => c.heading == 'Middle');
    final end = cubit.state.cues.indexWhere((c) => c.heading == 'End');

    cubit.nextSection();
    expect(cubit.state.cueIndex, middle);
    cubit.nextSection();
    expect(cubit.state.cueIndex, end);
    cubit.nextSection();
    expect(cubit.state.cueIndex, end, reason: 'no section after the last');

    cubit.previousSection();
    expect(cubit.state.cueIndex, middle);

    // From inside a section, previousSection goes to its start first.
    cubit
      ..restart()
      ..nextCue();
    expect(cubit.state.cueIndex, 1);
    cubit.previousSection();
    expect(cubit.state.cueIndex, 0);
  });

  test('restart returns to the first cue and plays', () {
    final cubit = build(lastPosition: 3)..restart();
    expect(cubit.state.cueIndex, 0);
    expect(cubit.state.status, PlaybackStatus.playing);
  });

  test('play after finishing restarts', () {
    final cubit = build()..markFinished();
    expect(cubit.state.status, PlaybackStatus.finished);
    cubit.play();
    expect(cubit.state.status, PlaybackStatus.playing);
    expect(cubit.state.cueIndex, 0);
  });

  group('glasses mode pacing', () {
    test('tick advances cues by words-per-minute and finishes at the end', () {
      final cubit = build(settings: glasses)..play();
      cubit.tick(const Duration(milliseconds: 500));
      expect(cubit.state.cueIndex, 0, reason: 'minimum dwell not reached');

      for (
        var i = 0;
        i < 200 && cubit.state.status == PlaybackStatus.playing;
        i++
      ) {
        cubit.tick(const Duration(seconds: 1));
      }
      expect(cubit.state.status, PlaybackStatus.finished);
    });

    test('speed controls step and clamp, and persist', () {
      PresentationSettings? reported;
      final cubit = PresentationCubit(
        script: testScript(),
        settings: glasses,
        onSettingsChanged: (s) => reported = s,
      );
      final start = cubit.state.settings.speed;
      cubit.faster();
      expect(cubit.state.settings.speed, start + 1);
      expect(reported?.speed, start + 1);
      cubit.slower();
      expect(cubit.state.settings.speed, start);

      cubit.setSpeed(99);
      expect(cubit.state.settings.speed, PresentationSettings.maxSpeed);
      cubit.faster();
      expect(cubit.state.settings.speed, PresentationSettings.maxSpeed);
      cubit.setSpeed(-5);
      expect(cubit.state.settings.speed, PresentationSettings.minSpeed);
    });

    test('changing speed mid-card keeps time already spent on it', () {
      final cubit = build(settings: glasses)..play();
      // Just short of the current card's dwell at the starting speed.
      final dwell = DurationEstimator.cueDuration(
        cubit.state.currentCue!.text,
        wpm: cubit.state.settings.wordsPerMinute,
      );
      cubit.tick(dwell - const Duration(milliseconds: 100));
      expect(cubit.state.cueIndex, 0);

      // Faster pace: the elapsed time now covers the shorter dwell.
      cubit
        ..setSpeed(PresentationSettings.maxSpeed)
        ..tick(const Duration(milliseconds: 1));
      expect(cubit.state.cueIndex, 1);
    });

    test('tick is ignored when paused or in phone mode', () {
      final paused = build(settings: glasses)..tick(const Duration(minutes: 1));
      expect(paused.state.cueIndex, 0);

      final phone = build()
        ..play()
        ..tick(const Duration(minutes: 1));
      expect(phone.state.cueIndex, 0);
    });
  });

  test('phone mode syncs cue and progress from scroll', () {
    final cubit = build()..syncFromScroll(cueIndex: 2, progress: 0.5);
    expect(cubit.state.cueIndex, 2);
    expect(cubit.state.progress, 0.5);
    cubit.syncFromScroll(cueIndex: 99, progress: 2);
    expect(cubit.state.cueIndex, cubit.state.cues.length - 1);
    expect(cubit.state.scrollProgress, 1);
  });

  test('settings changes are reported for persistence', () {
    PresentationSettings? reported;
    final cubit = PresentationCubit(
      script: testScript(),
      settings: const PresentationSettings(),
      onSettingsChanged: (s) => reported = s,
    );
    cubit.updateSettings(const PresentationSettings(fontSize: 48));
    expect(cubit.state.settings.fontSize, 48);
    expect(reported?.fontSize, 48);
  });

  test('empty scripts are handled safely', () {
    final cubit =
        PresentationCubit(
            script: testScript(body: '   '),
            settings: const PresentationSettings(),
          )
          ..play()
          ..nextCue()
          ..previousSection()
          ..tick(const Duration(seconds: 5));
    expect(cubit.state.isEmpty, isTrue);
    expect(cubit.state.status, PlaybackStatus.ready);
    expect(cubit.state.currentCue, isNull);
  });

  group('wearables', () {
    const connected = WearablesState(
      status: WearablesStatus.connected,
      displayAvailable: true,
    );

    test('does not send cues when glasses are not connected', () {
      final fake = FakeWearablesService();
      build(settings: glasses, wearables: fake)
        ..play()
        ..nextCue();
      expect(fake.shown, isEmpty);
    });

    test('sends compact cues on change when a display is connected', () async {
      final fake = FakeWearablesService(connected);
      final cubit = build(settings: glasses, wearables: fake)..play();
      expect(fake.shown, hasLength(1));
      expect(fake.shown.last.position, 1);
      expect(
        fake.shown.last.lines.every(
          (l) =>
              l.length <= PresentationCubit.glassesLineWidth ||
              !l.contains(' '),
        ),
        isTrue,
      );
      expect(
        fake.shown.last.lines.length,
        lessThanOrEqualTo(PresentationCubit.glassesMaxLines),
      );

      cubit.nextCue();
      expect(fake.shown.last.position, 2);

      // Phone mode never pushes to the glasses.
      cubit
        ..updateSettings(const PresentationSettings())
        ..nextCue();
      expect(fake.shown.last.position, 2);
      await cubit.close();
      expect(fake.cleared, 1);
    });

    test('maps band input to controls, honoring settings', () async {
      final fake = FakeWearablesService(connected);
      final cubit = build(wearables: fake);

      fake.emitInput(WearableInput.next);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.cueIndex, 1);

      fake.emitInput(WearableInput.previous);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.cueIndex, 0);

      fake.emitInput(WearableInput.select);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.status, PlaybackStatus.playing);

      fake.emitInput(WearableInput.back);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.status, PlaybackStatus.paused);

      final inverted = build(
        wearables: fake,
        invert: true,
        select: BandSelectAction.nextCue,
        lastPosition: 2,
      );
      fake.emitInput(WearableInput.next);
      await Future<void>.delayed(Duration.zero);
      expect(inverted.state.cueIndex, 1);
      fake.emitInput(WearableInput.select);
      await Future<void>.delayed(Duration.zero);
      expect(inverted.state.cueIndex, 2);
    });
  });
}
