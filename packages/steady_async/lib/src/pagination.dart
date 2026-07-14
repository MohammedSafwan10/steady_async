import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'localization.dart';
import 'optimistic.dart';
import 'request.dart';
import 'request_engine.dart';
import 'state_view.dart';
import 'theme.dart';

/// One cursor or offset page returned by a data source.
@immutable
class SteadyPage<T, K> {
  /// Creates a page with an optional key for the next request.
  const SteadyPage({required this.items, this.nextKey});

  /// Items received in this page.
  final List<T> items;

  /// Key for the next page, or `null` when pagination is complete.
  final K? nextKey;
}

/// Loads one page identified by a generic cursor or offset key.
typedef SteadyPageLoader<T, K> = Future<SteadyPage<T, K>> Function(K pageKey);

/// Loads one page and exposes the data client's real cancellation callback.
typedef SteadyCancellablePageLoader<T, K>
    = SteadyCancellableOperation<SteadyPage<T, K>> Function(K pageKey);

/// Controls what remains visible while a different data source is installed.
enum SteadySourceTransition { clear, retain }

/// Application-supplied cached pagination state shown before network refresh.
@immutable
class SteadyPagedSeed<T, K> {
  /// Creates an immutable hydration seed; the package does not persist it.
  const SteadyPagedSeed({
    required this.items,
    this.nextKey,
    this.lastUpdatedAt,
  });

  final List<T> items;
  final K? nextKey;
  final DateTime? lastUpdatedAt;
}

/// Error reported when a data source returns a non-null cursor that has already
/// been requested in the current pagination session.
class SteadyPaginationException implements Exception {
  /// Creates a non-advancing cursor error.
  const SteadyPaginationException.nonAdvancingCursor(this.pageKey);

  /// Cursor that repeated instead of advancing.
  final Object? pageKey;

  @override
  String toString() =>
      'SteadyPaginationException: The next page key repeated the already '
      'requested key $pageKey.';
}

/// Current stage of a paged data source.
enum SteadyPagedStatus {
  idle,
  initialLoading,
  loaded,
  refreshing,
  loadingMore,
  error,
}

/// Immutable pagination state that retains items across refresh and failures.
@immutable
class SteadyPagedState<T, K> {
  /// Creates pagination state.
  const SteadyPagedState({
    this.items = const [],
    this.status = SteadyPagedStatus.idle,
    this.nextKey,
    this.error,
    this.stackTrace,
    this.appendError = false,
    this.failure,
    this.lastUpdatedAt,
    this.lastAttemptAt,
  });

  /// All accepted, accumulated items.
  final List<T> items;

  /// Current request stage.
  final SteadyPagedStatus status;

  /// Key to request next, or `null` at the final page.
  final K? nextKey;

  /// Most recent initial, refresh, or append failure.
  final Object? error;

  /// Stack trace associated with [error].
  final StackTrace? stackTrace;

  /// Whether [error] came from appending while existing items were retained.
  final bool appendError;
  final SteadyFailure? failure;
  final DateTime? lastUpdatedAt;
  final DateTime? lastAttemptAt;

  /// Whether another page is available.
  bool get hasMore => nextKey != null;

  /// Whether any page request is currently active.
  bool get isBusy =>
      status == SteadyPagedStatus.initialLoading ||
      status == SteadyPagedStatus.refreshing ||
      status == SteadyPagedStatus.loadingMore;

  bool get isRefreshing => status == SteadyPagedStatus.refreshing;
  bool get isAppending => status == SteadyPagedStatus.loadingMore;
  bool get hasRefreshError =>
      status == SteadyPagedStatus.error &&
      failure?.operation == SteadyOperationKind.refresh;
  bool get hasAppendError => appendError;
  bool get hasTerminalError =>
      status == SteadyPagedStatus.error && items.isEmpty;

  bool isStale(Duration maximumAge, {DateTime? now}) {
    final updatedAt = lastUpdatedAt;
    if (updatedAt == null) return true;
    return (now ?? DateTime.now().toUtc()).toUtc().difference(updatedAt) >
        maximumAge;
  }

  SteadyPagedState<T, K> copyWith({
    List<T>? items,
    SteadyPagedStatus? status,
    K? nextKey,
    bool clearNextKey = false,
    Object? error,
    bool clearError = false,
    StackTrace? stackTrace,
    bool? appendError,
    SteadyFailure? failure,
    DateTime? lastUpdatedAt,
    DateTime? lastAttemptAt,
  }) =>
      SteadyPagedState<T, K>(
        items: items ?? this.items,
        status: status ?? this.status,
        nextKey: clearNextKey ? null : nextKey ?? this.nextKey,
        error: clearError ? null : error ?? this.error,
        stackTrace: clearError ? null : stackTrace ?? this.stackTrace,
        appendError: clearError ? false : appendError ?? this.appendError,
        failure: clearError ? null : failure ?? this.failure,
        lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
        lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      );
}

