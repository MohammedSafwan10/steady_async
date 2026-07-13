# steady_async

Your API is not slow. Your loading UI is noisy.

`steady_async` is a Flutter package family for calm, predictable async UX:
delayed loaders, preserved refresh content, safe retries, stale-result guards,
async actions, and production-ready pagination.

[Live showcase](https://steady-async.nexdark.com) ·
[Core package](packages/steady_async) ·
[Riverpod adapter](packages/steady_async_riverpod) ·
[BLoC adapter](packages/steady_async_bloc)

## Packages

| Package | Purpose | Minimum tested | Latest tested |
| --- | --- | --- | --- |
| `steady_async` | Independent state, builders, actions, pagination, theme, locales | Flutter 3.22.3 / Dart 3.4 | Flutter 3.44.3 / Dart 3.12.2 |
| `steady_async_riverpod` | Riverpod 3 `AsyncValue` conversion and view | Flutter 3.29.0 / Dart 3.7 | Flutter 3.44.3 / Dart 3.12.2 |
| `steady_async_bloc` | Typed BLoC/Cubit selector view | Flutter 3.22.3 / Dart 3.4 | Flutter 3.44.3 / Dart 3.12.2 |

The core deliberately has no state-management dependency. Adapters stay small
and separately versioned so applications install only what they use.

## Default UX policy

- Hide loaders for operations that finish within 200 ms.
- Keep a shown loader visible for at least 350 ms.
- Preserve previous data through refresh and append failures.
- Ignore obsolete completions after retry, reload, reset, or disposal.
- Drop duplicate action submissions by default.
- Respect reduced-motion preferences and RTL locales.

## Repository

```text
apps/showcase/                    Interactive Flutter web demo
packages/steady_async/            Framework-independent core
packages/steady_async_riverpod/   Riverpod 3 integration
packages/steady_async_bloc/       BLoC and Cubit integration
doc/                              Architecture, migration, and release guides
```

The Riverpod adapter's Dart 3.7 requirement makes Flutter 3.29.0 its practical
minimum tested Flutter release. Package SDK constraints remain the source of
truth; CI verifies the minimum and latest combinations above.

## Validate locally

Run `tool/verify.ps1` from PowerShell. It formats, analyzes, tests, documents,
and builds the Flutter web showcase. Publishing remains a deliberate manual
step for the first release.

## License

BSD-3-Clause. Copyright 2026 Mohammed Safwan.
