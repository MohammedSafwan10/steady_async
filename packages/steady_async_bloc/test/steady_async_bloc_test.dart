import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_async/steady_async.dart';
import 'package:steady_async_bloc/steady_async_bloc.dart';

class _TestCubit extends Cubit<SteadyAsyncState<int>> {
  _TestCubit() : super(const SteadyAsyncState.idle());

  void show(int value) => emit(SteadyAsyncState.data(value));
}

void main() {
  testWidgets('maps Cubit state through BlocSelector', (tester) async {
    final cubit = _TestCubit();
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: SteadyBlocView<_TestCubit, SteadyAsyncState<int>, int>(
            selector: (state) => state,
            dataBuilder: (_, value) => Text('$value'),
          ),
        ),
      ),
    );

    cubit.show(9);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 201));
    expect(find.text('9'), findsOneWidget);
    await cubit.close();
  });
}
