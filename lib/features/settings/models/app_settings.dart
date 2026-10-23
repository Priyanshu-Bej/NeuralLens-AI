import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../presentation/models/presentation_settings.dart';

class AppSettings extends Equatable {
  const AppSettings({
    this.presentation = const PresentationSettings(),
    this.themeMode = ThemeMode.dark,
    this.invertBandNavigation = false,
    this.bandSelectAction = BandSelectAction.pauseResume,
    this.lastScriptId,
  });

  /// Defaults for new presentations; also the last-used values.
  final PresentationSettings presentation;
  final ThemeMode themeMode;

  /// Swap the meaning of Neural Band forward/back navigation.
  final bool invertBandNavigation;
  final BandSelectAction bandSelectAction;

  /// Script of the last unfinished presentation, for "Continue presenting".
  final String? lastScriptId;

  AppSettings copyWith({
    PresentationSettings? presentation,
    ThemeMode? themeMode,
    bool? invertBandNavigation,
    BandSelectAction? bandSelectAction,
    String? Function()? lastScriptId,
  }) => AppSettings(
    presentation: presentation ?? this.presentation,
    themeMode: themeMode ?? this.themeMode,
    invertBandNavigation: invertBandNavigation ?? this.invertBandNavigation,
    bandSelectAction: bandSelectAction ?? this.bandSelectAction,
    lastScriptId: lastScriptId == null ? this.lastScriptId : lastScriptId(),
  );

  @override
  List<Object?> get props => [
    presentation,
    themeMode,
    invertBandNavigation,
    bandSelectAction,
    lastScriptId,
  ];
}
