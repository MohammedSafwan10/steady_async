import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:steady_async/steady_async.dart';

void main() => runApp(const SteadyShowcaseApp());

class SteadyShowcaseApp extends StatefulWidget {
  const SteadyShowcaseApp({super.key});

  @override
  State<SteadyShowcaseApp> createState() => _SteadyShowcaseAppState();
}

class _SteadyShowcaseAppState extends State<SteadyShowcaseApp> {
  ThemeMode _mode = ThemeMode.dark;
  Locale _locale = const Locale('en');
  static const brand = Color(0xFF78F7C5);

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'steady_async — Calm async UX for Flutter',
    debugShowCheckedModeBanner: false,
    themeMode: _mode,
    locale: _locale,
    supportedLocales: SteadyMessages.supported.keys.map(Locale.new),
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    home: SteadyTheme(
      data: const SteadyThemeData(accentColor: brand),
      child: ShowcasePage(
        mode: _mode,
        locale: _locale,
        onMode: (value) => setState(() => _mode = value),
        onLocale: (value) => setState(() => _locale = value),
      ),
    ),
  );

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: brightness,
      surface: dark ? const Color(0xFF101A20) : const Color(0xFFF8FBF9),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF071015)
          : const Color(0xFFF1F6F3),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: dark ? const Color(0xFF223139) : const Color(0xFFDCE7E1),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class ShowcasePage extends StatelessWidget {
  const ShowcasePage({
    required this.mode,
    required this.locale,
    required this.onMode,
    required this.onLocale,
    super.key,
  });

  final ThemeMode mode;
  final Locale locale;
  final ValueChanged<ThemeMode> onMode;
  final ValueChanged<Locale> onLocale;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SelectionArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _TopBar(
              mode: mode,
              locale: locale,
              onMode: onMode,
              onLocale: onLocale,
            ),
          ),
          const SliverToBoxAdapter(child: _Hero()),
          const SliverToBoxAdapter(child: _ComparisonDemo()),
          const SliverToBoxAdapter(child: _Features()),
          const SliverToBoxAdapter(child: _ActionDemo()),
          const SliverToBoxAdapter(child: _PaginationDemo()),
          const SliverToBoxAdapter(child: _CodeSection()),
          const SliverToBoxAdapter(child: _Footer()),
        ],
      ),
    ),
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.mode,
    required this.locale,
    required this.onMode,
    required this.onLocale,
  });

  final ThemeMode mode;
  final Locale locale;
  final ValueChanged<ThemeMode> onMode;
  final ValueChanged<Locale> onLocale;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: .92),
      border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                Icons.waves_rounded,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            const SizedBox(width: 11),
            const Text(
              'steady_async',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const Spacer(),
            DropdownButtonHideUnderline(
              child: DropdownButton<Locale>(
                value: locale,
                borderRadius: BorderRadius.circular(16),
                onChanged: (value) {
                  if (value != null) onLocale(value);
                },
                items: SteadyMessages.supported.keys
                    .map(
                      (code) => DropdownMenuItem(
                        value: Locale(code),
                        child: Text(code.toUpperCase()),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: mode == ThemeMode.dark
                  ? 'Use light mode'
                  : 'Use dark mode',
              onPressed: () => onMode(
                mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
              ),
              icon: Icon(
                mode == ThemeMode.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) => _PageWidth(
    padding: const EdgeInsets.fromLTRB(24, 72, 24, 30),
    child: Column(
      children: [
        Chip(
          avatar: const Icon(Icons.flutter_dash, size: 18),
          label: const Text('Flutter package · v0.1.0'),
          side: BorderSide.none,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        ),
        const SizedBox(height: 26),
        Text(
          'Your API isn’t slow.\nYour loading UI is noisy.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w900,
            height: 1.04,
            letterSpacing: -2,
          ),
        ),
        const SizedBox(height: 22),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Text(
            'Perception-aware async UX for Flutter. Stop flashing loaders, '
            'hiding refresh content, and accepting duplicate submissions.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.terminal),
              label: const Text('flutter pub add steady_async'),
            ),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.code),
              label: const Text('GitHub · MohammedSafwan10'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ComparisonDemo extends StatefulWidget {
  const _ComparisonDemo();

  @override
  State<_ComparisonDemo> createState() => _ComparisonDemoState();
}

class _ComparisonDemoState extends State<_ComparisonDemo> {
  double _latency = 700;
  double _failure = 0;
  bool _manualLoading = false;
  Object? _manualError;
  List<_Activity> _manualItems = _seed;
  SteadyAsyncState<List<_Activity>> _steady = const SteadyAsyncState.data(
    _seed,
  );
  int _generation = 0;
  final _random = Random();

  static const _seed = [
    _Activity(
      'Checkout completed',
      '2 minutes ago',
      Icons.shopping_bag_outlined,
    ),
    _Activity('Profile synchronized', '18 minutes ago', Icons.sync),
    _Activity('Report exported', '1 hour ago', Icons.description_outlined),
  ];

  Future<void> _run() async {
    final generation = ++_generation;
    final previous = _steady.valueOrNull ?? _seed;
    setState(() {
      _manualLoading = true;
      _manualError = null;
      _steady = SteadyAsyncState.loading(
        previousValue: previous,
        hasPreviousValue: true,
        phase: SteadyLoadingPhase.refresh,
      );
    });
    await Future<void>.delayed(Duration(milliseconds: _latency.round()));
    if (!mounted || generation != _generation) return;
    final failed = _random.nextDouble() < _failure / 100;
    setState(() {
      _manualLoading = false;
      if (failed) {
        final error = StateError('The network request failed');
        _manualError = error;
        _steady = SteadyAsyncState.error(
          error,
          previousValue: previous,
          hasPreviousValue: true,
        );
      } else {
        final fresh = [
          _Activity('Fresh data received', 'just now', Icons.bolt),
          ..._seed.take(2),
        ];
        _manualItems = fresh;
        _steady = SteadyAsyncState.data(fresh);
      }
    });
  }

  @override
  Widget build(BuildContext context) => _Section(
    eyebrow: 'LIVE NETWORK LAB',
    title: 'See the difference under real timing',
    description:
        'Change latency, add failures, and run the same request on both sides.',
    child: Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              spacing: 24,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _SliderControl(
                  label: 'Latency · ${_latency.round()} ms',
                  value: _latency,
                  min: 50,
                  max: 2000,
                  divisions: 39,
                  onChanged: (value) => setState(() => _latency = value),
                ),
                _SliderControl(
                  label: 'Failure chance · ${_failure.round()}%',
                  value: _failure,
                  min: 0,
                  max: 100,
                  divisions: 10,
                  onChanged: (value) => setState(() => _failure = value),
                ),
                FilledButton.icon(
                  onPressed: _manualLoading ? null : _run,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Run request'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 820;
            final normal = _DemoFrame(
              label: 'Typical implementation',
              positive: false,
              child: _manualLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _manualError != null
                  ? SteadyDefaultErrorView(onRetry: _run)
                  : _ActivityList(items: _manualItems),
            );
            final steady = _DemoFrame(
              label: 'With steady_async',
              positive: true,
              child: SteadyStateView<List<_Activity>>(
                state: _steady,
                onRetry: _run,
                dataBuilder: (_, value) => _ActivityList(items: value),
              ),
            );
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: normal),
                      const SizedBox(width: 18),
                      Expanded(child: steady),
                    ],
                  )
                : Column(
                    children: [normal, const SizedBox(height: 18), steady],
                  );
          },
        ),
      ],
    ),
  );
}

class _SliderControl extends StatelessWidget {
  const _SliderControl({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 290,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: label,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

class _DemoFrame extends StatelessWidget {
  const _DemoFrame({
    required this.label,
    required this.positive,
    required this.child,
  });
  final String label;
  final bool positive;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          color: positive
              ? Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: .7)
              : Theme.of(
                  context,
                ).colorScheme.errorContainer.withValues(alpha: .55),
          child: Row(
            children: [
              Icon(
                positive
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_rounded,
                size: 19,
              ),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        SizedBox(height: 300, child: child),
      ],
    ),
  );
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.items});
  final List<_Activity> items;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.all(16),
    itemCount: items.length,
    separatorBuilder: (_, _) => const Divider(height: 1),
    itemBuilder: (context, index) {
      final item = items[index];
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        leading: CircleAvatar(child: Icon(item.icon, size: 20)),
        title: Text(
          item.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(item.time),
        trailing: const Icon(Icons.chevron_right),
      );
    },
  );
}

