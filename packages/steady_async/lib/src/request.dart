import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Returns the current time for request metadata.
typedef SteadyClock = DateTime Function();

/// Identifies the work represented by a request or failure.
enum SteadyOperationKind { initialLoad, refresh, reload, append, action }

/// Immutable information about a failed request.
@immutable
class SteadyFailure {
  /// Creates complete machine-readable failure metadata.
  const SteadyFailure({
    required this.error,
    required this.stackTrace,
    required this.operation,
    required this.attempt,
    required this.occurredAt,
    this.automaticRetryEligible = false,
  });

  /// Wraps an externally supplied error that has no controller metadata.
  factory SteadyFailure.external(
    Object error, {
    StackTrace? stackTrace,
    SteadyOperationKind operation = SteadyOperationKind.initialLoad,
    DateTime? occurredAt,
  }) =>
      SteadyFailure(
        error: error,
        stackTrace: stackTrace ?? StackTrace.empty,
        operation: operation,
        attempt: 1,
        occurredAt: (occurredAt ?? DateTime.now()).toUtc(),
      );

  /// Raw error retained for application logic and custom builders.
  final Object error;

  /// Stack trace associated with [error].
  final StackTrace stackTrace;

  /// Request stage that failed.
  final SteadyOperationKind operation;

  /// One-based attempt number.
  final int attempt;

  /// UTC time at which the controller observed the failure.
  final DateTime occurredAt;

  /// Whether the configured policy scheduled another attempt.
  final bool automaticRetryEligible;

  /// Returns the same metadata with updated retry eligibility.
  SteadyFailure copyWith({bool? automaticRetryEligible}) => SteadyFailure(
        error: error,
        stackTrace: stackTrace,
        operation: operation,
        attempt: attempt,
        occurredAt: occurredAt,
        automaticRetryEligible:
            automaticRetryEligible ?? this.automaticRetryEligible,
      );
}

/// User-facing presentation returned by an application error mapper.
@immutable
class SteadyErrorPresentation {
  /// Creates user-facing error copy for package default widgets.
  const SteadyErrorPresentation({
    required this.message,
    this.retryLabel,
    this.semanticsLabel,
    this.showRetry = true,
  });

  /// Visible error message.
  final String message;

  /// Optional replacement for the localized retry label.
  final String? retryLabel;

  /// Optional accessibility announcement.
  final String? semanticsLabel;

  /// Whether package defaults expose a retry control.
  final bool showRetry;
}

/// Converts a raw failure into text and accessibility behavior for defaults.
typedef SteadyErrorMapper = SteadyErrorPresentation Function(
  BuildContext context,
  SteadyFailure failure,
);

/// Determines whether and when a failed request is automatically retried.
@immutable
class SteadyRetryPolicy {
  const SteadyRetryPolicy({
    this.maxAttempts = 1,
    this.delay = _zeroRetryDelay,
    this.shouldRetry = _retryEveryFailure,
  })  : _equalityKey = null,
        assert(maxAttempts >= 1);

  const SteadyRetryPolicy._({
    required this.maxAttempts,
    required this.delay,
    required this.shouldRetry,
    required Object equalityKey,
  })  : _equalityKey = equalityKey,
        assert(maxAttempts >= 1);

  /// Disables automatic retries.
  static const none = SteadyRetryPolicy();

  /// Creates a fixed-delay policy.
  factory SteadyRetryPolicy.fixed({
    required int maxAttempts,
    required Duration delay,
    bool Function(SteadyFailure failure) shouldRetry = _retryEveryFailure,
  }) =>
      SteadyRetryPolicy._(
        maxAttempts: maxAttempts,
        delay: (_, __) => delay,
        shouldRetry: shouldRetry,
        equalityKey: _FixedRetryKey(delay),
      );

  /// Creates an exponential policy whose first retry uses [initialDelay].
  factory SteadyRetryPolicy.exponential({
    required int maxAttempts,
    Duration initialDelay = const Duration(milliseconds: 250),
    double multiplier = 2,
    Duration maximumDelay = const Duration(seconds: 30),
    bool Function(SteadyFailure failure) shouldRetry = _retryEveryFailure,
  }) {
    assert(multiplier >= 1);
    return SteadyRetryPolicy._(
      maxAttempts: maxAttempts,
      shouldRetry: shouldRetry,
      equalityKey: _ExponentialRetryKey(
        initialDelay,
        multiplier,
        maximumDelay,
      ),
      delay: (nextAttempt, _) {
        final factor = math.pow(multiplier, math.max(0, nextAttempt - 2));
        final micros = math.min(
          maximumDelay.inMicroseconds,
          (initialDelay.inMicroseconds * factor).round(),
        );
        return Duration(microseconds: micros);
      },
    );
  }

  /// Total attempts, including the initial request.
  final int maxAttempts;

  /// Delay before `nextAttempt`, where the first retry is attempt two.
  final Duration Function(int nextAttempt, SteadyFailure failure) delay;

  /// Determines whether a particular failure may be retried automatically.
  final bool Function(SteadyFailure failure) shouldRetry;
  final Object? _equalityKey;

  @override
  bool operator ==(Object other) =>
      other is SteadyRetryPolicy &&
      other.maxAttempts == maxAttempts &&
      (_equalityKey == null && other._equalityKey == null
          ? identical(other.delay, delay)
          : _equalityKey != null && other._equalityKey == _equalityKey) &&
      identical(other.shouldRetry, shouldRetry);

  @override
  int get hashCode =>
      Object.hash(maxAttempts, _equalityKey ?? delay, shouldRetry);
}

class _FixedRetryKey {
  const _FixedRetryKey(this.delay);

  final Duration delay;

  @override
  bool operator ==(Object other) =>
      other is _FixedRetryKey && other.delay == delay;

