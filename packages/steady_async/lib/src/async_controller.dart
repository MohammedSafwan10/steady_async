import 'dart:async';

import 'package:flutter/foundation.dart';

import 'async_state.dart';
import 'policy.dart';

typedef SteadyLoader<T> = Future<T> Function();

/// Owns an async operation and prevents obsolete results from changing state.
class SteadyAsyncController<T> extends ChangeNotifier
    implements ValueListenable<SteadyAsyncState<T>> {
  SteadyAsyncController(
    SteadyLoader<T> loader, {
    SteadyAsyncState<T> initialState = const SteadyAsyncState.idle(),
  })  : _loader = loader,
        _value = initialState;

  SteadyLoader<T> _loader;
  SteadyAsyncState<T> _value;
  int _generation = 0;
  bool _disposed = false;
  SteadyLoadingPhase _lastPhase = SteadyLoadingPhase.initial;

  @override
  SteadyAsyncState<T> get value => _value;

  void updateLoader(SteadyLoader<T> loader) => _loader = loader;

  Future<void> load({
    SteadyLoadingPhase phase = SteadyLoadingPhase.initial,
  }) async {
    if (_disposed) return;
    _lastPhase = phase;
    final generation = ++_generation;
    final previous = _value.valueOrNull;
    final hasPrevious = _value.hasValue;
    _setValue(
      SteadyAsyncState<T>.loading(
        previousValue: previous,
        hasPreviousValue: hasPrevious,
        phase: phase,
      ),
    );

    try {
      final result = await Future<T>.sync(_loader);
      if (_accepts(generation)) _setValue(SteadyAsyncState<T>.data(result));
    } catch (error, stackTrace) {
      if (_accepts(generation)) {
        _setValue(
          SteadyAsyncState<T>.error(
            error,
            stackTrace: stackTrace,
            previousValue: previous,
            hasPreviousValue: hasPrevious,
          ),
        );
      }
    }
  }

  Future<void> refresh() => load(phase: SteadyLoadingPhase.refresh);
  Future<void> reload() => load(phase: SteadyLoadingPhase.reload);
  Future<void> retry() => load(phase: _lastPhase);

  /// Invalidates the current request without claiming to cancel its Future.
  void cancel({bool reset = false}) {
    _generation++;
    if (reset) this.reset();
  }

  void reset() {
    _generation++;
    _setValue(SteadyAsyncState<T>.idle());
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
      ),
    );
  }

  bool _accepts(int generation) => !_disposed && generation == _generation;

  void _setValue(SteadyAsyncState<T> next) {
    if (_disposed || next == _value) return;
    _value = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
