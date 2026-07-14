import 'dart:async';

import 'package:flutter/material.dart';
import 'package:steady_async/steady_async.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  Future<List<String>> _loadItems() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return const ['Delayed loader', 'Retry', 'Data retained during refresh'];
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        theme: ThemeData(colorSchemeSeed: const Color(0xFF5B5BD6)),
        home: Scaffold(
          appBar: AppBar(title: const Text('steady_async')),
          body: SteadyAsyncBuilder<List<String>>(
            load: _loadItems,
            isEmpty: (items) => items.isEmpty,
            dataBuilder: (context, items) => ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) => ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text(items[index]),
              ),
            ),
          ),
        ),
      );
}
