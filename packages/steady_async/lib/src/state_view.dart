import 'dart:async';

import 'package:flutter/material.dart';

import 'async_state.dart';
import 'localization.dart';
import 'policy.dart';
import 'theme.dart';

typedef SteadyDataBuilder<T> = Widget Function(BuildContext context, T value);
typedef SteadyLoadingBuilder<T> = Widget Function(
    BuildContext context, SteadyLoading<T> state);
typedef SteadyErrorBuilder<T> = Widget Function(
  BuildContext context,
  SteadyError<T> state,
  VoidCallback? retry,
);

/// Renders explicit async state while applying perception-aware timing.
class SteadyStateView<T> extends StatefulWidget {
  const SteadyStateView({
    required this.state,
    required this.dataBuilder,
    this.onRetry,
    this.loadingBuilder,
    this.emptyBuilder,
    this.errorBuilder,
    this.idleBuilder,
    this.isEmpty,
    this.policy,
    super.key,
  });

  final SteadyAsyncState<T> state;
  final SteadyDataBuilder<T> dataBuilder;
  final VoidCallback? onRetry;
  final SteadyLoadingBuilder<T>? loadingBuilder;
  final WidgetBuilder? emptyBuilder;
  final SteadyErrorBuilder<T>? errorBuilder;
  final WidgetBuilder? idleBuilder;
  final bool Function(T value)? isEmpty;
  final SteadyTransitionPolicy? policy;

  @override
  State<SteadyStateView<T>> createState() => _SteadyStateViewState<T>();
}

class _SteadyStateViewState<T> extends State<SteadyStateView<T>> {
  late SteadyAsyncState<T> _visibleState;
  late SteadyTransitionPolicy _appliedPolicy;
  bool _initialized = false;
  bool _suppressTransition = false;
  int _visibleRevision = 0;
  Timer? _delayTimer;
  Timer? _minimumTimer;
  DateTime? _loadingShownAt;

  SteadyTransitionPolicy get _policy =>
      widget.policy ?? SteadyTheme.of(context).policy;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final policy = _policy;
    if (!_initialized) {
      _initialized = true;
      _appliedPolicy = policy;
      _visibleState = widget.state is SteadyLoading<T>
          ? _fallbackFor(widget.state as SteadyLoading<T>)
          : widget.state;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.state is SteadyLoading<T>) {
          _handleState(widget.state);
        }
      });
      return;
    }
    if (!_samePolicy(_appliedPolicy, policy)) {
      _appliedPolicy = policy;
      _handleState(widget.state, restartLoadingDelay: true);
    }
  }

  @override
  void didUpdateWidget(covariant SteadyStateView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final policy = _policy;
    final policyChanged = !_samePolicy(_appliedPolicy, policy);
    if (policyChanged) _appliedPolicy = policy;
    if (oldWidget.state != widget.state || policyChanged) {
      _handleState(widget.state, restartLoadingDelay: policyChanged);
    }
  }

  bool _samePolicy(
    SteadyTransitionPolicy first,
    SteadyTransitionPolicy second,
  ) =>
      first.loadingDelay == second.loadingDelay &&
      first.minimumLoadingDuration == second.minimumLoadingDuration &&
      first.transitionDuration == second.transitionDuration &&
      first.keepPreviousData == second.keepPreviousData &&
      first.stabilizeLayout == second.stabilizeLayout;

  SteadyAsyncState<T> _fallbackFor(SteadyLoading<T> loading) {
    if (_policy.keepPreviousData && loading.hasPreviousValue) {
      return SteadyAsyncState<T>.data(loading.previousValue as T);
    }
    return SteadyAsyncState<T>.idle();
  }

  void _handleState(
    SteadyAsyncState<T> incoming, {
    bool restartLoadingDelay = false,
  }) {
    if (incoming is SteadyLoading<T>) {
      final delayPending = _delayTimer?.isActive ?? false;
      if (restartLoadingDelay) _delayTimer?.cancel();
      _suppressTransition = !_policy.keepPreviousData;
      final visibleLoading = _policy.keepPreviousData
          ? incoming
          : SteadyLoading<T>(
              phase: incoming.phase, progress: incoming.progress);
      _minimumTimer?.cancel();
      if (_visibleState is SteadyLoading<T>) {
        _delayTimer?.cancel();
        _setVisibleState(visibleLoading);
        return;
      }
      final fallback = _fallbackFor(incoming);
      _setVisibleState(fallback);
      if (delayPending && !restartLoadingDelay) return;
      final delay = _policy.loadingDelay;
      if (delay == Duration.zero) {
        _showLoading(visibleLoading);
      } else {
        _delayTimer = Timer(delay, () {
          if (mounted && widget.state is SteadyLoading<T>) {
            final latest = widget.state as SteadyLoading<T>;
            _showLoading(
              _policy.keepPreviousData
                  ? latest
                  : SteadyLoading<T>(
                      phase: latest.phase,
                      progress: latest.progress,
                    ),
            );
          }
        });
      }
      return;
    }

    _delayTimer?.cancel();
    _suppressTransition = false;
    if (_visibleState is SteadyLoading<T> && _loadingShownAt != null) {
      final elapsed = DateTime.now().difference(_loadingShownAt!);
      final remaining = _policy.minimumLoadingDuration - elapsed;
      if (remaining > Duration.zero) {
        _minimumTimer?.cancel();
        _minimumTimer = Timer(remaining, () {
          if (mounted) _setVisibleState(widget.state);
        });
        return;
      }
    }
    _loadingShownAt = null;
    _setVisibleState(incoming);
  }

  void _showLoading(SteadyLoading<T> loading) {
    _loadingShownAt = DateTime.now();
    _suppressTransition = false;
    _setVisibleState(loading);
  }

  void _setVisibleState(SteadyAsyncState<T> state) {
    if (_visibleState == state) return;
    setState(() {
      _visibleState = state;
      _visibleRevision++;
    });
  }

  bool _isEmpty(T value) {
    final predicate = widget.isEmpty;
    if (predicate != null) return predicate(value);
    return switch (value) {
      final Iterable<Object?> items => items.isEmpty,
      final Map<Object?, Object?> map => map.isEmpty,
      final String text => text.isEmpty,
      _ => false,
    };
  }

  Widget _buildVisible(BuildContext context) {
    final state = _visibleState;
    return switch (state) {
      SteadyIdle<T>() =>
        widget.idleBuilder?.call(context) ?? const SizedBox.shrink(),
      final SteadyLoading<T> loading =>
        widget.loadingBuilder?.call(context, loading) ??
            _DefaultLoadingView<T>(
              state: loading,
              dataBuilder: widget.dataBuilder,
            ),
      SteadyData<T>(:final value) => _isEmpty(value)
          ? widget.emptyBuilder?.call(context) ?? const SteadyDefaultEmptyView()
          : widget.dataBuilder(context, value),
      final SteadyError<T> error =>
        widget.errorBuilder?.call(context, error, widget.onRetry) ??
            _DefaultErrorView<T>(
              state: error,
              dataBuilder: widget.dataBuilder,
              onRetry: widget.onRetry,
            ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    final disableAnimations = media?.disableAnimations ?? false;
    final duration = disableAnimations || _suppressTransition
        ? Duration.zero
        : _policy.transitionDuration;
    final child = KeyedSubtree(
      key: ValueKey<int>(_visibleRevision),
      child: _buildVisible(context),
    );
    final switched = AnimatedSwitcher(duration: duration, child: child);
    if (!_policy.stabilizeLayout || duration == Duration.zero) return switched;
    return AnimatedSize(duration: duration, child: switched);
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _minimumTimer?.cancel();
    super.dispose();
  }
}

class _DefaultLoadingView<T> extends StatelessWidget {
  const _DefaultLoadingView({required this.state, required this.dataBuilder});

  final SteadyLoading<T> state;
  final SteadyDataBuilder<T> dataBuilder;

  @override
  Widget build(BuildContext context) {
    if (state.hasPreviousValue) {
      return Stack(
        children: [
          dataBuilder(context, state.previousValue as T),
          Positioned.fill(
            child: Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(value: state.progress),
            ),
          ),
        ],
      );
    }
    return SteadyDefaultLoadingView(progress: state.progress);
  }
}

