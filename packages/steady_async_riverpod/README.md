# steady_async_riverpod

Riverpod 3 integration for [`steady_async`](https://pub.dev/packages/steady_async).
It translates `AsyncValue<T>` without changing your provider architecture.

```yaml
dependencies:
  steady_async_riverpod: ^0.2.0
```

```dart
final users = ref.watch(usersProvider);

return SteadyRiverpodView<List<User>>(
  value: users,
  onRetry: () => ref.invalidate(usersProvider),
  isEmpty: (items) => items.isEmpty,
  dataBuilder: (context, items) => UsersList(items),
);
```

`AsyncValue.toSteadyState()` also gives you an explicit core state. Previous
values, refresh/reload intent, stack traces, typed failure origin, errors, and
progress are preserved. Riverpod does not expose request timestamps, so the
adapter does not invent `lastUpdatedAt` or `lastAttemptAt` values. Requires
Flutter 3.29+, Dart 3.7+, and Riverpod 3.

For cursor pagination, let an `autoDispose Provider` own a core
`SteadyPagedController` and dispose it through `ref.onDispose`. See the complete
[Riverpod 3 and Firestore recipe](https://github.com/MohammedSafwan10/steady_async/blob/main/doc/riverpod-firestore-pagination.md).
