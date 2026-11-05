import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/config/app_config.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/ai/data/gemini_service.dart';
import 'features/scripts/data/script_repository.dart';
import 'features/scripts/logic/library_cubit.dart';
import 'features/settings/data/settings_repository.dart';
import 'features/settings/logic/settings_cubit.dart';
import 'features/settings/models/app_settings.dart';
import 'features/wearables/data/wearables_service.dart';
import 'features/wearables/logic/wearables_cubit.dart';

/// Dependencies created once in `main` (or by tests) and injected here.
class AppDependencies {
  const AppDependencies({
    required this.config,
    required this.scripts,
    required this.settings,
    required this.gemini,
    required this.wearables,
  });

  final AppConfig config;
  final ScriptRepository scripts;
  final SettingsRepository settings;
  final GeminiService gemini;
  final WearablesService wearables;
}

class NeuralLensApp extends StatefulWidget {
  const NeuralLensApp({super.key, required this.deps});

  final AppDependencies deps;

  @override
  State<NeuralLensApp> createState() => _NeuralLensAppState();
}

class _NeuralLensAppState extends State<NeuralLensApp> {
  late final GoRouter _router = buildRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deps = widget.deps;
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: deps.config),
        RepositoryProvider.value(value: deps.scripts),
        RepositoryProvider.value(value: deps.gemini),
        RepositoryProvider.value(value: deps.wearables),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => LibraryCubit(deps.scripts)..load()),
          BlocProvider(create: (_) => SettingsCubit(deps.settings)),
          BlocProvider(
            create: (_) => WearablesCubit(deps.wearables)..initialize(),
          ),
        ],
        child: BlocSelector<SettingsCubit, AppSettings, ThemeMode>(
          selector: (s) => s.themeMode,
          builder: (context, themeMode) => MaterialApp.router(
            title: 'NeuralLens',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeMode,
            routerConfig: _router,
          ),
        ),
      ),
    );
  }
}
