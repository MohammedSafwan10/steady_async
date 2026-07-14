import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steady_async/steady_async.dart';
import 'package:steady_async_bloc/steady_async_bloc.dart';

class GreetingCubit extends Cubit<SteadyAsyncState<String>> {
  GreetingCubit() : super(const SteadyAsyncState.idle());

  Future<void> load() async {
    emit(const SteadyAsyncState.loading());
    await Future<void>.delayed(const Duration(milliseconds: 700));
    emit(const SteadyAsyncState.data('Loaded from Cubit'));
  }
}

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => GreetingCubit()..load(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: SteadyBlocView<GreetingCubit, SteadyAsyncState<String>,
                    String>(
                  selector: (state) => state,
                  onRetry: () => context.read<GreetingCubit>().load(),
                  dataBuilder: (context, greeting) => Text(greeting),
                ),
              ),
            ),
          ),
        ),
      );
}
