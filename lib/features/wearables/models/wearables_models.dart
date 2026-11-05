import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Connection lifecycle as reported by the platform SDK. Never synthesized
/// by the simulator.
enum WearablesStatus {
  /// No SDK on this platform/build (e.g. iOS for now).
  unsupported,
  initializing,

  /// App is not registered with the Meta AI app yet.
  unregistered,
  registering,

  /// Registered, but no glasses session is active.
  disconnected,
  connecting,
  connected,
  error,
}

enum InputsAvailability {
  unknown,
  available,

  /// Inputs are not enabled for this app in the Wearables Developer Center.
  denied,
  unavailable,
}

class WearablesState extends Equatable {
  const WearablesState({
    required this.status,
    this.deviceName,
    this.displayAvailable = false,
    this.inputs = InputsAvailability.unknown,
    this.message,
    this.needsRepair = false,
  });

  const WearablesState.unsupported([String? message])
    : this(status: WearablesStatus.unsupported, message: message);

  final WearablesStatus status;

  /// Device name from SDK metadata, when connected.
  final String? deviceName;

  /// True only after the SDK has attached a display to the session.
  final bool displayAvailable;
  final InputsAvailability inputs;

  /// Non-sensitive status or error detail from the platform.
  final String? message;

  /// The glasses can't start this app until its registration is repaired
  /// (unregister, then register once).
  final bool needsRepair;

  bool get isConnected => status == WearablesStatus.connected;
  bool get canShowCues => isConnected && displayAvailable;

  @override
  List<Object?> get props => [
    status,
    deviceName,
    displayAvailable,
    inputs,
    message,
    needsRepair,
  ];
}

/// Discrete control events mapped from the SDK's input events.
enum WearableInput { next, previous, select, back, capture }

/// Compact payload for a glasses display: short lines, not a full script.
class GlassesCue extends Equatable {
  const GlassesCue({
    required this.heading,
    required this.lines,
    required this.position,
    required this.total,
    this.next,
    this.paused = false,
  });

  final String heading;
  final List<String> lines;

  /// 1-based cue position and total, for a progress label.
  final int position;
  final int total;
  final String? next;
  final bool paused;

  Map<String, Object?> toMap() => {
    'heading': heading,
    'lines': lines,
    'position': position,
    'total': total,
    'next': next,
    'paused': paused,
  };

  @override
  List<Object?> get props => [heading, lines, position, total, next, paused];
}

/// A local-only preview frame. Never submitted to the AI service.
class CameraPreviewFrame {
  const CameraPreviewFrame({
    required this.jpeg,
    required this.width,
    required this.height,
  });
  final Uint8List jpeg;
  final int width;
  final int height;
  double get aspectRatio => width / height;
}
