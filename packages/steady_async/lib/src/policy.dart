import 'package:flutter/foundation.dart';

/// Identifies why an async operation entered a loading state.
enum SteadyLoadingPhase { initial, refresh, reload }

/// Controls when async state changes become visible.
@immutable
class SteadyTransitionPolicy {
  const SteadyTransitionPolicy({
    this.loadingDelay = const Duration(milliseconds: 200),
    this.minimumLoadingDuration = const Duration(milliseconds: 350),
    this.transitionDuration = const Duration(milliseconds: 200),
    this.keepPreviousData = true,
    this.stabilizeLayout = true,
  });

  /// Wait before revealing a loader, preventing flashes for quick operations.
  final Duration loadingDelay;

  /// Once shown, keep a loader visible for at least this long.
  final Duration minimumLoadingDuration;

  /// Duration of state cross-fades and size transitions.
  final Duration transitionDuration;

  /// Keeps existing content visible during refresh and reload.
  final bool keepPreviousData;

  /// Animates size changes to reduce layout jumps.
  final bool stabilizeLayout;

  SteadyTransitionPolicy copyWith({
    Duration? loadingDelay,
    Duration? minimumLoadingDuration,
    Duration? transitionDuration,
    bool? keepPreviousData,
    bool? stabilizeLayout,
  }) =>
      SteadyTransitionPolicy(
        loadingDelay: loadingDelay ?? this.loadingDelay,
        minimumLoadingDuration:
            minimumLoadingDuration ?? this.minimumLoadingDuration,
        transitionDuration: transitionDuration ?? this.transitionDuration,
        keepPreviousData: keepPreviousData ?? this.keepPreviousData,
        stabilizeLayout: stabilizeLayout ?? this.stabilizeLayout,
      );
}
