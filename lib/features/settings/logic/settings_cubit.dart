import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../presentation/models/presentation_settings.dart';
import '../data/settings_repository.dart';
import '../models/app_settings.dart';

class SettingsCubit extends Cubit<AppSettings> {
  SettingsCubit(this._repository) : super(_repository.load());

  final SettingsRepository _repository;

  void _update(AppSettings next) {
    emit(next);
    _repository.save(next).ignore();
  }

  void setPresentation(PresentationSettings presentation) =>
      _update(state.copyWith(presentation: presentation));

  void setThemeMode(ThemeMode mode) => _update(state.copyWith(themeMode: mode));

  void setInvertBandNavigation(bool value) =>
      _update(state.copyWith(invertBandNavigation: value));

  void setBandSelectAction(BandSelectAction action) =>
      _update(state.copyWith(bandSelectAction: action));

  void setLastScript(String? id) =>
      _update(state.copyWith(lastScriptId: () => id));
}