/// Loads, refreshes, appends, retries, and deduplicates a paged data source.
class SteadyPagedController<T, K> extends ChangeNotifier
    implements ValueListenable<SteadyPagedState<T, K>> {
  /// Creates a pagination controller.
  SteadyPagedController({
    required K firstPageKey,
    required SteadyPageLoader<T, K> loadPage,
    this.itemKey,
    Object? sourceKey,
    SteadyPagedSeed<T, K>? seed,
    this.refreshSeededData = true,
    this.requestPolicy = const SteadyRequestPolicy(),
    this.observer,
    this.operationLabel,
    SteadyClock? clock,
  })  : _firstPageKey = firstPageKey,
        _loadPage = loadPage,
        _cancellableLoadPage = null,
        _sourceKey = sourceKey,
        _clock = clock ?? DateTime.now {
    _installSeed(seed);
  }

  SteadyPagedController.cancellable({
    required K firstPageKey,
    required SteadyCancellablePageLoader<T, K> loadPage,
    this.itemKey,
    Object? sourceKey,
    SteadyPagedSeed<T, K>? seed,
    this.refreshSeededData = true,
    this.requestPolicy = const SteadyRequestPolicy(),
    this.observer,
    this.operationLabel,
    SteadyClock? clock,
  })  : _firstPageKey = firstPageKey,
        _loadPage = null,
        _cancellableLoadPage = loadPage,
        _sourceKey = sourceKey,
        _clock = clock ?? DateTime.now {
    _installSeed(seed);
  }

  /// Key used for the initial page and every refresh.
  K _firstPageKey;
  K get firstPageKey => _firstPageKey;
  Object? _sourceKey;
  Object? get sourceKey => _sourceKey;

  /// When provided, removes duplicate items both within and across pages.
  final Object? Function(T item)? itemKey;
  final bool refreshSeededData;
  final SteadyRequestPolicy requestPolicy;
  final SteadyObserver? observer;
  final String? operationLabel;
  final SteadyClock _clock;
  SteadyPageLoader<T, K>? _loadPage;
  SteadyCancellablePageLoader<T, K>? _cancellableLoadPage;
  SteadyPagedState<T, K> _value = const SteadyPagedState();
  List<T> _baseItems = [];
  final List<_PagedMutation<T>> _mutations = [];
  final Set<int> _committedMutations = {};
  final Map<int, SteadyOptimisticHandle> _handles = {};
  final Set<K> _requestedPageKeys = <K>{};
  int _generation = 0;
  int _sourceRevision = 0;
  int _operationId = 0;
  bool _disposed = false;
  bool _transitioning = false;
  bool _invalidating = false;
  bool _seedNeedsRefresh = false;
  SteadyRequestRunner<SteadyPage<T, K>>? _activeRunner;

  /// Latest public pagination state.
  @override
  SteadyPagedState<T, K> get value => _value;

  /// Replaces the loader used by future requests.
  void updateLoader(SteadyPageLoader<T, K> loader) {
    if (_disposed) return;
    _loadPage = loader;
    _cancellableLoadPage = null;
  }

  void updateCancellableLoader(SteadyCancellablePageLoader<T, K> loader) {
    if (_disposed) return;
    _cancellableLoadPage = loader;
    _loadPage = null;
  }

  /// Loads the first page once while the controller is idle.
  Future<void> loadInitial() async {
    if (_disposed || _transitioning) return;
    if (_seedNeedsRefresh) {
      _seedNeedsRefresh = false;
      await _replace(_firstPageKey, refreshing: true);
      return;
    }
    if (_value.status != SteadyPagedStatus.idle) return;
    await _replace(_firstPageKey, refreshing: false);
  }

  /// Replaces existing pages starting at [firstPageKey].
  Future<void> refresh() {
    if (_disposed || _transitioning) return Future<void>.value();
    return _replace(_firstPageKey, refreshing: true);
  }

  Future<void> _replace(K key, {required bool refreshing}) async {
    if (_disposed || _transitioning) return;
    _transitioning = true;
    late final int generation;
    final operation = refreshing
        ? SteadyOperationKind.refresh
        : SteadyOperationKind.initialLoad;
    SteadyRequestRunner<SteadyPage<T, K>>? runner;
    try {
      final previousRunner = _activeRunner;
      _activeRunner = null;
      generation = ++_generation;
      previousRunner?.cancel();
      if (!_accepts(generation)) return;
      _requestedPageKeys
        ..clear()
        ..add(key);
      _setValue(
        _value.copyWith(
          status: refreshing && _value.items.isNotEmpty
              ? SteadyPagedStatus.refreshing
              : SteadyPagedStatus.initialLoading,
          clearError: true,
          lastAttemptAt: _now(),
        ),
      );
      if (!_accepts(generation)) return;
      runner = _createPageRunner(key, operation, generation);
      _activeRunner = runner;
    } finally {
      _transitioning = false;
    }
    final execution = await runner.run();
    if (identical(_activeRunner, runner)) _activeRunner = null;
    if (!_accepts(generation)) return;
    switch (execution) {
      case SteadyExecutionSuccess<SteadyPage<T, K>>(
          value: final page,
          :final completedAt,
        ):
        _baseItems = _deduplicate(page.items);
        _setLoaded(page.nextKey, completedAt);
      case SteadyExecutionFailure<SteadyPage<T, K>>(:final failure):
        _setValue(
          SteadyPagedState<T, K>(
            items: _visibleItems(),
            status: SteadyPagedStatus.error,
            nextKey: _value.nextKey,
            error: failure.error,
            stackTrace: failure.stackTrace,
            failure: failure,
            lastUpdatedAt: _value.lastUpdatedAt,
            lastAttemptAt: _value.lastAttemptAt,
          ),
        );
      case SteadyExecutionCancelled<SteadyPage<T, K>>():
        break;
    }
  }

  /// Appends the page identified by the current next key.
  Future<void> loadMore() async {
    if (_disposed || _transitioning) return;
    final key = _value.nextKey;
    if (_value.isBusy || key == null) return;
    final generation = _generation;
    _transitioning = true;
    SteadyRequestRunner<SteadyPage<T, K>>? runner;
    try {
      _requestedPageKeys.add(key);
      _setValue(
        _value.copyWith(
          status: SteadyPagedStatus.loadingMore,
          clearError: true,
          lastAttemptAt: _now(),
        ),
      );
      if (!_accepts(generation)) return;
      runner = _createPageRunner(
        key,
        SteadyOperationKind.append,
        generation,
      );
      _activeRunner = runner;
    } finally {
      _transitioning = false;
    }
    final execution = await runner.run();
    if (identical(_activeRunner, runner)) _activeRunner = null;
    if (!_accepts(generation)) return;
    switch (execution) {
      case SteadyExecutionSuccess<SteadyPage<T, K>>(
          value: final page,
          :final completedAt,
        ):
        _baseItems = _deduplicate([..._baseItems, ...page.items]);
        _setLoaded(page.nextKey, completedAt);
      case SteadyExecutionFailure<SteadyPage<T, K>>(:final failure):
        _setValue(
          SteadyPagedState<T, K>(
            items: _visibleItems(),
            status: SteadyPagedStatus.loaded,
            nextKey: key,
            error: failure.error,
            stackTrace: failure.stackTrace,
            appendError: true,
            failure: failure,
            lastUpdatedAt: _value.lastUpdatedAt,
            lastAttemptAt: _value.lastAttemptAt,
          ),
        );
      case SteadyExecutionCancelled<SteadyPage<T, K>>():
        break;
    }
  }

  /// Repeats the failed initial, refresh, or append request.
  Future<void> retry() {
    if (_disposed) return Future<void>.value();
    if (_value.appendError) return loadMore();
    if (_value.failure?.operation == SteadyOperationKind.initialLoad) {
      return _replace(_firstPageKey, refreshing: false);
    }
    return refresh();
  }

  SteadyPage<T, K> _validatePage(SteadyPage<T, K> page) {
    final nextKey = page.nextKey;
    if (nextKey != null && _requestedPageKeys.contains(nextKey)) {
      throw SteadyPaginationException.nonAdvancingCursor(nextKey);
    }
    return page;
  }

  SteadyRequestRunner<SteadyPage<T, K>> _createPageRunner(
    K key,
    SteadyOperationKind operation,
    int generation,
  ) {
    final loadPage = _loadPage;
    final cancellableLoadPage = _cancellableLoadPage;
    final runner = SteadyRequestRunner<SteadyPage<T, K>>(
      operationId: ++_operationId,
      controllerType: 'pagination',
      operation: operation,
      factory: () => _pageOperation(key, loadPage, cancellableLoadPage),
      policy: requestPolicy,
      clock: _clock,
      observer: observer,
      label: operationLabel,
      onAttempt: (_, startedAt) {
        if (_accepts(generation) && _value.isBusy) {
          _setValue(_value.copyWith(lastAttemptAt: startedAt));
        }
      },
    );
    return runner;
  }

  SteadyCancellableOperation<SteadyPage<T, K>> _pageOperation(
    K key,
    SteadyPageLoader<T, K>? loadPage,
    SteadyCancellablePageLoader<T, K>? cancellable,
  ) {
    if (cancellable != null) {
      final operation = cancellable(key);
      return SteadyCancellableOperation(
        future: operation.future.then(_validatePage),
        cancel: operation.cancel,
      );
    }
    return steadyOperationFromFuture(
      Future<SteadyPage<T, K>>.sync(() => loadPage!(key)).then(_validatePage),
    );
  }

  List<T> _deduplicate(Iterable<T> items) {
    final keyOf = itemKey;
    if (keyOf == null) return List<T>.of(items);
    final seen = <Object?>{};
    return [
      for (final item in items)
        if (seen.add(keyOf(item))) item
    ];
  }

  List<T> _visibleItems() {
    var items = List<T>.of(_baseItems);
    for (final mutation in _mutations) {
      items = mutation.apply(items, itemKey);
    }
    return List<T>.unmodifiable(_deduplicate(items));
  }

  void _setLoaded(K? nextKey, DateTime updatedAt) {
    _setValue(
      SteadyPagedState<T, K>(
        items: _visibleItems(),
        status: SteadyPagedStatus.loaded,
        nextKey: nextKey,
        lastUpdatedAt: updatedAt,
        lastAttemptAt: _value.lastAttemptAt,
      ),
    );
  }

  /// Inserts [item] locally and invalidates older request completions.
  ///
  /// When `itemKey` is configured, an existing item with the same key is
  /// removed first. The current next-page key is retained.
  bool insert(T item, {int index = 0}) {
    if (_disposed || _transitioning) return false;
    _transitioning = true;
    try {
      _prepareImmediateMutation();
      final keyOf = itemKey;
      if (keyOf != null) {
        final key = keyOf(item);
        _baseItems.removeWhere((current) => keyOf(current) == key);
      }
      _baseItems.insert(index.clamp(0, _baseItems.length), item);
      _publishLocalMutation();
      return true;
    } finally {
      _transitioning = false;
    }
  }

  /// Replaces a local item selected by [key].
  ///
  /// Returns false when no item matches. This requires `itemKey`.
  bool updateByKey(Object? key, T Function(T current) update) {
    if (_disposed || _transitioning) return false;
    final keyOf = _requireItemKey('updateByKey');
    if (!_authoritativeItems().any((item) => keyOf(item) == key)) return false;
    _transitioning = true;
    try {
      _prepareImmediateMutation();
      final baseIndex = _baseItems.indexWhere((item) => keyOf(item) == key);
      if (baseIndex < 0) return false;
      _baseItems[baseIndex] = update(_baseItems[baseIndex]);
      _publishLocalMutation();
      return true;
    } finally {
      _transitioning = false;
    }
  }

  /// Removes every item matched by [predicate].
  ///
  /// A successful removal invalidates active requests so an older completion
  /// cannot restore a locally removed item. The current next-page key is kept.
  bool removeWhere(bool Function(T item) predicate) {
    if (_disposed || _transitioning) return false;
    if (!_authoritativeItems().any(predicate)) return false;
    _transitioning = true;
    try {
      _prepareImmediateMutation();
      _baseItems = _baseItems.where((item) => !predicate(item)).toList();
      _publishLocalMutation();
      return true;
    } finally {
      _transitioning = false;
    }
  }

  /// Removes items whose application key equals [key].
  ///
  /// An [itemKey] function must have been supplied to the controller.
  ///
  /// ```dart
  /// final pager = SteadyPagedController<Post, String>(
  ///   firstPageKey: 'first',
  ///   itemKey: (post) => post.id,
  ///   loadPage: repository.loadPosts,
  /// );
  /// pager.removeByKey(deletedPostId);
  /// ```
  bool removeByKey(Object? key) {
    if (_disposed) return false;
    final keyOf = itemKey;
    if (keyOf == null) {
      throw StateError('removeByKey requires an itemKey function.');
    }
    return removeWhere((item) => keyOf(item) == key);
  }

  /// Applies an insert overlay immediately and returns its transaction handle.
  ///
  /// ```dart
  /// final change = pager.optimisticInsert(draft);
  /// try {
  ///   await repository.create(draft);
  ///   change.commit();
  /// } catch (_) {
  ///   change.rollback();
  /// }
  /// ```
  SteadyOptimisticHandle optimisticInsert(T item, {int index = 0}) {
    if (_disposed || _transitioning) {
      return SteadyOptimisticHandle.invalidated();
    }
    final keyOf = _requireItemKey('optimisticInsert');
    return _addOptimistic(
      _PagedMutation.insert(
        id: ++_operationId,
        key: keyOf(item),
        item: item,
        index: index,
      ),
    );
  }

  /// Applies a keyed update overlay that survives refresh and append rebasing.
  SteadyOptimisticHandle optimisticUpdateByKey(
    Object? key,
    T Function(T current) update,
  ) {
    if (_disposed || _transitioning) {
      return SteadyOptimisticHandle.invalidated();
    }
    final keyOf = _requireItemKey('optimisticUpdateByKey');
    final current =
        _visibleItems().where((item) => keyOf(item) == key).firstOrNull;
    if (current == null) {
      throw StateError('No item exists for optimistic key $key.');
    }
    return _addOptimistic(
      _PagedMutation.update(
        id: ++_operationId,
        key: key,
        item: update(current),
      ),
    );
  }

  /// Hides a keyed item immediately until the handle commits or rolls back.
  SteadyOptimisticHandle optimisticRemoveByKey(Object? key) {
    if (_disposed || _transitioning) {
      return SteadyOptimisticHandle.invalidated();
    }
    final keyOf = _requireItemKey('optimisticRemoveByKey');
    if (!_visibleItems().any((item) => keyOf(item) == key)) {
      throw StateError('No item exists for optimistic key $key.');
    }
    return _addOptimistic(
      _PagedMutation.remove(id: ++_operationId, key: key),
    );
  }

  SteadyOptimisticHandle _addOptimistic(_PagedMutation<T> mutation) {
    if (_disposed) throw StateError('The controller has been disposed.');
    final revision = _sourceRevision;
    _mutations.add(mutation);
    late final SteadyOptimisticHandle handle;
    handle = SteadyOptimisticHandle.pending(
      commit: () => _resolveOptimistic(mutation.id, revision, commit: true),
      rollback: () => _resolveOptimistic(mutation.id, revision, commit: false),
    );
    _handles[mutation.id] = handle;
    _emitOptimistic(
      SteadyLifecycleEventKind.optimisticApplied,
      mutation.id,
    );
    _publishVisible();
    return handle;
  }

  bool _resolveOptimistic(int id, int revision, {required bool commit}) {
    if (_disposed || revision != _sourceRevision) return false;
    final index = _mutations.indexWhere((mutation) => mutation.id == id);
    if (index < 0) return false;
    _handles.remove(id);
    if (commit) {
      _committedMutations.add(id);
    } else {
      _mutations.removeAt(index);
    }
    _emitOptimistic(
      commit
          ? SteadyLifecycleEventKind.optimisticCommitted
          : SteadyLifecycleEventKind.optimisticRolledBack,
      id,
    );
    _flushCommittedPrefix();
    _publishVisible();
    return true;
  }

  void _flushCommittedPrefix() {
    while (_mutations.isNotEmpty &&
        _committedMutations.contains(_mutations.first.id)) {
      final mutation = _mutations.removeAt(0);
      _committedMutations.remove(mutation.id);
      _baseItems = mutation.apply(_baseItems, itemKey);
    }
  }

  List<T> _authoritativeItems() {
    var items = List<T>.of(_baseItems);
    for (final mutation in _mutations) {
      if (_committedMutations.contains(mutation.id)) {
        items = mutation.apply(items, itemKey);
      }
    }
    return _deduplicate(items);
  }

  void _prepareImmediateMutation() {
    final runner = _activeRunner;
    _activeRunner = null;
    _generation++;
    runner?.cancel();
    _invalidateOptimistic(preserveCommitted: true);
  }

  void _publishLocalMutation() {
    _setValue(
      SteadyPagedState<T, K>(
        items: _visibleItems(),
        status: SteadyPagedStatus.loaded,
        nextKey: _value.nextKey,
        lastUpdatedAt: _now(),
        lastAttemptAt: _value.lastAttemptAt,
      ),
    );
  }

  void _publishVisible() {
    _setValue(
      _value.copyWith(
        items: _visibleItems(),
        status: _value.isBusy ? _value.status : SteadyPagedStatus.loaded,
        clearError: true,
      ),
    );
  }

  Object? Function(T) _requireItemKey(String method) {
    final keyOf = itemKey;
    if (keyOf == null) {
      throw StateError('$method requires an itemKey function.');
    }
    return keyOf;
  }

  /// Atomically installs a loader for a user, workspace, query, or filter.
  ///
  /// Different identities clear existing items by default. Use
  /// [SteadySourceTransition.retain] only when old content is safe to show.
  Future<void> replaceSource({
    required Object? sourceKey,
    required K firstPageKey,
    required SteadyPageLoader<T, K> loadPage,
    SteadyPagedSeed<T, K>? seed,
    SteadySourceTransition transition = SteadySourceTransition.clear,
    bool loadImmediately = true,
    bool refreshSeededData = true,
  }) async {
    if (_disposed || _transitioning) return;
    await _replaceSourceConfiguration(
      sourceKey: sourceKey,
      firstPageKey: firstPageKey,
      seed: seed,
      transition: transition,
      loadImmediately: loadImmediately,
      refreshSeededData: refreshSeededData,
      loadPage: loadPage,
      cancellableLoadPage: null,
    );
  }

  /// Installs a source whose page requests provide real cancellation.
  Future<void> replaceCancellableSource({
    required Object? sourceKey,
    required K firstPageKey,
    required SteadyCancellablePageLoader<T, K> loadPage,
    SteadyPagedSeed<T, K>? seed,
    SteadySourceTransition transition = SteadySourceTransition.clear,
    bool loadImmediately = true,
    bool refreshSeededData = true,
  }) async {
    if (_disposed || _transitioning) return;
    await _replaceSourceConfiguration(
      sourceKey: sourceKey,
      firstPageKey: firstPageKey,
      seed: seed,
      transition: transition,
      loadImmediately: loadImmediately,
      refreshSeededData: refreshSeededData,
      loadPage: null,
      cancellableLoadPage: loadPage,
    );
  }

  Future<void> _replaceSourceConfiguration({
    required Object? sourceKey,
    required K firstPageKey,
    required SteadyPagedSeed<T, K>? seed,
    required SteadySourceTransition transition,
    required bool loadImmediately,
    required bool refreshSeededData,
    required SteadyPageLoader<T, K>? loadPage,
    required SteadyCancellablePageLoader<T, K>? cancellableLoadPage,
  }) async {
    if (_disposed || _transitioning) return;
    _transitioning = true;
    try {
      final runner = _activeRunner;
      _activeRunner = null;
      _generation++;
      runner?.cancel();
      if (_disposed) return;
      _loadPage = loadPage;
      _cancellableLoadPage = cancellableLoadPage;
      _requestedPageKeys.clear();
      final retainBase =
          seed == null && transition == SteadySourceTransition.retain;
      _invalidateOptimistic(preserveCommitted: retainBase);
      _seedNeedsRefresh = false;
      if (_sourceKey != sourceKey) _sourceRevision++;
      _sourceKey = sourceKey;
      _firstPageKey = firstPageKey;
      if (seed != null) {
        _installSeed(seed, needsRefresh: refreshSeededData);
      } else if (transition == SteadySourceTransition.retain) {
        _value = SteadyPagedState<T, K>(
          items: List<T>.unmodifiable(_deduplicate(_baseItems)),
          status: SteadyPagedStatus.loaded,
          lastUpdatedAt: _value.lastUpdatedAt,
        );
      } else {
        _baseItems = [];
        _value = SteadyPagedState<T, K>();
      }
      _emitSourceReplaced();
      if (_disposed) return;
      notifyListeners();
    } finally {
      _transitioning = false;
    }
    if (loadImmediately && !_disposed) {
      _seedNeedsRefresh = false;
      await _replace(_firstPageKey, refreshing: _value.items.isNotEmpty);
    }
  }

  void _installSeed(SteadyPagedSeed<T, K>? seed, {bool? needsRefresh}) {
    if (seed == null) return;
    _baseItems = _deduplicate(seed.items);
    _value = SteadyPagedState<T, K>(
      items: List<T>.unmodifiable(_baseItems),
      status: SteadyPagedStatus.loaded,
      nextKey: seed.nextKey,
      lastUpdatedAt: seed.lastUpdatedAt?.toUtc(),
    );
    _seedNeedsRefresh = needsRefresh ?? refreshSeededData;
  }

  void _invalidateOptimistic({bool preserveCommitted = false}) {
    if (preserveCommitted) {
      _baseItems = _authoritativeItems();
    }
    final handles = _handles.values.toList();
    _handles.clear();
    _mutations.clear();
    _committedMutations.clear();
    for (final handle in handles) {
      handle.invalidate();
    }
  }

  void _emitSourceReplaced() => _emitLifecycle(
        SteadyLifecycleEventKind.sourceReplaced,
        SteadyOperationKind.initialLoad,
      );

  void _emitOptimistic(
    SteadyLifecycleEventKind kind,
    int operationId,
  ) =>
      _emitLifecycle(
        kind,
        SteadyOperationKind.action,
        operationId: operationId,
      );

  void _emitLifecycle(
    SteadyLifecycleEventKind kind,
    SteadyOperationKind operation, {
    int? operationId,
  }) =>
      notifySteadyObserver(
        observer,
        SteadyLifecycleEvent(
          kind: kind,
          operationId: operationId ?? ++_operationId,
          controllerType: 'pagination',
          operation: operation,
          attempt: 0,
          timestamp: _now(),
          label: operationLabel,
        ),
      );

  /// Clears all items and invalidates active requests.
  void reset() {
    if (_disposed || _invalidating) return;
    final wasTransitioning = _transitioning;
    _invalidating = true;
    _transitioning = true;
    try {
      final runner = _activeRunner;
      _activeRunner = null;
      _generation++;
      runner?.cancel();
      _requestedPageKeys.clear();
      _invalidateOptimistic();
      _seedNeedsRefresh = false;
      _baseItems = [];
      _setValue(SteadyPagedState<T, K>());
    } finally {
      _transitioning = wasTransitioning;
      _invalidating = false;
    }
  }

  bool _accepts(int generation) => !_disposed && generation == _generation;

  void _setValue(SteadyPagedState<T, K> state) {
    if (_disposed) return;
    _value = state;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    final runner = _activeRunner;
    _activeRunner = null;
    runner?.cancel();
    _invalidateOptimistic();
    super.dispose();
  }

  DateTime _now() => _clock().toUtc();
}

