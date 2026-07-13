part of '../showcase.dart';

enum _MenuTarget { demo, features, adapters, docs, github }

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onDemo,
    required this.onFeatures,
    required this.onAdapters,
    required this.onDocs,
    required this.onGitHub,
    required this.onCopy,
  });

  final VoidCallback onDemo;
  final VoidCallback onFeatures;
  final VoidCallback onAdapters;
  final VoidCallback onDocs;
  final VoidCallback onGitHub;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    decoration: const BoxDecoration(
      color: _paper,
      border: Border(bottom: BorderSide(color: _line)),
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1320),
        child: SizedBox(
          height: 72,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 820;
              return Row(
                children: [
                  _Brand(showName: !compact),
                  const Spacer(),
                  if (compact) ...[
                    PopupMenuButton<_MenuTarget>(
                      tooltip: 'Open navigation',
                      icon: const Icon(Icons.menu),
                      onSelected: (target) {
                        switch (target) {
                          case _MenuTarget.demo:
                            onDemo();
                            return;
                          case _MenuTarget.features:
                            onFeatures();
                            return;
                          case _MenuTarget.adapters:
                            onAdapters();
                            return;
                          case _MenuTarget.docs:
                            onDocs();
                            return;
                          case _MenuTarget.github:
                            onGitHub();
                            return;
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _MenuTarget.demo,
                          child: Text('Demo'),
                        ),
                        PopupMenuItem(
                          value: _MenuTarget.features,
                          child: Text('Features'),
                        ),
                        PopupMenuItem(
                          value: _MenuTarget.adapters,
                          child: Text('Adapters'),
                        ),
                        PopupMenuItem(
                          value: _MenuTarget.docs,
                          child: Text('Docs'),
                        ),
                        PopupMenuItem(
                          value: _MenuTarget.github,
                          child: Text('GitHub'),
                        ),
                      ],
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (!compact) ...[
                    _NavButton('Demo', onPressed: onDemo),
                    _NavButton('Features', onPressed: onFeatures),
                    _NavButton('Adapters', onPressed: onAdapters),
                    _NavButton('Docs', onPressed: onDocs),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: onGitHub,
                      icon: const Icon(Icons.code, size: 20),
                      label: const Text('GitHub'),
                      style: TextButton.styleFrom(
                        foregroundColor: _ink,
                        textStyle: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  FilledButton(
                    onPressed: onCopy,
                    child: Text(compact ? 'Install' : 'Add to Flutter'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _TopBarDelegate extends SliverPersistentHeaderDelegate {
  const _TopBarDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 72;

  @override
  double get maxExtent => 72;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;

  @override
  bool shouldRebuild(covariant _TopBarDelegate oldDelegate) => true;
}

class _Brand extends StatelessWidget {
  const _Brand({required this.showName});

  final bool showName;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(width: 30, height: 34, child: _SteadyMark()),
      if (showName) ...[
        const SizedBox(width: 12),
        const Text(
          'steady_async',
          style: TextStyle(
            color: _ink,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -.5,
          ),
        ),
      ],
    ],
  );
}

class _SteadyMark extends StatelessWidget {
  const _SteadyMark();

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Transform.translate(
        offset: const Offset(4, -7),
        child: Transform.rotate(
          angle: -.72,
          child: Container(width: 8, height: 22, color: _indigo),
        ),
      ),
      Transform.translate(
        offset: const Offset(-4, 7),
        child: Transform.rotate(
          angle: -.72,
          child: Container(width: 8, height: 22, color: _indigo),
        ),
      ),
    ],
  );
}

class _NavButton extends StatelessWidget {
  const _NavButton(this.label, {required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: _ink,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 18),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),
    child: Text(label),
  );
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.requestLabKey,
    required this.latency,
    required this.failureRate,
    required this.refreshing,
    required this.lastFailed,
    required this.users,
    required this.onLatency,
    required this.onFailureRate,
    required this.onRun,
    required this.onCopy,
  });

  final GlobalKey requestLabKey;
  final double latency;
  final double failureRate;
  final bool refreshing;
  final bool lastFailed;
  final List<_User> users;
  final ValueChanged<double> onLatency;
  final ValueChanged<double> onFailureRate;
  final VoidCallback onRun;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) => _PageWidth(
    padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 930;
        final intro = _HeroCopy(onCopy: onCopy);
        final lab = KeyedSubtree(
          key: requestLabKey,
          child: _RequestLab(
            latency: latency,
            failureRate: failureRate,
            refreshing: refreshing,
            lastFailed: lastFailed,
            users: users,
            onLatency: onLatency,
            onFailureRate: onFailureRate,
            onRun: onRun,
          ),
        );
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [intro, const SizedBox(height: 38), lab],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 43, child: intro),
            const SizedBox(width: 60),
            Expanded(flex: 57, child: lab),
          ],
        );
      },
    ),
  );
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.onCopy});

  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 620;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ASYNC UI FOR FLUTTER',
          style: TextStyle(
            color: _indigo,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Loading, retry,\nand refresh — done.',
          style: Theme.of(
            context,
          ).textTheme.displayLarge?.copyWith(fontSize: narrow ? 48 : 68),
        ),
        const SizedBox(height: 22),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: const Text(
            'Stop wiring the same loading, empty, error, retry, and stale-result checks into every screen.',
            style: TextStyle(color: _muted, fontSize: 18, height: 1.45),
          ),
        ),
        const SizedBox(height: 24),
        InkWell(
          onTap: onCopy,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: narrow ? double.infinity : 390,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
            decoration: BoxDecoration(
              color: _ink,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Text(
                    'flutter pub add steady_async',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 15,
                    ),
                  ),
                ),
                Icon(Icons.copy_outlined, color: Colors.white, size: 19),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Adjust latency and failures in the demo',
              style: TextStyle(color: _indigo, fontWeight: FontWeight.w800),
            ),
            Icon(Icons.arrow_forward, size: 18, color: _indigo),
          ],
        ),
      ],
    );
  }
}

