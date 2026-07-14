import 'package:flutter/foundation.dart';

import 'policy.dart';
import 'request.dart';

/// A complete, immutable representation of an asynchronous operation.
sealed class SteadyAsyncState<T> {
  const SteadyAsyncState();

  const factory SteadyAsyncState.idle() = SteadyIdle<T>;

  const factory SteadyAsyncState.loading({
    T? previousValue,
    bool hasPreviousValue,
    SteadyLoadingPhase phase,
    double? progress,
    DateTime? previousUpdatedAt,
    DateTime? lastAttemptAt,
    int attempt,
  }) = SteadyLoading<T>;

  const factory SteadyAsyncState.data(
    T value, {
    DateTime? updatedAt,
    DateTime? lastAttemptAt,
    int attempt,
    SteadyOperationKind? operation,
  }) = SteadyData<T>;

  const factory SteadyAsyncState.error(
    Object error, {
    StackTrace? stackTrace,
    T? previousValue,
    bool hasPreviousValue,
    SteadyFailure? failure,
    DateTime? previousUpdatedAt,
    DateTime? lastAttemptAt,
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

  DateTime? get lastUpdatedAt => switch (this) {
        SteadyData<T>(:final updatedAt) => updatedAt,
        SteadyLoading<T>(:final previousUpdatedAt) => previousUpdatedAt,
        SteadyError<T>(:final previousUpdatedAt) => previousUpdatedAt,
        _ => null,
      };

  DateTime? get lastAttemptAt => switch (this) {
        SteadyData<T>(:final lastAttemptAt) => lastAttemptAt,
        SteadyLoading<T>(:final lastAttemptAt) => lastAttemptAt,
        SteadyError<T>(:final lastAttemptAt) => lastAttemptAt,
        _ => null,
      };

  int get attempt => switch (this) {
        SteadyData<T>(:final attempt) => attempt,
        SteadyLoading<T>(:final attempt) => attempt,
        SteadyError<T>(failure: final failure) => failure?.attempt ?? 0,
        _ => 0,
      };

  SteadyOperationKind? get operationOrigin => switch (this) {
        SteadyData<T>(:final operation) => operation,
        SteadyLoading<T>(:final phase) => switch (phase) {
            SteadyLoadingPhase.initial => SteadyOperationKind.initialLoad,
            SteadyLoadingPhase.refresh => SteadyOperationKind.refresh,
            SteadyLoadingPhase.reload => SteadyOperationKind.reload,
          },
        SteadyError<T>(failure: final failure) => failure?.operation,
        _ => null,
      };

  bool isStale(Duration maximumAge, {DateTime? now}) {
    final updatedAt = lastUpdatedAt;
    if (updatedAt == null) return true;
    return (now ?? DateTime.now().toUtc()).toUtc().difference(updatedAt) >
        maximumAge;
  }

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
    this.previousUpdatedAt,
    this.lastAttemptAt,
    this.attempt = 1,
  }) : assert(progress == null || (progress >= 0 && progress <= 1));

  final T? previousValue;
  final bool hasPreviousValue;
  final SteadyLoadingPhase phase;
  final double? progress;
  final DateTime? previousUpdatedAt;
  @override
  final DateTime? lastAttemptAt;
  @override
  final int attempt;

  @override
  bool operator ==(Object other) =>
      other is SteadyLoading<T> &&
      other.previousValue == previousValue &&
      other.hasPreviousValue == hasPreviousValue &&
      other.phase == phase &&
      other.progress == progress &&
      other.previousUpdatedAt == previousUpdatedAt &&
      other.lastAttemptAt == lastAttemptAt &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(previousValue, hasPreviousValue, phase,
      progress, previousUpdatedAt, lastAttemptAt, attempt);
}

@immutable
final class SteadyData<T> extends SteadyAsyncState<T> {
  const SteadyData(
    this.value, {
    this.updatedAt,
    this.lastAttemptAt,
    this.attempt = 1,
    this.operation,
  });

  final T value;
  final DateTime? updatedAt;
  @override
  final DateTime? lastAttemptAt;
  @override
  final int attempt;
  final SteadyOperationKind? operation;

  @override
  bool operator ==(Object other) =>
      other is SteadyData<T> &&
      other.value == value &&
      other.updatedAt == updatedAt &&
      other.lastAttemptAt == lastAttemptAt &&
      other.attempt == attempt &&
      other.operation == operation;

  @override
  int get hashCode => Object.hash(
      SteadyData, value, updatedAt, lastAttemptAt, attempt, operation);
}

@immutable
final class SteadyError<T> extends SteadyAsyncState<T> {
  const SteadyError(
    this.error, {
    this.stackTrace,
    this.previousValue,
    this.hasPreviousValue = false,
    this.failure,
    this.previousUpdatedAt,
    this.lastAttemptAt,
  });

  final Object error;
  final StackTrace? stackTrace;
  final T? previousValue;
  final bool hasPreviousValue;
  final SteadyFailure? failure;
  final DateTime? previousUpdatedAt;
  @override
  final DateTime? lastAttemptAt;

  @override
  bool operator ==(Object other) =>
      other is SteadyError<T> &&
      other.error == error &&
      other.stackTrace == stackTrace &&
      other.previousValue == previousValue &&
      other.hasPreviousValue == hasPreviousValue &&
      other.failure == failure &&
      other.previousUpdatedAt == previousUpdatedAt &&
      other.lastAttemptAt == lastAttemptAt;

  @override
  int get hashCode => Object.hash(error, stackTrace, previousValue,
      hasPreviousValue, failure, previousUpdatedAt, lastAttemptAt);
}
