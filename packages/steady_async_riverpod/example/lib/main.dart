import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:steady_async_riverpod/steady_async_riverpod.dart';

final greetingProvider = FutureProvider<String>((ref) async {
  await Future<void>.delayed(const Duration(milliseconds: 700));
  return 'AsyncValue, with calmer UX';
});

void main() => runApp(const ProviderScope(child: ExampleApp()));

class ExampleApp extends ConsumerWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: SteadyRiverpodView<String>(
          value: ref.watch(greetingProvider),
          onRetry: () => ref.invalidate(greetingProvider),
          dataBuilder: (context, greeting) => Text(greeting),
        ),
      ),
    ),
  );
}
