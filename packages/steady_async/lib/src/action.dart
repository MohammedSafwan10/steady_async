import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'localization.dart';
import 'optimistic.dart';
import 'request.dart';
import 'request_engine.dart';
import 'theme.dart';

/// Visible stages of an asynchronous action.
enum SteadyActionStatus { idle, running, success, error }

/// Determines how calls made while an action is running are handled.
enum SteadyActionConcurrency { drop, latestWins, sequential }

/// Immutable state for a submit, save, delete, or similar async action.
@immutable
class SteadyActionState<T> {
  const SteadyActionState._({
    required this.status,
    this.value,
    this.error,
    this.stackTrace,
    this.failure,
    this.lastAttemptAt,
    this.completedAt,
    this.attempt = 0,
  });

  const SteadyActionState.idle() : this._(status: SteadyActionStatus.idle);
  const SteadyActionState.running({DateTime? lastAttemptAt, int attempt = 1})
      : this._(
          status: SteadyActionStatus.running,
          lastAttemptAt: lastAttemptAt,
          attempt: attempt,
        );
  const SteadyActionState.success(
    T value, {
    DateTime? completedAt,
    DateTime? lastAttemptAt,
    int attempt = 1,
  }) : this._(
          status: SteadyActionStatus.success,
          value: value,
          completedAt: completedAt,
          lastAttemptAt: lastAttemptAt,
          attempt: attempt,
        );
  const SteadyActionState.error(
    Object error, [
    StackTrace? stackTrace,
    SteadyFailure? failure,
  ]) : this._(
          status: SteadyActionStatus.error,
          error: error,
          stackTrace: stackTrace,
          failure: failure,
        );

  /// Creates an error state with complete request metadata.
  SteadyActionState.failure(
    SteadyFailure failure, {
    DateTime? lastAttemptAt,
  }) : this._(
          status: SteadyActionStatus.error,
          error: failure.error,
          stackTrace: failure.stackTrace,
          failure: failure,
          lastAttemptAt: lastAttemptAt ?? failure.occurredAt,
          attempt: failure.attempt,
        );

  /// The current action stage.
  final SteadyActionStatus status;

  /// The most recent successful result.
  final T? value;

  /// The most recent failure.
  final Object? error;

  /// Stack trace associated with [error].
  final StackTrace? stackTrace;
  final SteadyFailure? failure;
  final DateTime? lastAttemptAt;
  final DateTime? completedAt;
  final int attempt;

  /// Timestamp of the most recently accepted successful action.
  DateTime? get lastUpdatedAt => completedAt;

  /// Kind of operation that produced [failure], when the state failed.
  SteadyOperationKind? get failureOrigin => failure?.operation;

  /// Calculates whether the last successful result is older than [maximumAge].
  bool isStale(Duration maximumAge, {DateTime? now}) {
    final updatedAt = lastUpdatedAt;
    if (updatedAt == null) return true;
    return (now ?? DateTime.now().toUtc()).toUtc().difference(updatedAt) >
        maximumAge;
  }

  /// Whether work is currently in progress.
  bool get isRunning => status == SteadyActionStatus.running;

  /// Whether the action completed successfully.
  bool get isSuccess => status == SteadyActionStatus.success;

  /// Whether the last accepted call failed.
  bool get hasError => status == SteadyActionStatus.error;
}

/// A retry-safe factory for an asynchronous action.
typedef SteadyAction<T> = Future<T> Function();
typedef SteadyCancellableAction<T> = SteadyCancellableOperation<T> Function();