enum _PagedMutationKind { insert, update, remove }

class _PagedMutation<T> {
  const _PagedMutation._({
    required this.id,
    required this.kind,
    required this.key,
    this.item,
    this.index = 0,
  });

  factory _PagedMutation.insert({
    required int id,
    required Object? key,
    required T item,
    required int index,
  }) =>
      _PagedMutation._(
        id: id,
        kind: _PagedMutationKind.insert,
        key: key,
        item: item,
        index: index,
      );

  factory _PagedMutation.update({
    required int id,
    required Object? key,
    required T item,
  }) =>
      _PagedMutation._(
        id: id,
        kind: _PagedMutationKind.update,
        key: key,
        item: item,
      );

  factory _PagedMutation.remove({required int id, required Object? key}) =>
      _PagedMutation._(id: id, kind: _PagedMutationKind.remove, key: key);

  final int id;
  final _PagedMutationKind kind;
  final Object? key;
  final T? item;
  final int index;

  List<T> apply(List<T> source, Object? Function(T)? itemKey) {
    if (itemKey == null) return List<T>.of(source);
    final items = List<T>.of(source);
    final existing = items.indexWhere((value) => itemKey(value) == key);
    switch (kind) {
      case _PagedMutationKind.insert:
        if (existing >= 0) items.removeAt(existing);
        items.insert(index.clamp(0, items.length), item as T);
      case _PagedMutationKind.update:
        if (existing >= 0) items[existing] = item as T;
      case _PagedMutationKind.remove:
        items.removeWhere((value) => itemKey(value) == key);
    }
    return items;
  }
}

