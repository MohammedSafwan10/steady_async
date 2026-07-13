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

  test('newer refresh wins when refreshes complete out of order', () async {
    final refreshes = <Completer<SteadyPage<int, int>>>[];
    var calls = 0;
    final controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      loadPage: (_) {
        calls++;
        if (calls == 1) return Future.value(const SteadyPage(items: [0]));
        final completer = Completer<SteadyPage<int, int>>();
        refreshes.add(completer);
        return completer.future;
      },
    );

    await controller.loadInitial();
    final first = controller.refresh();
    final second = controller.refresh();
    refreshes[1].complete(const SteadyPage(items: [2]));
    await second;
    refreshes[0].complete(const SteadyPage(items: [1]));
    await first;

    expect(controller.value.items, [2]);
    controller.dispose();
  });

  test('refresh invalidates an active append', () async {
    final append = Completer<SteadyPage<int, int>>();
    var firstPageCalls = 0;
    final controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      loadPage: (key) {
        if (key == 1) return append.future;
        firstPageCalls++;
        return Future.value(
          SteadyPage(
            items: firstPageCalls == 1 ? const [1] : const [9],
            nextKey: firstPageCalls == 1 ? 1 : null,
          ),
        );
      },
    );

    await controller.loadInitial();
    final oldAppend = controller.loadMore();
    await controller.refresh();
    append.complete(const SteadyPage(items: [2]));
    await oldAppend;

    expect(controller.value.items, [9]);
    expect(controller.value.hasMore, isFalse);
    controller.dispose();
  });

  test('reset invalidates an active initial request', () async {
    final initial = Completer<SteadyPage<int, int>>();
    final controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      loadPage: (_) => initial.future,
    );

    final load = controller.loadInitial();
    controller.reset();
    initial.complete(const SteadyPage(items: [1]));
    await load;

    expect(controller.value.status, SteadyPagedStatus.idle);
    expect(controller.value.items, isEmpty);
    controller.dispose();
  });

  test('reset invalidates active refresh and append requests', () async {
    final refresh = Completer<SteadyPage<int, int>>();
    final append = Completer<SteadyPage<int, int>>();
    var firstPageCalls = 0;
    final controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      loadPage: (key) {
        if (key == 1) return append.future;
        firstPageCalls++;
        if (firstPageCalls == 1) {
          return Future.value(const SteadyPage(items: [1], nextKey: 1));
        }
        return refresh.future;
      },
    );

    await controller.loadInitial();
    final appendRun = controller.loadMore();
    final refreshRun = controller.refresh();
    controller.reset();
    append.complete(const SteadyPage(items: [2]));
    refresh.complete(const SteadyPage(items: [3]));
    await Future.wait([appendRun, refreshRun]);

    expect(controller.value.status, SteadyPagedStatus.idle);
    expect(controller.value.items, isEmpty);
    controller.dispose();
  });

  test('dispose invalidates an active initial request', () async {
    final initial = Completer<SteadyPage<int, int>>();
    final controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      loadPage: (_) => initial.future,
    );

    final load = controller.loadInitial();
    controller.dispose();
    initial.complete(const SteadyPage(items: [1]));
    await load;
  });

  test('dispose invalidates active refresh and append requests', () async {
    final refresh = Completer<SteadyPage<int, int>>();
    final append = Completer<SteadyPage<int, int>>();
    var firstPageCalls = 0;
    final controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      loadPage: (key) {
        if (key == 1) return append.future;
        firstPageCalls++;
        if (firstPageCalls == 1) {
          return Future.value(const SteadyPage(items: [1], nextKey: 1));
        }
        return refresh.future;
      },
    );

    await controller.loadInitial();
    final appendRun = controller.loadMore();
    final refreshRun = controller.refresh();
    controller.dispose();
    append.complete(const SteadyPage(items: [2]));
    refresh.complete(const SteadyPage(items: [3]));
    await Future.wait([appendRun, refreshRun]);
  });

  test('public calls after disposal never invoke the loader', () async {
    var calls = 0;
    final controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      itemKey: (item) => item,
      loadPage: (_) async {
        calls++;
        return const SteadyPage(items: [1], nextKey: 1);
      },
    );
    controller.dispose();

    await controller.loadInitial();
    await controller.refresh();
    await controller.loadMore();
    await controller.retry();
    controller.updateLoader((_) async {
      calls++;
      return const SteadyPage(items: [2]);
    });
    controller.reset();

    expect(controller.removeWhere((_) => true), isFalse);
    expect(controller.removeByKey(1), isFalse);
    expect(calls, 0);
  });

  test('duplicate initial loads invoke the loader once', () async {
    final initial = Completer<SteadyPage<int, int>>();
    var calls = 0;
    final controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      loadPage: (_) {
        calls++;
        return initial.future;
      },
    );

    final first = controller.loadInitial();
    final second = controller.loadInitial();
    expect(calls, 1);
    initial.complete(const SteadyPage(items: [1]));
    await Future.wait([first, second]);
    controller.dispose();
  });

  test('refresh failure retains previous items', () async {
    var fail = false;
    final controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      loadPage: (_) async {
        if (fail) throw StateError('offline');
        return const SteadyPage(items: [1], nextKey: 2);
      },
    );

    await controller.loadInitial();
    fail = true;
    await controller.refresh();

    expect(controller.value.items, [1]);
    expect(controller.value.status, SteadyPagedStatus.error);
    expect(controller.value.error, isA<StateError>());
    controller.dispose();
  });

  test('supports a nullable first-page cursor', () async {
    final requested = <String?>[];
    final controller = SteadyPagedController<int, String?>(
      firstPageKey: null,
      loadPage: (key) async {
        requested.add(key);
        return key == null
            ? const SteadyPage(items: [1], nextKey: 'next')
            : const SteadyPage(items: [2]);
      },
    );

    await controller.loadInitial();
    await controller.loadMore();

    expect(requested, [null, 'next']);
    expect(controller.value.items, [1, 2]);
    controller.dispose();
  });

  test('non-advancing cursor becomes an append error', () async {
    final controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      loadPage: (key) async => key == 0
          ? const SteadyPage(items: [1], nextKey: 1)
          : const SteadyPage(items: [2], nextKey: 1),
    );

    await controller.loadInitial();
    await controller.loadMore();

    expect(controller.value.items, [1]);
    expect(controller.value.appendError, isTrue);
    expect(controller.value.error, isA<SteadyPaginationException>());
    controller.dispose();
  });

  test('cursor cycles become append errors', () async {
    final controller = SteadyPagedController<int, String>(
      firstPageKey: 'A',
      loadPage: (key) async => switch (key) {
        'A' => const SteadyPage(items: [1], nextKey: 'B'),
        'B' => const SteadyPage(items: [2], nextKey: 'A'),
        _ => const SteadyPage(items: []),
      },
    );

    await controller.loadInitial();
    await controller.loadMore();

    expect(controller.value.items, [1]);
    expect(controller.value.appendError, isTrue);
    expect(controller.value.error, isA<SteadyPaginationException>());
    controller.dispose();
  });

  test('removeWhere and removeByKey retain the next page key', () async {
    final controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      itemKey: (item) => item,
      loadPage: (_) async => const SteadyPage(items: [1, 2, 3], nextKey: 4),
    );
    await controller.loadInitial();

    expect(controller.removeWhere((item) => item.isEven), isTrue);
    expect(controller.removeByKey(3), isTrue);
    expect(controller.removeByKey(99), isFalse);
    expect(controller.value.items, [1]);
    expect(controller.value.nextKey, 4);
    expect(controller.value.status, SteadyPagedStatus.loaded);
    controller.dispose();
  });

  test('removeByKey requires an item key', () {
    final controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      loadPage: (_) async => const SteadyPage(items: []),
    );

    expect(() => controller.removeByKey(1), throwsStateError);
    controller.dispose();
  });

  test('removal invalidates active refresh and append results', () async {
    final refresh = Completer<SteadyPage<int, int>>();
    final append = Completer<SteadyPage<int, int>>();
    var firstPageCalls = 0;
    final controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      itemKey: (item) => item,
      loadPage: (key) {
        if (key == 1) return append.future;
        firstPageCalls++;
        if (firstPageCalls == 1) {
          return Future.value(const SteadyPage(items: [1, 2], nextKey: 1));
        }
        return refresh.future;
      },
    );

    await controller.loadInitial();
    final appendRun = controller.loadMore();
    expect(controller.removeByKey(2), isTrue);
    append.complete(const SteadyPage(items: [2, 3]));
    await appendRun;
    expect(controller.value.items, [1]);

    final refreshRun = controller.refresh();
    expect(controller.removeByKey(1), isTrue);
    refresh.complete(const SteadyPage(items: [1, 4]));
    await refreshRun;
    expect(controller.value.items, isEmpty);
    controller.dispose();
  });
}
