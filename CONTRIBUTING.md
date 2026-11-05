# Contributing to NeuralLens

Thanks for helping improve NeuralLens. Bug reports, usability feedback, documentation, and code contributions are welcome.

## Before you start

Read the [README](README.md) for current functionality, setup, and the roadmap. Base general contributions on `develop`. The conversational assistant and backend experiments live on separate branches and are not yet part of `develop`.

For a substantial change, open an issue first so we can agree on its scope. Keep individual pull requests focused on one problem or feature.

## Local workflow

1. Fork the repository and create a branch from `develop`.
2. Install dependencies with `flutter pub get`.
3. Keep API keys and device configuration in ignored local files. Never include real credentials in examples, screenshots, logs, or patches.
4. Make your change and add or update relevant tests when behavior changes.
5. Run the checks below, then open a pull request targeting `develop`.

```bash
dart format lib test
flutter analyze
flutter test
```

In the pull request, explain the problem, the resulting behavior, and what you verified. For interface changes, include screenshots without private data. For glasses changes, distinguish simulator or fake-device tests from physical-device testing and state the relevant device/SDK details.

## Reporting bugs

Open a [GitHub issue](https://github.com/Priyanshu-Bej/NeuralLens-AI/issues) with reproduction steps, expected and actual behavior, your app branch or commit, and relevant Flutter/Android versions. For wearable issues, include the glasses model and whether the problem occurs in the simulator or on hardware.

Remove credentials, private script contents, device identifiers, and personal information from logs before sharing them. For a suspected credential exposure or other sensitive security issue, contact [Priyanshu on LinkedIn](https://www.linkedin.com/in/priyanshubej/) privately first; do not post the secret in a public issue or send an active key.

## Licensing

Contributions of original code and documentation are accepted under the repository's [MIT License](LICENSE). Only submit material you have the right to contribute. Preserve existing notices and document any new dependency or copied third-party material in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), along with its applicable license.
