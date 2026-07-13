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
    bool appendError = false,
  }) =>
      SteadyPagedState<T, K>(
        items: items ?? this.items,
        status: status ?? this.status,
        nextKey: clearNextKey ? null : nextKey ?? this.nextKey,
        error: clearError ? null : error ?? this.error,
        stackTrace: clearError ? null : stackTrace ?? this.stackTrace,
        appendError: appendError,
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
  int _generation = 0;
  bool _disposed = false;

  /// Latest public pagination state.
  @override
  SteadyPagedState<T, K> get value => _value;

  /// Replaces the loader used by future requests.
  void updateLoader(SteadyPageLoader<T, K> loader) => _loadPage = loader;

  /// Loads the first page once while the controller is idle.
  Future<void> loadInitial() async {
    if (_value.status != SteadyPagedStatus.idle) return;
    await _replace(firstPageKey, refreshing: false);
  }

  /// Replaces existing pages starting at [firstPageKey].
  Future<void> refresh() => _replace(firstPageKey, refreshing: true);

  Future<void> _replace(K key, {required bool refreshing}) async {
    final generation = ++_generation;
    _setValue(
      _value.copyWith(
        status: refreshing && _value.items.isNotEmpty
            ? SteadyPagedStatus.refreshing
            : SteadyPagedStatus.initialLoading,
        clearError: true,
      ),
    );
    try {
      final page = await Future<SteadyPage<T, K>>.sync(() => _loadPage(key));
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
    final key = _value.nextKey;
    if (_value.isBusy || key == null) return;
    final generation = _generation;
    _setValue(
      _value.copyWith(status: SteadyPagedStatus.loadingMore, clearError: true),
    );
    try {
      final page = await Future<SteadyPage<T, K>>.sync(() => _loadPage(key));
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
  Future<void> retry() =>
      _value.items.isEmpty || !_value.appendError ? refresh() : loadMore();

  List<T> _deduplicate(Iterable<T> items) {
    final keyOf = itemKey;
    if (keyOf == null) return List<T>.of(items);
    final seen = <Object?>{};
    return [
      for (final item in items)
        if (seen.add(keyOf(item))) item
    ];
  }

  /// Clears all items and invalidates active requests.
  void reset() {
    _generation++;
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
    super.key,
  });

  final SteadyPagedController<T, K> controller;
  final SteadyPagedItemBuilder<T> itemBuilder;
  final ScrollController? scrollController;
  final EdgeInsetsGeometry? padding;
  final double prefetchExtent;
  final WidgetBuilder? emptyBuilder;

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

  void _attachScrollController() {
    _ownsScrollController = widget.scrollController == null;
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter <= widget.prefetchExtent) {
      unawaited(widget.controller.loadMore());
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final state = widget.controller.value;
          if (state.items.isEmpty &&
              state.status == SteadyPagedStatus.initialLoading) {
            return const SteadyDefaultLoadingView();
          }
          if (state.items.isEmpty && state.status == SteadyPagedStatus.error) {
            return SteadyDefaultErrorView(
              onRetry: () => unawaited(widget.controller.retry()),
            );
          }
          if (state.items.isEmpty && state.status == SteadyPagedStatus.loaded) {
            return widget.emptyBuilder?.call(context) ??
                const SteadyDefaultEmptyView();
          }
          return RefreshIndicator(
            onRefresh: widget.controller.refresh,
            child: ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: widget.padding,
              itemCount: state.items.length + (_showFooter(state) ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == state.items.length) {
                  return _PagedFooter<T, K>(
                    state: state,
                    onRetry: () => unawaited(widget.controller.loadMore()),
                  );
                }
                return widget.itemBuilder(context, state.items[index], index);
              },
            ),
          );
        },
      );

  bool _showFooter(SteadyPagedState<T, K> state) =>
      state.status == SteadyPagedStatus.loadingMore || state.appendError;

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    if (_ownsScrollController) _scrollController.dispose();
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
    super.key,
  });

  final SteadyPagedController<T, K> controller;
  final SteadyPagedItemBuilder<T> itemBuilder;
  final SliverGridDelegate gridDelegate;
  final EdgeInsetsGeometry? padding;
  final double prefetchExtent;
  final WidgetBuilder? emptyBuilder;

  @override
  State<SteadyPagedGridView<T, K>> createState() =>
      _SteadyPagedGridViewState<T, K>();
}

class _SteadyPagedGridViewState<T, K> extends State<SteadyPagedGridView<T, K>> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.controller.loadInitial());
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final state = widget.controller.value;
          if (state.items.isEmpty && state.isBusy) {
            return const SteadyDefaultLoadingView();
          }
          if (state.items.isEmpty && state.status == SteadyPagedStatus.error) {
            return SteadyDefaultErrorView(
              onRetry: () => unawaited(widget.controller.retry()),
            );
          }
          if (state.items.isEmpty && state.status == SteadyPagedStatus.loaded) {
            return widget.emptyBuilder?.call(context) ??
                const SteadyDefaultEmptyView();
          }
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.extentAfter <= widget.prefetchExtent) {
                unawaited(widget.controller.loadMore());
              }
              return false;
            },
            child: RefreshIndicator(
              onRefresh: widget.controller.refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
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
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );

  bool _showFooter(SteadyPagedState<T, K> state) =>
      state.status == SteadyPagedStatus.loadingMore || state.appendError;
}

/// Sliver list that automatically requests pages near its trailing edge.
class SteadyPagedSliverList<T, K> extends StatelessWidget {
  /// Creates a paged sliver list.
  const SteadyPagedSliverList({
    required this.controller,
    required this.itemBuilder,
    super.key,
  });

  final SteadyPagedController<T, K> controller;
  final SteadyPagedItemBuilder<T> itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (controller.value.status == SteadyPagedStatus.idle) {
      scheduleMicrotask(controller.loadInitial);
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.value;
        if (state.items.isEmpty && state.isBusy) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: SteadyDefaultLoadingView(),
          );
        }
        if (state.items.isEmpty && state.status == SteadyPagedStatus.error) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: SteadyDefaultErrorView(
              onRetry: () => unawaited(controller.retry()),
            ),
          );
        }
        if (state.items.isEmpty && state.status == SteadyPagedStatus.loaded) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: SteadyDefaultEmptyView(),
          );
        }
        return SliverList.builder(
          itemCount: state.items.length + (_showFooter(state) ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == state.items.length) {
              return _PagedFooter<T, K>(
                state: state,
                onRetry: () => unawaited(controller.loadMore()),
              );
            }
            if (index >= state.items.length - 3) {
              unawaited(controller.loadMore());
            }
            return itemBuilder(context, state.items[index], index);
          },
        );
      },
    );
  }

  bool _showFooter(SteadyPagedState<T, K> state) =>
      state.status == SteadyPagedStatus.loadingMore || state.appendError;
}

class _PagedFooter<T, K> extends StatelessWidget {
  const _PagedFooter({required this.state, required this.onRetry});

  final SteadyPagedState<T, K> state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.appendError) {
      return Center(
        child: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(SteadyMessages.resolve(context).retry),
        ),
      );
    }
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
