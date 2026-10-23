# NeuralLens

**See beyond the screen.** NeuralLens is an AI-powered teleprompter for Meta smart glasses. It turns rough ideas into natural speaking scripts, keeps a local library of scripts and notes, and presents readable cues on your phone or on Meta Ray-Ban Display glasses.

This is an Android-first Flutter MVP. The code is laid out so iOS can be added later without rewriting the AI or script features.

## Features

- **AI Script Studio (Gemini)**: generate a script from a topic or notes, choosing format, duration, tone and language. Includes cancel, retry, regenerate and typed error messages.
- **Editor**: title and body editing with debounced autosave, which also flushes when you leave the screen. Also supports duplicate, delete with confirmation, favorites, tags, format and tone. **Revise with AI** and **Cue sections** always show a preview that you confirm before your text is replaced.
- **Library**: search, filters (all, scripts, notes, favorites), most recent first, and empty and no-results states. Everything is stored offline in SQLite.
- **Teleprompter**:
  - **Phone mode**: smooth scrolling with a reading-line marker; adjustable speed and font size; mirror mode; previous/next cue and section controls; restart; a progress bar; the screen stays awake. Your position is saved when you pause or exit.
  - **Glasses mode**: a compact cue layout made for a 600×600 display. It shows on the phone as a **simulator** and is sent to real glasses when they're connected.
- **Meta glasses**: a native Kotlin bridge to Meta's official Wearables Device Access Toolkit (DAT 1.0.0). It covers registration, a display-capable session, cue rendering and Neural Band / touch input.
- **Settings**: default font size, speed and mode; mirror; theme (dark, light, system); Neural Band mapping; Gemini and glasses status; app version.

The app works with **no Gemini key and no glasses**. AI actions then explain how to configure Gemini, and the simulator still works.

## Requirements

- Flutter 3.44+ (Dart 3.12+), JDK 17+
- An Android device or emulator running **Android 10 (API 29) or newer**. The DAT AARs declare `minSdkVersion 29`.
- Accept the Android SDK licenses once: `flutter doctor --android-licenses`

## Run

```bash
flutter pub get
flutter analyze
flutter test

# One-time: create your local config (git-ignored) and fill in GEMINI_API_KEY
cp .env.example .env

# Run with the keys from .env (VS Code's launch configs already pass this)
flutter run --dart-define-from-file=.env

# Build an APK
flutter build apk --debug --dart-define-from-file=.env
```

Without a key (or without the flag), the app still runs: local scripts, the teleprompter and the simulator all work.

## Gemini configuration

