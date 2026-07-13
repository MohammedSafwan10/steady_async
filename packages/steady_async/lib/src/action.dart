import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'localization.dart';
import 'theme.dart';

/// Visible stages of an asynchronous action.
enum SteadyActionStatus { idle, running, success, error }

/// Determines how calls made while an action is running are handled.
enum SteadyActionConcurrency { drop, latestWins, sequential }

/// Immutable state for a submit, save, delete, or similar async action.
@immutable
class SteadyActionState<T> {
  const SteadyActionState._({
    required this.status,
    this.value,
    this.error,
    this.stackTrace,
  });

  const SteadyActionState.idle() : this._(status: SteadyActionStatus.idle);
  const SteadyActionState.running()
      : this._(status: SteadyActionStatus.running);
  const SteadyActionState.success(T value)
      : this._(status: SteadyActionStatus.success, value: value);
  const SteadyActionState.error(Object error, [StackTrace? stackTrace])
      : this._(
          status: SteadyActionStatus.error,
          error: error,
          stackTrace: stackTrace,
        );

  /// The current action stage.
  final SteadyActionStatus status;

  /// The most recent successful result.
  final T? value;

  /// The most recent failure.
  final Object? error;

  /// Stack trace associated with [error].
  final StackTrace? stackTrace;

  /// Whether work is currently in progress.
  bool get isRunning => status == SteadyActionStatus.running;

  /// Whether the action completed successfully.
  bool get isSuccess => status == SteadyActionStatus.success;

  /// Whether the last accepted call failed.
  bool get hasError => status == SteadyActionStatus.error;
}

/// A retry-safe factory for an asynchronous action.
typedef SteadyAction<T> = Future<T> Function();

/// Runs actions with duplicate-call protection and stale-result guards.
class SteadyActionController<T> extends ChangeNotifier
    implements ValueListenable<SteadyActionState<T>> {
  /// Creates a controller for [action].
  SteadyActionController(
    SteadyAction<T> action, {
    this.concurrency = SteadyActionConcurrency.drop,
    this.successVisibleDuration = const Duration(milliseconds: 800),
  }) : _action = action;

  SteadyAction<T> _action;
  final SteadyActionConcurrency concurrency;
  final Duration successVisibleDuration;
  SteadyActionState<T> _value = const SteadyActionState.idle();
  Future<void> _queue = Future<void>.value();
  Timer? _successTimer;
  int _generation = 0;
  bool _disposed = false;

  /// The latest public action state.
  @override
  SteadyActionState<T> get value => _value;

  /// Replaces the factory used by future calls.
  void updateAction(SteadyAction<T> action) => _action = action;

  /// Runs or schedules the action according to [concurrency].
  Future<T?> run() {
    if (_disposed) return Future<T?>.value();
    if (concurrency == SteadyActionConcurrency.drop && _value.isRunning) {
      return Future<T?>.value();
    }
    if (concurrency == SteadyActionConcurrency.sequential) {
      final completer = Completer<T?>();
      _queue = _queue.then((_) async {
        try {
          completer.complete(await _execute());
        } catch (error, stackTrace) {
          completer.completeError(error, stackTrace);
        }
      });
      return completer.future;
    }
    return _execute();
  }

  Future<T?> _execute() async {
    if (_disposed) return null;
    _successTimer?.cancel();
    final generation = ++_generation;
    _setValue(SteadyActionState<T>.running());
    try {
      final result = await Future<T>.sync(_action);
      if (_accepts(generation)) {
        _setValue(SteadyActionState<T>.success(result));
        if (successVisibleDuration > Duration.zero) {
          _successTimer = Timer(successVisibleDuration, () {
            if (_accepts(generation) && _value.isSuccess) reset();
          });
        }
      }
      return result;
    } catch (error, stackTrace) {
      if (_accepts(generation)) {
        _setValue(SteadyActionState<T>.error(error, stackTrace));
      }
      return null;
    }
  }

  /// Returns to idle and invalidates results from active calls.
  void reset() {
    _successTimer?.cancel();
    _successTimer = null;
    _generation++;
    _setValue(SteadyActionState<T>.idle());
  }

  bool _accepts(int generation) => !_disposed && generation == _generation;

  void _setValue(SteadyActionState<T> next) {
    if (_disposed) return;
    _value = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _successTimer?.cancel();
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

/// Builds UI from an action state and a function that starts the action.
typedef SteadyActionWidgetBuilder<T> = Widget Function(
  BuildContext context,
  SteadyActionState<T> state,
  Future<T?> Function() run,
);

/// Stateful convenience widget for an asynchronous action.
class SteadyActionBuilder<T> extends StatefulWidget {
  /// Creates an action builder.
  const SteadyActionBuilder({
    required this.action,
    required this.builder,
    this.controller,
    this.concurrency = SteadyActionConcurrency.drop,
    this.successVisibleDuration,
    super.key,
  });

  /// Retry-safe action factory.
  final SteadyAction<T> action;

  /// Builds the action UI.
  final SteadyActionWidgetBuilder<T> builder;

  /// Optional externally owned controller.
  final SteadyActionController<T>? controller;

  /// Policy applied to overlapping calls.
  final SteadyActionConcurrency concurrency;

  /// Time that success UI remains visible before resetting.
  final Duration? successVisibleDuration;

  @override
  State<SteadyActionBuilder<T>> createState() => _SteadyActionBuilderState<T>();
}

class _SteadyActionBuilderState<T> extends State<SteadyActionBuilder<T>> {
  late SteadyActionController<T> _controller;
  late bool _ownsController;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        SteadyActionController<T>(
          widget.action,
          concurrency: widget.concurrency,
          successVisibleDuration: widget.successVisibleDuration ??
              const Duration(milliseconds: 800),
        );
    _controller.updateAction(widget.action);
  }

  @override
  void didUpdateWidget(covariant SteadyActionBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.concurrency != widget.concurrency) {
      if (_ownsController) _controller.dispose();
      _attach();
    } else {
      _controller.updateAction(widget.action);
    }
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<SteadyActionState<T>>(
        valueListenable: _controller,
        builder: (context, state, _) =>
            widget.builder(context, state, _controller.run),
      );

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }
}

