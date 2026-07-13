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
}
