import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:steady_async/steady_async.dart';
import 'package:steady_async_riverpod/steady_async_riverpod.dart';

final greetingProvider = FutureProvider<String>((ref) async {
  await Future<void>.delayed(const Duration(milliseconds: 700));
  return 'Loaded from AsyncValue';
});

final signedInUserProvider = Provider<String?>((ref) => 'demo-user');

final messagesPagerProvider =
    Provider.autoDispose<SteadyPagedController<String, String?>>((ref) {
      final userId = ref.watch(signedInUserProvider);
      final controller = SteadyPagedController<String, String?>(
        firstPageKey: null,
        itemKey: (message) => message,
        loadPage: (cursor) async {
          if (userId == null) return const SteadyPage(items: []);
          return cursor == null
              ? const SteadyPage(
                items: ['Message 1', 'Message 2'],
                nextKey: '2',
              )
              : const SteadyPage(items: ['Message 3']);
        },
      );
      ref.onDispose(controller.dispose);
      unawaited(controller.loadInitial());
      return controller;
    });

void main() => runApp(const ProviderScope(child: ExampleApp()));

class ExampleApp extends ConsumerWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pager = ref.watch(messagesPagerProvider);
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('steady_async_riverpod')),
        body: Column(
          children: [
            SizedBox(
              height: 100,
              child: Center(
                child: SteadyRiverpodView<String>(
                  value: ref.watch(greetingProvider),
                  onRetry: () => ref.invalidate(greetingProvider),
                  dataBuilder: (context, greeting) => Text(greeting),
                ),
              ),
            ),
            Expanded(
              child: SteadyPagedListView<String, String?>(
                controller: pager,
                itemBuilder:
                    (context, message, index) => ListTile(title: Text(message)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
