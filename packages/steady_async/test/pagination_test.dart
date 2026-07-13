import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:steady_async/steady_async.dart';

void main() {
  test('loads cursor pages and detects the final page', () async {
    final controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      loadPage: (key) async => key == 0
          ? const SteadyPage(items: [1, 2], nextKey: 1)
          : const SteadyPage(items: [3]),
    );

    await controller.loadInitial();
    await controller.loadMore();

    expect(controller.value.items, [1, 2, 3]);
    expect(controller.value.hasMore, isFalse);
    controller.dispose();
  });

  test('deduplicates overlapping append requests', () async {
    final append = Completer<SteadyPage<int, int>>();
    var appendCalls = 0;
    final controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      loadPage: (key) {
        if (key == 0) {
          return Future.value(const SteadyPage(items: [1], nextKey: 1));
        }
        appendCalls++;
        return append.future;
      },
    );
    await controller.loadInitial();
    final one = controller.loadMore();
    final two = controller.loadMore();
    expect(appendCalls, 1);
    append.complete(const SteadyPage(items: [2]));
    await Future.wait([one, two]);
    expect(controller.value.items, [1, 2]);
    controller.dispose();
  });

  test('deduplicates items by application key', () async {
    final controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      itemKey: (item) => item,
      loadPage: (key) async => key == 0
          ? const SteadyPage(items: [1, 2, 2], nextKey: 1)
          : const SteadyPage(items: [2, 3]),
    );

    await controller.loadInitial();
    await controller.loadMore();

    expect(controller.value.items, [1, 2, 3]);
    controller.dispose();
  });

  test('append failure keeps items and can retry', () async {
    var fail = true;
    final controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      loadPage: (key) async {
        if (key == 0) return const SteadyPage(items: [1], nextKey: 1);
        if (fail) throw StateError('offline');
        return const SteadyPage(items: [2]);
      },
    );
    await controller.loadInitial();
    await controller.loadMore();
    expect(controller.value.items, [1]);
    expect(controller.value.appendError, isTrue);

    fail = false;
    await controller.retry();
    expect(controller.value.items, [1, 2]);
    controller.dispose();
  });
}
