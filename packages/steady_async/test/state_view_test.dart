import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_async/steady_async.dart';

void main() {
  testWidgets('quick operation never flashes a loader', (tester) async {
    final result = Completer<String>();
    await tester.pumpWidget(
      MaterialApp(
        home: SteadyAsyncBuilder<String>(
          load: () => result.future,
          dataBuilder: (_, value) => Text(value),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    result.complete('ready');
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 201));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('ready'), findsOneWidget);
  });

  testWidgets('visible loader respects its minimum duration', (tester) async {
    final result = Completer<String>();
    await tester.pumpWidget(
      MaterialApp(
        home: SteadyAsyncBuilder<String>(
          load: () => result.future,
          dataBuilder: (_, value) => Text(value),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 201));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    result.complete('ready');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 151));
    expect(find.text('ready'), findsOneWidget);
  });

  testWidgets('progress updates do not restart the loader delay', (
    tester,
  ) async {
    SteadyAsyncState<int> state = const SteadyAsyncState.loading(progress: 0);
    late StateSetter rebuild;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return SteadyStateView<int>(
              state: state,
              policy: const SteadyTransitionPolicy(
                loadingDelay: Duration(milliseconds: 200),
                minimumLoadingDuration: Duration.zero,
                transitionDuration: Duration.zero,
              ),
              dataBuilder: (_, value) => Text('$value'),
            );
          },
        ),
      ),
    );
    await tester.pump();

    for (var progress = 1; progress <= 3; progress++) {
      await tester.pump(const Duration(milliseconds: 60));
      rebuild(() {
        state = SteadyAsyncState.loading(progress: progress / 10);
      });
      await tester.pump();
    }
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pump(const Duration(milliseconds: 21));
    final indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(indicator.value, 0.3);
  });

  testWidgets('refresh keeps previous data before revealing progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SteadyStateView<List<String>>(
          state: SteadyAsyncState.loading(
            previousValue: ['saved'],
            hasPreviousValue: true,
            phase: SteadyLoadingPhase.refresh,
          ),
          dataBuilder: _listBuilder,
        ),
      ),
    );
    expect(find.text('saved'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.pump(const Duration(milliseconds: 201));
    await tester.pump(const Duration(milliseconds: 201));
    expect(find.text('saved'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('keepPreviousData false replaces retained content with loader', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SteadyStateView<List<String>>(
          state: SteadyAsyncState.loading(
            previousValue: ['saved'],
            hasPreviousValue: true,
            phase: SteadyLoadingPhase.refresh,
          ),
          policy: SteadyTransitionPolicy(
            loadingDelay: Duration.zero,
            minimumLoadingDuration: Duration.zero,
            transitionDuration: Duration.zero,
            keepPreviousData: false,
          ),
          dataBuilder: _listBuilder,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('saved'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('keepPreviousData false hides data during a nonzero delay', (
    tester,
  ) async {
    SteadyAsyncState<List<String>> state =
        const SteadyAsyncState.data(['saved']);
    late StateSetter rebuild;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return SteadyStateView<List<String>>(
              state: state,
              policy: const SteadyTransitionPolicy(
                loadingDelay: Duration(milliseconds: 200),
                minimumLoadingDuration: Duration.zero,
                transitionDuration: Duration.zero,
                keepPreviousData: false,
              ),
              dataBuilder: _listBuilder,
            );
          },
        ),
      ),
    );
    expect(find.text('saved'), findsOneWidget);

    rebuild(() {
      state = const SteadyAsyncState.loading(
        previousValue: ['saved'],
        hasPreviousValue: true,
        phase: SteadyLoadingPhase.refresh,
      );
    });
    await tester.pump();
    expect(find.text('saved'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pump(const Duration(milliseconds: 201));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('quick loading completion stays blank instead of retaining data',
      (
    tester,
  ) async {
    SteadyAsyncState<List<String>> state =
        const SteadyAsyncState.data(['saved']);
    late StateSetter rebuild;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return SteadyStateView<List<String>>(
              state: state,
              policy: const SteadyTransitionPolicy(
                loadingDelay: Duration(milliseconds: 200),
                minimumLoadingDuration: Duration.zero,
                transitionDuration: Duration.zero,
                keepPreviousData: false,
              ),
              dataBuilder: _listBuilder,
            );
          },
        ),
      ),
    );

    rebuild(() {
      state = const SteadyAsyncState.loading(
        previousValue: ['saved'],
        hasPreviousValue: true,
        phase: SteadyLoadingPhase.refresh,
      );
    });
    await tester.pump();
    expect(find.text('saved'), findsNothing);

    rebuild(() => state = const SteadyAsyncState.data(['fresh']));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('fresh'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('runtime policy replacement updates retained loading content', (
    tester,
  ) async {
    var keepPreviousData = true;
    late StateSetter rebuild;
    const loading = SteadyAsyncState<List<String>>.loading(
      previousValue: ['saved'],
      hasPreviousValue: true,
      phase: SteadyLoadingPhase.refresh,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return SteadyStateView<List<String>>(
              state: loading,
              policy: SteadyTransitionPolicy(
                loadingDelay: const Duration(seconds: 1),
                keepPreviousData: keepPreviousData,
              ),
              dataBuilder: _listBuilder,
            );
          },
        ),
      ),
    );
    expect(find.text('saved'), findsOneWidget);

    rebuild(() => keepPreviousData = false);
    await tester.pump();

    expect(find.text('saved'), findsNothing);
  });

  testWidgets('inherited policy replacement updates retained loading content', (
    tester,
  ) async {
    var keepPreviousData = true;
    late StateSetter rebuild;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return SteadyTheme(
              data: SteadyThemeData(
                policy: SteadyTransitionPolicy(
                  loadingDelay: const Duration(seconds: 1),
                  keepPreviousData: keepPreviousData,
                ),
              ),
              child: const SteadyStateView<List<String>>(
                state: SteadyAsyncState.loading(
                  previousValue: ['saved'],
                  hasPreviousValue: true,
                  phase: SteadyLoadingPhase.refresh,
                ),
                dataBuilder: _listBuilder,
              ),
            );
          },
        ),
      ),
    );
    expect(find.text('saved'), findsOneWidget);

    rebuild(() => keepPreviousData = false);
    await tester.pump();

    expect(find.text('saved'), findsNothing);
  });

  testWidgets('replacement idle async controller honors autoStart', (
    tester,
  ) async {
    var firstCalls = 0;
    var secondCalls = 0;
    final first = SteadyAsyncController<int>(() async => -1);
    final second = SteadyAsyncController<int>(() async => -1);
    var active = first;
    late StateSetter rebuild;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            final load = identical(active, first)
                ? () async => ++firstCalls
                : () async => ++secondCalls;
            return SteadyAsyncBuilder<int>(
              controller: active,
              load: load,
              policy: const SteadyTransitionPolicy(
                loadingDelay: Duration.zero,
                minimumLoadingDuration: Duration.zero,
                transitionDuration: Duration.zero,
              ),
              dataBuilder: (_, value) => Text('$value'),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(firstCalls, 1);

    rebuild(() => active = second);
    await tester.pump();
    await tester.pump();

    expect(secondCalls, 1);
    expect(find.text('1'), findsOneWidget);
    first.dispose();
    second.dispose();
  });

  testWidgets('inline cancellable loader survives an ordinary parent rebuild',
      (tester) async {
    final result = Completer<int>();
    var calls = 0;
    var cancellations = 0;
    var rebuilds = 0;
    late StateSetter rebuild;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Column(
              children: [
                Text('$rebuilds'),
                SteadyAsyncBuilder<int>.cancellable(
                  load: () {
                    calls++;
                    return SteadyCancellableOperation(
                      future: result.future,
                      cancel: () => cancellations++,
                    );
                  },
                  dataBuilder: (_, value) => Text('value $value'),
                ),
              ],
            );
          },
        ),
      ),
    );
    await tester.pump();
    rebuild(() => rebuilds++);
    await tester.pump();

    expect(calls, 1);
    expect(cancellations, 0);
    result.complete(7);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('value 7'), findsOneWidget);
  });

  testWidgets('inline cancellable action keeps running across parent rebuild',
      (tester) async {
    final result = Completer<int>();
    var calls = 0;
    var cancellations = 0;
    var rebuilds = 0;
    late StateSetter rebuild;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Column(
              children: [
                Text('$rebuilds'),
                SteadyActionBuilder<int>.cancellable(
                  action: () {
                    calls++;
                    return SteadyCancellableOperation(
                      future: result.future,
                      cancel: () => cancellations++,
                    );
                  },
                  builder: (context, state, run) => TextButton(
                    onPressed: run,
                    child: Text(state.status.name),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('idle'));
    await tester.pump();
    expect(find.text('running'), findsOneWidget);

    rebuild(() => rebuilds++);
    await tester.pump();
    expect(find.text('running'), findsOneWidget);
    expect(calls, 1);
    expect(cancellations, 0);

    result.complete(7);
    await tester.pump();
    expect(find.text('success'), findsOneWidget);
  });

  testWidgets('initial non-idle external controller is not auto-started', (
    tester,
  ) async {
    var calls = 0;
    final controller = SteadyAsyncController<int>(() async {
      calls++;
      return 7;
    });
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        home: SteadyAsyncBuilder<int>(
          controller: controller,
          load: () async {
            calls++;
            return 9;
          },
          dataBuilder: (_, value) => Text('$value'),
        ),
      ),
    );
    await tester.pump();

    expect(calls, 1);
    expect(find.text('7'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('controller and loader replacement still honors reload flag', (
    tester,
  ) async {
    final first = SteadyAsyncController<int>(() async => 0);
    final second = SteadyAsyncController<int>(() async => 99);
    await second.load();
    var replacementCalls = 0;
    var active = first;
    late StateSetter rebuild;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            final load = identical(active, first)
                ? () async => 0
                : () async => ++replacementCalls;
            return SteadyAsyncBuilder<int>(
              controller: active,
              load: load,
              autoStart: false,
              reloadOnLoaderChange: true,
              policy: const SteadyTransitionPolicy(
                loadingDelay: Duration.zero,
                minimumLoadingDuration: Duration.zero,
                transitionDuration: Duration.zero,
              ),
              dataBuilder: (_, value) => Text('$value'),
            );
          },
        ),
      ),
    );

    rebuild(() => active = second);
    await tester.pump();
    await tester.pump();

    expect(replacementCalls, 1);
    expect(find.text('1'), findsOneWidget);
    first.dispose();
    second.dispose();
  });

  testWidgets('uses Arabic default messages and RTL context', (tester) async {
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('ar'),
        delegates: const [DefaultWidgetsLocalizations.delegate],
        child: const Directionality(
          textDirection: TextDirection.rtl,
          child: Material(
            child: SteadyStateView<List<String>>(
              state: SteadyAsyncState.data([]),
              dataBuilder: _listBuilder,
            ),
          ),
        ),
      ),
    );
    expect(find.text('لا يوجد شيء هنا بعد'), findsOneWidget);
  });
}

Widget _listBuilder(BuildContext context, List<String> value) =>
    Text(value.join(','));