class _Activity {
  const _Activity(this.title, this.time, this.icon);
  final String title;
  final String time;
  final IconData icon;
}

class _Features extends StatelessWidget {
  const _Features();

  @override
  Widget build(BuildContext context) {
    const features = [
      (
        Icons.flash_off_outlined,
        'No loader flashes',
        'Fast operations finish without visual noise.',
      ),
      (
        Icons.layers_outlined,
        'Previous data stays',
        'Refresh without throwing useful content away.',
      ),
      (
        Icons.filter_none,
        'No duplicate actions',
        'Drop, latest-wins, or sequential concurrency.',
      ),
      (
        Icons.accessibility_new,
        'Accessible motion',
        'Reduced-motion settings are respected.',
      ),
    ];
    return _Section(
      eyebrow: 'BUILT FOR EVERY SCREEN',
      title: 'A consistent async contract',
      description:
          'One timing and state model for loading, actions, streams, and pagination.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 900 ? 4 : 2;
          final width = (constraints.maxWidth - 18 * (columns - 1)) / columns;
          return Wrap(
            spacing: 18,
            runSpacing: 18,
            children: features
                .map(
                  (feature) => SizedBox(
                    width: width,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              feature.$1,
                              size: 28,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              feature.$2,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              feature.$3,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

class _ActionDemo extends StatelessWidget {
  const _ActionDemo();

  @override
  Widget build(BuildContext context) => _Section(
    eyebrow: 'ASYNC ACTIONS',
    title: 'Buttons that understand Futures',
    description:
        'Tap repeatedly. The action runs once and communicates every state.',
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Wrap(
          spacing: 24,
          runSpacing: 18,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SteadyButton<void>(
              icon: const Icon(Icons.save_outlined),
              action: () =>
                  Future<void>.delayed(const Duration(milliseconds: 1100)),
              child: const Text('Save profile'),
            ),
            Text(
              'Loading → Success → Ready · duplicate taps are dropped',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PaginationDemo extends StatefulWidget {
  const _PaginationDemo();

  @override
  State<_PaginationDemo> createState() => _PaginationDemoState();
}

class _PaginationDemoState extends State<_PaginationDemo> {
  late final SteadyPagedController<String, int> _controller;

  @override
  void initState() {
    super.initState();
    _controller = SteadyPagedController<String, int>(
      firstPageKey: 0,
      loadPage: (key) async {
        await Future<void>.delayed(const Duration(milliseconds: 650));
        final start = key * 8;
        return SteadyPage(
          items: List.generate(8, (index) => 'Result ${start + index + 1}'),
          nextKey: key >= 2 ? null : key + 1,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => _Section(
    eyebrow: 'PAGINATION',
    title: 'Load more without edge-case chaos',
    description:
        'Scroll this list. Requests deduplicate and stop at the final page.',
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 350,
        child: SteadyPagedListView<String, int>(
          controller: _controller,
          padding: const EdgeInsets.all(12),
          itemBuilder: (context, item, index) => Card.filled(
            child: ListTile(
              leading: CircleAvatar(child: Text('${index + 1}')),
              title: Text(
                item,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'Cursor pagination · retained on append error',
              ),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _CodeSection extends StatelessWidget {
  const _CodeSection();

  @override
  Widget build(BuildContext context) => _Section(
    eyebrow: 'SMALL API · BIG UX WIN',
    title: 'Keep your architecture',
    description: 'Use Futures, Streams, explicit state, Riverpod, or BLoC.',
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: const Color(0xFF071015),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF28433D)),
      ),
      child: const SelectableText(
        '''SteadyAsyncBuilder<List<Product>>(
  load: repository.getProducts,
  dataBuilder: (_, products) => ProductList(products),
  isEmpty: (products) => products.isEmpty,
)''',
        style: TextStyle(
          color: Color(0xFFC6FBE6),
          fontFamily: 'monospace',
          fontSize: 15,
          height: 1.65,
        ),
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.child,
  });
  final String eyebrow;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) => _PageWidth(
    padding: const EdgeInsets.fromLTRB(24, 54, 24, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          eyebrow,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -.8,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          description,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 26),
        child,
      ],
    ),
  );
}

class _PageWidth extends StatelessWidget {
  const _PageWidth({required this.child, this.padding = EdgeInsets.zero});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1180),
      child: Padding(padding: padding, child: child),
    ),
  );
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 80, 24, 48),
    child: Column(
      children: [
        Icon(
          Icons.waves_rounded,
          color: Theme.of(context).colorScheme.primary,
          size: 34,
        ),
        const SizedBox(height: 14),
        const Text(
          'steady_async',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          'BSD-3-Clause · Mohammed Safwan · Published by nexdark.com',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}
