import 'package:flutter/material.dart';
import 'package:steady_async/steady_async.dart';

void main() => runApp(const SmokeApp());

class SmokeApp extends StatefulWidget {
  const SmokeApp({super.key});

  @override
  State<SmokeApp> createState() => _SmokeAppState();
}

class _SmokeAppState extends State<SmokeApp> {
  late final SteadyPagedController<int, int> pages;

  @override
  void initState() {
    super.initState();
    pages = SteadyPagedController(
      firstPageKey: 0,
      itemKey: (item) => item,
      seed: const SteadyPagedSeed(items: [1, 2], nextKey: 1),
      loadPage: (key) async => SteadyPage(
        items: [key * 2 + 1, key * 2 + 2],
        nextKey: key >= 2 ? null : key + 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: const Text('steady_async smoke')),
      body: SteadyPagedGridView<int, int>(
        controller: pages,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
        ),
        itemBuilder: (_, item, _) => Center(child: Text('$item')),
      ),
    ),
  );

  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }
}
