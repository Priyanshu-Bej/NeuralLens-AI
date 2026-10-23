import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../presentation/models/presentation_settings.dart';
import '../models/app_settings.dart';

/// Lightweight settings persisted in SharedPreferences.
class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _fontSize = 'presentation.fontSize';
  static const _speed = 'presentation.speed';
  static const _mode = 'presentation.mode';
  static const _mirror = 'presentation.mirror';
  static const _theme = 'app.themeMode';
  static const _invertNav = 'band.invertNavigation';
  static const _selectAction = 'band.selectAction';
  static const _lastScript = 'session.lastScriptId';

  AppSettings load() => AppSettings(
    presentation: PresentationSettings(
      fontSize:
          _prefs.getDouble(_fontSize) ?? PresentationSettings.defaultFontSize,
      speed: _prefs.getInt(_speed) ?? PresentationSettings.defaultSpeed,
      mode: PresentationMode.fromName(_prefs.getString(_mode)),
      mirror: _prefs.getBool(_mirror) ?? false,
    ).copyWith(),
    themeMode: ThemeMode.values.firstWhere(
      (m) => m.name == _prefs.getString(_theme),
      orElse: () => ThemeMode.dark,
    ),
    invertBandNavigation: _prefs.getBool(_invertNav) ?? false,
    bandSelectAction: BandSelectAction.fromName(
      _prefs.getString(_selectAction),
    ),
    lastScriptId: _prefs.getString(_lastScript),
  );

  Future<void> save(AppSettings s) async {
    final p = s.presentation;
    await Future.wait([
      _prefs.setDouble(_fontSize, p.fontSize),
      _prefs.setInt(_speed, p.speed),
      _prefs.setString(_mode, p.mode.name),
      _prefs.setBool(_mirror, p.mirror),
      _prefs.setString(_theme, s.themeMode.name),
      _prefs.setBool(_invertNav, s.invertBandNavigation),
      _prefs.setString(_selectAction, s.bandSelectAction.name),
      if (s.lastScriptId == null)
        _prefs.remove(_lastScript)
      else
        _prefs.setString(_lastScript, s.lastScriptId!),
    ]);
  }
}
