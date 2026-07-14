import 'package:flutter/material.dart';

import 'localization.dart';
import 'policy.dart';
import 'request.dart';

@immutable
class SteadyThemeData {
  const SteadyThemeData({
    this.policy = const SteadyTransitionPolicy(),
    this.messages,
    this.accentColor,
    this.indicatorSize = 28,
    this.successVisibleDuration = const Duration(milliseconds: 800),
    this.errorMapper,
  });

  final SteadyTransitionPolicy policy;
  final SteadyMessages? messages;
  final Color? accentColor;
  final double indicatorSize;
  final Duration successVisibleDuration;
  final SteadyErrorMapper? errorMapper;

  SteadyThemeData copyWith({
    SteadyTransitionPolicy? policy,
    SteadyMessages? messages,
    Color? accentColor,
    double? indicatorSize,
    Duration? successVisibleDuration,
    SteadyErrorMapper? errorMapper,
    bool clearErrorMapper = false,
  }) =>
      SteadyThemeData(
        policy: policy ?? this.policy,
        messages: messages ?? this.messages,
        accentColor: accentColor ?? this.accentColor,
        indicatorSize: indicatorSize ?? this.indicatorSize,
        successVisibleDuration:
            successVisibleDuration ?? this.successVisibleDuration,
        errorMapper: clearErrorMapper ? null : errorMapper ?? this.errorMapper,
      );
}

class SteadyTheme extends InheritedWidget {
  const SteadyTheme({required this.data, required super.child, super.key});

  final SteadyThemeData data;

  static SteadyThemeData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SteadyTheme>()?.data ??
      const SteadyThemeData();

  @override
  bool updateShouldNotify(SteadyTheme oldWidget) => data != oldWidget.data;
}