class _RequestLab extends StatelessWidget {
  const _RequestLab({
    required this.latency,
    required this.failureRate,
    required this.refreshing,
    required this.lastFailed,
    required this.users,
    required this.onLatency,
    required this.onFailureRate,
    required this.onRun,
  });

  final double latency;
  final double failureRate;
  final bool refreshing;
  final bool lastFailed;
  final List<_User> users;
  final ValueChanged<double> onLatency;
  final ValueChanged<double> onFailureRate;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 18, 12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Request lab',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                ),
              ),
              FilledButton(
                onPressed: refreshing ? null : onRun,
                style: FilledButton.styleFrom(
                  backgroundColor: _indigo,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                ),
                child: Text(refreshing ? 'Running…' : 'Send request'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 520;
              final latencyControl = _LabSlider(
                label: 'Latency',
                valueLabel: '${latency.round()} ms',
                value: latency,
                max: 2000,
                onChanged: onLatency,
              );
              final failureControl = _LabSlider(
                label: 'Failure',
                valueLabel: '${failureRate.round()}%',
                value: failureRate,
                max: 100,
                onChanged: onFailureRate,
              );
              return stacked
                  ? Column(children: [latencyControl, failureControl])
                  : Row(
                      children: [
                        Expanded(child: latencyControl),
                        const SizedBox(width: 28),
                        Expanded(child: failureControl),
                      ],
                    );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _line)),
          ),
          child: Row(
            children: [
              Icon(
                lastFailed
                    ? Icons.error_outline
                    : refreshing
                    ? Icons.sync
                    : Icons.check_circle_outline,
                size: 19,
                color: lastFailed ? Colors.red.shade700 : _indigo,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  lastFailed
                      ? 'Request failed · previous data kept'
                      : refreshing
                      ? 'Refreshing · previous data kept'
                      : 'Request finished',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 3,
          alignment: Alignment.centerLeft,
          color: _line,
          child: FractionallySizedBox(
            widthFactor: refreshing ? .78 : 0,
            child: const ColoredBox(color: _indigo),
          ),
        ),
        for (final user in users) _UserRow(user: user),
      ],
    ),
  );
}

class _LabSlider extends StatelessWidget {
  const _LabSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text.rich(
        TextSpan(
          text: '$label  ',
          style: const TextStyle(fontWeight: FontWeight.w800, color: _ink),
          children: [
            TextSpan(
              text: valueLabel,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      Slider(value: value, max: max, onChanged: onChanged),
    ],
  );
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user, this.compact = false});

