/// BLoC and Cubit adapters for steady_async.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steady_async/steady_async.dart';

/// Selects a core async state from application-owned BLoC state.
typedef SteadyBlocStateSelector<S, T> = SteadyAsyncState<T> Function(S state);

/// Selects async state from any BLoC or Cubit without requiring base classes.
class SteadyBlocView<B extends StateStreamable<S>, S, T>
    extends StatelessWidget {
  /// Creates a view using [BlocSelector] for efficient rebuilds.
  const SteadyBlocView({
    required this.selector,
    required this.dataBuilder,
    this.bloc,
    this.onRetry,
    this.loadingBuilder,
    this.emptyBuilder,
    this.errorBuilder,
    this.idleBuilder,
    this.isEmpty,
    this.policy,
    super.key,
  }) : buildWhen = null;

  /// Uses [BlocBuilder] when an application needs custom rebuild filtering.
  const SteadyBlocView.withBuildWhen({
    required this.selector,
    required this.dataBuilder,
    required BlocBuilderCondition<S> this.buildWhen,
    this.bloc,
    this.onRetry,
    this.loadingBuilder,
    this.emptyBuilder,
    this.errorBuilder,
    this.idleBuilder,
    this.isEmpty,
    this.policy,
    super.key,
  });

  /// Optional BLoC/Cubit instance; otherwise the nearest provider is used.
  final B? bloc;

  /// Maps application state into [SteadyAsyncState].
  final SteadyBlocStateSelector<S, T> selector;

  /// Optional application-specific rebuild filter.
  final BlocBuilderCondition<S>? buildWhen;

  /// Builds accepted data.
  final SteadyDataBuilder<T> dataBuilder;

  /// Dispatches the application's retry event or Cubit method.
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

  Widget _view(BuildContext context, SteadyAsyncState<T> state) =>
      SteadyStateView<T>(
        state: state,
        dataBuilder: dataBuilder,
        onRetry: onRetry,
        loadingBuilder: loadingBuilder,
        emptyBuilder: emptyBuilder,
        errorBuilder: errorBuilder,
        idleBuilder: idleBuilder,
        isEmpty: isEmpty,
        policy: policy,
      );

  @override
  Widget build(BuildContext context) {
    final condition = buildWhen;
    if (condition != null) {
      return BlocBuilder<B, S>(
        bloc: bloc,
        buildWhen: condition,
        builder: (context, state) => _view(context, selector(state)),
      );
    }
    return BlocSelector<B, S, SteadyAsyncState<T>>(
      bloc: bloc,
      selector: selector,
      builder: _view,
    );
  }
}
