import 'package:flutter_test/flutter_test.dart';
import 'package:steady_async/steady_async.dart';

void main() {
  test('local-path consumer can execute request and pagination APIs', () async {
    final request = SteadyAsyncController<int>(
      () async => 7,
      requestPolicy: const SteadyRequestPolicy(),
    );
    await request.load();
    expect(request.value.valueOrNull, 7);

    final pages = SteadyPagedController<int, int>(
      firstPageKey: 0,
      itemKey: (item) => item,
      loadPage: (_) async => const SteadyPage(items: [1]),
    );
    await pages.loadInitial();
    final removal = pages.optimisticRemoveByKey(1);
    expect(removal.rollback(), isTrue);
    expect(pages.value.items, [1]);

    request.dispose();
    pages.dispose();
  });
}