/// Runs actions with duplicate-call protection and stale-result guards.
class SteadyActionController<T> extends ChangeNotifier
    implements ValueListenable<SteadyActionState<T>> {
  /// Creates a controller for [action].
  SteadyActionController(
    SteadyAction<T> action, {
    this.concurrency = SteadyActionConcurrency.drop,
    this.successVisibleDuration = const Duration(milliseconds: 800),
    this.requestPolicy = const SteadyRequestPolicy(),
    this.observer,
    this.operationLabel,
    SteadyClock? clock,
  })  : _action = action,
        _cancellableAction = null,
        _clock = clock ?? DateTime.now;

  SteadyActionController.cancellable(
    SteadyCancellableAction<T> action, {
    this.concurrency = SteadyActionConcurrency.drop,
    this.successVisibleDuration = const Duration(milliseconds: 800),
    this.requestPolicy = const SteadyRequestPolicy(),
    this.observer,
    this.operationLabel,
    SteadyClock? clock,
  })  : _action = null,
        _cancellableAction = action,
        _clock = clock ?? DateTime.now;

  SteadyAction<T>? _action;
  SteadyCancellableAction<T>? _cancellableAction;
  final SteadyActionConcurrency concurrency;
  final Duration successVisibleDuration;
  final SteadyRequestPolicy requestPolicy;
  final SteadyObserver? observer;
  final String? operationLabel;
  final SteadyClock _clock;
  SteadyActionState<T> _value = const SteadyActionState.idle();
  Future<void> _queue = Future<void>.value();
  Timer? _successTimer;
  int _generation = 0;
  int _operationId = 0;
  bool _disposed = false;
  bool _transitioning = false;
  bool _invalidating = false;
  final Map<SteadyRequestRunner<T>, _RunningAction<T>> _activeRunners = {};
  final Set<_QueuedAction<T>> _queuedActions = {};

  /// The latest public action state.
  @override
  SteadyActionState<T> get value => _value;

  /// Replaces the factory used by future calls.
  void updateAction(SteadyAction<T> action) {
    if (_disposed) return;
    _action = action;
    _cancellableAction = null;
  }

  void updateCancellableAction(SteadyCancellableAction<T> action) {
    if (_disposed) return;
    _cancellableAction = action;
    _action = null;
  }

  /// Runs or schedules the action according to [concurrency].
  Future<T?> run() => _run(null, null);

  /// Runs the action and resolves [mutation] from the actual action outcome.
  Future<T?> runOptimistic(SteadyOptimisticHandle mutation) {
    if (!mutation.isPending) {
      throw StateError('runOptimistic requires a pending optimistic handle.');
    }
    return _run(mutation, ++_operationId);
  }

  Future<T?> _run(
    SteadyOptimisticHandle? mutation,
    int? transactionId,
  ) {
    if (_disposed || _transitioning) {
      _activateMutation(mutation, transactionId);
      if (mutation?.rollback() ?? false) {
        _emitOptimistic(
          SteadyLifecycleEventKind.optimisticRolledBack,
          transactionId!,
        );
      }
      return Future<T?>.value();
    }
    if (concurrency == SteadyActionConcurrency.drop && _value.isRunning) {
      _activateMutation(mutation, transactionId);
      if (mutation?.rollback() ?? false) {
        _emitOptimistic(
          SteadyLifecycleEventKind.optimisticRolledBack,
          transactionId!,
        );
      }
      return Future<T?>.value();
    }
    if (concurrency == SteadyActionConcurrency.sequential) {
      final queued = _QueuedAction<T>(mutation, transactionId);
      _queuedActions.add(queued);
      _queue = _queue.then((_) async {
        if (queued.isCancelled) return;
        _queuedActions.remove(queued);
        if (!_activateMutation(mutation, transactionId)) {
          queued.complete(null);
          return;
        }
        try {
          queued.complete(await _execute(mutation, transactionId));
        } catch (error, stackTrace) {
          queued.completeError(error, stackTrace);
        }
      });
      return queued.future;
    }
    if (concurrency == SteadyActionConcurrency.latestWins) {
      _transitioning = true;
      try {
        _stopActiveRunners(rollbackOptimistic: true);
      } finally {
        _transitioning = false;
      }
    }
    if (!_activateMutation(mutation, transactionId)) {
      return Future<T?>.value();
    }
    return _execute(mutation, transactionId);
  }

  bool _activateMutation(
    SteadyOptimisticHandle? mutation,
    int? transactionId,
  ) {
    if (mutation == null) return true;
    if (!mutation.isApplied && !mutation.activate()) return false;
    _emitOptimistic(
      SteadyLifecycleEventKind.optimisticApplied,
      transactionId!,
    );
    return true;
  }

  Future<T?> _execute(
    SteadyOptimisticHandle? mutation,
    int? transactionId,
  ) async {
    if (_disposed || _transitioning) {
      if (mutation?.rollback() ?? false) {
        _emitOptimistic(
          SteadyLifecycleEventKind.optimisticRolledBack,
          transactionId!,
        );
      }
      return null;
    }
    _transitioning = true;
    late final int generation;
    late final SteadyRequestRunner<T> runner;
    try {
      _successTimer?.cancel();
      generation = ++_generation;
      final action = _action;
      final cancellableAction = _cancellableAction;
      _setValue(
        SteadyActionState<T>.running(lastAttemptAt: _now()),
      );
      if (!_accepts(generation)) {
        if (mutation?.rollback() ?? false) {
          _emitOptimistic(
            SteadyLifecycleEventKind.optimisticRolledBack,
            transactionId!,
          );
        }
        return null;
      }
      runner = SteadyRequestRunner<T>(
        operationId: ++_operationId,
        controllerType: 'action',
        operation: SteadyOperationKind.action,
        factory: cancellableAction ??
            () => steadyOperationFromFuture<T>(Future<T>.sync(action!)),
        policy: requestPolicy,
        clock: _clock,
        observer: observer,
        label: operationLabel,
        onAttempt: (attempt, startedAt) {
          if (_accepts(generation)) {
            _setValue(
              SteadyActionState<T>.running(
                lastAttemptAt: startedAt,
                attempt: attempt,
              ),
            );
          }
        },
      );
      _activeRunners[runner] = _RunningAction<T>(
        cancellable: cancellableAction != null,
        mutation: mutation,
        transactionId: transactionId,
      );
    } finally {
      _transitioning = false;
    }
    final execution = await runner.run();
    _activeRunners.remove(runner);
    switch (execution) {
      case SteadyExecutionSuccess<T>(:final value, :final completedAt):
        if (mutation?.commit() ?? false) {
          _emitOptimistic(
            SteadyLifecycleEventKind.optimisticCommitted,
            transactionId!,
          );
        }
        if (!_accepts(generation)) return value;
        _setValue(
          SteadyActionState<T>.success(
            value,
            completedAt: completedAt,
            lastAttemptAt: _value.lastAttemptAt,
            attempt: runner.attempt,
          ),
        );
        if (successVisibleDuration > Duration.zero) {
          _successTimer = Timer(successVisibleDuration, () {
            if (_accepts(generation) && _value.isSuccess) reset();
          });
        }
        return value;
      case SteadyExecutionFailure<T>(:final failure):
        if (mutation?.rollback() ?? false) {
          _emitOptimistic(
            SteadyLifecycleEventKind.optimisticRolledBack,
            transactionId!,
          );
        }
        if (_accepts(generation)) {
          _setValue(
            SteadyActionState<T>.failure(
              failure,
              lastAttemptAt: _value.lastAttemptAt,
            ),
          );
        }
        return null;
      case SteadyExecutionCancelled<T>():
        if (mutation?.rollback() ?? false) {
          _emitOptimistic(
            SteadyLifecycleEventKind.optimisticRolledBack,
            transactionId!,
          );
        }
        return null;
    }
  }

  /// Returns to idle and invalidates results from active calls.
  void reset() {
    if (_disposed || _invalidating) return;
    final wasTransitioning = _transitioning;
    _invalidating = true;
    _transitioning = true;
    try {
      _successTimer?.cancel();
      _successTimer = null;
      _generation++;
      _stopActiveRunners(rollbackOptimistic: true);
      _cancelQueuedActions();
      _setValue(SteadyActionState<T>.idle());
    } finally {
      _transitioning = wasTransitioning;
      _invalidating = false;
    }
  }

  bool _accepts(int generation) => !_disposed && generation == _generation;

  void _stopActiveRunners({bool rollbackOptimistic = false}) {
    for (final entry in _activeRunners.entries.toList()) {
      final running = entry.value;
      if (rollbackOptimistic && (running.mutation?.rollback() ?? false)) {
        _emitOptimistic(
          SteadyLifecycleEventKind.optimisticRolledBack,
          running.transactionId!,
        );
      }
      if (running.cancellable) {
        entry.key.cancel();
      } else {
        entry.key.stopAfterCurrent();
      }
    }
  }

  void _cancelQueuedActions() {
    for (final queued in _queuedActions.toList().reversed) {
      if (queued.cancel()) {
        final transactionId = queued.transactionId;
        final mutation = queued.mutation;
        final resolved = mutation == null
            ? false
            : mutation.isApplied
                ? mutation.rollback()
                : mutation.invalidate();
        if (resolved && mutation.status == SteadyOptimisticStatus.rolledBack) {
          _emitOptimistic(
            SteadyLifecycleEventKind.optimisticRolledBack,
            transactionId!,
          );
        }
      }
    }
    _queuedActions.clear();
  }

  DateTime _now() => _clock().toUtc();

  void _emitOptimistic(
    SteadyLifecycleEventKind kind,
    int transactionId,
  ) =>
      notifySteadyObserver(
        observer,
        SteadyLifecycleEvent(
          kind: kind,
          operationId: transactionId,
          controllerType: 'action',
          operation: SteadyOperationKind.action,
          attempt: 0,
          timestamp: _now(),
          label: operationLabel,
        ),
      );

  void _setValue(SteadyActionState<T> next) {
    if (_disposed) return;
    _value = next;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _successTimer?.cancel();
    _disposed = true;
    _generation++;
    _stopActiveRunners();
    _cancelQueuedActions();
    super.dispose();
  }
}

