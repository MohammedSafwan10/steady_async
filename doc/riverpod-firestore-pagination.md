# Riverpod 3 and Firestore pagination

Keep Firestore types in the application and let Riverpod own the controller's
lifecycle. Watching the authenticated user creates a new controller when the
user changes; disposing the old provider invalidates its pending results.

```dart
final notesPagerProvider = Provider.autoDispose<
    SteadyPagedController<Note, DocumentSnapshot<Map<String, dynamic>>?>>(ref) {
  final userId = ref.watch(
    currentUserProvider.select((user) => user?.uid),
  );
  final repository = ref.watch(notesRepositoryProvider);

  final controller = SteadyPagedController<
      Note, DocumentSnapshot<Map<String, dynamic>>?>(
    firstPageKey: null,
    itemKey: (note) => note.id,
    loadPage: (cursor) async {
      if (userId == null) return const SteadyPage(items: []);
      final page = await repository.getNotesPage(
        userId,
        startAfterDocument: cursor,
      );
      return SteadyPage(
        items: page.items,
        nextKey: page.hasMore ? page.lastDocument : null,
      );
    },
  );

  ref.onDispose(controller.dispose);
  unawaited(controller.loadInitial());
  return controller;
});
```

The packaged views listen to the controller, so the Riverpod provider only
owns its identity and lifetime:

```dart
final pager = ref.watch(notesPagerProvider);

return SteadyPagedListView<
  Note,
  DocumentSnapshot<Map<String, dynamic>>?
>(
  controller: pager,
  itemBuilder: (context, note, index) => NoteTile(note),
  loadingBuilder: (context, state) => const NotesSkeleton(),
  appendErrorBuilder: (context, state, retry) => LoadMoreError(
    error: state.error,
    onRetry: retry,
  ),
);
```

Do not reuse one controller whose loader reads the current user dynamically.
Capture one user ID per provider instance so an authentication change disposes
the old controller and its eventual Firestore completion is ignored.

Firestore is intentionally not a dependency of `steady_async` or
`steady_async_riverpod`; `DocumentSnapshot` is simply the application's generic
page-key type.
