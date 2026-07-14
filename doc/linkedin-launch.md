# LinkedIn launch

## 12-second video storyboard

| Time | Screen | Caption |
| --- | --- | --- |
| 0–2s | A fast response briefly flashes a spinner | Fast request: no spinner needed |
| 2–5s | Refresh replaces the current content | Refresh: keep current data visible |
| 5–9s | `steady_async` delays the loader and retains data | Loading and refresh behavior in one controller |
| 9–12s | Package name, pub.dev command, demo URL | `flutter pub add steady_async` |

## Post copy

I kept rewriting loader timing, refresh state, retries, duplicate-submit guards,
and pagination handling in Flutter projects, so I moved that code into
`steady_async`. The core package works with plain Flutter, and Riverpod and BLoC
adapters are separate packages.

Try the interactive before/after demo: https://steady-async.nexdark.com

Feedback and reproducible edge cases are welcome on GitHub.
