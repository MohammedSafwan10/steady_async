import 'dart:async';

import 'package:flutter/foundation.dart';

import 'request.dart';

typedef SteadyOperationFactory<T> = SteadyCancellableOperation<T> Function();

sealed class SteadyExecution<T> {
  const SteadyExecution();
}

final class SteadyExecutionSuccess<T> extends SteadyExecution<T> {
  const SteadyExecutionSuccess(this.value, this.completedAt);

  final T value;
  final DateTime completedAt;
}

final class SteadyExecutionFailure<T> extends SteadyExecution<T> {
  const SteadyExecutionFailure(this.failure);

  final SteadyFailure failure;
}

final class SteadyExecutionCancelled<T> extends SteadyExecution<T> {
  const SteadyExecutionCancelled();
}

class SteadyRequestRunner<T> {
  SteadyRequestRunner({
    required this.operationId,
    required this.controllerType,
    required this.operation,
    required SteadyOperationFactory<T> factory,
    required this.policy,
    required this.clock,
    this.observer,
    this.label,
    this.onAttempt,
  }) : _factory = factory;

  final int operationId;
  final String controllerType;
  final SteadyOperationKind operation;
  final SteadyOperationFactory<T> _factory;
  final SteadyRequestPolicy policy;
  final SteadyClock clock;
  final SteadyObserver? observer;
  final String? label;
  final void Function(int attempt, DateTime startedAt)? onAttempt;

  final Completer<void> _cancelSignal = Completer<void>();
  final Completer<void> _stopRetrySignal = Completer<void>();
  SteadyCancellableOperation<T>? _active;
  _AttemptGuard? _guard;
  bool _cancelled = false;
  bool _stopAfterCurrent = false;
  bool _cancelEventSent = false;
  int _attempt = 0;
  late final DateTime _startedAt = _now();

  int get attempt => _attempt;
  bool get isCancelled => _cancelled;

  Future<SteadyExecution<T>> run() async {
    while (!_cancelled) {
      _attempt++;
      onAttempt?.call(_attempt, _now());
      _emit(SteadyLifecycleEventKind.started);
      final outcome = await _runAttempt();
      if (outcome is _AttemptCancelled<T>) {
        return SteadyExecutionCancelled<T>();
      }
      if (outcome is _AttemptSuccess<T>) {
        final completedAt = _now();
        _emit(SteadyLifecycleEventKind.succeeded);
        return SteadyExecutionSuccess<T>(outcome.value, completedAt);
      }

      final failed = outcome as _AttemptFailure<T>;
      var failure = failed.failure;
      final retryable = !_stopAfterCurrent &&
          _attempt < policy.retry.maxAttempts &&
          _safeShouldRetry(policy.retry, failure);
      failure = failure.copyWith(automaticRetryEligible: retryable);
      _emit(
        failure.error is SteadyTimeoutException
            ? SteadyLifecycleEventKind.timedOut
            : SteadyLifecycleEventKind.failed,
        failure: failure,
      );
      if (!retryable) return SteadyExecutionFailure<T>(failure);

      final nextAttempt = _attempt + 1;
      final delay = _safeDelay(policy.retry, nextAttempt, failure);
      _emit(SteadyLifecycleEventKind.retryScheduled, failure: failure);
      if (!await _wait(delay)) {
        if (_stopAfterCurrent) _emitCancelledOnce();
        return SteadyExecutionCancelled<T>();
      }
    }
    return SteadyExecutionCancelled<T>();
  }

