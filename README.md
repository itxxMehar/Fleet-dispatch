# badrgo Ops Console

Flutter Web operations dashboard for the [badrgo assessment API](https://sandbox.badrgo.com).

## Requirements

| Tool | Version |
| --- | --- |
| Flutter | **3.44.5** (stable) — recommended; matches this repo’s `.metadata` |
| Dart | **3.12.2** (`pubspec.yaml` requires `sdk: ^3.12.2`) |
| Target | **Flutter Web** (Chrome recommended) |
| App version | `1.0.0+1` (`pubspec.yaml`) |

Check your machine:

```bash
flutter --version
dart --version
```

Channel: **stable**. Agar Flutter purana hai to pehle upgrade karo taake Dart `^3.12.2` satisfy ho.

## Web setup and run

```bash
flutter pub get
flutter run -d chrome --dart-define=API_URL=https://sandbox.badrgo.com
```

Release build:

```bash
flutter build web --release --dart-define=API_URL=https://sandbox.badrgo.com
```

Do not hardcode secrets. Pass the API base URL with `--dart-define=API_URL=…`.
