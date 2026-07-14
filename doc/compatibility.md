# Compatibility matrix

The package constraints in each `pubspec.yaml` are authoritative. CI exercises
the minimum and latest combinations below.

| Package | Release | Minimum Flutter | Minimum Dart | Integration dependency | Latest verified |
| --- | --- | --- | --- | --- | --- |
| `steady_async` | 0.3.0 | 3.22.3 | 3.4 | Flutter SDK only | Flutter 3.44.3 / Dart 3.12.2 |
| `steady_async_bloc` | 0.2.0 | 3.22.3 | 3.4 | `flutter_bloc` 9.x | Flutter 3.44.3 / Dart 3.12.2 |
| `steady_async_riverpod` | 0.2.0 | 3.29.0 | 3.7 | `flutter_riverpod` 3.x | Flutter 3.44.3 / Dart 3.12.2 |

Core analysis and tests run on Linux, Windows, and macOS. A separate local-path
consumer smoke app builds for macOS and the iOS Simulator. The web showcase is
built in release mode.

The Riverpod adapter's higher minimum follows Riverpod 3 and Dart 3.7. The core
and BLoC adapter continue to support Flutter 3.22.3.
