import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neurallens/core/config/app_config.dart';
import 'package:neurallens/features/ai/data/gemini_exception.dart';
import 'package:neurallens/features/ai/data/gemini_service.dart';
import 'package:neurallens/features/questions/logic/question_cubit.dart';
import 'package:neurallens/features/questions/models/question_answer.dart';
import 'package:neurallens/features/wearables/models/wearables_models.dart';

import 'helpers/fakes.dart';
import 'question_answer_test.dart'
    show questionJson, codingQuestionJson, openEndedQuestionJson;

const connected = WearablesState(
  status: WearablesStatus.connected,
  displayAvailable: true,
  inputs: InputsAvailability.available,
);

const _previewJpeg =
    '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAADAAQDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD26iiigD//2Q==';

class CameraFake extends FakeWearablesService {
  CameraFake() : super(connected);
  int captures = 0;
  int previewStarts = 0;
  int previewStops = 0;
  double? capturedZoom;
  final frames = StreamController<CameraPreviewFrame>.broadcast(sync: true);

  @override
  Stream<CameraPreviewFrame> get cameraPreview => frames.stream;

  @override
  Future<void> startCameraPreview() async {
    previewStarts++;
    if (denied) {
      throw PlatformException(
        code: 'camera_permission',
        message: 'Camera denied',
      );
    }
    frames.add(
      CameraPreviewFrame(jpeg: base64Decode(_previewJpeg), width: 4, height: 3),
    );
  }

  @override
  Future<void> stopCameraPreview() async {
    previewStops++;
  }

  @override
  Future<void> dispose() async {
    await frames.close();
    await super.dispose();
  }

  bool deliver = true;
  bool denied = false;
  final modes = <bool>[];

  @override
  Future<void> setQuestionMode(bool enabled) async => modes.add(enabled);

  @override
  Future<Uint8List> capturePhoto({double zoom = 1}) async {
    captures++;
    capturedZoom = zoom;
    if (denied) {
      throw PlatformException(
        code: 'camera_permission',
        message: 'Camera denied',
      );
    }
    return base64Decode(_previewJpeg);
  }

  @override
  Future<bool> showCue(GlassesCue cue) async {
    await super.showCue(cue);
    return deliver;
  }
}

class AnswerFake extends GeminiService {
  AnswerFake()
    : super(
        client: MockClient((_) async => http.Response('', 500)),
        config: const AppConfig(geminiApiKey: 'test', geminiModel: 'test'),
      );
  final requests = <Completer<QuestionAnswer>>[];
  bool configured = true;

  @override
  bool get isConfigured => configured;

