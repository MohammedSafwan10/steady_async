import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_async_showcase/showcase.dart';

void main() {
  testWidgets('renders the complete desktop showcase', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const SteadyShowcaseApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Loading, retry'), findsOneWidget);
    expect(find.text('Request lab'), findsOneWidget);
    expect(find.text('steady_async'), findsWidgets);
    expect(find.widgetWithText(TextButton, 'Demo'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'GitHub'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Features'));
    await tester.pumpAndSettle();
    expect(find.text('Loader timing built in'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(TextButton, 'Adapters'));
    await tester.pumpAndSettle();
    expect(
      find.text('Use the state manager you already have.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile menu navigates without layout errors', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const SteadyShowcaseApp());
    await tester.pump();
    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Features').last);
    await tester.pumpAndSettle();

    expect(find.text('Loader timing built in'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
