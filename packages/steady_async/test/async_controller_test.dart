import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:steady_async/steady_async.dart';

void main() {
  test('ignores stale Future completions after reload', () async {
    final first = Completer<String>();
    final second = Completer<String>();
    var attempt = 0;
    final controller = SteadyAsyncController<String>(() {
      attempt++;
      return attempt == 1 ? first.future : second.future;
    });

    final firstRun = controller.load();
    final secondRun = controller.reload();
    second.complete('fresh');
    await secondRun;
    first.complete('stale');
    await firstRun;

    expect(controller.value, const SteadyAsyncState<String>.data('fresh'));
    controller.dispose();
  });

  test('retains previous data when refresh fails', () async {
    var fail = false;
    final controller = SteadyAsyncController<int>(() async {
      if (fail) throw StateError('offline');
      return 42;
    });

    await controller.load();
    fail = true;
    await controller.refresh();

    final state = controller.value as SteadyError<int>;
    expect(state.hasPreviousValue, isTrue);
    expect(state.previousValue, 42);
    controller.dispose();
  });

  test('cancel invalidates a pending Future', () async {
    final pending = Completer<int>();
    final controller = SteadyAsyncController<int>(() => pending.future);
    final run = controller.load();
    controller.cancel(reset: true);
    pending.complete(1);
    await run;

    expect(controller.value, isA<SteadyIdle<int>>());
    controller.dispose();
  });
}