/// Builds one item in a paged list, grid, or sliver.
typedef SteadyPagedItemBuilder<T> = Widget Function(
    BuildContext context, T item, int index);

/// Builds a custom paged loading state or append-loading footer.
///
/// ```dart
/// loadingBuilder: (context, state) => const PostsSkeleton()
/// ```
typedef SteadyPagedStateBuilder<T, K> = Widget Function(
  BuildContext context,
  SteadyPagedState<T, K> state,
);

/// Builds a custom paged error state with its retry callback.
///
/// ```dart
/// appendErrorBuilder: (context, state, retry) => TextButton(
///   onPressed: retry,
///   child: const Text('Retry page'),
/// )
/// ```
typedef SteadyPagedRetryBuilder<T, K> = Widget Function(
  BuildContext context,
  SteadyPagedState<T, K> state,
  VoidCallback retry,
);

/// List view with automatic paging, pull-to-refresh, and append retry.
class SteadyPagedListView<T, K> extends StatefulWidget {
  /// Creates a paged list view.
  const SteadyPagedListView({
    required this.controller,
    required this.itemBuilder,
    this.scrollController,
    this.padding,
    this.prefetchExtent = 240,
    this.emptyBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.refreshErrorBuilder,
    this.appendLoadingBuilder,
    this.appendErrorBuilder,
    super.key,
  });