  Future<_AttemptOutcome<T>> _runAttempt() async {
    if (_cancelled) return _AttemptCancelled<T>();
    SteadyCancellableOperation<T> operation;
    try {
      operation = _factory();
    } catch (error, stackTrace) {
      return _AttemptFailure<T>(_failure(error, stackTrace));
    }

    _active = operation;
    final guard = _AttemptGuard();
    _guard = guard;
    final completion = operation.future
        .then<_AttemptOutcome<T>>(
      (value) => _AttemptSuccess<T>(value),
      onError: (Object error, StackTrace stackTrace) =>
          _AttemptFailure<T>(_failure(error, stackTrace)),
    )
        .then((outcome) {
      if (guard.obsolete) {
        _emit(SteadyLifecycleEventKind.staleCompletion);
      }
      return outcome;
    });

    Timer? timeoutTimer;
    final candidates = <Future<_AttemptOutcome<T>>>[
      completion,
      _cancelSignal.future.then((_) => _AttemptCancelled<T>()),
    ];
    final timeout = policy.timeout;
    if (timeout != null) {
      final timeoutCompleter = Completer<_AttemptOutcome<T>>();
      timeoutTimer = Timer(timeout, () {
        guard.obsolete = true;
        timeoutCompleter.complete(
          _AttemptFailure<T>(
            _failure(SteadyTimeoutException(timeout), StackTrace.current),
          ),
        );
        _cancelActive();
      });
      candidates.add(timeoutCompleter.future);
    }

    final outcome = await Future.any(candidates);
    timeoutTimer?.cancel();
    if (outcome is _AttemptCancelled<T>) guard.obsolete = true;
    if (identical(_active, operation)) _active = null;
    if (identical(_guard, guard)) _guard = null;
    return outcome;
  }

  bool _safeShouldRetry(SteadyRetryPolicy retry, SteadyFailure failure) {
    try {
      return retry.shouldRetry(failure);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stackTrace),
      );
      return false;
    }
  }

  Duration _safeDelay(
    SteadyRetryPolicy retry,
    int nextAttempt,
    SteadyFailure failure,
  ) {
    try {
      final delay = retry.delay(nextAttempt, failure);
      return delay < Duration.zero ? Duration.zero : delay;
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stackTrace),
      );
      return Duration.zero;
    }
  }

  Future<bool> _wait(Duration delay) async {
    if (_cancelled) return false;
    if (delay == Duration.zero) {
      await Future<void>.delayed(Duration.zero);
      return !_cancelled && !_stopAfterCurrent;
    }
    final timerCompleter = Completer<bool>();
    final timer = Timer(delay, () => timerCompleter.complete(true));
    final completed = await Future.any<bool>([
      timerCompleter.future,
      _cancelSignal.future.then((_) => false),
      _stopRetrySignal.future.then((_) => false),
    ]);
    timer.cancel();
    return completed && !_cancelled && !_stopAfterCurrent;
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _guard?.obsolete = true;
    _cancelActive();
    if (!_cancelSignal.isCompleted) _cancelSignal.complete();
    _emitCancelledOnce();
  }

  /// Stops retries while allowing an active non-cancellable attempt to finish.
  void stopAfterCurrent() {
    if (_cancelled || _stopAfterCurrent) return;
    _stopAfterCurrent = true;
    if (!_stopRetrySignal.isCompleted) _stopRetrySignal.complete();
  }

  void _emitCancelledOnce() {
    if (_cancelEventSent) return;
    _cancelEventSent = true;
    _emit(SteadyLifecycleEventKind.cancelled);
  }

  void _cancelActive() {
    final active = _active;
    if (active == null) return;
    try {
      active.cancel();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stackTrace),
      );
    }
  }

  SteadyFailure _failure(Object error, StackTrace stackTrace) => SteadyFailure(
        error: error,
        stackTrace: stackTrace,
        operation: operation,
        attempt: _attempt,
        occurredAt: _now(),
      );

  DateTime _now() => clock().toUtc();

  void _emit(
    SteadyLifecycleEventKind kind, {
    SteadyFailure? failure,
  }) =>
      notifySteadyObserver(
        observer,
        SteadyLifecycleEvent(
          kind: kind,
          operationId: operationId,
          controllerType: controllerType,
          operation: operation,
          attempt: _attempt,
          timestamp: _now(),
          label: label,
          elapsed: _now().difference(_startedAt),
          failure: failure == null
              ? null
              : SteadyObservedFailure.fromFailure(failure),
        ),
      );
}

class _AttemptGuard {
  bool obsolete = false;
}

sealed class _AttemptOutcome<T> {
  const _AttemptOutcome();
}

final class _AttemptSuccess<T> extends _AttemptOutcome<T> {
  const _AttemptSuccess(this.value);
  final T value;
}

final class _AttemptFailure<T> extends _AttemptOutcome<T> {
  const _AttemptFailure(this.failure);
  final SteadyFailure failure;
}

final class _AttemptCancelled<T> extends _AttemptOutcome<T> {
  const _AttemptCancelled();
}
