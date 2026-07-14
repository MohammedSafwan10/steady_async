## 0.2.0

- Updated the core constraint to `steady_async >=0.3.0 <0.4.0`.
- Maps Riverpod errors to typed failure metadata and preserves initial,
  refresh, and reload operation origin.
- Keeps Riverpod-owned timestamps unknown while the core records when an
  external failure is observed.

## 0.1.1

- Added a tested nullable-cursor `autoDispose` pagination example.
- Expanded the compatible `steady_async` range through 0.2.x.

## 0.1.0

- Initial Riverpod 3 adapter for `steady_async`.
- Added `AsyncValue` conversion and `SteadyRiverpodView`.
