# steady_async

Async UI infrastructure for Flutter: loader timing, retained refresh data,
retries, timeouts, real cancellation, actions, pagination, optimistic updates,
and stale-result protection.

`steady_async` does not replace Riverpod, BLoC, Provider, GetX, or `setState`.
It handles the request and UI edge cases around them.

## Install

```yaml
dependencies:
  steady_async: ^0.3.0
```

Requires Flutter 3.22.3+ and Dart 3.4+.

## Load a screen

Pass a factory so retry can create a new request:

```dart
SteadyAsyncBuilder<List<User>>(
  load: api.fetchUsers,
  isEmpty: (users) => users.isEmpty,
  dataBuilder: (context, users) => ListView.builder(
    itemCount: users.length,
    itemBuilder: (context, index) => Text(users[index].name),
  ),
)
```

Fast requests skip the spinner. Refresh keeps existing data visible. Obsolete
results after reload, reset, or disposal cannot replace newer state.

## Retry, timeout, and real cancellation

Automatic retry and timeout are disabled unless configured:

```dart
final controller = SteadyAsyncController<User>(
  api.fetchUser,
  requestPolicy: SteadyRequestPolicy(
    timeout: const Duration(seconds: 8),
    retry: SteadyRetryPolicy.exponential(
      maxAttempts: 3, // includes the first call
      shouldRetry: (failure) => failure.error is NetworkException,
    ),
  ),
);
```

Ordinary Dart futures cannot be cancelled. When the data client has a real
cancel API, expose it explicitly:

```dart
final controller = SteadyAsyncController<User>.cancellable(
  () {
    final request = api.startUserRequest();
    return SteadyCancellableOperation(
      future: request.result,
      cancel: request.cancel,
    );
  },
  requestPolicy: const SteadyRequestPolicy(
    timeout: Duration(seconds: 8),
  ),
);
```

Replacement, timeout, reset, and disposal call `cancel` once. Normal Future
factories still use generation guards, without claiming to cancel the work.

## Map application errors

Default error surfaces can share application-specific copy and accessibility:

```dart
SteadyTheme(
  data: SteadyThemeData(
    errorMapper: (context, failure) => switch (failure.error) {
      NetworkException() => const SteadyErrorPresentation(
          message: 'You appear to be offline.',
          retryLabel: 'Try again',
          semanticsLabel: 'Network request failed',
        ),
      _ => const SteadyErrorPresentation(message: 'Could not load this page.'),
    },
  ),
  child: const MyApp(),
)
```

Custom error builders keep receiving the raw typed state and bypass this
presentation layer.

## Async actions and optimistic actions

```dart
SteadyButton<void>(
  action: form.save,
  child: const Text('Save'),
  successChild: const Text('Saved'),
)
```

Duplicate taps are dropped by default. `latestWins` and `sequential` are also
available. Application-owned state can participate in the same transaction:

```dart
final change = SteadyOptimisticHandle.apply(
  apply: () => cart.remove(item),
  rollback: () => cart.insert(item),
);

await deleteController.runOptimistic(change);
```

Success commits; sync/async failure and cancellable timeout roll back. A
dropped call rolls back immediately because no server request started.

## Pagination, cache hydration, and source changes

```dart
final pages = SteadyPagedController<Post, String?>(
  firstPageKey: null,
  sourceKey: signedInUser.id,
  seed: SteadyPagedSeed(
    items: repository.cachedPosts,
    nextKey: repository.cachedCursor,
    lastUpdatedAt: repository.cacheTime,
  ),
  itemKey: (post) => post.id,
  loadPage: repository.fetchPosts,
);
```

The seed is visible immediately and refreshes once on `loadInitial()` by
default. Storage remains application-owned; Hive, Isar, SQLite, Firebase, and
encrypted stores do not become package dependencies.

Replace an authenticated user, workspace, or query atomically:

```dart
await pages.replaceSource(
  sourceKey: nextUser.id,
  firstPageKey: null,
  loadPage: nextRepository.fetchPosts,
  seed: nextRepository.cachedSeed,
  // clear is the default and prevents cross-user data leakage.
  transition: SteadySourceTransition.clear,
);
```

Use `retain` only for safe filter/search transitions where showing old content
briefly is acceptable.

## Immediate and optimistic list mutations

With `itemKey` configured:

```dart
pages.insert(createdPost);
pages.updateByKey(post.id, (current) => current.copyWith(title: title));
pages.removeByKey(post.id);

final removal = pages.optimisticRemoveByKey(post.id);
try {
  await repository.delete(post.id);
  removal.commit();
} catch (_) {
  removal.rollback();
}
```

Pending optimistic overlays survive refresh and append, replay in creation
order, and are invalidated by reset, source replacement, or disposal.

## Pagination widgets

```dart
SteadyPagedListView<Post, String?>(
  controller: pages,
  itemBuilder: (context, post, index) => PostTile(post),
)
```

List, grid, sliver list, and sliver grid variants include underfilled-page
prefetch, retained refresh errors, append retry, final-page detection, cursor
cycle protection, and replaceable loading/error builders.

## Request telemetry

```dart
class RequestObserver implements SteadyObserver {
  @override
  void onEvent(SteadyLifecycleEvent event) {
    analytics.record(event.kind.name, event.elapsed);
  }
}
```

Events contain operation IDs, type, attempts, timing, label, and failure
metadata. Observer failures expose only the exception type and request metadata;
the raw exception remains available on controller state and is never forwarded
to telemetry. Events never contain response values, list items, cursors, or
source keys. Observer errors are reported through Flutter diagnostics and cannot
alter request state.

## State metadata

Async, action, and paged states expose failure metadata, attempt timestamps,
last successful update time, and deterministic `isStale(maximumAge, now: ...)`.
All controller timestamps are UTC; tests can inject `SteadyClock`.

See the [interactive showcase](https://steady-async.nexdark.com),
[migration guide](https://github.com/MohammedSafwan10/steady_async/blob/main/doc/migration.md), and
[Riverpod/Firestore recipe](https://github.com/MohammedSafwan10/steady_async/blob/main/doc/riverpod-firestore-pagination.md).