class _RunningAction<T> {
  const _RunningAction({
    required this.cancellable,
    required this.mutation,
    required this.transactionId,
  });

  final bool cancellable;
  final SteadyOptimisticHandle? mutation;
  final int? transactionId;
}

class _QueuedAction<T> {
  _QueuedAction(this.mutation, this.transactionId);

  final SteadyOptimisticHandle? mutation;
  final int? transactionId;
  final Completer<T?> _completer = Completer<T?>();
  bool isCancelled = false;

  Future<T?> get future => _completer.future;

  bool cancel() {
    if (isCancelled || _completer.isCompleted) return false;
    isCancelled = true;
    _completer.complete(null);
    return true;
  }

  void complete(T? value) {
    if (!_completer.isCompleted) _completer.complete(value);
  }

  void completeError(Object error, StackTrace stackTrace) {
    if (!_completer.isCompleted) _completer.completeError(error, stackTrace);
  }
}

/// Builds UI from an action state and a function that starts the action.
typedef SteadyActionWidgetBuilder<T> = Widget Function(
  BuildContext context,
  SteadyActionState<T> state,
  Future<T?> Function() run,
);

/// Stateful convenience widget for an asynchronous action.
class SteadyActionBuilder<T> extends StatefulWidget {
  /// Creates an action builder.
  const SteadyActionBuilder({
    required this.action,
    required this.builder,
    this.controller,
    this.concurrency = SteadyActionConcurrency.drop,
    this.successVisibleDuration,
    this.requestPolicy = const SteadyRequestPolicy(),
    this.observer,
    this.operationLabel,
    super.key,
  }) : cancellableAction = null;