  final SteadyPagedController<T, K> controller;
  final SteadyPagedItemBuilder<T> itemBuilder;
  final ScrollController? scrollController;
  final EdgeInsetsGeometry? padding;
  final double prefetchExtent;
  final WidgetBuilder? emptyBuilder;
  final SteadyPagedStateBuilder<T, K>? loadingBuilder;
  final SteadyPagedRetryBuilder<T, K>? errorBuilder;

  /// Builds an inline refresh error while previously loaded items remain.
  final SteadyPagedRetryBuilder<T, K>? refreshErrorBuilder;
  final SteadyPagedStateBuilder<T, K>? appendLoadingBuilder;
  final SteadyPagedRetryBuilder<T, K>? appendErrorBuilder;

  @override
  State<SteadyPagedListView<T, K>> createState() =>
      _SteadyPagedListViewState<T, K>();
}

class _SteadyPagedListViewState<T, K> extends State<SteadyPagedListView<T, K>> {
  late ScrollController _scrollController;
  late bool _ownsScrollController;

  @override
  void initState() {
    super.initState();
    _attachScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.controller.loadInitial());
    });
  }

  @override
  void didUpdateWidget(covariant SteadyPagedListView<T, K> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      _detachScrollController();
      _attachScrollController();
    }
    if (oldWidget.controller != widget.controller) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(widget.controller.loadInitial());
      });
    }
  }

  void _attachScrollController() {
    _ownsScrollController = widget.scrollController == null;
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  void _detachScrollController() {
    _scrollController.removeListener(_onScroll);
    if (_ownsScrollController) _scrollController.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (widget.controller.value.status == SteadyPagedStatus.loaded &&
        !widget.controller.value.appendError &&
        _scrollController.position.extentAfter <= widget.prefetchExtent) {
      unawaited(widget.controller.loadMore());
    }
  }

  void _scheduleLoadIfUnderfilled() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final state = widget.controller.value;
      if (state.status == SteadyPagedStatus.loaded &&
          !state.appendError &&
          state.hasMore &&
          _scrollController.position.extentAfter <= widget.prefetchExtent) {
        unawaited(widget.controller.loadMore());
      }
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final state = widget.controller.value;
          _scheduleLoadIfUnderfilled();
          if (state.items.isEmpty &&
              state.status == SteadyPagedStatus.initialLoading) {
            return widget.loadingBuilder?.call(context, state) ??
                const SteadyDefaultLoadingView();
          }
          if (state.items.isEmpty && state.status == SteadyPagedStatus.error) {
            void retry() => unawaited(widget.controller.retry());
            return widget.errorBuilder?.call(context, state, retry) ??
                SteadyDefaultErrorView(
                  onRetry: retry,
                  failure: _failureFor(state),
                );
          }
          if (state.items.isEmpty &&
              state.status == SteadyPagedStatus.loaded &&
              !state.hasMore) {
            return widget.emptyBuilder?.call(context) ??
                const SteadyDefaultEmptyView();
          }
          final showRetainedError = _showRetainedError(state);
          final leadingCount = showRetainedError ? 1 : 0;
          return RefreshIndicator(
            onRefresh: widget.controller.refresh,
            child: ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: widget.padding,
              itemCount: leadingCount +
                  state.items.length +
                  (_showFooter(state) ? 1 : 0),
              itemBuilder: (context, index) {
                if (showRetainedError && index == 0) {
                  return _PagedRetainedError<T, K>(
                    state: state,
                    onRetry: () => unawaited(widget.controller.retry()),
                    errorBuilder: widget.refreshErrorBuilder,
                  );
                }
                final itemIndex = index - leadingCount;
                if (itemIndex == state.items.length) {
                  return _PagedFooter<T, K>(
                    state: state,
                    onRetry: () => unawaited(widget.controller.loadMore()),
                    loadingBuilder: widget.appendLoadingBuilder,
                    errorBuilder: widget.appendErrorBuilder,
                  );
                }
                return widget.itemBuilder(
                  context,
                  state.items[itemIndex],
                  itemIndex,
                );
              },
            ),
          );
        },
      );

  bool _showFooter(SteadyPagedState<T, K> state) =>
      state.status == SteadyPagedStatus.loadingMore || state.appendError;

  bool _showRetainedError(SteadyPagedState<T, K> state) =>
      state.items.isNotEmpty &&
      state.status == SteadyPagedStatus.error &&
      !state.appendError;

  @override
  void dispose() {
    _detachScrollController();
    super.dispose();
  }
}

