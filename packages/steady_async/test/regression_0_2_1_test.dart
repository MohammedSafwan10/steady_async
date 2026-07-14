import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_async/steady_async.dart';

/// Isolated regression tests for issues reported against steady_async 0.2.1.
///
/// Each case expects the *corrected* contract. On 0.2.1 these assertions fail
/// and document the current broken behavior. Do not "fix" these by weakening
/// expectations — fix production code instead.
void main() {
  group('0.2.1 regressions', () {
    test(
      'cancel(reset: false) must not leave the controller stuck loading',
      () async {
        final pending = Completer<int>();
        final controller = SteadyAsyncController<int>(() => pending.future);

        final run = controller.load();
        expect(controller.value, isA<SteadyLoading<int>>());

        controller.cancel();
        pending.complete(99);
        await run;

        // Correctness: invalidating a request should not pin public state on
        // SteadyLoading forever. Prefer idle, or prior data when present.
        expect(
          controller.value,
          isNot(isA<SteadyLoading<int>>()),
          reason: 'cancel(reset: false) currently leaves SteadyLoading after '
              'the Future is discarded',
        );
        controller.dispose();
      },
    );

    test('cancel restores retained data and rejects the pending result',
        () async {
      final pending = Completer<int>();
      var calls = 0;
      final controller = SteadyAsyncController<int>(() async {
        calls++;
        return calls == 1 ? 7 : pending.future;
      });

      await controller.load();
      final refresh = controller.refresh();
      expect(controller.value, isA<SteadyLoading<int>>());

      controller.cancel();
      expect(controller.value.valueOrNull, 7);
      final retainedTimestamp = controller.value.lastUpdatedAt;

      pending.complete(99);
      await refresh;
      expect(controller.value.valueOrNull, 7);
      expect(controller.value.lastUpdatedAt, retainedTimestamp);
      controller.dispose();
    });

    testWidgets(
      'stream error after data must retain the latest value on SteadyError',
      (tester) async {
        final stream = StreamController<String>();
        addTearDown(() async {
          if (!stream.isClosed) await stream.close();
        });
        SteadyError<String>? seenError;

        await tester.pumpWidget(
          MaterialApp(
            home: SteadyStreamBuilder<String>(
              stream: () => stream.stream,
              policy: _instantPolicy,
              dataBuilder: (_, value) => Text('data:$value'),
              errorBuilder: (context, state, retry) {
                seenError = state;
                return Text(
                  'error hasPrev=${state.hasPreviousValue} '
                  'prev=${state.previousValue}',
                );
              },
            ),
          ),
        );
        await tester.pump();

        stream.add('latest');
        await tester.pump();
        expect(find.text('data:latest'), findsOneWidget);

        stream.addError(StateError('offline'));
        await tester.pump();

        expect(seenError, isNotNull, reason: 'error UI should be visible');
        expect(
          seenError!.hasPreviousValue,
          isTrue,
          reason: 'onError captures previous only at subscribe time, so the '
              'emitted "latest" value is lost',
        );
        expect(seenError!.previousValue, 'latest');
      },
    );

    testWidgets(
      'synchronously throwing stream factory must leave loading and show error',
      (tester) async {
        // Probes the catch path in SteadyStreamBuilder._subscribe where
        // `widget.stream()` throws before listen(). Production assigns
        // SteadyError without setState. That is only safe because setState
        // (loading) runs immediately before the try and already dirties the
        // element; the catch then mutates _state to error before build.
        //
        // This test expects the user-visible contract (error, not loading).
        // On 0.2.1 it currently *passes* (masked); keep it so a future
        // refactor that drops the preceding setState fails loudly.
        Stream<String> Function() streamFactory =
            () => Stream<String>.value('ok');
        late StateSetter rebuild;

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return SteadyStreamBuilder<String>(
                  stream: streamFactory,
                  policy: _instantPolicy,
                  dataBuilder: (_, value) => Text('data:$value'),
                  loadingBuilder: (_, __) => const Text('loading-visible'),
                  errorBuilder: (context, state, retry) =>
                      Text('error-visible:${state.error}'),
                );
              },
            ),
          ),
        );
        await tester.pump();
        await tester.pump(); // Stream.value delivery
        expect(find.text('data:ok'), findsOneWidget);

        rebuild(() {
          streamFactory = () => throw StateError('factory boom');
        });
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));

        final texts = tester.allWidgets
            .whereType<Text>()
            .map((t) => t.data)
            .whereType<String>()
            .toList();

        expect(
          find.text('loading-visible'),
          findsNothing,
          reason: 'after sync factory throw, visible texts were $texts',
        );
        expect(
          find.textContaining('error-visible:'),
          findsOneWidget,
          reason: 'after sync factory throw, visible texts were $texts',
        );
      },
    );

    test(
      'SteadyPagedState.copyWith must preserve appendError when omitted',
      () {
        final original = SteadyPagedState<int, int>(
          items: const [1, 2],
          status: SteadyPagedStatus.loaded,
          nextKey: 3,
          error: StateError('append failed'),
          stackTrace: StackTrace.current,
          appendError: true,
        );

        final copied = original.copyWith(status: SteadyPagedStatus.loaded);

        expect(
          copied.appendError,
          isTrue,
          reason: 'copyWith defaults appendError to false instead of keeping '
              'the existing flag when the parameter is omitted',
        );
        expect(copied.error, same(original.error));
        expect(copied.items, original.items);

        final cleared = original.copyWith(clearError: true);
        expect(cleared.error, isNull);
        expect(cleared.stackTrace, isNull);
        expect(cleared.appendError, isFalse);
      },
    );

    testWidgets(
      'list, grid, and sliver must agree on empty non-terminal loadingMore UI',
      (tester) async {
        Future<_EmptyLoadMoreSurface> surfaceFor(
          Widget Function(
            SteadyPagedController<int, int> controller,
          ) buildPaged,
        ) async {
          final more = Completer<SteadyPage<int, int>>();
          final controller = SteadyPagedController<int, int>(
            firstPageKey: 0,
            loadPage: (key) async {
              if (key == 0) {
                return const SteadyPage<int, int>(items: [], nextKey: 1);
              }
              return more.future;
            },
          );

          // Drive first page outside the widget so loadMore can be started
          // deterministically without underfill races differing by widget.
          await controller.loadInitial();
          expect(controller.value.items, isEmpty);
          expect(controller.value.hasMore, isTrue);
          expect(controller.value.status, SteadyPagedStatus.loaded);

          final loadMore = controller.loadMore();
          expect(controller.value.status, SteadyPagedStatus.loadingMore);
          expect(controller.value.items, isEmpty);

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: buildPaged(controller),
              ),
            ),
          );
          await tester.pump();

          final fullPage = find.text('full-page-loading').evaluate().isNotEmpty;
          final append = find.text('append-loading').evaluate().isNotEmpty;

          more.complete(const SteadyPage<int, int>(items: [1]));
          await loadMore;
          controller.dispose();
          await tester.pumpWidget(const SizedBox.shrink());

          return _EmptyLoadMoreSurface(
            fullPageLoading: fullPage,
            appendLoading: append,
          );
        }

        final list = await surfaceFor(
          (controller) => SteadyPagedListView<int, int>(
            controller: controller,
            itemBuilder: (_, item, index) => Text('item $item'),
            loadingBuilder: (_, __) => const Text('full-page-loading'),
            appendLoadingBuilder: (_, __) => const Text('append-loading'),
          ),
        );
        final grid = await surfaceFor(
          (controller) => SteadyPagedGridView<int, int>(
            controller: controller,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
            ),
            itemBuilder: (_, item, index) => Text('item $item'),
            loadingBuilder: (_, __) => const Text('full-page-loading'),
            appendLoadingBuilder: (_, __) => const Text('append-loading'),
          ),
        );
        final sliver = await surfaceFor(
          (controller) => CustomScrollView(
            slivers: [
              SteadyPagedSliverList<int, int>(
                controller: controller,
                itemBuilder: (_, item, index) => Text('item $item'),
                loadingBuilder: (_, __) => const Text('full-page-loading'),
                appendLoadingBuilder: (_, __) => const Text('append-loading'),
              ),
            ],
          ),
        );

        // Correct contract: empty + hasMore + loadingMore is an append stage,
        // not a full-page initial load. List already does this; grid/sliver use
        // isBusy and show full-page loading instead.
        const expected = _EmptyLoadMoreSurface(
          fullPageLoading: false,
          appendLoading: true,
        );
        final observed = {
          'list': list,
          'grid': grid,
          'sliver': sliver,
        };
        final mismatches = [
          for (final entry in observed.entries)
            if (entry.value != expected) '${entry.key}=${entry.value}',
        ];
        expect(
          mismatches,
          isEmpty,
          reason: 'expected all surfaces $expected; mismatches: $mismatches',
        );
      },
    );

    testWidgets(
      'changing only successVisibleDuration must update owned action controller',
      (tester) async {
        var duration = const Duration(seconds: 5);
        late StateSetter rebuild;
        SteadyActionState<int>? latest;

        Widget app() => MaterialApp(
              home: StatefulBuilder(
                builder: (context, setState) {
                  rebuild = setState;
                  return SteadyActionBuilder<int>(
                    action: () async => 1,
                    successVisibleDuration: duration,
                    builder: (context, state, run) {
                      latest = state;
                      return Column(
                        children: [
                          Text('status:${state.status.name}'),
                          TextButton(
                            onPressed: () => unawaited(run()),
                            child: const Text('run'),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            );

        await tester.pumpWidget(app());
        // Replace only the success visibility duration on the same builder.
        rebuild(() => duration = const Duration(milliseconds: 10));
        await tester.pump();

        await tester.tap(find.text('run'));
        await tester.pump(); // start
        await tester.pump(); // complete -> success

        expect(latest?.isSuccess, isTrue);

        // With a 10ms success window the controller should return to idle.
        // Owned controllers ignore successVisibleDuration changes and keep the
        // duration captured at first attach (here 5 seconds).
        await tester.pump(const Duration(milliseconds: 30));

        expect(
          latest?.status,
          SteadyActionStatus.idle,
          reason: 'SteadyActionBuilder only rebuilds its owned controller when '
              'controller or concurrency changes, not successVisibleDuration',
        );
      },
    );
  });
}

const _instantPolicy = SteadyTransitionPolicy(
  loadingDelay: Duration.zero,
  minimumLoadingDuration: Duration.zero,
  transitionDuration: Duration.zero,
);

@immutable
class _EmptyLoadMoreSurface {
  const _EmptyLoadMoreSurface({
    required this.fullPageLoading,
    required this.appendLoading,
  });

  final bool fullPageLoading;
  final bool appendLoading;

  @override
  bool operator ==(Object other) =>
      other is _EmptyLoadMoreSurface &&
      other.fullPageLoading == fullPageLoading &&
      other.appendLoading == appendLoading;

  @override
  int get hashCode => Object.hash(fullPageLoading, appendLoading);

  @override
  String toString() =>
      '_EmptyLoadMoreSurface(fullPageLoading: $fullPageLoading, '
      'appendLoading: $appendLoading)';
}
