import 'package:flutter/material.dart';

import 'localization.dart';
import 'policy.dart';

@immutable
class SteadyThemeData {
  const SteadyThemeData({
    this.policy = const SteadyTransitionPolicy(),
    this.messages,
    this.accentColor,
    this.indicatorSize = 28,
    this.successVisibleDuration = const Duration(milliseconds: 800),
  });

  final SteadyTransitionPolicy policy;
  final SteadyMessages? messages;
  final Color? accentColor;
  final double indicatorSize;
  final Duration successVisibleDuration;

  SteadyThemeData copyWith({
    SteadyTransitionPolicy? policy,
    SteadyMessages? messages,
    Color? accentColor,
    double? indicatorSize,
    Duration? successVisibleDuration,
  }) =>
      SteadyThemeData(
        policy: policy ?? this.policy,
        messages: messages ?? this.messages,
        accentColor: accentColor ?? this.accentColor,
        indicatorSize: indicatorSize ?? this.indicatorSize,
        successVisibleDuration:
            successVisibleDuration ?? this.successVisibleDuration,
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
