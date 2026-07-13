import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_async/steady_async.dart';

void main() {
  testWidgets('list loads a replacement controller', (tester) async {
    final first = _countingController(1);
    final second = _countingController(2);
    late StateSetter rebuild;
    var active = first.controller;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return SteadyPagedListView<int, int>(
              controller: active,
              itemBuilder: (context, item, index) => Text('$item'),
            );
          },
        ),
      ),
    );
    await tester.pump();
    expect(first.calls, 1);

    rebuild(() => active = second.controller);
    await tester.pump();
    await tester.pump();

    expect(second.calls, 1);
    expect(find.text('2'), findsOneWidget);
    first.controller.dispose();
    second.controller.dispose();
  });

  testWidgets('grid loads a replacement controller', (tester) async {
    final first = _countingController(1);
    final second = _countingController(2);
    late StateSetter rebuild;
    var active = first.controller;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return SteadyPagedGridView<int, int>(
              controller: active,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1,
              ),
              itemBuilder: (context, item, index) => Text('$item'),
            );
          },
        ),
      ),
    );
    await tester.pump();
    expect(first.calls, 1);

    rebuild(() => active = second.controller);
    await tester.pump();
    await tester.pump();

    expect(second.calls, 1);
    expect(find.text('2'), findsOneWidget);
    first.controller.dispose();
    second.controller.dispose();
  });

  testWidgets('list continues loading while content underfills viewport', (
    tester,
  ) async {
    var calls = 0;
    final controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      loadPage: (key) async {
        calls++;
        return key == 0
            ? const SteadyPage(items: [1], nextKey: 1)
            : const SteadyPage(items: [2]);
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SteadyPagedListView<int, int>(
          controller: controller,
          itemBuilder: (_, item, index) => SizedBox(
            height: 40,
            child: Text('item $item'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(controller.value.items, [1, 2]);
    controller.dispose();
  });

  testWidgets('grid continues loading while content underfills viewport', (
    tester,
  ) async {
    var calls = 0;
    final controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      loadPage: (key) async {
        calls++;
        return key == 0
            ? const SteadyPage(items: [1], nextKey: 1)
            : const SteadyPage(items: [2]);
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SteadyPagedGridView<int, int>(
          controller: controller,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
          ),
          itemBuilder: (_, item, index) => Text('item $item'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(controller.value.items, [1, 2]);
    controller.dispose();
  });

  testWidgets('list continues past an empty non-terminal page', (tester) async {
    final paging = _emptyFirstPageController();
    await tester.pumpWidget(
      MaterialApp(
        home: SteadyPagedListView<int, int>(
          controller: paging.controller,
          itemBuilder: (_, item, index) => Text('item $item'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(paging.calls, 2);
    expect(find.text('item 2'), findsOneWidget);
    paging.controller.dispose();
  });

  testWidgets('grid continues past an empty non-terminal page', (tester) async {
    final paging = _emptyFirstPageController();
    await tester.pumpWidget(
      MaterialApp(
        home: SteadyPagedGridView<int, int>(
          controller: paging.controller,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
          ),
          itemBuilder: (_, item, index) => Text('item $item'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(paging.calls, 2);
    expect(find.text('item 2'), findsOneWidget);
    paging.controller.dispose();
  });

  testWidgets('sliver continues past an empty non-terminal page', (
    tester,
  ) async {
    final paging = _emptyFirstPageController();
    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          slivers: [
            SteadyPagedSliverList<int, int>(
              controller: paging.controller,
              itemBuilder: (_, item, index) => Text('item $item'),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(paging.calls, 2);
    expect(find.text('item 2'), findsOneWidget);
    paging.controller.dispose();
  });

  testWidgets('refresh error stays visible with retained list items', (
    tester,
  ) async {
    var fail = false;
    final controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      loadPage: (_) async {
        if (fail) throw StateError('offline');
        return const SteadyPage(items: [1]);
      },
    );
    await controller.loadInitial();

    await tester.pumpWidget(
      MaterialApp(
        home: SteadyPagedListView<int, int>(
          controller: controller,
          itemBuilder: (_, item, index) => Text('item $item'),
          refreshErrorBuilder: (_, state, retry) => TextButton(
            onPressed: retry,
            child: const Text('refresh failed'),
          ),
        ),
      ),
    );
    fail = true;
    await controller.refresh();
    await tester.pump();

    expect(find.text('item 1'), findsOneWidget);
    expect(find.text('refresh failed'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('initial errorBuilder is not reused inside retained list data', (
    tester,
  ) async {
    var fail = false;
    var initialErrorBuilds = 0;
    final controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      loadPage: (_) async {
        if (fail) throw StateError('offline');
        return const SteadyPage(items: [1]);
      },
    );
    await controller.loadInitial();

    await tester.pumpWidget(
      MaterialApp(
        home: SteadyPagedListView<int, int>(
          controller: controller,
          itemBuilder: (_, item, index) => Text('item $item'),
          errorBuilder: (_, state, retry) {
            initialErrorBuilds++;
            return const SizedBox.expand(child: Text('full-screen error'));
          },
        ),
      ),
    );
    fail = true;
    await controller.refresh();
    await tester.pump();

    expect(initialErrorBuilds, 0);
    expect(find.text('item 1'), findsOneWidget);
    expect(find.text('Something went wrong'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('list waits for retry after an automatic append fails', (
    tester,
  ) async {
    final paging = _failingAppendController();
    await tester.pumpWidget(
      MaterialApp(
        home: SteadyPagedListView<int, int>(
          controller: paging.controller,
          itemBuilder: (_, item, index) => Text('item $item'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(paging.calls, 2);
    expect(find.text('Try again'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(paging.calls, 2);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(paging.calls, 3);
    paging.controller.dispose();
  });

  testWidgets('grid waits for retry after an automatic append fails', (
    tester,
  ) async {
    final paging = _failingAppendController();
    await tester.pumpWidget(
      MaterialApp(
        home: SteadyPagedGridView<int, int>(
          controller: paging.controller,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
          ),
          itemBuilder: (_, item, index) => Text('item $item'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(paging.calls, 2);
    expect(find.text('Try again'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(paging.calls, 2);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(paging.calls, 3);
    paging.controller.dispose();
  });

  testWidgets('sliver waits for retry after an automatic append fails', (
    tester,
  ) async {
    final paging = _failingAppendController();
    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          slivers: [
            SteadyPagedSliverList<int, int>(
              controller: paging.controller,
              itemBuilder: (_, item, index) => Text('item $item'),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(paging.calls, 2);
    expect(find.text('Try again'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(paging.calls, 2);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(paging.calls, 3);
    paging.controller.dispose();
  });

  testWidgets('list reconnects when its scroll controller changes', (
    tester,
  ) async {
    final paging = _countingController(1);
    final first = ScrollController();
    final second = ScrollController();
    var active = first;
    late StateSetter rebuild;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return SteadyPagedListView<int, int>(
              controller: paging.controller,
              scrollController: active,
              itemBuilder: (_, item, index) => Text('$item'),
            );
          },
        ),
      ),
    );
    await tester.pump();
    expect(first.hasClients, isTrue);

    rebuild(() => active = second);
    await tester.pump();

    expect(first.hasClients, isFalse);
    expect(second.hasClients, isTrue);
    paging.controller.dispose();
    first.dispose();
    second.dispose();
  });

  testWidgets('custom pagination builders receive every request stage', (
    tester,
  ) async {
    final initial = Completer<SteadyPage<int, int>>();
    final append = Completer<SteadyPage<int, int>>();
    var initialCalls = 0;
    final controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      loadPage: (key) {
        if (key == 1) return append.future;
        initialCalls++;
        if (initialCalls == 1) return initial.future;
        return Future.value(const SteadyPage(items: [1], nextKey: 1));
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SteadyPagedListView<int, int>(
          controller: controller,
          itemBuilder: (context, item, index) => Text('item $item'),
          loadingBuilder: (context, state) => const Text('custom loading'),
          errorBuilder: (context, state, retry) => TextButton(
            onPressed: retry,
            child: const Text('custom error'),
          ),
          appendLoadingBuilder: (context, state) =>
              const Text('custom append loading'),
          appendErrorBuilder: (context, state, retry) => TextButton(
            onPressed: retry,
            child: const Text('custom append error'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('custom loading'), findsOneWidget);

    initial.completeError(StateError('initial failed'));
    await tester.pump();
    await tester.pump();
    expect(find.text('custom error'), findsOneWidget);

    await tester.tap(find.text('custom error'));
    await tester.pump();
    expect(find.text('item 1'), findsOneWidget);

    unawaited(controller.loadMore());
    await tester.pump();
    expect(find.text('custom append loading'), findsOneWidget);

    append.completeError(StateError('append failed'));
    await tester.pump();
    await tester.pump();
    expect(find.text('custom append error'), findsOneWidget);
    controller.dispose();
  });
}

_CountingController _countingController(int item) => _CountingController(item);

class _CountingController {
  _CountingController(int item) {
    controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      loadPage: (_) async {
        calls++;
        return SteadyPage(items: [item]);
      },
    );
  }

  late final SteadyPagedController<int, int> controller;
  int calls = 0;
}

_FailingAppendController _failingAppendController() =>
    _FailingAppendController();

class _FailingAppendController {
  _FailingAppendController() {
    controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      loadPage: (key) async {
        calls++;
        if (key == 0) return const SteadyPage(items: [1], nextKey: 1);
        throw StateError('offline');
      },
    );
  }

  late final SteadyPagedController<int, int> controller;
  int calls = 0;
}

_EmptyFirstPageController _emptyFirstPageController() =>
    _EmptyFirstPageController();

class _EmptyFirstPageController {
  _EmptyFirstPageController() {
    controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      loadPage: (key) async {
        calls++;
        return key == 0
            ? const SteadyPage(items: [], nextKey: 1)
            : const SteadyPage(items: [2]);
      },
    );
  }

  late final SteadyPagedController<int, int> controller;
  int calls = 0;
}
