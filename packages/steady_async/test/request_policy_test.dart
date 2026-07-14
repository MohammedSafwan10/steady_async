import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_async/steady_async.dart';

void main() {
  test('fixed and exponential retry policies are structurally comparable', () {
    final fixedA = SteadyRetryPolicy.fixed(
      maxAttempts: 3,
      delay: const Duration(milliseconds: 50),
    );
    final fixedB = SteadyRetryPolicy.fixed(
      maxAttempts: 3,
      delay: const Duration(milliseconds: 50),
    );
    final exponentialA = SteadyRetryPolicy.exponential(maxAttempts: 4);
    final exponentialB = SteadyRetryPolicy.exponential(maxAttempts: 4);

    expect(fixedA, fixedB);
    expect(fixedA.hashCode, fixedB.hashCode);
    expect(exponentialA, exponentialB);
    expect(exponentialA.hashCode, exponentialB.hashCode);
  });

  test('async controller retries eligible failures', () async {
    var calls = 0;
    final controller = SteadyAsyncController<int>(
      () async {
        calls++;
        if (calls < 3) throw StateError('temporary');
        return 7;
      },
      requestPolicy: SteadyRequestPolicy(
        retry: SteadyRetryPolicy.fixed(
          maxAttempts: 3,
          delay: Duration.zero,
        ),
      ),
    );

    await controller.load();

    expect(calls, 3);
    expect(controller.value.valueOrNull, 7);
    controller.dispose();
  });

  test('timeout cancels a cancellable operation exactly once', () async {
    var cancellations = 0;
    final never = Completer<int>();
    final controller = SteadyAsyncController<int>.cancellable(
      () => SteadyCancellableOperation<int>(
        future: never.future,
        cancel: () => cancellations++,
      ),
      requestPolicy: const SteadyRequestPolicy(
        timeout: Duration(milliseconds: 5),
      ),
    );

    await controller.load();
    controller.cancel();

    final error = controller.value as SteadyError<int>;
    expect(error.error, isA<SteadyTimeoutException>());
    expect(error.failure?.operation, SteadyOperationKind.initialLoad);
    expect(cancellations, 1);
    controller.dispose();
  });

  test('cancel during retry delay completes without another attempt', () async {
    var calls = 0;
    final controller = SteadyAsyncController<int>(
      () async {
        calls++;
        throw StateError('offline');
      },
      requestPolicy: SteadyRequestPolicy(
        retry: SteadyRetryPolicy.fixed(
          maxAttempts: 3,
          delay: const Duration(seconds: 1),
        ),
      ),
    );

    final load = controller.load();
    await Future<void>.delayed(Duration.zero);
    controller.cancel();
    await load;

    expect(calls, 1);
    expect(controller.value, isA<SteadyIdle<int>>());
    controller.dispose();
  });

  test('ordinary action disposal stops retries after the active attempt',
      () async {
    var calls = 0;
    final first = Completer<void>();
    final controller = SteadyActionController<void>(
      () {
        calls++;
        return first.future;
      },
      requestPolicy: SteadyRequestPolicy(
        retry: SteadyRetryPolicy.fixed(
          maxAttempts: 3,
          delay: Duration.zero,
        ),
      ),
    );

    final run = controller.run();
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    first.completeError(StateError('failed'));
    await run;

    expect(calls, 1);
  });

  test('ordinary action reset during backoff stops later attempts', () async {
    var calls = 0;
    final controller = SteadyActionController<void>(
      () async {
        calls++;
        throw StateError('failed');
      },
      requestPolicy: SteadyRequestPolicy(
        retry: SteadyRetryPolicy.fixed(
          maxAttempts: 3,
          delay: const Duration(seconds: 1),
        ),
      ),
    );

    final run = controller.run();
    await Future<void>.delayed(Duration.zero);
    controller.reset();
    await run;

    expect(calls, 1);
    expect(controller.value.status, SteadyActionStatus.idle);
    controller.dispose();
  });

  test('retry cannot cross a stop fired at the timer completion boundary',
      () async {
    var calls = 0;
    var stoppedAtBoundary = false;
    final observer = _RecordingObserver();
    late SteadyActionController<void> controller;
    const retryDelay = Duration(milliseconds: 5);

    await runZoned(
      () async {
        controller = SteadyActionController<void>(
          () async {
            calls++;
            throw StateError('failed');
          },
          observer: observer,
          successVisibleDuration: Duration.zero,
          requestPolicy: SteadyRequestPolicy(
            retry: SteadyRetryPolicy.fixed(
              maxAttempts: 3,
              delay: retryDelay,
            ),
          ),
        );

        await controller.run();
      },
      zoneSpecification: ZoneSpecification(
        createTimer: (self, parent, zone, duration, callback) {
          return parent.createTimer(zone, duration, () {
            callback();
            if (!stoppedAtBoundary && duration == retryDelay) {
              stoppedAtBoundary = true;
              controller.reset();
            }
          });
        },
      ),
    );

    expect(stoppedAtBoundary, isTrue);
    expect(calls, 1);
    expect(observer.events.last.kind, SteadyLifecycleEventKind.cancelled);
    expect(controller.value.status, SteadyActionStatus.idle);
    controller.dispose();
  });

  test('latest-wins stops retries without faking Future cancellation',
      () async {
    final old = Completer<int>();
    final current = Completer<int>();
    var calls = 0;
    final controller = SteadyActionController<int>(
      () => calls++ == 0 ? old.future : current.future,
      concurrency: SteadyActionConcurrency.latestWins,
      successVisibleDuration: Duration.zero,
      requestPolicy: SteadyRequestPolicy(
        retry: SteadyRetryPolicy.fixed(
          maxAttempts: 2,
          delay: Duration.zero,
        ),
      ),
    );

    final firstRun = controller.run();
    final secondRun = controller.run();
    current.complete(2);
    await secondRun;
    old.completeError(StateError('old failure'));
    await firstRun;

    expect(calls, 2);
    expect(controller.value.value, 2);
    controller.dispose();
  });

  test('observer receives ordered request metadata', () async {
    final observer = _RecordingObserver();
    final controller = SteadyAsyncController<int>(
      () async => 1,
      observer: observer,
      operationLabel: 'users',
    );

    await controller.load();

    expect(
      observer.events.map((event) => event.kind),
      [SteadyLifecycleEventKind.started, SteadyLifecycleEventKind.succeeded],
    );
    expect(observer.events.every((event) => event.label == 'users'), isTrue);
    controller.dispose();
  });

  test('observer receives retry attempts without changing request outcome',
      () async {
    final observer = _RecordingObserver();
    var calls = 0;
    final controller = SteadyAsyncController<int>(
      () async {
        if (calls++ == 0) throw StateError('temporary');
        return 9;
      },
      observer: observer,
      requestPolicy: SteadyRequestPolicy(
        retry: SteadyRetryPolicy.fixed(
          maxAttempts: 2,
          delay: Duration.zero,
        ),
      ),
    );

    await controller.load();

    expect(
      observer.events.map((event) => event.kind),
      [
        SteadyLifecycleEventKind.started,
        SteadyLifecycleEventKind.failed,
        SteadyLifecycleEventKind.retryScheduled,
        SteadyLifecycleEventKind.started,
        SteadyLifecycleEventKind.succeeded,
      ],
    );
    expect(observer.events.map((event) => event.attempt), [1, 1, 1, 2, 2]);
    expect(observer.events.map((event) => event.operationId).toSet(), {1});
    expect(controller.value.valueOrNull, 9);
    controller.dispose();
  });

  test('observer failure metadata excludes raw error messages', () async {
    final observer = _RecordingObserver();
    final controller = SteadyAsyncController<int>(
      () async => throw const _SecretError('token=private'),
      observer: observer,
    );

    await controller.load();

    final observed = observer.events
        .firstWhere((event) => event.kind == SteadyLifecycleEventKind.failed)
        .failure!;
    expect(observed.errorType, '_SecretError');
    expect(observed.errorType, isNot(contains('private')));
    expect(controller.value, isA<SteadyError<int>>());
    expect((controller.value as SteadyError<int>).error.toString(),
        contains('private'));
    controller.dispose();
  });

  test('observer exceptions are reported but cannot fail the request',
      () async {
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);
    final controller = SteadyAsyncController<int>(
      () async => 4,
      observer: _ThrowingObserver(),
    );

    await controller.load();

    expect(controller.value.valueOrNull, 4);
    expect(reported, isNotEmpty);
    controller.dispose();
  });

  test('optimistic action commits on success and rolls back on failure',
      () async {
    var value = 0;
    var fail = false;
    final observer = _RecordingObserver();
    final controller = SteadyActionController<void>(() async {
      if (fail) throw StateError('failed');
    }, successVisibleDuration: Duration.zero, observer: observer);

    SteadyOptimisticHandle mutation() => SteadyOptimisticHandle.apply(
          apply: () => value++,
          rollback: () => value--,
        );

    await controller.runOptimistic(mutation());
    expect(value, 1);

    fail = true;
    await controller.runOptimistic(mutation());
    expect(value, 1);
    final optimisticEvents = observer.events
        .where((event) => event.kind.name.startsWith('optimistic'))
        .toList();
    expect(optimisticEvents, hasLength(4));
    expect(optimisticEvents[0].operationId, optimisticEvents[1].operationId);
    expect(optimisticEvents[2].operationId, optimisticEvents[3].operationId);
    controller.dispose();
  });

  test('drop policy immediately rolls back the operation that never starts',
      () async {
    final running = Completer<void>();
    var applied = 0;
    final controller = SteadyActionController<void>(() => running.future);
    final first = controller.run();
    final dropped = SteadyOptimisticHandle.apply(
      apply: () => applied++,
      rollback: () => applied--,
    );

    await controller.runOptimistic(dropped);

    expect(applied, 0);
    expect(dropped.status, SteadyOptimisticStatus.rolledBack);
    running.complete();
    await first;
    controller.dispose();
  });

  test('disposing sequential action invalidates deferred queued handles',
      () async {
    final firstResult = Completer<void>();
    var applied = 0;
    final controller = SteadyActionController<void>(
      () => firstResult.future,
      concurrency: SteadyActionConcurrency.sequential,
      successVisibleDuration: Duration.zero,
    );
    final firstRun = controller.run();
    await Future<void>.delayed(Duration.zero);
    final queuedMutation = SteadyOptimisticHandle.apply(
      apply: () => applied++,
      rollback: () => applied--,
    );
    final queuedRun = controller.runOptimistic(queuedMutation);
    final queuedCompleted = queuedRun.then((_) => true);

    controller.dispose();

    expect(await queuedCompleted, isTrue);
    expect(queuedMutation.status, SteadyOptimisticStatus.invalidated);
    expect(applied, 0);
    firstResult.complete();
    await firstRun;
  });

  test('optimistic actions reject an already resolved handle', () async {
    var applied = 0;
    final mutation = SteadyOptimisticHandle.apply(
      apply: () => applied++,
      rollback: () => applied--,
    );
    expect(mutation.rollback(), isTrue);
    final controller = SteadyActionController<void>(() async {});

    expect(
      () => controller.runOptimistic(mutation),
      throwsA(isA<StateError>()),
    );
    expect(applied, 0);
    controller.dispose();
  });

  test('latest-wins rolls back the old mutation before applying the new one',
      () async {
    final firstResult = Completer<int>();
    final secondResult = Completer<int>();
    var calls = 0;
    var visible = 0;
    final controller = SteadyActionController<int>(
      () => calls++ == 0 ? firstResult.future : secondResult.future,
      concurrency: SteadyActionConcurrency.latestWins,
      successVisibleDuration: Duration.zero,
    );
    SteadyOptimisticHandle mutation(int next) {
      final previous = visible;
      return SteadyOptimisticHandle.apply(
        apply: () => visible = next,
        rollback: () => visible = previous,
      );
    }

    final firstMutation = mutation(1);
    final secondMutation = mutation(2);

    final first = controller.runOptimistic(firstMutation);
    final second = controller.runOptimistic(secondMutation);
    secondResult.complete(2);
    await second;
    firstResult.complete(1);
    await first;

    expect(firstMutation.status, SteadyOptimisticStatus.rolledBack);
    expect(secondMutation.status, SteadyOptimisticStatus.committed);
    expect(visible, 2);
    expect(controller.value.value, 2);
    controller.dispose();
  });

  test('cancellable action timeout rolls back and cancels once', () async {
    var value = 0;
    var cancelled = 0;
    final never = Completer<void>();
    final controller = SteadyActionController<void>.cancellable(
      () => SteadyCancellableOperation(
        future: never.future,
        cancel: () => cancelled++,
      ),
      requestPolicy: const SteadyRequestPolicy(
        timeout: Duration(milliseconds: 5),
      ),
    );
    final mutation = SteadyOptimisticHandle.apply(
      apply: () => value++,
      rollback: () => value--,
    );

    await controller.runOptimistic(mutation);

    expect(value, 0);
    expect(cancelled, 1);
    expect(mutation.status, SteadyOptimisticStatus.rolledBack);
    expect(controller.value.failure?.error, isA<SteadyTimeoutException>());
    controller.dispose();
  });

  test('timeout wins when cancellation synchronously completes with an error',
      () async {
    final result = Completer<int>();
    final controller = SteadyAsyncController<int>.cancellable(
      () => SteadyCancellableOperation(
        future: result.future,
        cancel: () => result.completeError(StateError('transport cancelled')),
      ),
      requestPolicy: const SteadyRequestPolicy(
        timeout: Duration(milliseconds: 5),
      ),
    );

    await controller.load();

    expect((controller.value as SteadyError<int>).error,
        isA<SteadyTimeoutException>());
    controller.dispose();
  });

  test('state timestamps use the injected UTC clock and calculate staleness',
      () async {
    var now = DateTime.utc(2026, 7, 14, 10);
    final controller = SteadyAsyncController<int>(
      () async => 1,
      clock: () => now,
    );

    await controller.load();
    final state = controller.value;

    expect(state.lastUpdatedAt, now);
    expect(state.isStale(const Duration(minutes: 5), now: now), isFalse);
    now = now.add(const Duration(minutes: 6));
    expect(state.isStale(const Duration(minutes: 5), now: now), isTrue);
    controller.dispose();
  });

  test('cancelling a refresh preserves the previous update timestamp',
      () async {
    final refresh = Completer<int>();
    var calls = 0;
    final updatedAt = DateTime.utc(2026, 7, 14, 10);
    final controller = SteadyAsyncController<int>(
      () => calls++ == 0 ? Future.value(1) : refresh.future,
      clock: () => updatedAt,
    );
    await controller.load();

    final pending = controller.refresh();
    await Future<void>.delayed(Duration.zero);
    controller.cancel();

    expect(controller.value.valueOrNull, 1);
    expect(controller.value.lastUpdatedAt, updatedAt);
    refresh.complete(2);
    await pending;
    expect(controller.value.valueOrNull, 1);
    controller.dispose();
  });
}

class _RecordingObserver implements SteadyObserver {
  final events = <SteadyLifecycleEvent>[];

  @override
  void onEvent(SteadyLifecycleEvent event) => events.add(event);
}

class _ThrowingObserver implements SteadyObserver {
  @override
  void onEvent(SteadyLifecycleEvent event) => throw StateError('observer');
}

class _SecretError implements Exception {
  const _SecretError(this.secret);

  final String secret;

  @override
  String toString() => '_SecretError: $secret';
}