  @override
  Future<QuestionAnswer> answerQuestion(Uint8List jpeg) {
    final result = Completer<QuestionAnswer>();
    requests.add(result);
    return result.future;
  }
}

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  late CameraFake camera;
  late AnswerFake ai;
  late QuestionCubit cubit;
  final answer = QuestionAnswer.parse(jsonEncode(questionJson));

  setUp(() async {
    camera = CameraFake();
    ai = AnswerFake();
    cubit = QuestionCubit(camera, ai);
    await cubit.start();
  });
  tearDown(() async {
    if (!cubit.isClosed) await cubit.close();
    await camera.dispose();
  });

  Future<void> captureWithPreview() async {
    await cubit.openPreview();
    await cubit.capture();
  }

  test('capture, analyze, display and repeat from glasses input', () async {
    final first = captureWithPreview();
    await tick();
    expect(cubit.state.phase, QuestionPhase.analyzing);
    expect(cubit.state.photo, isNotNull);
    await cubit.capture(); // Ignore duplicate taps while busy.
    expect(camera.captures, 1);
    ai.requests[0].complete(answer);
    await first;
    expect(cubit.state.shownOnGlasses, isTrue);
    expect(camera.shown.single.lines.join(' '), 'B. 4');

    camera.emitInput(WearableInput.capture);
    await tick();
    expect(cubit.state.phase, QuestionPhase.preview);
    expect(camera.captures, 1);
    camera.emitInput(WearableInput.capture);
    await tick();
    expect(camera.captures, 2);
    expect(cubit.state.answer, isNull);
    expect(camera.cleared, 2);
    ai.requests[1].complete(answer);
    await tick();
    expect(cubit.state.phase, QuestionPhase.ready);
    expect(camera.shown.length, 2);
  });

  test('missing key or disconnection never captures or uploads', () async {
    ai.configured = false;
    await cubit.openPreview();
    ai.configured = true;
    camera.emitState(
      const WearablesState(status: WearablesStatus.disconnected),
    );
    await tick();
    await cubit.openPreview();
    expect(camera.captures, 0);
    expect(ai.requests, isEmpty);
  });

  test(
    'permission denial does not submit a request and can be retried',
    () async {
      camera.denied = true;
      await cubit.openPreview();
      expect(cubit.state.message, 'Camera denied');
      expect(ai.requests, isEmpty);
      camera.denied = false;
      final pending = captureWithPreview();
      await tick();
      ai.requests.single.complete(answer);
      await pending;
      expect(cubit.state.phase, QuestionPhase.ready);
    },
  );

  test('network retry reuses the current photo', () async {
    final first = captureWithPreview();
    await tick();
    ai.requests[0].completeError(
      const GeminiException(GeminiErrorKind.network),
    );
    await first;
    expect(cubit.state.phase, QuestionPhase.error);
    expect(cubit.state.photo, isNotNull);
    final retry = cubit.retry();
    await tick();
    ai.requests[1].complete(answer);
    await retry;
    expect(camera.captures, 1);
    expect(cubit.state.phase, QuestionPhase.ready);
  });

  test('display failure preserves answer and allows delivery retry', () async {
    camera.deliver = false;
    final pending = captureWithPreview();
    await tick();
    ai.requests.single.complete(answer);
    await pending;
    expect(cubit.state.answer, answer);
    expect(cubit.state.shownOnGlasses, isFalse);
    camera.deliver = true;
    await cubit.showAgain();
    expect(cubit.state.shownOnGlasses, isTrue);
    expect(ai.requests.length, 1);
  });

  test(
    'late answer after disconnect cannot overwrite a newer capture',
    () async {
      final first = captureWithPreview();
      await tick();
      camera.emitState(
        const WearablesState(status: WearablesStatus.disconnected),
      );
      await tick();
      camera.emitState(connected);
      await tick();
      final next = captureWithPreview();
      await tick();
      ai.requests[1].complete(answer);
      await next;
      ai.requests[0].complete(answer);
      await first;
      expect(camera.shown.length, 1);
      expect(cubit.state.phase, QuestionPhase.ready);
    },
  );

  test(
    'temporary session pause during permission redirect keeps request alive',
    () async {
      final pending = captureWithPreview();
      await tick();
      camera.emitState(
        const WearablesState(status: WearablesStatus.connecting),
      );
      await tick();
      camera.emitState(connected);
      await tick();
      ai.requests.single.complete(answer);
      await pending;
      expect(cubit.state.shownOnGlasses, isTrue);
    },
  );

  test(
    'leaving screen disables capture and discards outstanding answer',
    () async {
      final pending = captureWithPreview();
      await tick();
      await cubit.close();
      ai.requests.single.complete(answer);
      await pending;
      expect(camera.shown, isEmpty);
      expect(camera.modes, [true, false]);
    },
  );

  test('covered screen does not react to input', () async {
    await cubit.suspend();
    camera.emitInput(WearableInput.next);
    await tick();
    expect(camera.captures, 0);
  });
  test(
    'opening preview never captures or submits to AI; shutter requires preview',
    () async {
      await cubit.capture();
      expect(camera.captures, 0);
      await cubit.openPreview();
      expect(cubit.state.phase, QuestionPhase.preview);
      expect(cubit.state.preview, isNotNull);
      expect(camera.captures, 0);
      expect(ai.requests, isEmpty);
    },
  );

  test('zoom is bounded and is passed to the manual shutter', () async {
    await cubit.openPreview();
    cubit.setZoom(2.5);
    cubit.setZoom(double.nan);
    expect(cubit.state.zoom, 2.5);
    final pending = cubit.capture();
    await tick();
    expect(camera.capturedZoom, 2.5);
    ai.requests.single.complete(answer);
    await pending;
    expect(camera.previewStops, greaterThan(0));
    await cubit.openPreview();
    expect(cubit.state.zoom, 1);
    cubit.setZoom(10);
    expect(cubit.state.zoom, 3);
    cubit.setZoom(0);
    expect(cubit.state.zoom, 1);
  });

  test(
    'cancel stops preview without capture or upload; reopening works',
    () async {
      await cubit.openPreview();
      await cubit.cancelPreview();
      expect(cubit.state.phase, QuestionPhase.idle);
      expect(camera.previewStops, 1);
      expect(camera.captures, 0);
      expect(ai.requests, isEmpty);
      await cubit.openPreview();
      expect(cubit.state.phase, QuestionPhase.preview);
    },
  );

  test('next gesture only opens preview and never fires the shutter', () async {
    camera.emitInput(WearableInput.next);
    await tick();
    camera.emitInput(WearableInput.next);
    await tick();
    expect(cubit.state.phase, QuestionPhase.preview);
    expect(camera.captures, 0);
    expect(ai.requests, isEmpty);
  });

  test('preview stream failure disables shutter and releases camera', () async {
    await cubit.openPreview();
    camera.frames.addError(
      PlatformException(code: 'stream_error', message: 'Preview stopped'),
    );
    await tick();
    await cubit.capture();
    expect(cubit.state.phase, QuestionPhase.error);
    expect(camera.previewStops, 1);
    expect(camera.captures, 0);
  });

  test('backgrounding closes preview without capture', () async {
    await cubit.openPreview();
    cubit.pauseCamera();
    await tick();
    expect(cubit.state.phase, QuestionPhase.idle);
    expect(camera.previewStops, 1);
    expect(camera.captures, 0);
  });
  for (final resultJson in [codingQuestionJson, openEndedQuestionJson]) {
    test(
      '${resultJson['kind']} answer sends a summary to glasses without retake',
      () async {
        final pending = captureWithPreview();
        await tick();
        final result = QuestionAnswer.parse(jsonEncode(resultJson));
        ai.requests.single.complete(result);
        await pending;
        expect(cubit.state.phase, QuestionPhase.ready);
        expect(cubit.state.answer!.hasAnswer, isTrue);
        expect(camera.shown.single.heading, 'Suggested answer');
        expect(camera.shown.single.lines.join(' '), result.glassesSummary);
      },
    );
  }
}
