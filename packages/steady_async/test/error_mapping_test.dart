import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_async/steady_async.dart';

void main() {
  testWidgets('async defaults apply typed error presentation and semantics', (
    tester,
  ) async {
    final failure = SteadyFailure.external(StateError('technical'));

    await tester.pumpWidget(
      MaterialApp(
        home: SteadyTheme(
          data: SteadyThemeData(
            errorMapper: (_, value) {
              expect(value, same(failure));
              return const SteadyErrorPresentation(
                message: 'You appear to be offline.',
                retryLabel: 'Try connection',
                semanticsLabel: 'Network request failed',
              );
            },
          ),
          child: SteadyStateView<int>(
            state: SteadyAsyncState.error(
              failure.error,
              failure: failure,
            ),
            onRetry: () {},
            dataBuilder: (_, value) => Text('$value'),
          ),
        ),
      ),
    );

    expect(find.text('You appear to be offline.'), findsOneWidget);
    expect(find.text('Try connection'), findsOneWidget);
    final semantics = tester.getSemantics(find.byType(SteadyDefaultErrorView));
    expect(semantics.label, contains('Network request failed'));
  });

  testWidgets('custom async error builder bypasses the theme mapper', (
    tester,
  ) async {
    var mapperCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SteadyTheme(
          data: SteadyThemeData(
            errorMapper: (_, __) {
              mapperCalls++;
              return const SteadyErrorPresentation(message: 'mapped');
            },
          ),
          child: SteadyStateView<int>(
            state: SteadyAsyncState.error(StateError('failed')),
            errorBuilder: (_, state, __) => Text('custom ${state.error}'),
            dataBuilder: (_, value) => Text('$value'),
          ),
        ),
      ),
    );

    expect(find.textContaining('custom'), findsOneWidget);
    expect(mapperCalls, 0);
  });

  testWidgets('retained async errors apply mapped semantics', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SteadyTheme(
          data: SteadyThemeData(
            errorMapper: (_, __) => const SteadyErrorPresentation(
              message: 'Refresh failed',
              semanticsLabel: 'Retained refresh failed',
            ),
          ),
          child: SteadyStateView<int>(
            state: SteadyAsyncState.error(
              StateError('technical'),
              previousValue: 1,
              hasPreviousValue: true,
            ),
            dataBuilder: (_, value) => Text('value $value'),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(RegExp('Retained refresh failed')),
      findsOneWidget,
    );
  });

  testWidgets('action defaults honor hidden retry presentation', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SteadyTheme(
          data: SteadyThemeData(
            errorMapper: (_, __) => const SteadyErrorPresentation(
              message: 'Payment failed',
              retryLabel: 'Pay again',
              semanticsLabel: 'Payment could not complete',
              showRetry: false,
            ),
          ),
          child: Scaffold(
            body: SteadyButton<void>(
              action: () async {
                calls++;
                throw StateError('gateway');
              },
              child: const Text('Pay'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Pay'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Pay again'), findsOneWidget);
    final actionButton = find.ancestor(
      of: find.text('Pay again'),
      matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
    );
    expect(
      tester.widget<ButtonStyleButton>(actionButton).onPressed,
      isNull,
    );
    expect(calls, 1);
  });

  testWidgets('pagination append errors use mapped retry UI', (tester) async {
    var failAppend = true;
    final controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      loadPage: (key) async {
        if (key == 0) return const SteadyPage(items: [1], nextKey: 1);
        if (failAppend) throw StateError('offline');
        return const SteadyPage(items: [2]);
      },
    );
    await controller.loadInitial();
    await controller.loadMore();

    await tester.pumpWidget(
      MaterialApp(
        home: SteadyTheme(
          data: SteadyThemeData(
            errorMapper: (_, __) => const SteadyErrorPresentation(
              message: 'No network',
              retryLabel: 'Load page again',
            ),
          ),
          child: SteadyPagedListView<int, int>(
            controller: controller,
            itemBuilder: (_, item, __) => Text('$item'),
          ),
        ),
      ),
    );

    expect(find.text('No network'), findsOneWidget);
    expect(find.text('Load page again'), findsOneWidget);
    failAppend = false;
    await tester.tap(find.text('Load page again'));
    await tester.pump();
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('retained pagination errors apply mapped semantics',
      (tester) async {
    var fail = false;
    final controller = SteadyPagedController<int, int>(
      firstPageKey: 0,
      loadPage: (_) async {
        if (fail) throw StateError('offline');
        return const SteadyPage(items: [1]);
      },
    );
    await controller.loadInitial();
    fail = true;
    await controller.refresh();

    await tester.pumpWidget(
      MaterialApp(
        home: SteadyTheme(
          data: SteadyThemeData(
            errorMapper: (_, __) => const SteadyErrorPresentation(
              message: 'Could not refresh',
              semanticsLabel: 'Paged refresh failed',
            ),
          ),
          child: SteadyPagedListView<int, int>(
            controller: controller,
            itemBuilder: (_, item, __) => Text('$item'),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(RegExp('Paged refresh failed')),
      findsOneWidget,
    );
    controller.dispose();
  });
}
