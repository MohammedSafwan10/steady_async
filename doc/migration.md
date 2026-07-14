# Migration guide

## From 0.2.x to 0.3.0

Existing Future loaders, action factories, controllers, and pagination widgets
remain supported. The adapter releases require the matching core line:

```yaml
steady_async: ^0.3.0
steady_async_riverpod: ^0.2.0 # when used
steady_async_bloc: ^0.2.0     # when used
```

Automatic retry and timeout default to disabled, so upgrading does not silently
repeat requests. Opt in with `SteadyRequestPolicy`.

Use named `.cancellable` constructors only when the underlying client exposes
a real cancel callback. Existing Future factories keep their stale-result
guards and are not described as cancellable.

Pagination cache hydration now accepts `SteadyPagedSeed`. It does not read or
write storage. When an authenticated user, workspace, or query changes, call
`replaceSource`; the default `SteadySourceTransition.clear` avoids displaying
content from the previous source. `retain` is explicit.

Keyed mutation methods require `itemKey`. Optimistic methods return a handle;
the application must commit or roll it back, or pass it to
`SteadyActionController.runOptimistic`. The handle must still be pending when
it is passed. Callback-backed handles created with
`SteadyOptimisticHandle.apply` are applied by `runOptimistic` immediately before
the request starts or is queued. Under `latestWins`, the previous mutation is
rolled back before the replacement is applied, so an old snapshot cannot
overwrite newer UI. Sequential optimistic calls that have not started are
rolled back in reverse order when the action controller is reset or disposed.

Retained source replacement keeps authoritative server data and already
committed optimistic changes. Pending optimistic overlays are invalidated and
never copied into the replacement source.

The new `SteadyFailure` is available as `state.failure`. Existing raw `error`
and `stackTrace` access remains available throughout the 0.x line. Application
error copy belongs in `SteadyThemeData.errorMapper`; custom builders still
receive raw state and bypass that mapper.

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

## Pagination from 0.2.x

Existing paged controllers and widgets remain source-compatible. Applications
may opt into custom pagination state builders or remove a dismissed item with
`removeWhere` or `removeByKey`.

`removeByKey` requires the controller's `itemKey`. Successful local removal
invalidates active requests so an older completion cannot restore the item.

A non-null page key must advance. Returning the requested key again now produces
a `SteadyPaginationException` instead of allowing an infinite request loop.
