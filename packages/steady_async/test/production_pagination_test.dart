import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_async/steady_async.dart';

void main() {
  test('cached seed is deduplicated, visible immediately, and refreshed once',
      () async {
    var calls = 0;
    final controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      itemKey: (item) => item,
      seed: const SteadyPagedSeed(items: [1, 1], nextKey: 2),
      loadPage: (_) async {
        calls++;
        return const SteadyPage(items: [3]);
      },
    );

    expect(controller.value.items, [1]);
    expect(controller.value.status, SteadyPagedStatus.loaded);

    await controller.loadInitial();
    await controller.loadInitial();

    expect(calls, 1);
    expect(controller.value.items, [3]);
    controller.dispose();
  });

  test('source replacement clears by default and rejects old completion',
      () async {
    final oldPage = Completer<SteadyPage<int, int>>();
    final controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      sourceKey: 'user-a',
      loadPage: (_) => oldPage.future,
    );

    final oldLoad = controller.loadInitial();
    await controller.replaceSource(
      sourceKey: 'user-b',
      firstPageKey: 0,
      loadPage: (_) async => const SteadyPage(items: [9]),
    );
    oldPage.complete(const SteadyPage(items: [1]));
    await oldLoad;

    expect(controller.sourceKey, 'user-b');
    expect(controller.value.items, [9]);
    controller.dispose();
  });

  test('retained source transition keeps safe filter data while loading',
      () async {
    final next = Completer<SteadyPage<int, int>>();
    final controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      sourceKey: 'all',
      loadPage: (_) async => const SteadyPage(items: [1]),
    );
    await controller.loadInitial();

    final replacement = controller.replaceSource(
      sourceKey: 'favorites',
      firstPageKey: 0,
      loadPage: (_) => next.future,
      transition: SteadySourceTransition.retain,
    );

    expect(controller.value.items, [1]);
    expect(controller.value.isRefreshing, isTrue);
    next.complete(const SteadyPage(items: [2]));
    await replacement;
    expect(controller.value.items, [2]);
    controller.dispose();
  });

  test('immediate insert and update retain pagination cursor', () async {
    final controller = SteadyPagedController<_Item, int>(
      firstPageKey: 0,
      itemKey: (item) => item.id,
      loadPage: (_) async => const SteadyPage(
        items: [_Item(1, 'one')],
        nextKey: 2,
      ),
    );
    await controller.loadInitial();

    expect(controller.insert(const _Item(2, 'two')), isTrue);
    expect(
      controller.updateByKey(1, (item) => _Item(item.id, 'updated')),
      isTrue,
    );

    expect(
        controller.value.items.map((item) => item.label), ['two', 'updated']);
    expect(controller.value.nextKey, 2);
    controller.dispose();
  });

  test('optimistic overlays survive refresh and resolve independently',
      () async {
    var page = const SteadyPage<_Item, int>(
      items: [_Item(1, 'old')],
    );
    final controller = SteadyPagedController<_Item, int>(
      firstPageKey: 0,
      itemKey: (item) => item.id,
      loadPage: (_) async => page,
    );
    await controller.loadInitial();

    final first = controller.optimisticUpdateByKey(
      1,
      (item) => _Item(item.id, 'first'),
    );
    final second = controller.optimisticUpdateByKey(
      1,
      (item) => _Item(item.id, 'second'),
    );
    page = const SteadyPage(items: [_Item(1, 'server')]);
    await controller.refresh();

    expect(controller.value.items.single.label, 'second');
    expect(first.rollback(), isTrue);
    expect(controller.value.items.single.label, 'second');
    expect(second.rollback(), isTrue);
    expect(controller.value.items.single.label, 'server');
    controller.dispose();
  });

  test('same-key optimistic commits preserve creation order', () async {
    final controller = SteadyPagedController<_Item, int>(
      firstPageKey: 0,
      itemKey: (item) => item.id,
      loadPage: (_) async => const SteadyPage(items: [_Item(1, 'v0')]),
    );
    await controller.loadInitial();
    final first = controller.optimisticUpdateByKey(
      1,
      (item) => _Item(item.id, 'v1'),
    );
    final second = controller.optimisticUpdateByKey(
      1,
      (item) => _Item(item.id, 'v2'),
    );

    expect(second.commit(), isTrue);
    expect(controller.value.items.single.label, 'v2');
    expect(first.commit(), isTrue);
    expect(controller.value.items.single.label, 'v2');
    controller.dispose();
  });

  test('rolling back an older overlay preserves a newer committed update',
      () async {
    final controller = SteadyPagedController<_Item, int>(
      firstPageKey: 0,
      itemKey: (item) => item.id,
      loadPage: (_) async => const SteadyPage(items: [_Item(1, 'v0')]),
    );
    await controller.loadInitial();
    final first = controller.optimisticUpdateByKey(
      1,
      (item) => _Item(item.id, 'v1'),
    );
    final second = controller.optimisticUpdateByKey(
      1,
      (item) => _Item(item.id, 'v2'),
    );

    second.commit();
    first.rollback();

    expect(controller.value.items.single.label, 'v2');
    controller.dispose();
  });

  test('source replacement invalidates optimistic handles', () async {
    final controller = SteadyPagedController<_Item, int>(
      firstPageKey: 0,
      itemKey: (item) => item.id,
      loadPage: (_) async => const SteadyPage(items: [_Item(1, 'old')]),
    );
    await controller.loadInitial();
    final mutation = controller.optimisticRemoveByKey(1);

    await controller.replaceSource(
      sourceKey: 'new-user',
      firstPageKey: 0,
      loadPage: (_) async => const SteadyPage(items: [_Item(2, 'new')]),
    );

    expect(mutation.status, SteadyOptimisticStatus.invalidated);
    expect(mutation.rollback(), isFalse);
    expect(controller.value.items.single.id, 2);
    controller.dispose();
  });

  test('retained source replacement discards pending optimistic overlays',
      () async {
    final controller = SteadyPagedController<_Item, int>(
      firstPageKey: 0,
      sourceKey: 'all',
      itemKey: (item) => item.id,
      loadPage: (_) async => const SteadyPage(items: [_Item(1, 'server')]),
    );
    await controller.loadInitial();

    final edit = controller.optimisticUpdateByKey(
      1,
      (item) => _Item(item.id, 'draft'),
    );
    await controller.replaceSource(
      sourceKey: 'filtered',
      firstPageKey: 0,
      loadPage: (_) async => const SteadyPage(items: []),
      transition: SteadySourceTransition.retain,
      loadImmediately: false,
    );

    expect(edit.status, SteadyOptimisticStatus.invalidated);
    expect(controller.value.items.single.label, 'server');

    final removal = controller.optimisticRemoveByKey(1);
    await controller.replaceSource(
      sourceKey: 'filtered-again',
      firstPageKey: 0,
      loadPage: (_) async => const SteadyPage(items: []),
      transition: SteadySourceTransition.retain,
      loadImmediately: false,
    );

    expect(removal.status, SteadyOptimisticStatus.invalidated);
    expect(controller.value.items.single.label, 'server');
    controller.dispose();
  });

  test('immediate update materializes out-of-order committed overlays first',
      () async {
    final controller = SteadyPagedController<_Item, int>(
      firstPageKey: 0,
      itemKey: (item) => item.id,
      loadPage: (_) async => const SteadyPage(items: [_Item(1, 'v0')]),
    );
    await controller.loadInitial();
    final pending = controller.optimisticUpdateByKey(
      1,
      (item) => _Item(item.id, 'v1'),
    );
    final committed = controller.optimisticUpdateByKey(
      1,
      (item) => _Item(item.id, 'v2'),
    );
    expect(committed.commit(), isTrue);

    expect(
      controller.updateByKey(
        1,
        (item) => _Item(item.id, '${item.label}+local'),
      ),
      isTrue,
    );

    expect(pending.status, SteadyOptimisticStatus.invalidated);
    expect(controller.value.items.single.label, 'v2+local');
    controller.dispose();
  });

  test('immediate removal sees an out-of-order committed optimistic insert',
      () async {
    final controller = SteadyPagedController<_Item, int>(
      firstPageKey: 0,
      itemKey: (item) => item.id,
      loadPage: (_) async => const SteadyPage(items: [_Item(1, 'v0')]),
    );
    await controller.loadInitial();
    final pending = controller.optimisticUpdateByKey(
      1,
      (item) => _Item(item.id, 'pending'),
    );
    final inserted = controller.optimisticInsert(const _Item(2, 'inserted'));
    expect(inserted.commit(), isTrue);
    expect(controller.value.items.any((item) => item.id == 2), isTrue);

    expect(controller.removeByKey(2), isTrue);

    expect(pending.status, SteadyOptimisticStatus.invalidated);
    expect(controller.value.items.map((item) => item.id), [1]);
    controller.dispose();
  });

  test('optimistic insert remains deduplicated when the server returns it',
      () async {
    var page = const SteadyPage<_Item, int>(items: [_Item(1, 'one')]);
    final controller = SteadyPagedController<_Item, int>(
      firstPageKey: 0,
      itemKey: (item) => item.id,
      loadPage: (_) async => page,
    );
    await controller.loadInitial();
    final insertion = controller.optimisticInsert(const _Item(2, 'two'));
    page = const SteadyPage(items: [_Item(1, 'one'), _Item(2, 'server two')]);

    await controller.refresh();

    expect(controller.value.items.where((item) => item.id == 2), hasLength(1));
    expect(insertion.commit(), isTrue);
    expect(controller.value.items.where((item) => item.id == 2), hasLength(1));
    controller.dispose();
  });

  test('reset and disposal invalidate pending optimistic handles', () async {
    final controller = SteadyPagedController<_Item, int>(
      firstPageKey: 0,
      itemKey: (item) => item.id,
      loadPage: (_) async => const SteadyPage(items: [_Item(1, 'one')]),
    );
    await controller.loadInitial();
    final resetHandle = controller.optimisticRemoveByKey(1);
    controller.reset();
    expect(resetHandle.status, SteadyOptimisticStatus.invalidated);
    expect(resetHandle.rollback(), isFalse);

    await controller.loadInitial();
    final disposeHandle = controller.optimisticRemoveByKey(1);
    controller.dispose();
    expect(disposeHandle.status, SteadyOptimisticStatus.invalidated);
    expect(disposeHandle.commit(), isFalse);
  });

  test('same-source replacement refreshes without changing source identity',
      () async {
    var calls = 0;
    final controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      sourceKey: 'user-a',
      loadPage: (_) async => const SteadyPage(items: [1]),
    );
    await controller.loadInitial();

    await controller.replaceSource(
      sourceKey: 'user-a',
      firstPageKey: 5,
      loadPage: (key) async {
        calls++;
        expect(key, 5);
        return const SteadyPage(items: [2]);
      },
    );

    expect(controller.sourceKey, 'user-a');
    expect(controller.value.items, [2]);
    expect(calls, 1);
    controller.dispose();
  });

  test('retained source replacement never carries the previous cursor',
      () async {
    var replacementCalls = 0;
    final controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      sourceKey: 'a',
      loadPage: (_) async => const SteadyPage(items: [1], nextKey: 2),
    );
    await controller.loadInitial();

    await controller.replaceSource(
      sourceKey: 'b',
      firstPageKey: 10,
      loadPage: (_) async {
        replacementCalls++;
        return const SteadyPage(items: [2]);
      },
      transition: SteadySourceTransition.retain,
      loadImmediately: false,
    );
    await controller.loadMore();

    expect(controller.value.items, [1]);
    expect(controller.value.nextKey, isNull);
    expect(replacementCalls, 0);
    controller.dispose();
  });

  test('pagination optimistic lifecycle events share one transaction id',
      () async {
    final observer = _PagedObserver();
    final controller = SteadyPagedController<_Item, int>(
      firstPageKey: 0,
      itemKey: (item) => item.id,
      observer: observer,
      loadPage: (_) async => const SteadyPage(items: [_Item(1, 'one')]),
    );
    await controller.loadInitial();

    final mutation = controller.optimisticRemoveByKey(1);
    mutation.rollback();

    final events = observer.events
        .where((event) => event.kind.name.startsWith('optimistic'))
        .toList();
    expect(events, hasLength(2));
    expect(events.first.operationId, events.last.operationId);
    controller.dispose();
  });

  test('pagination timeout invokes real cancellation', () async {
    var cancelled = 0;
    final never = Completer<SteadyPage<int, int>>();
    final controller = SteadyPagedController<int, int>.cancellable(
      firstPageKey: 0,
      loadPage: (_) => SteadyCancellableOperation(
        future: never.future,
        cancel: () => cancelled++,
      ),
      requestPolicy: const SteadyRequestPolicy(
        timeout: Duration(milliseconds: 5),
      ),
    );

    await controller.loadInitial();

    expect(cancelled, 1);
    expect(controller.value.error, isA<SteadyTimeoutException>());
    controller.dispose();
  });

  testWidgets('paged sliver grid loads and renders cursor pages',
      (tester) async {
    final controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      loadPage: (key) async => key == 0
          ? const SteadyPage(items: [1, 2], nextKey: 1)
          : const SteadyPage(items: [3]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          slivers: [
            SteadyPagedSliverGrid<int, int>(
              controller: controller,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
              ),
              itemBuilder: (_, item, __) => Text('item $item'),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('item 1'), findsOneWidget);
    expect(find.text('item 3'), findsOneWidget);
    controller.dispose();
  });
}

class _Item {
  const _Item(this.id, this.label);

  final int id;
  final String label;
}

class _PagedObserver implements SteadyObserver {
  final events = <SteadyLifecycleEvent>[];

  @override
  void onEvent(SteadyLifecycleEvent event) => events.add(event);
}
