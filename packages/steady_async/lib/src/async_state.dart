import 'package:flutter/foundation.dart';

import 'policy.dart';

/// A complete, immutable representation of an asynchronous operation.
sealed class SteadyAsyncState<T> {
  const SteadyAsyncState();

  const factory SteadyAsyncState.idle() = SteadyIdle<T>;

  const factory SteadyAsyncState.loading({
    T? previousValue,
    bool hasPreviousValue,
    SteadyLoadingPhase phase,
    double? progress,
  }) = SteadyLoading<T>;

  const factory SteadyAsyncState.data(T value) = SteadyData<T>;

  const factory SteadyAsyncState.error(
    Object error, {
    StackTrace? stackTrace,
    T? previousValue,
    bool hasPreviousValue,
  }) = SteadyError<T>;

  bool get isIdle => this is SteadyIdle<T>;
  bool get isLoading => this is SteadyLoading<T>;
  bool get hasError => this is SteadyError<T>;

  bool get hasValue => switch (this) {
        SteadyData<T>() => true,
        SteadyLoading<T>(:final hasPreviousValue) => hasPreviousValue,
        SteadyError<T>(:final hasPreviousValue) => hasPreviousValue,
        _ => false,
      };

  T? get valueOrNull => switch (this) {
        SteadyData<T>(:final value) => value,
        SteadyLoading<T>(:final previousValue) => previousValue,
        SteadyError<T>(:final previousValue) => previousValue,
        _ => null,
      };

  R when<R>({
    required R Function() idle,
    required R Function(SteadyLoading<T> state) loading,
    required R Function(T value) data,
    required R Function(SteadyError<T> state) error,
  }) =>
      switch (this) {
        SteadyIdle<T>() => idle(),
        final SteadyLoading<T> state => loading(state),
        SteadyData<T>(:final value) => data(value),
        final SteadyError<T> state => error(state),
      };
}

@immutable
final class SteadyIdle<T> extends SteadyAsyncState<T> {
  const SteadyIdle();

  @override
  bool operator ==(Object other) => other is SteadyIdle<T>;

  @override
  int get hashCode => Object.hash(SteadyIdle, T);
}

@immutable
final class SteadyLoading<T> extends SteadyAsyncState<T> {
  const SteadyLoading({
    this.previousValue,
    this.hasPreviousValue = false,
    this.phase = SteadyLoadingPhase.initial,
    this.progress,
  }) : assert(progress == null || (progress >= 0 && progress <= 1));

  final T? previousValue;
  final bool hasPreviousValue;
  final SteadyLoadingPhase phase;
  final double? progress;

  @override
  bool operator ==(Object other) =>
      other is SteadyLoading<T> &&
      other.previousValue == previousValue &&
      other.hasPreviousValue == hasPreviousValue &&
      other.phase == phase &&
      other.progress == progress;

  @override
  int get hashCode =>
      Object.hash(previousValue, hasPreviousValue, phase, progress);
}

@immutable
final class SteadyData<T> extends SteadyAsyncState<T> {
  const SteadyData(this.value);

  final T value;

  @override
  bool operator ==(Object other) =>
      other is SteadyData<T> && other.value == value;

  @override
  int get hashCode => Object.hash(SteadyData, value);
}

@immutable
final class SteadyError<T> extends SteadyAsyncState<T> {
  const SteadyError(
    this.error, {
    this.stackTrace,
    this.previousValue,
    this.hasPreviousValue = false,
  });

  final Object error;
  final StackTrace? stackTrace;
  final T? previousValue;
  final bool hasPreviousValue;

  @override
  bool operator ==(Object other) =>
      other is SteadyError<T> &&
      other.error == error &&
      other.stackTrace == stackTrace &&
      other.previousValue == previousValue &&
      other.hasPreviousValue == hasPreviousValue;

  @override
  int get hashCode =>
      Object.hash(error, stackTrace, previousValue, hasPreviousValue);
}
