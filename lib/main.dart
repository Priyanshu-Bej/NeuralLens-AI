import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'data/local/app_database.dart';
import 'features/ai/data/gemini_service.dart';
import 'features/scripts/data/script_repository.dart';
import 'features/settings/data/settings_repository.dart';
import 'features/wearables/data/meta_wearables_service.dart';
import 'features/wearables/data/wearables_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'Geist',
      'Geist Mono',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final config = AppConfig.fromEnvironment();
  final results = await (
    AppDatabase.open(),
    SharedPreferences.getInstance(),
  ).wait;

  final WearablesService wearables =
      defaultTargetPlatform == TargetPlatform.android
      ? MetaWearablesService()
      : const UnsupportedWearablesService(
          'Meta glasses integration is currently Android-only.',
        );

  runApp(
    NeuralLensApp(
      deps: AppDependencies(
        config: config,
        scripts: ScriptRepository(results.$1),
        settings: SettingsRepository(results.$2),
        gemini: GeminiService(client: http.Client(), config: config),
        wearables: wearables,
      ),
    ),
  );
}