  final _User user;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 14 : 24,
      vertical: compact ? 12 : 14,
    ),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: _line)),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: compact ? 16 : 19,
          backgroundColor: user.avatarColor,
          foregroundColor: _ink,
          child: Text(
            user.initials,
            style: TextStyle(
              fontSize: compact ? 12 : 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          flex: 4,
          child: Text(
            user.name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        if (MediaQuery.sizeOf(context).width > 560)
          Expanded(
            flex: 5,
            child: Text(
              user.email,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ),
        const SizedBox(width: 10),
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: user.online ? _mint : const Color(0xFF9A9C98),
            shape: BoxShape.circle,
          ),
        ),
        if (!compact) ...[
          const SizedBox(width: 7),
          Text(
            user.online ? 'Online' : 'Offline',
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ],
    ),
  );
}

class _ProofStrip extends StatelessWidget {
  const _ProofStrip();

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border.symmetric(horizontal: BorderSide(color: _line)),
    ),
    child: _PageWidth(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const items = [
            _ProofItem(Icons.timer_outlined, '200 ms loader delay'),
            _ProofItem(Icons.shield_outlined, 'Stale-result safe'),
            _ProofItem(Icons.language, '9 built-in locales'),
            _ProofItem(Icons.extension_outlined, 'No state-manager lock-in'),
          ];
          if (constraints.maxWidth < 600) {
            return Column(
              children: [
                items[0],
                const SizedBox(height: 14),
                items[1],
                const SizedBox(height: 14),
                items[2],
                const SizedBox(height: 14),
                items[3],
              ],
            );
          }
          return const Wrap(
            spacing: 32,
            runSpacing: 18,
            alignment: WrapAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 245,
                child: _ProofItem(Icons.timer_outlined, '200 ms loader delay'),
              ),
              SizedBox(
                width: 245,
                child: _ProofItem(Icons.shield_outlined, 'Stale-result safe'),
              ),
              SizedBox(
                width: 245,
                child: _ProofItem(Icons.language, '9 built-in locales'),
              ),
              SizedBox(
                width: 245,
                child: _ProofItem(
                  Icons.extension_outlined,
                  'No state-manager lock-in',
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _ProofItem extends StatelessWidget {
  const _ProofItem(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: _indigo, size: 27),
      const SizedBox(width: 11),
      Expanded(
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    ],
  );
}

class _Comparison extends StatelessWidget {
  const _Comparison({
    required this.refreshing,
    required this.users,
    required this.onRun,
  });

  final bool refreshing;
  final List<_User> users;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) => _PageWidth(
    padding: const EdgeInsets.fromLTRB(24, 62, 24, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What changes during refresh',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Both panels run the same request. Only the state UI is different.',
                    style: TextStyle(color: _muted, fontSize: 17),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: onRun,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Run again'),
            ),
          ],
        ),
        const SizedBox(height: 30),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 850;
            final typical = _ComparisonPanel(
              title: 'Typical implementation',
              caption: 'The list disappears while refresh runs.',
              child: refreshing
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        for (final user in users)
                          _UserRow(user: user, compact: true),
                      ],
                    ),
            );
            final steady = _ComparisonPanel(
              title: 'steady_async',
              caption: 'The list stays visible and remains usable.',
              highlighted: true,
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 3,
                    color: refreshing ? _indigo : Colors.transparent,
                  ),
                  for (final user in users) _UserRow(user: user, compact: true),
                ],
              ),
            );
            if (stacked) {
              return Column(
                children: [typical, const SizedBox(height: 20), steady],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: typical),
                const Padding(
                  padding: EdgeInsets.fromLTRB(22, 125, 22, 0),
                  child: Text(
                    'VS',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Expanded(child: steady),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _ComparisonPanel extends StatelessWidget {
  const _ComparisonPanel({
    required this.title,
    required this.caption,
    required this.child,
    this.highlighted = false,
  });

  final String title;
  final String caption;
  final Widget child;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        height: 280,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: highlighted ? _indigo : _line,
            width: highlighted ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Text(
                title,
                style: TextStyle(
                  color: highlighted ? _indigo : _ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Divider(height: 1, color: _line),
            Expanded(child: child),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Text(
        caption,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: highlighted ? _indigo : _muted,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  @override
  Widget build(BuildContext context) => _PageWidth(
    padding: const EdgeInsets.fromLTRB(24, 44, 24, 64),
    child: LayoutBuilder(
      builder: (context, constraints) {
        const cards = [
          _FeatureCard(
            Icons.timer_outlined,
            'Loader timing built in',
            'Short requests skip the spinner. Longer ones avoid flicker.',
          ),
          _FeatureCard(
            Icons.touch_app_outlined,
            'No duplicate submits',
            'Drop, queue, or keep only the latest action result.',
          ),
          _FeatureCard(
            Icons.format_list_bulleted,
            'Pagination keeps its items',
            'Append errors do not wipe the pages already on screen.',
          ),
        ];
        if (constraints.maxWidth < 780) {
          return Column(
            children: [
              cards[0],
              const SizedBox(height: 14),
              cards[1],
              const SizedBox(height: 14),
              cards[2],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 16),
            Expanded(child: cards[1]),
            const SizedBox(width: 16),
            Expanded(child: cards[2]),
          ],
        );
      },
    ),
  );
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard(this.icon, this.title, this.body);

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _indigo, size: 34),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(body, style: const TextStyle(color: _muted, height: 1.4)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CodeSection extends StatelessWidget {
  const _CodeSection();

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 62),
    child: _PageWidth(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 850;
          const copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'One builder for the whole screen state.',
                style: TextStyle(
                  color: _ink,
                  fontSize: 38,
                  height: 1.04,
                  letterSpacing: -1.4,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Use a Future factory. Retry stays safe, refresh keeps old data, and obsolete results are ignored.',
                style: TextStyle(color: _muted, fontSize: 17, height: 1.45),
              ),
            ],
          );
          const code = _CodeBlock();
          return stacked
              ? const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [copy, SizedBox(height: 28), code],
                )
              : const Row(
                  children: [
                    Expanded(flex: 4, child: copy),
                    SizedBox(width: 60),
                    Expanded(flex: 6, child: code),
                  ],
                );
        },
      ),
    ),
  );
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: _ink,
      borderRadius: BorderRadius.circular(10),
    ),
    child: const SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Text(
        '''SteadyAsyncBuilder<List<User>>(
  load: api.fetchUsers,
  isEmpty: (users) => users.isEmpty,
  dataBuilder: (context, users) {
    return UsersList(users);
  },
)''',
        style: TextStyle(
          color: Color(0xFFF2F2ED),
          fontFamily: 'monospace',
          fontSize: 14,
          height: 1.55,
        ),
      ),
    ),
  );
}

