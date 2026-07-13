import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_async/steady_async.dart';

void main() {
  testWidgets('replaces streams and recovers after an error', (tester) async {
    final first = StreamController<String>();
    final second = StreamController<String>();

    await tester.pumpWidget(_app(() => first.stream));
    first.add('first');
    await tester.pump();
    expect(find.text('first'), findsOneWidget);

    first.addError(StateError('offline'));
    await tester.pump();
    expect(find.text('first'), findsOneWidget);

    first.add('recovered');
    await tester.pump();
    expect(find.text('recovered'), findsOneWidget);

    await tester.pumpWidget(_app(() => second.stream));
    expect(find.text('recovered'), findsOneWidget);
    second.add('replacement');
    await tester.pump();
    expect(find.text('replacement'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    first.add('obsolete');
    second.add('disposed');
    await tester.pump();
    expect(tester.takeException(), isNull);

    unawaited(first.close());
    unawaited(second.close());
  });
}

Widget _app(Stream<String> Function() stream) => MaterialApp(
      home: SteadyStreamBuilder<String>(
        stream: stream,
        policy: const SteadyTransitionPolicy(
          loadingDelay: Duration.zero,
          minimumLoadingDuration: Duration.zero,
          transitionDuration: Duration.zero,
        ),
        dataBuilder: (context, value) => Text(value),
      ),
    );
