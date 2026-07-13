import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:steady_async/steady_async.dart';
import 'package:url_launcher/url_launcher.dart';

import 'src/clipboard/clipboard_service.dart';

part 'src/showcase_page.dart';
part 'src/showcase_sections.dart';
part 'src/scenario_showcase.dart';

const _ink = Color(0xFF171817);
const _paper = Color(0xFFF7F6F2);
const _indigo = Color(0xFF4E54E8);
const _mint = Color(0xFF28A875);
const _line = Color(0xFFD9D9D4);
const _muted = Color(0xFF62645F);

class SteadyShowcaseApp extends StatelessWidget {
  const SteadyShowcaseApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'steady_async — async state UI for Flutter',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: _paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _indigo,
        brightness: Brightness.light,
        surface: Colors.white,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: _ink,
          fontSize: 68,
          height: .98,
          letterSpacing: -3.2,
          fontWeight: FontWeight.w900,
        ),
        headlineLarge: TextStyle(
          color: _ink,
          fontSize: 42,
          height: 1.03,
          letterSpacing: -1.8,
          fontWeight: FontWeight.w900,
        ),
        headlineSmall: TextStyle(
          color: _ink,
          fontSize: 22,
          height: 1.1,
          fontWeight: FontWeight.w800,
        ),
        bodyLarge: TextStyle(color: _muted, fontSize: 18, height: 1.45),
        bodyMedium: TextStyle(color: _muted, height: 1.45),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _ink,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: _indigo,
        inactiveTrackColor: _line,
        thumbColor: _indigo,
        trackHeight: 3,
        overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
      ),
    ),
    home: const SteadyTheme(
      data: SteadyThemeData(accentColor: _indigo),
      child: ShowcasePage(),
    ),
  );
}
