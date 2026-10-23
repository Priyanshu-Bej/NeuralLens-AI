import 'dart:async';

import 'package:flutter/services.dart';

import '../models/wearables_models.dart';
import 'wearables_service.dart';

/// Meta Wearables Device Access Toolkit via the Android platform bridge
/// (`MetaWearablesBridge.kt`).
///
/// All state comes from the native SDK; nothing here fabricates a
/// connection.
class MetaWearablesService implements WearablesService {
  MetaWearablesService({
    this._methods = const MethodChannel('neurallens/wearables'),
    this._stateEvents = const EventChannel('neurallens/wearables/state'),
    this._inputEvents = const EventChannel('neurallens/wearables/inputs'),
  });

  final MethodChannel _methods;
  final EventChannel _stateEvents;
  final EventChannel _inputEvents;

  final _states = StreamController<WearablesState>.broadcast();
  StreamSubscription<Object?>? _stateSub;
  Stream<WearableInput>? _inputs;
  WearablesState _state = const WearablesState(
    status: WearablesStatus.initializing,
  );
  bool _initialized = false;

  @override
  WearablesState get state => _state;

  @override
  Stream<WearablesState> get states => _states.stream;

  @override
  Stream<WearableInput> get inputs => _inputs ??= _inputEvents
      .receiveBroadcastStream()
      .map(_parseInput)
      .where((i) => i != null)
      .cast<WearableInput>()
      .handleError((Object _) {});

  void _set(WearablesState next) {
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _stateSub = _stateEvents.receiveBroadcastStream().listen((event) {
      if (event is Map) _set(parseState(event.cast<String, Object?>()));
    }, onError: (Object e) => _set(_errorState(e)));
    await _invoke('initialize');
  }

  @override
  Future<void> register() => _invoke('register');

  @override
  Future<void> unregister() => _invoke('unregister');

  @override
  Future<void> repair() => _invoke('repair');

  @override
  Future<void> connect() => _invoke('connect');

  @override
  Future<void> disconnect() => _invoke('disconnect');

  @override
  Future<bool> showCue(GlassesCue cue) async {
    if (!_state.canShowCues) return false;
    try {
      return await _methods.invokeMethod<bool>('showCue', cue.toMap()) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> clearDisplay() async {
    try {
      await _methods.invokeMethod<void>('clearDisplay');
    } on PlatformException {
      // Display already gone; nothing to clear.
    } on MissingPluginException {
      // Bridge not present in this build.
    }
  }

  Future<void> _invoke(String method) async {
    try {
      await _methods.invokeMethod<void>(method);
    } on MissingPluginException {
      _set(
        const WearablesState.unsupported(
          'The native glasses bridge is not included in this build.',
        ),
      );
    } on PlatformException catch (e) {
      _set(_errorState(e));
    }
  }

  WearablesState _errorState(Object e) => WearablesState(
    status: WearablesStatus.error,
    message: e is PlatformException
        ? (e.message ?? e.code)
        : 'Unexpected glasses error.',
  );

  /// Parses the native state map. Unknown values degrade safely.
  static WearablesState parseState(Map<String, Object?> map) {
    final status = WearablesStatus.values.firstWhere(
      (s) => s.name == map['status'],
      orElse: () => WearablesStatus.error,
    );
    return WearablesState(
      status: status,
      deviceName: map['deviceName'] as String?,
      displayAvailable: map['displayAvailable'] == true,
      inputs: InputsAvailability.values.firstWhere(
        (i) => i.name == map['inputs'],
        orElse: () => InputsAvailability.unknown,
      ),
      message: map['message'] as String?,
      needsRepair: map['needsRepair'] == true,
    );
  }

  static WearableInput? _parseInput(Object? event) =>
      WearableInput.values.where((i) => i.name == event).firstOrNull;

  @override
  Future<void> dispose() async {
    await _stateSub?.cancel();
    await _states.close();
  }
}
