import 'package:equatable/equatable.dart';

enum PresentationMode {
  phone('Phone', 'Scrolling teleprompter on this screen'),
  glasses('Glasses', 'Short cards for smart-glasses displays');

  const PresentationMode(this.label, this.description);
  final String label;
  final String description;

  static PresentationMode fromName(String? name) =>
      values.firstWhere((v) => v.name == name, orElse: () => phone);
}

/// What a Neural Band "select" gesture does during a presentation.
enum BandSelectAction {
  pauseResume('Pause / resume'),
  nextCue('Next card');

  const BandSelectAction(this.label);
  final String label;

  static BandSelectAction fromName(String? name) =>
      values.firstWhere((v) => v.name == name, orElse: () => pauseResume);
}

class PresentationSettings extends Equatable {
  const PresentationSettings({
    this.fontSize = defaultFontSize,
    this.speed = defaultSpeed,
    this.mode = PresentationMode.phone,
    this.mirror = false,
  });

  static const double minFontSize = 20;
  static const double maxFontSize = 72;
  static const double defaultFontSize = 36;
  static const int minSpeed = 1;
  static const int maxSpeed = 10;
  static const int defaultSpeed = 5;

  final double fontSize;

  /// 1–10. Drives scroll velocity in phone mode and words-per-minute pacing
  /// in glasses mode.
  final int speed;
  final PresentationMode mode;
  final bool mirror;

  /// Speed 5 ≈ 150 wpm (typical conversational pace).
  int get wordsPerMinute => 60 + speed * 18;

  /// Phone-mode scroll velocity, scaled with font size so reading pace stays
  /// roughly constant as text grows.
  double get scrollPixelsPerSecond => speed * 5.0 * (fontSize / 34);

  PresentationSettings copyWith({
    double? fontSize,
    int? speed,
    PresentationMode? mode,
    bool? mirror,
  }) => PresentationSettings(
    fontSize: (fontSize ?? this.fontSize).clamp(minFontSize, maxFontSize),
    speed: (speed ?? this.speed).clamp(minSpeed, maxSpeed),
    mode: mode ?? this.mode,
    mirror: mirror ?? this.mirror,
  );

  @override
  List<Object?> get props => [fontSize, speed, mode, mirror];
}
