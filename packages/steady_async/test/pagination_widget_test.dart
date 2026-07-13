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
