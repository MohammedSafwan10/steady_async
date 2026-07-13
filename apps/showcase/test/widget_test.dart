import 'package:flutter_test/flutter_test.dart';
import 'package:steady_async_showcase/main.dart';

void main() {
  testWidgets('renders the interactive showcase', (tester) async {
    await tester.pumpWidget(const SteadyShowcaseApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.textContaining('Loading, retry'), findsOneWidget);
    expect(find.text('Request lab'), findsOneWidget);
    expect(find.text('steady_async'), findsWidgets);
  });
}
