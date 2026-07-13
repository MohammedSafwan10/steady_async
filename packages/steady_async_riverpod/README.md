# steady_async_riverpod

Riverpod 3 integration for [`steady_async`](https://pub.dev/packages/steady_async).
It translates `AsyncValue<T>` without changing your provider architecture.

```yaml
dependencies:
  steady_async_riverpod: ^0.1.0
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
values, refresh/reload intent, stack traces, errors, and progress are preserved.
Requires Dart 3.7+ and Riverpod 3.
