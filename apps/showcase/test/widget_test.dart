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

  testWidgets('sending a request does not move the page', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const SteadyShowcaseApp());
    await tester.pump(const Duration(seconds: 2));
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    final before = scrollable.position.pixels;

    await tester.tap(find.text('Send request'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(scrollable.position.pixels, before);
    expect(find.text('Running · 800 ms'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('interactive scenarios show failure and retry states', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const SteadyShowcaseApp());
    await tester.scrollUntilVisible(
      find.text('Load with error'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load with error'));
    await tester.pump(const Duration(milliseconds: 1300));

    expect(find.text('Could not load projects'), findsOneWidget);
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, 180),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.text('Mobile checkout'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
