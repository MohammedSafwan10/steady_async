# steady_async_bloc

BLoC and Cubit integration for
[`steady_async`](https://pub.dev/packages/steady_async). It requires only a
typed selector; no special state classes or base BLoC are imposed.

```yaml
dependencies:
  steady_async_bloc: ^0.1.0
```

```dart
SteadyBlocView<UsersCubit, UsersState, List<User>>(
  selector: (state) => state.users,
  onRetry: () => context.read<UsersCubit>().reload(),
  dataBuilder: (context, users) => UsersList(users),
)
```

Use `SteadyBlocView.withBuildWhen` when application-specific rebuild filtering
is required. Both Cubit and Bloc are supported without package base classes.
