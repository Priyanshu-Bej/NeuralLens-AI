import 'dart:async';

import 'package:neurallens/features/scripts/models/script.dart';
import 'package:neurallens/features/scripts/models/script_enums.dart';
import 'package:neurallens/features/wearables/data/wearables_service.dart';
import 'package:neurallens/features/wearables/models/wearables_models.dart';

/// Test double that lets tests drive connection state and input events.
class FakeWearablesService implements WearablesService {
  FakeWearablesService([
    this._state = const WearablesState(status: WearablesStatus.disconnected),
  ]);

  WearablesState _state;
  final _states = StreamController<WearablesState>.broadcast();
  final _inputs = StreamController<WearableInput>.broadcast();
  final shown = <GlassesCue>[];
  var cleared = 0;

  void emitState(WearablesState s) {
    _state = s;
    _states.add(s);
  }

  void emitInput(WearableInput i) => _inputs.add(i);

  @override
  WearablesState get state => _state;

  @override
  Stream<WearablesState> get states => _states.stream;

  @override
  Stream<WearableInput> get inputs => _inputs.stream;

  @override
  Future<bool> showCue(GlassesCue cue) async {
    shown.add(cue);
    return true;
  }

  @override
  Future<void> clearDisplay() async => cleared++;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> register() async {}

  @override
  Future<void> unregister() async {}

  @override
  Future<void> repair() async {}

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() async {
    await _states.close();
    await _inputs.close();
  }
}

Script testScript({String body = _body, int lastPosition = 0}) => Script(
  id: 'script-1',
  kind: ScriptKind.script,
  title: 'Test',
  body: body,
  lastPosition: lastPosition,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// Three sections; the first splits into two cues at the default width.
const _body = '''## Intro
Welcome to the show. Today we talk about focus and the tools that help us keep it. We will also cover habits that stick.

## Middle
Here is the main point.

## End
Thanks for listening.''';