class _PackagesSection extends StatelessWidget {
  const _PackagesSection();

  @override
  Widget build(BuildContext context) => _PageWidth(
    padding: const EdgeInsets.fromLTRB(24, 68, 24, 72),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Use the state manager you already have.',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 12),
        const Text(
          'The core package has no Riverpod, BLoC, Provider, or GetX dependency.',
          style: TextStyle(color: _muted, fontSize: 17),
        ),
        const SizedBox(height: 28),
        const Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _PackageTag('steady_async', 'Core widgets and controllers'),
            _PackageTag('steady_async_riverpod', 'AsyncValue adapter'),
            _PackageTag('steady_async_bloc', 'BLoC and Cubit adapter'),
          ],
        ),
      ],
    ),
  );
}

class _PackageTag extends StatelessWidget {
  const _PackageTag(this.name, this.description);

  final String name;
  final String description;

  Future<void> _openPackage(BuildContext context) async {
    final opened = await launchUrl(
      Uri.parse('https://pub.dev/packages/$name'),
      webOnlyWindowName: '_blank',
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open package')));
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: _line),
      borderRadius: BorderRadius.circular(10),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => _openPackage(context),
      child: SizedBox(
        width: 340,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: _indigo,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(Icons.open_in_new, size: 17, color: _indigo),
                ],
              ),
              const SizedBox(height: 8),
              Text(description, style: const TextStyle(color: _muted)),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) => Container(
    color: _ink,
    padding: const EdgeInsets.symmetric(vertical: 34),
    child: _PageWidth(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: const Wrap(
        spacing: 24,
        runSpacing: 14,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Text(
            'steady_async · BSD-3-Clause',
            style: TextStyle(color: Colors.white),
          ),
          Text(
            'Built by Mohammed Safwan',
            style: TextStyle(color: Color(0xFFB8BAB5)),
          ),
        ],
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [
        BoxShadow(
          color: Color(0x12000000),
          blurRadius: 22,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: child,
  );
}

class _PageWidth extends StatelessWidget {
  const _PageWidth({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1320),
      child: Padding(padding: padding, child: child),
    ),
  );
}

class _User {
  const _User(
    this.initials,
    this.name,
    this.email,
    this.online,
    this.avatarColor,
  );

  final String initials;
  final String name;
  final String email;
  final bool online;
  final Color avatarColor;
}