class SteadyDefaultLoadingView extends StatelessWidget {
  const SteadyDefaultLoadingView({this.progress, super.key});

  final double? progress;

  @override
  Widget build(BuildContext context) {
    final steadyTheme = SteadyTheme.of(context);
    final messages = steadyTheme.messages ?? SteadyMessages.resolve(context);
    return Semantics(
      liveRegion: true,
      label: messages.loading,
      child: Center(
        child: SizedBox.square(
          dimension: steadyTheme.indicatorSize,
          child: CircularProgressIndicator(
            value: progress,
            color: steadyTheme.accentColor,
            strokeWidth: 3,
          ),
        ),
      ),
    );
  }
}

class SteadyDefaultEmptyView extends StatelessWidget {
  const SteadyDefaultEmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    final messages =
        SteadyTheme.of(context).messages ?? SteadyMessages.resolve(context);
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 42, color: colors.outline),
            const SizedBox(height: 12),
            Text(messages.empty, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _DefaultErrorView<T> extends StatelessWidget {
  const _DefaultErrorView({
    required this.state,
    required this.dataBuilder,
    required this.onRetry,
  });

  final SteadyError<T> state;
  final SteadyDataBuilder<T> dataBuilder;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (!state.hasPreviousValue) {
      return SteadyDefaultErrorView(onRetry: onRetry);
    }
    final messages =
        SteadyTheme.of(context).messages ?? SteadyMessages.resolve(context);
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        dataBuilder(context, state.previousValue as T),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined),
                  const SizedBox(width: 8),
                  Flexible(child: Text(messages.error)),
                  if (onRetry != null)
                    TextButton(
                      onPressed: onRetry,
                      child: Text(messages.retry),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class SteadyDefaultErrorView extends StatelessWidget {
  const SteadyDefaultErrorView({this.onRetry, super.key});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final messages =
        SteadyTheme.of(context).messages ?? SteadyMessages.resolve(context);
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 42, color: colors.error),
            const SizedBox(height: 12),
            Text(messages.error, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(messages.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
