import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'localization.dart';
import 'state_view.dart';

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

  /// Whether another page is available.
  bool get hasMore => nextKey != null;

  /// Whether any page request is currently active.
  bool get isBusy =>
      status == SteadyPagedStatus.initialLoading ||
      status == SteadyPagedStatus.refreshing ||
      status == SteadyPagedStatus.loadingMore;

  SteadyPagedState<T, K> copyWith({
    List<T>? items,
    SteadyPagedStatus? status,
    K? nextKey,
    bool clearNextKey = false,
    Object? error,
    bool clearError = false,
    StackTrace? stackTrace,
    bool? appendError,
  }) =>
      SteadyPagedState<T, K>(
        items: items ?? this.items,
        status: status ?? this.status,
        nextKey: clearNextKey ? null : nextKey ?? this.nextKey,
        error: clearError ? null : error ?? this.error,
        stackTrace: clearError ? null : stackTrace ?? this.stackTrace,
        appendError: clearError ? false : appendError ?? this.appendError,
      );
}

/// Loads, refreshes, appends, retries, and deduplicates a paged data source.
class SteadyPagedController<T, K> extends ChangeNotifier
    implements ValueListenable<SteadyPagedState<T, K>> {
  /// Creates a pagination controller.
  SteadyPagedController({
    required this.firstPageKey,
    required SteadyPageLoader<T, K> loadPage,
    this.itemKey,
  }) : _loadPage = loadPage;

  /// Key used for the initial page and every refresh.
  final K firstPageKey;

  /// When provided, removes duplicate items both within and across pages.
  final Object? Function(T item)? itemKey;
  SteadyPageLoader<T, K> _loadPage;
  SteadyPagedState<T, K> _value = const SteadyPagedState();
  final Set<K> _requestedPageKeys = <K>{};
  int _generation = 0;
  bool _disposed = false;

  /// Latest public pagination state.
  @override
  SteadyPagedState<T, K> get value => _value;

  /// Replaces the loader used by future requests.
  void updateLoader(SteadyPageLoader<T, K> loader) {
    if (_disposed) return;
    _loadPage = loader;
  }

  /// Loads the first page once while the controller is idle.
  Future<void> loadInitial() async {
    if (_disposed || _value.status != SteadyPagedStatus.idle) return;
    await _replace(firstPageKey, refreshing: false);
  }

  /// Replaces existing pages starting at [firstPageKey].
  Future<void> refresh() {
    if (_disposed) return Future<void>.value();
    return _replace(firstPageKey, refreshing: true);
  }

  Future<void> _replace(K key, {required bool refreshing}) async {
    if (_disposed) return;
    final generation = ++_generation;
    _requestedPageKeys
      ..clear()
      ..add(key);
    _setValue(
      _value.copyWith(
        status: refreshing && _value.items.isNotEmpty
            ? SteadyPagedStatus.refreshing
            : SteadyPagedStatus.initialLoading,
        clearError: true,
      ),
    );
    try {
      final page = _validatePage(
        await Future<SteadyPage<T, K>>.sync(() => _loadPage(key)),
      );
      if (!_accepts(generation)) return;
      _setValue(
        SteadyPagedState<T, K>(
          items: List<T>.unmodifiable(_deduplicate(page.items)),
          status: SteadyPagedStatus.loaded,
          nextKey: page.nextKey,
        ),
      );
    } catch (error, stackTrace) {
      if (!_accepts(generation)) return;
      _setValue(
        SteadyPagedState<T, K>(
          items: _value.items,
          status: SteadyPagedStatus.error,
          nextKey: _value.nextKey,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Appends the page identified by the current next key.
  Future<void> loadMore() async {
    if (_disposed) return;
    final key = _value.nextKey;
    if (_value.isBusy || key == null) return;
    final generation = _generation;
    _requestedPageKeys.add(key);
    _setValue(
      _value.copyWith(status: SteadyPagedStatus.loadingMore, clearError: true),
    );
    try {
      final page = _validatePage(
        await Future<SteadyPage<T, K>>.sync(() => _loadPage(key)),
      );
      if (!_accepts(generation)) return;
      _setValue(
        SteadyPagedState<T, K>(
          items: List<T>.unmodifiable(
            _deduplicate([..._value.items, ...page.items]),
          ),
          status: SteadyPagedStatus.loaded,
          nextKey: page.nextKey,
        ),
      );
    } catch (error, stackTrace) {
      if (!_accepts(generation)) return;
      _setValue(
        SteadyPagedState<T, K>(
          items: _value.items,
          status: SteadyPagedStatus.loaded,
          nextKey: key,
          error: error,
          stackTrace: stackTrace,
          appendError: true,
        ),
      );
    }
  }

  /// Repeats the failed initial, refresh, or append request.
  Future<void> retry() {
    if (_disposed) return Future<void>.value();
    return _value.items.isEmpty || !_value.appendError ? refresh() : loadMore();
  }

  SteadyPage<T, K> _validatePage(SteadyPage<T, K> page) {
    final nextKey = page.nextKey;
    if (nextKey != null && _requestedPageKeys.contains(nextKey)) {
      throw SteadyPaginationException.nonAdvancingCursor(nextKey);
    }
    return page;
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

  /// Removes every item matched by [predicate].
  ///
  /// A successful removal invalidates active requests so an older completion
  /// cannot restore a locally removed item. The current next-page key is kept.
  bool removeWhere(bool Function(T item) predicate) {
    if (_disposed) return false;
    final items = _value.items.where((item) => !predicate(item)).toList();
    if (items.length == _value.items.length) return false;
    _generation++;
    _setValue(
      SteadyPagedState<T, K>(
        items: List<T>.unmodifiable(items),
        status: SteadyPagedStatus.loaded,
        nextKey: _value.nextKey,
      ),
    );
    return true;
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

  /// Clears all items and invalidates active requests.
  void reset() {
    if (_disposed) return;
    _generation++;
    _requestedPageKeys.clear();
    _setValue(SteadyPagedState<T, K>());
  }

  bool _accepts(int generation) => !_disposed && generation == _generation;

  void _setValue(SteadyPagedState<T, K> state) {
    if (_disposed) return;
    _value = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
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
                SteadyDefaultErrorView(onRetry: retry);
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
                SteadyDefaultErrorView(onRetry: retry);
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
    super.key,
  });

  final SteadyPagedController<T, K> controller;
  final SteadyPagedItemBuilder<T> itemBuilder;
  final WidgetBuilder? emptyBuilder;
  final SteadyPagedStateBuilder<T, K>? loadingBuilder;
  final SteadyPagedRetryBuilder<T, K>? errorBuilder;

  /// Builds an inline refresh error while previously loaded items remain.
  final SteadyPagedRetryBuilder<T, K>? refreshErrorBuilder;
  final SteadyPagedStateBuilder<T, K>? appendLoadingBuilder;
  final SteadyPagedRetryBuilder<T, K>? appendErrorBuilder;

  @override
  Widget build(BuildContext context) {
    if (controller.value.status == SteadyPagedStatus.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(controller.loadInitial());
      });
    }
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
                SteadyDefaultErrorView(onRetry: retry),
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
                itemIndex >= state.items.length - 3) {
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
    final messages = SteadyMessages.resolve(context);
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(
        leading: const Icon(Icons.error_outline),
        title: Text(messages.error),
        trailing: TextButton(onPressed: onRetry, child: Text(messages.retry)),
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
      return Center(
        child: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(SteadyMessages.resolve(context).retry),
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
