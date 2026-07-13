# steady_async

Calm, production-ready async UX for Flutter. `steady_async` prevents flashing
spinners, keeps existing content visible during refresh, ignores stale results,
and provides consistent retry, action, and pagination states.

## Why use it?

A normal `FutureBuilder` exposes snapshots; your app still has to solve loader
timing, refresh continuity, retry safety, stale completions, empty states,
accessibility, and motion. `steady_async` makes those behaviors one reusable
policy while remaining independent of Provider, Riverpod, BLoC, and GetX.

## Install

```yaml
dependencies:
  steady_async: ^0.2.1
```

Flutter 3.22+ and Dart 3.4+ are supported.

## Future

Pass a factory, not an already-created Future, so retry is safe:

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

Fast operations do not flash a loader. Refreshes preserve previous content by
default. Use `SteadyAsyncController` when you need explicit refresh or reload:

```dart
final controller = SteadyAsyncController(api.fetchUsers);

await controller.load();
await controller.refresh();
await controller.retry();
```

## Async actions

```dart
SteadyButton<void>(
  action: form.save,
  child: const Text('Save'),
  successChild: const Text('Saved'),
)
```

Duplicate taps are dropped by default. Choose `latestWins` or `sequential` for
searches and queues.

## Pagination

```dart
final pages = SteadyPagedController<Post, String>(
  firstPageKey: 'first',
  loadPage: api.fetchPosts,
);

SteadyPagedListView<Post, String>(
  controller: pages,
  itemBuilder: (context, post, index) => PostTile(post),
)
```

The controller supports cursor or offset keys, guards overlapping requests,
retains items after append failures, rejects non-advancing cursors, and retries
the failed page. Local removal is available when a dismissed item must disappear
before the next refresh:

```dart
final pages = SteadyPagedController<Post, String>(
  firstPageKey: 'first',
  itemKey: (post) => post.id,
  loadPage: api.fetchPosts,
);

pages.removeByKey(deletedPostId);
```

Paged list, grid, and sliver widgets accept custom loading, initial-error,
retained refresh-error, append-loading, and append-error builders while
retaining Material defaults.
Every controller operation becomes a safe no-op after disposal.

## Customize globally

```dart
SteadyTheme(
  data: const SteadyThemeData(
    policy: SteadyTransitionPolicy(loadingDelay: Duration(milliseconds: 150)),
  ),
  child: const MyApp(),
)
```

All loading, empty, error, retry, transition, timing, and empty-predicate APIs
can be replaced. Built-in messages support English, Hindi, Arabic, Spanish,
French, German, Brazilian Portuguese, Simplified Chinese, and Japanese.

See the [interactive showcase](https://steady-async.nexdark.com) and the
[repository](https://github.com/MohammedSafwan10/steady_async).