/// Material button with automatic running, success, and retry states.
class SteadyButton<T> extends StatelessWidget {
  /// Creates a steady action button.
  const SteadyButton({
    required this.action,
    required this.child,
    this.controller,
    this.successChild,
    this.errorChild,
    this.icon,
    this.concurrency = SteadyActionConcurrency.drop,
    this.style,
    super.key,
  });

  /// Retry-safe callback invoked by the button.
  final SteadyAction<T> action;

  /// Idle button content.
  final Widget child;

  /// Optional externally owned action controller.
  final SteadyActionController<T>? controller;

  /// Content shown after success.
  final Widget? successChild;

  /// Content shown after failure.
  final Widget? errorChild;

  /// Optional leading icon while idle.
  final Widget? icon;

  /// Policy applied to repeated taps.
  final SteadyActionConcurrency concurrency;

  /// Optional Material button style.
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) => SteadyActionBuilder<T>(
        action: action,
        controller: controller,
        concurrency: concurrency,
        successVisibleDuration: SteadyTheme.of(context).successVisibleDuration,
        builder: (context, state, run) {
          final messages = SteadyTheme.of(context).messages ??
              SteadyMessages.resolve(context);
          final content = switch (state.status) {
            SteadyActionStatus.idle => child,
            SteadyActionStatus.running => const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            SteadyActionStatus.success => successChild ??
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check, size: 18),
                    const SizedBox(width: 8),
                    Text(messages.success),
                  ],
                ),
            SteadyActionStatus.error => errorChild ??
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh, size: 18),
                    const SizedBox(width: 8),
                    Text(messages.retry),
                  ],
                ),
          };
          return Semantics(
            liveRegion: true,
            button: true,
            child: FilledButton.icon(
              style: style,
              onPressed:
                  state.isRunning && concurrency == SteadyActionConcurrency.drop
                      ? null
                      : () => unawaited(run()),
              icon: state.status == SteadyActionStatus.idle
                  ? icon ?? const SizedBox.shrink()
                  : const SizedBox.shrink(),
              label: AnimatedSwitcher(
                duration:
                    MediaQuery.maybeOf(context)?.disableAnimations ?? false
                        ? Duration.zero
                        : const Duration(milliseconds: 160),
                child:
                    KeyedSubtree(key: ValueKey(state.status), child: content),
              ),
            ),
          );
        },
      );
}
