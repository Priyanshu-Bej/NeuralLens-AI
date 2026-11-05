# Third-party notices

The root [MIT License](LICENSE) applies to original NeuralLens code and documentation. It does not replace the licenses, copyright notices, or service terms of third-party components.

## Bundled fonts: Geist and Geist Mono

- **Copyright:** 2024 The Geist Project Authors.
- **Source:** <https://github.com/vercel/geist-font>
- **License:** SIL Open Font License, Version 1.1.
- **Files:** `assets/fonts/Geist-*.ttf` and `assets/fonts/GeistMono-*.ttf`.
- **Full license and copyright notice:** [assets/fonts/OFL.txt](assets/fonts/OFL.txt).

Keep the font copyright notice and OFL text with redistributed fonts. The fonts retain their OFL license; they are not relicensed under MIT. The app registers this license with Flutter's license registry, accessible through **Settings → Licenses**.

## Meta Wearables Device Access Toolkit

The Android integration depends on `com.meta.wearable:mwdat-core`, `mwdat-display`, and `mwdat-inputs`, currently pinned to `1.0.0` in [android/app/build.gradle.kts](android/app/build.gradle.kts).

- **Upstream:** <https://github.com/meta/meta-wearables-dat-android>
- **Upstream license reference:** <https://github.com/meta/meta-wearables-dat-android/blob/main/LICENSE>
- **Developer terms:** <https://wearables.developer.meta.com/terms>
- **Acceptable use policy:** <https://wearables.developer.meta.com/acceptable-use-policy>
- **Upstream third-party notices:** <https://github.com/meta/meta-wearables-dat-android/blob/main/NOTICE>

These SDK components are governed by Meta's terms, not NeuralLens's MIT license. The Maven metadata for the pinned components links to the SDK's upstream license reference. Follow the terms and retain notices applicable to the exact SDK artifacts you distribute. Upstream `main` may change independently of the pinned version. The experimental Inputs capability also requires appropriate developer access.

The SDK is resolved by Gradle; its binaries are not checked into this source repository. The Flutter license page is not a complete inventory of native Gradle dependencies or their notices.

## Flutter, Dart packages, and native dependencies

Flutter, Dart, the packages resolved in [pubspec.lock](pubspec.lock), and the Android/iOS dependencies retain their respective licenses. Source dependencies are declared in [pubspec.yaml](pubspec.yaml) and the platform build files; a dependency's inclusion does not make it MIT-licensed.

Flutter collects package license information for the app's **Settings → Licenses** screen. For a binary distribution, retain the applicable license and attribution material for the resolved Flutter engine, Dart packages, native libraries, and any assets you add. Review native dependency notices separately, including those supplied with Meta's SDK.

## Hosted services

Google Gemini is an external service rather than code redistributed under this repository's MIT license. Use requires your own configuration and is subject to the [Gemini API terms](https://ai.google.dev/gemini-api/terms). Meta platform access is similarly subject to its developer requirements. This repository's license does not grant API credentials or service access.

## Names and trademarks

Meta, Ray-Ban, Google, Gemini, Flutter, and other third-party names and marks belong to their respective owners. References identify integrations and dependencies and do not imply endorsement.
