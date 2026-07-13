import 'dart:async';

import 'package:flutter/widgets.dart';

import 'async_controller.dart';
import 'async_state.dart';
import 'policy.dart';
import 'state_view.dart';

/// Future-powered convenience wrapper around [SteadyStateView].
class SteadyAsyncBuilder<T> extends StatefulWidget {
  const SteadyAsyncBuilder({
    required this.load,
    required this.dataBuilder,
    this.controller,
    this.autoStart = true,
    this.reloadOnLoaderChange = false,
    this.loadingBuilder,
    this.emptyBuilder,
    this.errorBuilder,
    this.idleBuilder,
    this.isEmpty,
    this.policy,
    super.key,
  });

  final SteadyLoader<T> load;
  final SteadyDataBuilder<T> dataBuilder;
  final SteadyAsyncController<T>? controller;
  final bool autoStart;
  final bool reloadOnLoaderChange;
  final SteadyLoadingBuilder<T>? loadingBuilder;
  final WidgetBuilder? emptyBuilder;
  final SteadyErrorBuilder<T>? errorBuilder;
  final WidgetBuilder? idleBuilder;
  final bool Function(T value)? isEmpty;
  final SteadyTransitionPolicy? policy;

  @override
  State<SteadyAsyncBuilder<T>> createState() => _SteadyAsyncBuilderState<T>();
}

class _SteadyAsyncBuilderState<T> extends State<SteadyAsyncBuilder<T>> {
  late SteadyAsyncController<T> _controller;
  late bool _ownsController;

  @override
  void initState() {
    super.initState();
    _attachController();
    if (widget.autoStart && _controller.value.isIdle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.value.isIdle) {
          unawaited(_controller.load());
        }
      });
    }
  }

  void _attachController() {
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? SteadyAsyncController<T>(widget.load);
    _controller.updateLoader(widget.load);
  }

  @override
  void didUpdateWidget(covariant SteadyAsyncBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controllerChanged = oldWidget.controller != widget.controller;
    if (controllerChanged) {
      if (_ownsController) _controller.dispose();
      _attachController();
      if (oldWidget.load != widget.load && widget.reloadOnLoaderChange) {
        unawaited(_controller.reload());
      } else if (widget.autoStart && _controller.value.isIdle) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _controller.value.isIdle) {
            unawaited(_controller.load());
          }
        });
      }
    } else {
      _controller.updateLoader(widget.load);
      if (oldWidget.load != widget.load && widget.reloadOnLoaderChange) {
        unawaited(_controller.reload());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SteadyAsyncState<T>>(
      valueListenable: _controller,
      builder: (context, state, _) => SteadyStateView<T>(
        state: state,
        dataBuilder: widget.dataBuilder,
        onRetry: () => unawaited(_controller.retry()),
        loadingBuilder: widget.loadingBuilder,
        emptyBuilder: widget.emptyBuilder,
        errorBuilder: widget.errorBuilder,
        idleBuilder: widget.idleBuilder,
        isEmpty: widget.isEmpty,
        policy: widget.policy,
      ),
    );
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }
}

typedef SteadyStreamFactory<T> = Stream<T> Function();

/// Stream-powered state view with subscription replacement and stale guards.
class SteadyStreamBuilder<T> extends StatefulWidget {
  const SteadyStreamBuilder({
    required this.stream,
    required this.dataBuilder,
    this.loadingBuilder,
    this.emptyBuilder,
    this.errorBuilder,
    this.idleBuilder,
    this.isEmpty,
    this.policy,
    super.key,
  });

  final SteadyStreamFactory<T> stream;
  final SteadyDataBuilder<T> dataBuilder;
  final SteadyLoadingBuilder<T>? loadingBuilder;
  final WidgetBuilder? emptyBuilder;
  final SteadyErrorBuilder<T>? errorBuilder;
  final WidgetBuilder? idleBuilder;
  final bool Function(T value)? isEmpty;
  final SteadyTransitionPolicy? policy;

  @override
  State<SteadyStreamBuilder<T>> createState() => _SteadyStreamBuilderState<T>();
}

class _SteadyStreamBuilderState<T> extends State<SteadyStreamBuilder<T>> {
  SteadyAsyncState<T> _state = const SteadyAsyncState.idle();
  StreamSubscription<T>? _subscription;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe({bool refresh = false}) {
    final generation = ++_generation;
    unawaited(_subscription?.cancel());
    final previous = _state.valueOrNull;
    final hasPrevious = _state.hasValue;
    setState(() {
      _state = SteadyAsyncState<T>.loading(
        previousValue: previous,
        hasPreviousValue: hasPrevious,
        phase:
            refresh ? SteadyLoadingPhase.refresh : SteadyLoadingPhase.initial,
      );
    });
    try {
      _subscription = widget.stream().listen(
        (value) {
          if (mounted && generation == _generation) {
            setState(() => _state = SteadyAsyncState<T>.data(value));
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (mounted && generation == _generation) {
            setState(() {
              _state = SteadyAsyncState<T>.error(
                error,
                stackTrace: stackTrace,
                previousValue: previous,
                hasPreviousValue: hasPrevious,
              );
            });
          }
        },
      );
    } catch (error, stackTrace) {
      _state = SteadyAsyncState<T>.error(
        error,
        stackTrace: stackTrace,
        previousValue: previous,
        hasPreviousValue: hasPrevious,
      );
    }
  }

  @override
  void didUpdateWidget(covariant SteadyStreamBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream != widget.stream) _subscribe(refresh: true);
  }

  @override
  Widget build(BuildContext context) => SteadyStateView<T>(
        state: _state,
        dataBuilder: widget.dataBuilder,
        onRetry: () => _subscribe(refresh: true),
        loadingBuilder: widget.loadingBuilder,
        emptyBuilder: widget.emptyBuilder,
        errorBuilder: widget.errorBuilder,
        idleBuilder: widget.idleBuilder,
        isEmpty: widget.isEmpty,
        policy: widget.policy,
      );

  @override
  void dispose() {
    _generation++;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
