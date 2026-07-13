import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:steady_async/steady_async.dart';

void main() {
  test('drop policy prevents duplicate submissions', () async {
    final pending = Completer<int>();
    var calls = 0;
    final controller = SteadyActionController<int>(() {
      calls++;
      return pending.future;
    });

    final first = controller.run();
    await controller.run();
    expect(calls, 1);
    pending.complete(7);
    expect(await first, 7);
    controller.dispose();
  });

  test('latestWins ignores the older result', () async {
    final first = Completer<int>();
    final second = Completer<int>();
    var calls = 0;
    final controller = SteadyActionController<int>(
      () => calls++ == 0 ? first.future : second.future,
      concurrency: SteadyActionConcurrency.latestWins,
      successVisibleDuration: Duration.zero,
    );

    final firstRun = controller.run();
    final secondRun = controller.run();
    second.complete(2);
    await secondRun;
    first.complete(1);
    await firstRun;

    expect(controller.value.value, 2);
    controller.dispose();
  });

  test('action errors remain retryable', () async {
    var fail = true;
    final controller = SteadyActionController<int>(() async {
      if (fail) throw StateError('failed');
      return 9;
    }, successVisibleDuration: Duration.zero);

    await controller.run();
    expect(controller.value.hasError, isTrue);
    fail = false;
    await controller.run();
    expect(controller.value.value, 9);
    controller.dispose();
  });

  test('sequential policy runs calls in order', () async {
    final order = <int>[];
    var next = 0;
    final controller = SteadyActionController<int>(
      () async {
        final value = next++;
        await Future<void>.delayed(Duration.zero);
        order.add(value);
        return value;
      },
      concurrency: SteadyActionConcurrency.sequential,
      successVisibleDuration: Duration.zero,
    );

    await Future.wait([controller.run(), controller.run(), controller.run()]);

    expect(order, [0, 1, 2]);
    controller.dispose();
  });

  test('success resets after the configured duration', () async {
    final controller = SteadyActionController<int>(
      () async => 1,
      successVisibleDuration: const Duration(milliseconds: 10),
    );

    await controller.run();
    expect(controller.value.isSuccess, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(controller.value.status, SteadyActionStatus.idle);
    controller.dispose();
  });
}
