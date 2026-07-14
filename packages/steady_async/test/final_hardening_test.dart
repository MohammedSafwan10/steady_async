import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_async/steady_async.dart';

void main() {
  test('async cancellation cannot start an orphaned request reentrantly',
      () async {
    final pending = Completer<int>();
    var starts = 0;
    var cancellations = 0;
    late SteadyAsyncController<int> controller;
    controller = SteadyAsyncController<int>.cancellable(
      () {
        starts++;
        return SteadyCancellableOperation<int>(
          future: pending.future,
          cancel: () {
            cancellations++;
            unawaited(controller.load());
          },
        );
      },
    );

    final run = controller.load();
    await Future<void>.delayed(Duration.zero);
    controller.reset();
    await run;

    expect(starts, 1);
    expect(cancellations, 1);
    expect(controller.value.isIdle, isTrue);
    controller.dispose();
  });

  test('reset from initial-loading notification prevents loader start',
      () async {
    var starts = 0;
    late SteadyPagedController<int, int> controller;
    controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      loadPage: (_) async {
        starts++;
        return const SteadyPage(items: [1]);
      },
    );
    controller.addListener(() {
      if (controller.value.status == SteadyPagedStatus.initialLoading) {
        controller.reset();
      }
    });

    await controller.loadInitial();

    expect(starts, 0);
    expect(controller.value.status, SteadyPagedStatus.idle);
    controller.dispose();
  });

  test('pagination cancellation cannot start an orphaned refresh', () async {
    final pending = Completer<SteadyPage<int, int>>();
    var starts = 0;
    var cancellations = 0;
    late SteadyPagedController<int, int> controller;
    controller = SteadyPagedController<int, int>.cancellable(
      firstPageKey: 0,
      loadPage: (_) {
        starts++;
        return SteadyCancellableOperation(
          future: pending.future,
          cancel: () {
            cancellations++;
            unawaited(controller.refresh());
          },
        );
      },
    );

    final run = controller.loadInitial();
    await Future<void>.delayed(Duration.zero);
    controller.reset();
    await run;

    expect(starts, 1);
    expect(cancellations, 1);
    expect(controller.value.status, SteadyPagedStatus.idle);
    controller.dispose();
  });

  test('source replacement observer may dispose the controller safely',
      () async {
    late SteadyPagedController<int, int> controller;
    final observer = _CallbackObserver((event) {
      if (event.kind == SteadyLifecycleEventKind.sourceReplaced) {
        controller.dispose();
      }
    });
    controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      loadPage: (_) async => const SteadyPage(items: []),
      observer: observer,
    );

    await controller.replaceSource(
      sourceKey: 'next',
      firstPageKey: 0,
      loadImmediately: false,
      loadPage: (_) async => const SteadyPage(items: []),
    );
  });

  test('source replacement reset prevents its automatic load', () async {
    var starts = 0;
    late SteadyPagedController<int, int> controller;
    final observer = _CallbackObserver((event) {
      if (event.kind == SteadyLifecycleEventKind.sourceReplaced) {
        controller.reset();
      }
    });
    controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      loadPage: (_) async => const SteadyPage(items: []),
      observer: observer,
    );

    await controller.replaceSource(
      sourceKey: 'next',
      firstPageKey: 0,
      loadPage: (_) async {
        starts++;
        return const SteadyPage(items: []);
      },
    );

    expect(starts, 0);
    expect(controller.value.status, SteadyPagedStatus.idle);
    controller.dispose();
  });

  test('optimistic observer reset remains authoritative', () {
    late SteadyPagedController<int, int> controller;
    var resetOn = SteadyLifecycleEventKind.optimisticApplied;
    final observer = _CallbackObserver((event) {
      if (event.kind == resetOn) controller.reset();
    });
    controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      itemKey: (item) => item,
      seed: const SteadyPagedSeed(items: [1]),
      loadPage: (_) async => const SteadyPage(items: []),
      observer: observer,
    );

    final applied = controller.optimisticUpdateByKey(1, (_) => 2);
    expect(applied.status, SteadyOptimisticStatus.invalidated);
    expect(controller.value.status, SteadyPagedStatus.idle);
    controller.dispose();

    controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      itemKey: (item) => item,
      seed: const SteadyPagedSeed(items: [1]),
      loadPage: (_) async => const SteadyPage(items: []),
      observer: observer,
    );
    resetOn = SteadyLifecycleEventKind.optimisticCommitted;
    final committed = controller.optimisticUpdateByKey(1, (_) => 2);
    expect(committed.commit(), isTrue);
    expect(controller.value.status, SteadyPagedStatus.idle);
    controller.dispose();
  });

  test('an optimistic handle cannot roll itself back during commit', () {
    final controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      itemKey: (item) => item,
      seed: const SteadyPagedSeed(items: [1]),
      loadPage: (_) async => const SteadyPage(items: []),
    );
    final handle = controller.optimisticUpdateByKey(1, (_) => 2);
    var rollbackResult = true;
    controller.addListener(() => rollbackResult = handle.rollback());

    expect(handle.commit(), isTrue);

    expect(rollbackResult, isFalse);
    expect(handle.status, SteadyOptimisticStatus.committed);
    expect(controller.value.items, [2]);
    controller.dispose();
  });

  test('optimistic methods are side-effect-free after disposal', () {
    var updateCalls = 0;
    final controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      itemKey: (item) => item,
      seed: const SteadyPagedSeed(items: [1]),
      loadPage: (_) async => const SteadyPage(items: []),
    );
    controller.dispose();

    final handle = controller.optimisticUpdateByKey(1, (item) {
      updateCalls++;
      return item + 1;
    });

    expect(updateCalls, 0);
    expect(handle.status, SteadyOptimisticStatus.invalidated);
  });

  test('retry preserves initial-load operation metadata', () async {
    var calls = 0;
    final controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      loadPage: (_) async {
        calls++;
        throw StateError('offline');
      },
    );

    await controller.loadInitial();
    await controller.retry();

    expect(calls, 2);
    expect(
      controller.value.failure?.operation,
      SteadyOperationKind.initialLoad,
    );
    controller.dispose();
  });

  testWidgets('seeded slivers refresh cached data automatically',
      (tester) async {
    var listCalls = 0;
    var gridCalls = 0;
    final listController = SteadyPagedController<int, int>(
      firstPageKey: 0,
      seed: const SteadyPagedSeed(items: [1]),
      loadPage: (_) async {
        listCalls++;
        return const SteadyPage(items: [2]);
      },
    );
    final gridController = SteadyPagedController<int, int>(
      firstPageKey: 0,
      seed: const SteadyPagedSeed(items: [1]),
      loadPage: (_) async {
        gridCalls++;
        return const SteadyPage(items: [2]);
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          slivers: [
            SteadyPagedSliverList<int, int>(
              controller: listController,
              itemBuilder: (_, item, __) => Text('list $item'),
            ),
            SteadyPagedSliverGrid<int, int>(
              controller: gridController,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1,
              ),
              itemBuilder: (_, item, __) => Text('grid $item'),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(listCalls, 1);
    expect(gridCalls, 1);
    listController.dispose();
    gridController.dispose();
  });

  test('one async request keeps the loader captured at its start', () async {
    var oldCalls = 0;
    var newCalls = 0;
    final controller = SteadyAsyncController<int>(
      () async {
        oldCalls++;
        if (oldCalls == 1) throw StateError('retry');
        return 7;
      },
      requestPolicy: SteadyRequestPolicy(
        retry: SteadyRetryPolicy.fixed(
          maxAttempts: 2,
          delay: const Duration(milliseconds: 20),
        ),
      ),
    );

    final run = controller.load();
    await Future<void>.delayed(const Duration(milliseconds: 2));
    controller.updateLoader(() async {
      newCalls++;
      return 9;
    });
    await run;

    expect(oldCalls, 2);
    expect(newCalls, 0);
    expect(controller.value.valueOrNull, 7);
    controller.dispose();
  });

  test('telemetry elapsed is nonnegative and stale actions are reported',
      () async {
    var tick = 0;
    final origin = DateTime.utc(2026);
    DateTime clock() => origin.add(Duration(milliseconds: tick++));
    final events = <SteadyLifecycleEvent>[];
    final first = Completer<int>();
    var calls = 0;
    final controller = SteadyActionController<int>(
      () => calls++ == 0 ? first.future : Future<int>.value(2),
      concurrency: SteadyActionConcurrency.latestWins,
      successVisibleDuration: Duration.zero,
      clock: clock,
      observer: _CallbackObserver(events.add),
    );

    final oldRun = controller.run();
    await controller.run();
    first.complete(1);
    await oldRun;

    expect(
      events.where((event) => event.elapsed != null),
      everyElement(
        predicate<SteadyLifecycleEvent>(
          (event) => !event.elapsed!.isNegative,
        ),
      ),
    );
    expect(
      events.any(
        (event) => event.kind == SteadyLifecycleEventKind.staleCompletion,
      ),
      isTrue,
    );
    controller.dispose();
  });

  test('successful state retains request attempt metadata', () async {
    var calls = 0;
    final asyncController = SteadyAsyncController<int>(
      () async {
        calls++;
        if (calls == 1) throw StateError('retry');
        return 1;
      },
      requestPolicy: SteadyRequestPolicy(
        retry: SteadyRetryPolicy.fixed(
          maxAttempts: 2,
          delay: Duration.zero,
        ),
      ),
    );
    final actionController = SteadyActionController<int>(
      () async => 2,
      successVisibleDuration: Duration.zero,
    );

    await asyncController.load();
    await actionController.run();

    expect(asyncController.value.attempt, 2);
    expect(asyncController.value.lastAttemptAt, isNotNull);
    expect(
      asyncController.value.operationOrigin,
      SteadyOperationKind.initialLoad,
    );
    expect(actionController.value.attempt, 1);
    expect(actionController.value.lastAttemptAt, isNotNull);
    asyncController.dispose();
    actionController.dispose();
  });

  test('sequential optimistic actions apply at their own execution time',
      () async {
    final firstResult = Completer<void>();
    var calls = 0;
    var visible = 0;
    final controller = SteadyActionController<void>(
      () async {
        if (calls++ == 0) {
          await firstResult.future;
          throw StateError('first failed');
        }
      },
      concurrency: SteadyActionConcurrency.sequential,
      successVisibleDuration: Duration.zero,
    );

    SteadyOptimisticHandle mutation(int next) {
      final previous = visible;
      return SteadyOptimisticHandle.apply(
        apply: () => visible = next,
        rollback: () => visible = previous,
      );
    }

    final first = controller.runOptimistic(mutation(1));
    final second = controller.runOptimistic(mutation(2));
    await Future<void>.delayed(Duration.zero);
    expect(visible, 1);
    firstResult.complete();
    await first;
    await second;

    expect(visible, 2);
    controller.dispose();
  });

  test('action setup blocks reentrant request starts', () async {
    final result = Completer<void>();
    var starts = 0;
    var reacted = false;
    late SteadyActionController<void> controller;
    controller = SteadyActionController<void>(
      () {
        starts++;
        return result.future;
      },
      concurrency: SteadyActionConcurrency.latestWins,
    );
    controller.addListener(() {
      if (!reacted && controller.value.isRunning) {
        reacted = true;
        unawaited(controller.run());
      }
    });

    final run = controller.run();
    await Future<void>.delayed(Duration.zero);
    expect(starts, 1);
    result.complete();
    await run;
    controller.dispose();
  });

  test('reset rolls back an old mutation before a replacement is applied',
      () async {
    final firstResult = Completer<void>();
    var visible = 0;
    var calls = 0;
    final controller = SteadyActionController<void>(
      () => calls++ == 0 ? firstResult.future : Future<void>.value(),
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

    final oldRun = controller.runOptimistic(mutation(1));
    controller.reset();
    final newRun = controller.runOptimistic(mutation(2));
    firstResult.complete();
    await oldRun;
    await newRun;

    expect(visible, 2);
    controller.dispose();
  });
}

class _CallbackObserver implements SteadyObserver {
  const _CallbackObserver(this.callback);

  final void Function(SteadyLifecycleEvent event) callback;

  @override
  void onEvent(SteadyLifecycleEvent event) => callback(event);
}