- Create a key at [Google AI Studio → API keys](https://aistudio.google.com/apikey). Restrict it with **Add restrictions → Restrict to Gemini API only**. Put it in `.env` as `GEMINI_API_KEY=...`. `--dart-define-from-file=.env` passes it to the build, and the app reads it through `String.fromEnvironment` in `lib/core/config/app_config.dart`. No Firebase project is needed for development.
- The default model is `gemini-3.5-flash-lite`. In October 2026 the [Gemini models page](https://ai.google.dev/gemini-api/docs/models) recommended 3.5 Flash-Lite or 3.8 Flash for new projects. You can override it with `GEMINI_MODEL` in `.env`.
- Requests use `models.generateContent` (v1beta), with the key in the `x-goog-api-key` header and `responseMimeType: application/json` plus a `responseSchema`. Responses are validated before display. Malformed output never crashes the app.
- **Security:** a key passed with `--dart-define` or `--dart-define-from-file` is compiled into the APK and can be extracted. Use this only for local development and testing. For a public release, move Gemini calls behind your own backend or use Firebase AI Logic with App Check.
- Never commit keys. `.env` and `android/local.properties` are git-ignored. Only `.env.example`, which has no values, is committed.

## Meta glasses setup

These steps were verified against the official [Wearables docs](https://wearables.developer.meta.com/docs/develop/) and the [`meta-wearables-dat-android`](https://github.com/facebook/meta-wearables-dat-android) samples (DAT **1.0.0**, a developer preview).

1. Use **Meta Ray-Ban Display** glasses, with firmware and the Meta AI app meeting the [version dependencies](https://wearables.developer.meta.com/docs/develop/dat/version-dependencies/).
2. In the **Meta AI** app, enable **Developer Mode**: go to App Info and tap the app version 5 times.
3. Run NeuralLens and open **Glasses**. Tap **Connect with Meta AI**, allow the Bluetooth permission, and approve the app in Meta AI.
4. Wear the glasses and tap **Connect glasses**. Then present a script in **Glasses** mode.
5. **Neural Band input** uses the experimental Inputs capability. It must be **enabled for your app in the Wearables Developer Center**; without that the SDK reports `PERMISSION_DENIED` and the app falls back to on-screen controls.

Developer Mode uses `0` for the application ID and client token. For a release, put the values from the Wearables Developer Center in `.env`, which Gradle also reads:

```properties
MWDAT_APPLICATION_ID=YOUR_APP_ID
MWDAT_CLIENT_TOKEN=YOUR_CLIENT_TOKEN
```

The older `mwdat_application_id` / `mwdat_client_token` entries in `android/local.properties` still work as a fallback.

Also register the app's callback URL scheme (`neurallens`, declared in `AndroidManifest.xml`) in the Developer Center.

### What the integration does (and doesn't)

| Capability | Status |
|---|---|
| Registration with Meta AI | `Wearables.startRegistration` / `startUnregistration` |
| Session | `Wearables.createSession(AutoDeviceSelector(filter = isDisplayCapable))`; the state comes only from the SDK |
| Display | `session.addDisplay()` → `display.sendContent { flexBox { text(...) } }`, sent only when the cue changes and throttled to ≥ 400 ms |
| Neural Band / touch | `session.addInputs(InputsConfiguration(sources = {NEURAL_BAND, CAPTOUCH}))`. `Nav` RIGHT/DOWN → next, LEFT/UP → previous, `Select` → pause/resume (configurable), `Back` → pause |
| Simulator | On-phone preview only. It is never reported as a connection. |
| MockDeviceKit | Not used, so a mock device can never appear as connected |

**Known limitations**
- DAT is a developer preview, and Inputs is experimental: apps using it can't ship to production release channels yet.
- Meta notes that real glasses don't deliver `Back` yet.
- Each `sendContent` replaces the whole display and updates go over Bluetooth, so glasses mode shows discrete cues rather than pixel scrolling.
- Not yet tested on real hardware. Check on your glasses:
  - the cue layout and text sizes (`TextStyle.HEADING` lines)
  - which Nav direction feels like "forward". There's an *Invert navigation* setting if it's backwards.
- iOS has no glasses bridge yet. On iOS the app reports the integration as unavailable.

## Project structure

```
lib/
  main.dart, app.dart              # bootstrap + dependency injection
  core/                            # config, theme tokens, router + shell, shared widgets
  data/local/app_database.dart     # sqflite schema (v1)
  features/
    ai/                            # GeminiService, prompts, GeneratedScript parsing, Studio UI
    scripts/                       # models, repository, cue segmenter, duration estimator, library + editor
    presentation/                  # PresentationCubit state machine, phone teleprompter, glasses cue view
    wearables/                     # WearablesService interface, Meta platform-channel service, UI
    settings/                      # SharedPreferences-backed settings
android/app/src/main/kotlin/.../MetaWearablesBridge.kt   # native DAT bridge
test/                              # unit, cubit and widget tests
```

State management uses `flutter_bloc` cubits, navigation uses `go_router`, scripts are stored with `sqflite`, settings with `shared_preferences`, and Gemini is called through `http`.

## Tests

`flutter test` covers:
- cue segmentation
- duration estimation
- AI response parsing and validation
- Gemini error handling with a mocked HTTP client
- repository create, edit, delete, duplicate and persistence across reopen
- editor autosave and AI-revision confirmation
- the presentation state machine, including glasses output and band input mapping with a fake device
- launch smoke tests with no API key and no glasses
