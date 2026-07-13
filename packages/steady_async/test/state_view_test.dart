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