  @override
  int get hashCode => delay.hashCode;
}

class _ExponentialRetryKey {
  const _ExponentialRetryKey(
    this.initialDelay,
    this.multiplier,
    this.maximumDelay,
  );

  final Duration initialDelay;
  final double multiplier;
  final Duration maximumDelay;

  @override
  bool operator ==(Object other) =>
      other is _ExponentialRetryKey &&
      other.initialDelay == initialDelay &&
      other.multiplier == multiplier &&
      other.maximumDelay == maximumDelay;

  @override
  int get hashCode => Object.hash(initialDelay, multiplier, maximumDelay);
}

Duration _zeroRetryDelay(int _, SteadyFailure __) => Duration.zero;
bool _retryEveryFailure(SteadyFailure _) => true;

/// Execution behavior shared by async, action, and pagination controllers.
@immutable
class SteadyRequestPolicy {
  /// Creates request execution policy; both features default to disabled.
  const SteadyRequestPolicy({
    this.retry = SteadyRetryPolicy.none,
    this.timeout,
  });

  /// Automatic retry configuration.
  final SteadyRetryPolicy retry;

  /// Per-attempt deadline, or null for no timeout.
  final Duration? timeout;

  @override
  bool operator ==(Object other) =>
      other is SteadyRequestPolicy &&
      other.retry == retry &&
      other.timeout == timeout;

  @override
  int get hashCode => Object.hash(retry, timeout);
}

/// Failure produced when an operation exceeds its configured timeout.
class SteadyTimeoutException implements Exception {
  /// Creates a timeout failure for [duration].
  const SteadyTimeoutException(this.duration);

  /// Deadline that the operation exceeded.
  final Duration duration;

  @override
  String toString() => 'SteadyTimeoutException: operation exceeded $duration.';
}

/// A Future paired with a real, idempotent cancellation callback.
class SteadyCancellableOperation<T> {
  /// Creates an operation paired with the underlying client's [cancel].
  SteadyCancellableOperation({
    required this.future,
    required VoidCallback cancel,
  }) : _cancel = cancel;

  /// Wraps an ordinary Future with a no-op cancellation callback.
  factory SteadyCancellableOperation.fromFuture(Future<T> future) =>
      SteadyCancellableOperation(future: future, cancel: _noop);

  /// Result produced if the operation finishes before cancellation.
  final Future<T> future;
  final VoidCallback _cancel;
  bool _cancelled = false;

  /// Whether [cancel] has already been invoked.
  bool get isCancelled => _cancelled;

  /// Invokes the supplied callback at most once.
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _cancel();
  }
}

void _noop() {}

/// Kinds of telemetry emitted by steady controllers.
enum SteadyLifecycleEventKind {
  started,
  retryScheduled,
  succeeded,
  failed,
  timedOut,
  cancelled,
  staleCompletion,
  sourceReplaced,
  optimisticApplied,
  optimisticCommitted,
  optimisticRolledBack,
}

/// Sanitized failure metadata safe to forward from an observer.
@immutable
class SteadyObservedFailure {
  /// Creates sanitized metadata without retaining the raw exception.
  const SteadyObservedFailure({
    required this.errorType,
    required this.operation,
    required this.attempt,
    required this.occurredAt,
    required this.automaticRetryEligible,
    required this.isTimeout,
  });

  /// Creates observer metadata from a controller failure.
  factory SteadyObservedFailure.fromFailure(SteadyFailure failure) =>
      SteadyObservedFailure(
        errorType: failure.error.runtimeType.toString(),
        operation: failure.operation,
        attempt: failure.attempt,
        occurredAt: failure.occurredAt,
        automaticRetryEligible: failure.automaticRetryEligible,
        isTimeout: failure.error is SteadyTimeoutException,
      );

  /// Runtime type name, without an exception message or fields.
  final String errorType;

  /// Request stage that failed.
  final SteadyOperationKind operation;

  /// One-based attempt number.
  final int attempt;

  /// UTC failure timestamp.
  final DateTime occurredAt;

  /// Whether another automatic attempt was scheduled.
  final bool automaticRetryEligible;

  /// Whether the configured per-attempt deadline elapsed.
  final bool isTimeout;
}

/// Payload-free lifecycle metadata suitable for logging and analytics.
@immutable
class SteadyLifecycleEvent {
  /// Creates payload-free request lifecycle metadata.
  const SteadyLifecycleEvent({
    required this.kind,
    required this.operationId,
    required this.controllerType,
    required this.operation,
    required this.attempt,
    required this.timestamp,
    this.label,
    this.elapsed,
    this.failure,
  });

  /// Stage represented by this event.
  final SteadyLifecycleEventKind kind;

  /// Controller-local request or transaction identifier.
  final int operationId;

  /// Stable controller family name such as `async`, `action`, or `pagination`.
  final String controllerType;

  /// Operation category.
  final SteadyOperationKind operation;

  /// One-based request attempt, or zero for transaction-only events.
  final int attempt;

  /// UTC time at which this event was emitted.
  final DateTime timestamp;

  /// Optional developer label configured on the controller.
  final String? label;

  /// Time elapsed since the request began.
  final Duration? elapsed;

  /// Failure metadata for failure, timeout, and retry events.
  final SteadyObservedFailure? failure;
}

/// Receives controller lifecycle metadata without observing loaded values.
abstract interface class SteadyObserver {
  /// Receives one payload-free lifecycle [event].
  void onEvent(SteadyLifecycleEvent event);
}

void notifySteadyObserver(
  SteadyObserver? observer,
  SteadyLifecycleEvent event,
) {
  if (observer == null) return;
  try {
    observer.onEvent(event);
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'steady_async',
        context: ErrorDescription('while notifying a SteadyObserver'),
      ),
    );
  }
}
