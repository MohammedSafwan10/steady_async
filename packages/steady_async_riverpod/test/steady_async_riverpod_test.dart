import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_async/steady_async.dart';
import 'package:steady_async_riverpod/steady_async_riverpod.dart';

void main() {
  test('maps data, loading progress, and errors', () {
    expect(
      const AsyncData<int>(7).toSteadyState(),
      const SteadyAsyncState<int>.data(7),
    );

    final loading = const AsyncLoading<int>(progress: 0.4).toSteadyState();
    expect(loading, isA<SteadyLoading<int>>());
    expect((loading as SteadyLoading<int>).progress, 0.4);

    final error = StateError('failed');
    final mapped = AsyncError<int>(error, StackTrace.empty).toSteadyState();
    expect(mapped, isA<SteadyError<int>>());
    expect((mapped as SteadyError<int>).error, same(error));
  });

  test('autoDispose owns a nullable-cursor paged controller', () async {
    var calls = 0;
    var disposed = false;
    final pagerProvider =
        Provider.autoDispose<SteadyPagedController<int, String?>>((ref) {
          final controller = SteadyPagedController<int, String?>(
            firstPageKey: null,
            loadPage: (cursor) async {
              calls++;
              return cursor == null
                  ? const SteadyPage(items: [1], nextKey: 'next')
                  : const SteadyPage(items: [2]);
            },
          );
          ref.onDispose(() {
            disposed = true;
            controller.dispose();
          });
          return controller;
        });
    final container = ProviderContainer();
    final subscription = container.listen(pagerProvider, (_, _) {});
    final controller = container.read(pagerProvider);

    await controller.loadInitial();
    await controller.loadMore();
    expect(controller.value.items, [1, 2]);
    expect(calls, 2);

    subscription.close();
    container.dispose();
    expect(disposed, isTrue);
  });
}