/// Grid view with automatic paging, pull-to-refresh, and append retry.
class SteadyPagedGridView<T, K> extends StatefulWidget {
  /// Creates a paged grid view.
  const SteadyPagedGridView({
    required this.controller,
    required this.itemBuilder,
    required this.gridDelegate,
    this.padding,
    this.prefetchExtent = 240,
    this.emptyBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.refreshErrorBuilder,
    this.appendLoadingBuilder,
    this.appendErrorBuilder,
    super.key,
  });

  final SteadyPagedController<T, K> controller;
  final SteadyPagedItemBuilder<T> itemBuilder;
  final SliverGridDelegate gridDelegate;
  final EdgeInsetsGeometry? padding;
  final double prefetchExtent;
  final WidgetBuilder? emptyBuilder;
  final SteadyPagedStateBuilder<T, K>? loadingBuilder;
  final SteadyPagedRetryBuilder<T, K>? errorBuilder;

  /// Builds an inline refresh error while previously loaded items remain.
  final SteadyPagedRetryBuilder<T, K>? refreshErrorBuilder;
  final SteadyPagedStateBuilder<T, K>? appendLoadingBuilder;
  final SteadyPagedRetryBuilder<T, K>? appendErrorBuilder;

  @override
  State<SteadyPagedGridView<T, K>> createState() =>
      _SteadyPagedGridViewState<T, K>();
}

