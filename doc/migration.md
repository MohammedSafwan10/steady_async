# Migration guide

## From FutureBuilder

Replace an already-created Future with a retry-safe factory:

```dart
// Before
FutureBuilder<List<User>>(
  future: api.fetchUsers(),
  builder: (context, snapshot) { /* state branches */ },
)

// After
SteadyAsyncBuilder<List<User>>(
  load: api.fetchUsers,
  dataBuilder: (context, users) => UsersList(users),
)
```

Move special UI into `loadingBuilder`, `emptyBuilder`, and `errorBuilder` only
when the Material 3 defaults are not sufficient.

## From StreamBuilder

Use `SteadyStreamBuilder(stream: repository.watchUsers, ...)`. The factory is
resubscribed when its identity changes; the previous value is retained while a
replacement stream begins.

## Existing state management

Provider, GetX, `setState`, and custom controllers can pass an explicit
`SteadyAsyncState<T>` to `SteadyStateView<T>`. Riverpod and BLoC applications
can install their dedicated adapter without restructuring providers or blocs.
