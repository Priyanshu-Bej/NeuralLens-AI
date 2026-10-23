import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neurallens/app.dart';
import 'package:neurallens/core/config/app_config.dart';
import 'package:neurallens/data/local/app_database.dart';
import 'package:neurallens/features/ai/data/gemini_service.dart';
import 'package:neurallens/features/scripts/data/script_repository.dart';
import 'package:neurallens/features/presentation/ui/widgets/glasses_cue_view.dart';
import 'package:neurallens/features/presentation/ui/widgets/teleprompter_controls.dart';
import 'package:neurallens/features/settings/data/settings_repository.dart';
import 'package:neurallens/features/wearables/data/wearables_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Launch checks: no Gemini key and no glasses must still give a usable app.
void main() {
  sqfliteFfiInit();

  Future<AppDependencies> deps(WidgetTester tester) async {
    // Small-phone logical viewport (360×800).
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final db = await tester.runAsync(
      () => AppDatabase.open(
        factory: databaseFactoryFfiNoIsolate,
        path: inMemoryDatabasePath,
      ),
    );
    addTearDown(() => tester.runAsync(db!.close));
    const config = AppConfig(geminiApiKey: '', geminiModel: 'm');
    return AppDependencies(
      config: config,
      scripts: ScriptRepository(db!),
      settings: SettingsRepository(await SharedPreferences.getInstance()),
      gemini: GeminiService(
        client: MockClient((_) async => http.Response('', 500)),
        config: config,
      ),
      wearables: const UnsupportedWearablesService('test'),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('launches without an API key or glasses', (tester) async {
    await tester.pumpWidget(NeuralLensApp(deps: await deps(tester)));
    await settle(tester);

    expect(find.text('See beyond the screen.'), findsOneWidget);
    expect(find.text('Create with AI'), findsOneWidget);
    expect(
      find.textContaining('Setup required', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Not available on this device'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Your library is empty'), 200);
    expect(find.text('Your library is empty'), findsOneWidget);
  });

  testWidgets('AI studio explains how to configure Gemini', (tester) async {
    await tester.pumpWidget(NeuralLensApp(deps: await deps(tester)));
    await settle(tester);

    await tester.tap(find.text('Create with AI'));
    await settle(tester);

    expect(find.text('Connect Gemini to generate'), findsOneWidget);
    expect(
      find.text('flutter run --dart-define=GEMINI_API_KEY=YOUR_KEY'),
      findsOneWidget,
    );
    // Generate is disabled without a key: tapping it starts nothing.
    await tester.tap(find.text('Generate script'), warnIfMissed: false);
    await settle(tester);
    expect(find.text('Writing your script…'), findsNothing);
  });

  testWidgets('bottom navigation reaches Library and Settings', (tester) async {
    await tester.pumpWidget(NeuralLensApp(deps: await deps(tester)));
    await settle(tester);

    await tester.tap(find.text('Library'));
    await settle(tester);
    expect(find.text('Nothing saved yet'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Gemini not configured'), 300);
    expect(find.text('Gemini not configured'), findsOneWidget);
  });

  testWidgets('saved script opens in editor and both presentation modes', (
    tester,
  ) async {
    final d = await deps(tester);
    await tester.runAsync(
      () => d.scripts.save(
        d.scripts.draft(
          title: 'Demo talk',
          body:
              '## Hook\nHello everyone. Thanks for coming today.\n\n'
              '## Close\nThat is all from me.',
        ),
      ),
    );
    await tester.pumpWidget(NeuralLensApp(deps: d));
    await settle(tester);

    await tester.tap(find.text('Library'));
    await settle(tester);
    await tester.tap(find.text('Demo talk'));
    await settle(tester);
    expect(find.text('Present'), findsOneWidget);
    expect(find.text('Revise with AI'), findsOneWidget);

    await tester.tap(find.text('Present'));
    await settle(tester);
    expect(find.byType(TeleprompterControls), findsOneWidget);
    expect(find.text('HOOK'), findsOneWidget);

    await tester.tap(find.byTooltip('Switch to glasses mode'));
    await settle(tester);
    expect(find.byType(GlassesCueView), findsOneWidget);
    expect(
      find.textContaining(
        'Simulator · glasses not connected',
        findRichText: true,
      ),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Start'));
    await settle(tester);
    await tester.tap(find.byTooltip('Exit'), warnIfMissed: false);
    await settle(tester);
  });
}