class _SteadyPagedGridViewState<T, K> extends State<SteadyPagedGridView<T, K>> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.controller.loadInitial());
    });
  }

  @override
  void didUpdateWidget(covariant SteadyPagedGridView<T, K> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(widget.controller.loadInitial());
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (widget.controller.value.status == SteadyPagedStatus.loaded &&
        !widget.controller.value.appendError &&
        _scrollController.position.extentAfter <= widget.prefetchExtent) {
      unawaited(widget.controller.loadMore());
    }
  }

  void _scheduleLoadIfUnderfilled() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final state = widget.controller.value;
      if (state.status == SteadyPagedStatus.loaded &&
          !state.appendError &&
          state.hasMore &&
          _scrollController.position.extentAfter <= widget.prefetchExtent) {
        unawaited(widget.controller.loadMore());
      }
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final state = widget.controller.value;
          _scheduleLoadIfUnderfilled();
          if (state.items.isEmpty &&
              state.status == SteadyPagedStatus.initialLoading) {
            return widget.loadingBuilder?.call(context, state) ??
                const SteadyDefaultLoadingView();
          }
          if (state.items.isEmpty && state.status == SteadyPagedStatus.error) {
            void retry() => unawaited(widget.controller.retry());
            return widget.errorBuilder?.call(context, state, retry) ??
                SteadyDefaultErrorView(
                  onRetry: retry,
                  failure: _failureFor(state),
                );
          }
          if (state.items.isEmpty &&
              state.status == SteadyPagedStatus.loaded &&
              !state.hasMore) {
            return widget.emptyBuilder?.call(context) ??
                const SteadyDefaultEmptyView();
          }
          return RefreshIndicator(
            onRefresh: widget.controller.refresh,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (_showRetainedError(state))
                  SliverToBoxAdapter(
                    child: _PagedRetainedError<T, K>(
                      state: state,
                      onRetry: () => unawaited(widget.controller.retry()),
                      errorBuilder: widget.refreshErrorBuilder,
                    ),
                  ),
                SliverPadding(
                  padding: widget.padding ?? EdgeInsets.zero,
                  sliver: SliverGrid.builder(
                    gridDelegate: widget.gridDelegate,
                    itemCount: state.items.length,
                    itemBuilder: (context, index) => widget.itemBuilder(
                      context,
                      state.items[index],
                      index,
                    ),
                  ),
                ),
                if (_showFooter(state))
                  SliverToBoxAdapter(
                    child: _PagedFooter<T, K>(
                      state: state,
                      onRetry: () => unawaited(widget.controller.loadMore()),
                      loadingBuilder: widget.appendLoadingBuilder,
                      errorBuilder: widget.appendErrorBuilder,
                    ),
                  ),
              ],
            ),
          );
        },
      );

  bool _showFooter(SteadyPagedState<T, K> state) =>
      state.status == SteadyPagedStatus.loadingMore || state.appendError;

  bool _showRetainedError(SteadyPagedState<T, K> state) =>
      state.items.isNotEmpty &&
      state.status == SteadyPagedStatus.error &&
      !state.appendError;

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }
}

/// Sliver list that automatically requests pages near its trailing edge.
class SteadyPagedSliverList<T, K> extends StatelessWidget {
  /// Creates a paged sliver list.
  const SteadyPagedSliverList({
    required this.controller,
    required this.itemBuilder,
    this.emptyBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.refreshErrorBuilder,
    this.appendLoadingBuilder,
    this.appendErrorBuilder,
    this.prefetchItemCount = 3,
    super.key,
  }) : assert(prefetchItemCount >= 1);

  final SteadyPagedController<T, K> controller;
  final SteadyPagedItemBuilder<T> itemBuilder;
  final WidgetBuilder? emptyBuilder;
  final SteadyPagedStateBuilder<T, K>? loadingBuilder;
  final SteadyPagedRetryBuilder<T, K>? errorBuilder;

  /// Builds an inline refresh error while previously loaded items remain.
  final SteadyPagedRetryBuilder<T, K>? refreshErrorBuilder;
  final SteadyPagedStateBuilder<T, K>? appendLoadingBuilder;
  final SteadyPagedRetryBuilder<T, K>? appendErrorBuilder;
  final int prefetchItemCount;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(controller.loadInitial());
    });
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.value;
        if (state.items.isEmpty &&
            state.status == SteadyPagedStatus.initialLoading) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: loadingBuilder?.call(context, state) ??
                const SteadyDefaultLoadingView(),
          );
        }
        if (state.items.isEmpty && state.status == SteadyPagedStatus.error) {
          void retry() => unawaited(controller.retry());
          return SliverFillRemaining(
            hasScrollBody: false,
            child: errorBuilder?.call(context, state, retry) ??
                SteadyDefaultErrorView(
                  onRetry: retry,
                  failure: _failureFor(state),
                ),
          );
        }
        if (state.items.isEmpty && state.status == SteadyPagedStatus.loaded) {
          if (!state.hasMore) {
            return SliverFillRemaining(
              hasScrollBody: false,
              child:
                  emptyBuilder?.call(context) ?? const SteadyDefaultEmptyView(),
            );
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final latest = controller.value;
            if (latest.items.isEmpty &&
                latest.status == SteadyPagedStatus.loaded &&
                latest.hasMore &&
                !latest.appendError) {
              unawaited(controller.loadMore());
            }
          });
        }
        final showRetainedError = state.items.isNotEmpty &&
            state.status == SteadyPagedStatus.error &&
            !state.appendError;
        final leadingCount = showRetainedError ? 1 : 0;
        return SliverList.builder(
          itemCount:
              leadingCount + state.items.length + (_showFooter(state) ? 1 : 0),
          itemBuilder: (context, index) {
            if (showRetainedError && index == 0) {
              return _PagedRetainedError<T, K>(
                state: state,
                onRetry: () => unawaited(controller.retry()),
                errorBuilder: refreshErrorBuilder,
              );
            }
            final itemIndex = index - leadingCount;
            if (itemIndex == state.items.length) {
              return _PagedFooter<T, K>(
                state: state,
                onRetry: () => unawaited(controller.loadMore()),
                loadingBuilder: appendLoadingBuilder,
                errorBuilder: appendErrorBuilder,
              );
            }
            if (state.status == SteadyPagedStatus.loaded &&
                !state.appendError &&
                itemIndex >= state.items.length - prefetchItemCount) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final latest = controller.value;
                if (latest.status == SteadyPagedStatus.loaded &&
                    !latest.appendError) {
                  unawaited(controller.loadMore());
                }
              });
            }
            return itemBuilder(context, state.items[itemIndex], itemIndex);
          },
        );
      },
    );
  }

  bool _showFooter(SteadyPagedState<T, K> state) =>
      state.status == SteadyPagedStatus.loadingMore || state.appendError;
}