  SteadyActionBuilder.cancellable({
    required SteadyCancellableAction<T> action,
    required this.builder,
    this.controller,
    this.concurrency = SteadyActionConcurrency.drop,
    this.successVisibleDuration,
    this.requestPolicy = const SteadyRequestPolicy(),
    this.observer,
    this.operationLabel,
    super.key,
  })  : cancellableAction = action,
        action = (() => action().future);

  /// Retry-safe action factory.
  final SteadyAction<T> action;
  final SteadyCancellableAction<T>? cancellableAction;

  /// Builds the action UI.
  final SteadyActionWidgetBuilder<T> builder;

  /// Optional externally owned controller.
  final SteadyActionController<T>? controller;

  /// Policy applied to overlapping calls.
  final SteadyActionConcurrency concurrency;

  /// Time that success UI remains visible before resetting.
  final Duration? successVisibleDuration;
  final SteadyRequestPolicy requestPolicy;
  final SteadyObserver? observer;
  final String? operationLabel;

  @override
  State<SteadyActionBuilder<T>> createState() => _SteadyActionBuilderState<T>();
}

class _SteadyActionBuilderState<T> extends State<SteadyActionBuilder<T>> {
  late SteadyActionController<T> _controller;
  late bool _ownsController;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    _ownsController = widget.controller == null;
    final cancellable = widget.cancellableAction;
    _controller = widget.controller ??
        (cancellable == null
            ? SteadyActionController<T>(
                widget.action,
                concurrency: widget.concurrency,
                successVisibleDuration: widget.successVisibleDuration ??
                    const Duration(milliseconds: 800),
                requestPolicy: widget.requestPolicy,
                observer: widget.observer,
                operationLabel: widget.operationLabel,
              )
            : SteadyActionController<T>.cancellable(
                cancellable,
                concurrency: widget.concurrency,
                successVisibleDuration: widget.successVisibleDuration ??
                    const Duration(milliseconds: 800),
                requestPolicy: widget.requestPolicy,
                observer: widget.observer,
                operationLabel: widget.operationLabel,
              ));
    if (cancellable == null) {
      _controller.updateAction(widget.action);
    } else {
      _controller.updateCancellableAction(cancellable);
    }
  }

  @override
  void didUpdateWidget(covariant SteadyActionBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controllerChanged = oldWidget.controller != widget.controller;
    final ownedConfigurationChanged = _ownsController &&
        (oldWidget.concurrency != widget.concurrency ||
            oldWidget.successVisibleDuration != widget.successVisibleDuration);
    final ownedRequestConfigurationChanged = _ownsController &&
        (oldWidget.requestPolicy != widget.requestPolicy ||
            oldWidget.observer != widget.observer ||
            oldWidget.operationLabel != widget.operationLabel);
    if (controllerChanged ||
        ownedConfigurationChanged ||
        ownedRequestConfigurationChanged) {
      if (_ownsController) _controller.dispose();
      _attach();
    } else {
      final cancellable = widget.cancellableAction;
      if (cancellable == null) {
        _controller.updateAction(widget.action);
      } else {
        _controller.updateCancellableAction(cancellable);
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<SteadyActionState<T>>(
        valueListenable: _controller,
        builder: (context, state, _) =>
            widget.builder(context, state, _controller.run),
      );

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }
}

/// Material button with automatic running, success, and retry states.
class SteadyButton<T> extends StatelessWidget {
  /// Creates a steady action button.
  const SteadyButton({
    required this.action,
    required this.child,
    this.controller,
    this.successChild,
    this.errorChild,
    this.icon,
    this.concurrency = SteadyActionConcurrency.drop,
    this.style,
    this.requestPolicy = const SteadyRequestPolicy(),
    this.observer,
    this.operationLabel,
    super.key,
  }) : cancellableAction = null;

  SteadyButton.cancellable({
    required SteadyCancellableAction<T> action,
    required this.child,
    this.controller,
    this.successChild,
    this.errorChild,
    this.icon,
    this.concurrency = SteadyActionConcurrency.drop,
    this.style,
    this.requestPolicy = const SteadyRequestPolicy(),
    this.observer,
    this.operationLabel,
    super.key,
  })  : cancellableAction = action,
        action = (() => action().future);

  /// Retry-safe callback invoked by the button.
  final SteadyAction<T> action;
  final SteadyCancellableAction<T>? cancellableAction;

  /// Idle button content.
  final Widget child;

  /// Optional externally owned action controller.
  final SteadyActionController<T>? controller;

  /// Content shown after success.
  final Widget? successChild;

  /// Content shown after failure.
  final Widget? errorChild;

  /// Optional leading icon while idle.
  final Widget? icon;

  /// Policy applied to repeated taps.
  final SteadyActionConcurrency concurrency;

  /// Optional Material button style.
  final ButtonStyle? style;
  final SteadyRequestPolicy requestPolicy;
  final SteadyObserver? observer;
  final String? operationLabel;

  @override
  Widget build(BuildContext context) {
    Widget builder(
      BuildContext context,
      SteadyActionState<T> state,
      Future<T?> Function() run,
    ) {
      final steadyTheme = SteadyTheme.of(context);
      final messages = steadyTheme.messages ?? SteadyMessages.resolve(context);
      final failure = state.failure ??
          (state.error == null
              ? null
              : SteadyFailure.external(
                  state.error!,
                  stackTrace: state.stackTrace,
                  operation: SteadyOperationKind.action,
                ));
      final presentation = failure == null
          ? null
          : steadyTheme.errorMapper?.call(context, failure);
      final content = switch (state.status) {
        SteadyActionStatus.idle => child,
        SteadyActionStatus.running => const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        SteadyActionStatus.success => successChild ??
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check, size: 18),
                const SizedBox(width: 8),
                Text(messages.success),
              ],
            ),
        SteadyActionStatus.error => errorChild ??
            (presentation?.showRetry ?? true
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh, size: 18),
                      const SizedBox(width: 8),
                      Text(presentation?.retryLabel ?? messages.retry),
                    ],
                  )
                : Text(presentation?.message ?? messages.error)),
      };
      return Semantics(
        liveRegion: true,
        button: true,
        label: presentation?.semanticsLabel,
        child: FilledButton.icon(
          style: style,
          onPressed: (state.isRunning &&
                      concurrency == SteadyActionConcurrency.drop) ||
                  (state.hasError && !(presentation?.showRetry ?? true))
              ? null
              : () => unawaited(run()),
          icon: state.status == SteadyActionStatus.idle
              ? icon ?? const SizedBox.shrink()
              : const SizedBox.shrink(),
          label: AnimatedSwitcher(
            duration: MediaQuery.maybeOf(context)?.disableAnimations ?? false
                ? Duration.zero
                : const Duration(milliseconds: 160),
            child: KeyedSubtree(key: ValueKey(state.status), child: content),
          ),
        ),
      );
    }

    final cancellable = cancellableAction;
    if (cancellable != null) {
      return SteadyActionBuilder<T>.cancellable(
        action: cancellable,
        controller: controller,
        concurrency: concurrency,
        successVisibleDuration: SteadyTheme.of(context).successVisibleDuration,
        requestPolicy: requestPolicy,
        observer: observer,
        operationLabel: operationLabel,
        builder: builder,
      );
    }
    return SteadyActionBuilder<T>(
      action: action,
      controller: controller,
      concurrency: concurrency,
      successVisibleDuration: SteadyTheme.of(context).successVisibleDuration,
      requestPolicy: requestPolicy,
      observer: observer,
      operationLabel: operationLabel,
      builder: builder,
    );
  }
}
