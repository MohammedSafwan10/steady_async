import 'dart:async';

import 'package:flutter/foundation.dart';

import 'async_state.dart';
import 'policy.dart';
import 'request.dart';
import 'request_engine.dart';

typedef SteadyLoader<T> = Future<T> Function();
typedef SteadyCancellableLoader<T> = SteadyCancellableOperation<T> Function();

/// Owns an async operation and prevents obsolete results from changing state.
class SteadyAsyncController<T> extends ChangeNotifier
    implements ValueListenable<SteadyAsyncState<T>> {
  SteadyAsyncController(
    SteadyLoader<T> loader, {
    SteadyAsyncState<T> initialState = const SteadyAsyncState.idle(),
    this.requestPolicy = const SteadyRequestPolicy(),
    this.observer,
    this.operationLabel,
    SteadyClock? clock,
  })  : _loader = loader,
        _cancellableLoader = null,
        _value = initialState,
        _clock = clock ?? DateTime.now;

  SteadyAsyncController.cancellable(
    SteadyCancellableLoader<T> loader, {
    SteadyAsyncState<T> initialState = const SteadyAsyncState.idle(),
    this.requestPolicy = const SteadyRequestPolicy(),
    this.observer,
    this.operationLabel,
    SteadyClock? clock,
  })  : _loader = null,
        _cancellableLoader = loader,
        _value = initialState,
        _clock = clock ?? DateTime.now;

  SteadyLoader<T>? _loader;
  SteadyCancellableLoader<T>? _cancellableLoader;
  SteadyAsyncState<T> _value;
  final SteadyClock _clock;
  final SteadyRequestPolicy requestPolicy;
  final SteadyObserver? observer;
  final String? operationLabel;
  int _generation = 0;
  int _operationId = 0;
  bool _disposed = false;
  bool _transitioning = false;
  bool _invalidating = false;
  SteadyLoadingPhase _lastPhase = SteadyLoadingPhase.initial;
  SteadyRequestRunner<T>? _activeRunner;

  @override
  SteadyAsyncState<T> get value => _value;

  void updateLoader(SteadyLoader<T> loader) {
    if (_disposed) return;
    _loader = loader;
    _cancellableLoader = null;
  }

  void updateCancellableLoader(SteadyCancellableLoader<T> loader) {
    if (_disposed) return;
    _cancellableLoader = loader;
    _loader = null;
  }

  Future<void> load({
    SteadyLoadingPhase phase = SteadyLoadingPhase.initial,
  }) async {
    if (_disposed || _transitioning) return;
    _transitioning = true;
    late final int generation;
    late final T? previous;
    late final bool hasPrevious;
    late final DateTime? previousUpdatedAt;
    SteadyRequestRunner<T>? runner;
    try {
      final previousRunner = _activeRunner;
      _activeRunner = null;
      generation = ++_generation;
      previousRunner?.cancel();
      if (!_accepts(generation)) return;

      _lastPhase = phase;
      previous = _value.valueOrNull;
      hasPrevious = _value.hasValue;
      previousUpdatedAt = _value.lastUpdatedAt;
      final cancellableLoader = _cancellableLoader;
      final loader = _loader;
      final operationFactory = cancellableLoader ??
          () => steadyOperationFromFuture<T>(Future<T>.sync(loader!));
      _setValue(
        SteadyAsyncState<T>.loading(
          previousValue: previous,
          hasPreviousValue: hasPrevious,
          phase: phase,
          previousUpdatedAt: previousUpdatedAt,
          lastAttemptAt: _now(),
        ),
      );
      if (!_accepts(generation)) return;

      runner = SteadyRequestRunner<T>(
        operationId: ++_operationId,
        controllerType: 'async',
        operation: _operationFor(phase),
        factory: operationFactory,
        policy: requestPolicy,
        clock: _clock,
        observer: observer,
        label: operationLabel,
        onAttempt: (attempt, startedAt) {
          if (!_accepts(generation)) return;
          final current = _value;
          if (current is! SteadyLoading<T>) return;
          _setValue(
            SteadyAsyncState<T>.loading(
              previousValue: current.previousValue,
              hasPreviousValue: current.hasPreviousValue,
              phase: current.phase,
              progress: current.progress,
              previousUpdatedAt: current.previousUpdatedAt,
              lastAttemptAt: startedAt,
              attempt: attempt,
            ),
          );
        },
      );
      _activeRunner = runner;
    } finally {
      _transitioning = false;
    }
    final execution = await runner.run();
    if (identical(_activeRunner, runner)) _activeRunner = null;
    if (!_accepts(generation)) return;
    switch (execution) {
      case SteadyExecutionSuccess<T>(:final value, :final completedAt):
        _setValue(
          SteadyAsyncState<T>.data(
            value,
            updatedAt: completedAt,
            lastAttemptAt: _value.lastAttemptAt,
            attempt: runner.attempt,
            operation: _operationFor(phase),
          ),
        );
      case SteadyExecutionFailure<T>(:final failure):
        _setValue(
          SteadyAsyncState<T>.error(
            failure.error,
            stackTrace: failure.stackTrace,
            previousValue: previous,
            hasPreviousValue: hasPrevious,
            failure: failure,
            previousUpdatedAt: previousUpdatedAt,
            lastAttemptAt: failure.occurredAt,
          ),
        );
      case SteadyExecutionCancelled<T>():
        break;
    }
  }

  Future<void> refresh() => load(phase: SteadyLoadingPhase.refresh);
  Future<void> reload() => load(phase: SteadyLoadingPhase.reload);
  Future<void> retry() => load(phase: _lastPhase);

  /// Invalidates the current request and cancels it when a real callback exists.
  ///
  /// When a request is loading, the controller returns to its retained data or
  /// to idle. This prevents an ignored completion from leaving the public state
  /// permanently stuck in loading.
  void cancel({bool reset = false}) {
    if (_disposed || _invalidating) return;
    final wasTransitioning = _transitioning;
    _invalidating = true;
    _transitioning = true;
    try {
      final runner = _activeRunner;
      _activeRunner = null;
      _generation++;
      runner?.cancel();
      if (_disposed) return;
      if (reset) {
        _setValue(SteadyAsyncState<T>.idle());
        return;
      }
      final current = _value;
      if (current is SteadyLoading<T>) {
        _setValue(
          current.hasPreviousValue
              ? SteadyAsyncState<T>.data(
                  current.previousValue as T,
                  updatedAt: current.previousUpdatedAt,
                  lastAttemptAt: current.lastAttemptAt,
                  attempt: current.attempt,
                  operation: _operationFor(current.phase),
                )
              : SteadyAsyncState<T>.idle(),
        );
      }
    } finally {
      _transitioning = wasTransitioning;
      _invalidating = false;
    }
  }

  void reset() {
    cancel(reset: true);
  }

  void setProgress(double progress) {
    final current = _value;
    if (current is! SteadyLoading<T>) return;
    _setValue(
      SteadyAsyncState<T>.loading(
        previousValue: current.previousValue,
        hasPreviousValue: current.hasPreviousValue,
        phase: current.phase,
        progress: progress.clamp(0, 1),
        previousUpdatedAt: current.previousUpdatedAt,
        lastAttemptAt: current.lastAttemptAt,
        attempt: current.attempt,
      ),
    );
  }

  SteadyOperationKind _operationFor(SteadyLoadingPhase phase) =>
      switch (phase) {
        SteadyLoadingPhase.initial => SteadyOperationKind.initialLoad,
        SteadyLoadingPhase.refresh => SteadyOperationKind.refresh,
        SteadyLoadingPhase.reload => SteadyOperationKind.reload,
      };

  DateTime _now() => _clock().toUtc();

  bool _accepts(int generation) => !_disposed && generation == _generation;

  void _setValue(SteadyAsyncState<T> next) {
    if (_disposed || next == _value) return;
    _value = next;
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
    super.dispose();
  }
}
