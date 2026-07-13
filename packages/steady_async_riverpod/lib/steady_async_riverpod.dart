/// Riverpod 3 adapters for steady_async.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:steady_async/steady_async.dart';

extension SteadyAsyncValueX<T> on AsyncValue<T> {
  /// Converts Riverpod state without losing previous data or loading intent.
  SteadyAsyncState<T> toSteadyState() {
    final hasPrevious = hasValue;
    final previous = hasPrevious ? value : null;
    if (isLoading) {
      final rawProgress = progress;
      final normalizedProgress = rawProgress?.toDouble().clamp(0.0, 1.0);
      return SteadyAsyncState<T>.loading(
        previousValue: previous,
        hasPreviousValue: hasPrevious,
        phase:
            isRefreshing
                ? SteadyLoadingPhase.refresh
                : isReloading
                ? SteadyLoadingPhase.reload
                : SteadyLoadingPhase.initial,
        progress: normalizedProgress,
      );
    }
    if (hasError) {
      return SteadyAsyncState<T>.error(
        error!,
        stackTrace: stackTrace,
        previousValue: previous,
        hasPreviousValue: hasPrevious,
      );
    }
    if (hasValue) return SteadyAsyncState<T>.data(value as T);
    return SteadyAsyncState<T>.idle();
  }
}

/// Renders a Riverpod [AsyncValue] through steady_async timing and defaults.
class SteadyRiverpodView<T> extends StatelessWidget {
  /// Creates a steady view for a Riverpod [AsyncValue].
  const SteadyRiverpodView({
    required this.value,
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

  /// Riverpod state to translate and render.
  final AsyncValue<T> value;

  /// Builds accepted data.
  final SteadyDataBuilder<T> dataBuilder;

  /// Invalidates or retries the application provider.
  final VoidCallback? onRetry;

  /// Optional loading UI override.
  final SteadyLoadingBuilder<T>? loadingBuilder;

  /// Optional empty UI override.
  final WidgetBuilder? emptyBuilder;

  /// Optional error UI override.
  final SteadyErrorBuilder<T>? errorBuilder;

  /// Optional idle UI override.
  final WidgetBuilder? idleBuilder;

  /// Application-specific empty predicate.
  final bool Function(T value)? isEmpty;

  /// Optional transition policy override.
  final SteadyTransitionPolicy? policy;

  @override
  Widget build(BuildContext context) => SteadyStateView<T>(
    state: value.toSteadyState(),
    dataBuilder: dataBuilder,
    onRetry: onRetry,
    loadingBuilder: loadingBuilder,
    emptyBuilder: emptyBuilder,
    errorBuilder: errorBuilder,
    idleBuilder: idleBuilder,
    isEmpty: isEmpty,
    policy: policy,
  );
}