/// Sliver grid with automatic cursor paging and full-width request surfaces.
class SteadyPagedSliverGrid<T, K> extends StatelessWidget {
  const SteadyPagedSliverGrid({
    required this.controller,
    required this.itemBuilder,
    required this.gridDelegate,
    this.emptyBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.refreshErrorBuilder,
    this.appendLoadingBuilder,
    this.appendErrorBuilder,
    this.prefetchItemCount = 3,
    super.key,
  }) : assert(prefetchItemCount >= 1);

  final SteadyPagedController<T, K> controller;
  final SteadyPagedItemBuilder<T> itemBuilder;
  final SliverGridDelegate gridDelegate;
  final WidgetBuilder? emptyBuilder;
  final SteadyPagedStateBuilder<T, K>? loadingBuilder;
  final SteadyPagedRetryBuilder<T, K>? errorBuilder;
  final SteadyPagedRetryBuilder<T, K>? refreshErrorBuilder;
  final SteadyPagedStateBuilder<T, K>? appendLoadingBuilder;
  final SteadyPagedRetryBuilder<T, K>? appendErrorBuilder;
  final int prefetchItemCount;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(controller.loadInitial());
    });
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.value;
        if (state.items.isEmpty &&
            state.status == SteadyPagedStatus.initialLoading) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: loadingBuilder?.call(context, state) ??
                const SteadyDefaultLoadingView(),
          );
        }
        if (state.items.isEmpty && state.status == SteadyPagedStatus.error) {
          void retry() => unawaited(controller.retry());
          return SliverFillRemaining(
            hasScrollBody: false,
            child: errorBuilder?.call(context, state, retry) ??
                SteadyDefaultErrorView(
                  onRetry: retry,
                  failure: _failureFor(state),
                ),
          );
        }
        if (state.items.isEmpty && state.status == SteadyPagedStatus.loaded) {
          if (!state.hasMore) {
            return SliverFillRemaining(
              hasScrollBody: false,
              child:
                  emptyBuilder?.call(context) ?? const SteadyDefaultEmptyView(),
            );
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final latest = controller.value;
            if (latest.items.isEmpty &&
                latest.status == SteadyPagedStatus.loaded &&
                latest.hasMore &&
                !latest.appendError) {
              unawaited(controller.loadMore());
            }
          });
        }
        final retainedError = state.items.isNotEmpty &&
            state.status == SteadyPagedStatus.error &&
            !state.appendError;
        return SliverMainAxisGroup(
          slivers: [
            if (retainedError)
              SliverToBoxAdapter(
                child: _PagedRetainedError<T, K>(
                  state: state,
                  onRetry: () => unawaited(controller.retry()),
                  errorBuilder: refreshErrorBuilder,
                ),
              ),
            SliverGrid.builder(
              gridDelegate: gridDelegate,
              itemCount: state.items.length,
              itemBuilder: (context, index) {
                if (state.status == SteadyPagedStatus.loaded &&
                    !state.appendError &&
                    index >= state.items.length - prefetchItemCount) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final latest = controller.value;
                    if (latest.status == SteadyPagedStatus.loaded &&
                        !latest.appendError) {
                      unawaited(controller.loadMore());
                    }
                  });
                }
                return itemBuilder(context, state.items[index], index);
              },
            ),
            if (state.status == SteadyPagedStatus.loadingMore ||
                state.appendError)
              SliverToBoxAdapter(
                child: _PagedFooter<T, K>(
                  state: state,
                  onRetry: () => unawaited(controller.loadMore()),
                  loadingBuilder: appendLoadingBuilder,
                  errorBuilder: appendErrorBuilder,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PagedRetainedError<T, K> extends StatelessWidget {
  const _PagedRetainedError({
    required this.state,
    required this.onRetry,
    this.errorBuilder,
  });

  final SteadyPagedState<T, K> state;
  final VoidCallback onRetry;
  final SteadyPagedRetryBuilder<T, K>? errorBuilder;

  @override
  Widget build(BuildContext context) {
    final custom = errorBuilder;
    if (custom != null) return custom(context, state, onRetry);
    final steadyTheme = SteadyTheme.of(context);
    final messages = steadyTheme.messages ?? SteadyMessages.resolve(context);
    final presentation = steadyTheme.errorMapper?.call(
      context,
      _failureFor(state),
    );
    return Semantics(
      liveRegion: true,
      label: presentation?.semanticsLabel,
      child: Material(
        color: Theme.of(context).colorScheme.errorContainer,
        child: ListTile(
          leading: const Icon(Icons.error_outline),
          title: Text(presentation?.message ?? messages.error),
          trailing: (presentation?.showRetry ?? true)
              ? TextButton(
                  onPressed: onRetry,
                  child: Text(presentation?.retryLabel ?? messages.retry),
                )
              : null,
        ),
      ),
    );
  }
}

class _PagedFooter<T, K> extends StatelessWidget {
  const _PagedFooter({
    required this.state,
    required this.onRetry,
    this.loadingBuilder,
    this.errorBuilder,
  });

  final SteadyPagedState<T, K> state;
  final VoidCallback onRetry;
  final SteadyPagedStateBuilder<T, K>? loadingBuilder;
  final SteadyPagedRetryBuilder<T, K>? errorBuilder;

  @override
  Widget build(BuildContext context) {
    if (state.appendError) {
      final custom = errorBuilder;
      if (custom != null) return custom(context, state, onRetry);
      final steadyTheme = SteadyTheme.of(context);
      final messages = steadyTheme.messages ?? SteadyMessages.resolve(context);
      final presentation = steadyTheme.errorMapper?.call(
        context,
        _failureFor(state),
      );
      return Center(
        child: Semantics(
          liveRegion: true,
          label: presentation?.semanticsLabel,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(presentation?.message ?? messages.error),
              if (presentation?.showRetry ?? true)
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(presentation?.retryLabel ?? messages.retry),
                ),
            ],
          ),
        ),
      );
    }
    final custom = loadingBuilder;
    if (custom != null) return custom(context, state);
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}

SteadyFailure _failureFor<T, K>(SteadyPagedState<T, K> state) =>
    state.failure ??
    SteadyFailure.external(
      state.error ?? StateError('Unknown pagination failure.'),
      stackTrace: state.stackTrace,
      operation: state.appendError
          ? SteadyOperationKind.append
          : SteadyOperationKind.refresh,
    );
