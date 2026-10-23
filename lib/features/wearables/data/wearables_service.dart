import '../models/wearables_models.dart';

/// Hardware abstraction for smart glasses.
///
/// Implementations expose only what the underlying SDK verifiably supports.
/// The on-phone glasses simulator is a UI preview and deliberately does not
/// implement this interface, so it can never masquerade as a real connection.
abstract interface class WearablesService {
  WearablesState get state;
  Stream<WearablesState> get states;

  /// Discrete input events (e.g. Neural Band) while a session is active.
  Stream<WearableInput> get inputs;

  Future<void> initialize();

  /// Starts registration with the Meta AI app (opens it for approval).
  Future<void> register();
  Future<void> unregister();

  /// Unregisters, then registers exactly once, to recover a broken
  /// registration.
  Future<void> repair();

  /// Starts a device session and attaches display and inputs where
  /// supported.
  Future<void> connect();
  Future<void> disconnect();

  /// Replaces the glasses display content. Returns false when not shown.
  Future<bool> showCue(GlassesCue cue);
  Future<void> clearDisplay();

  Future<void> dispose();
}

/// Used where no SDK integration exists (non-Android platforms).
class UnsupportedWearablesService implements WearablesService {
  const UnsupportedWearablesService([this.reason]);

  final String? reason;

  @override
  WearablesState get state => WearablesState.unsupported(reason);

  @override
  Stream<WearablesState> get states => Stream.value(state);

  @override
  Stream<WearableInput> get inputs => const Stream.empty();

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
  Future<bool> showCue(GlassesCue cue) async => false;

  @override
  Future<void> clearDisplay() async {}

  @override
  Future<void> dispose() async {}
}
