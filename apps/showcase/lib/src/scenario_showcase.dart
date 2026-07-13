part of '../showcase.dart';

enum _Scenario { load, refresh, action, pagination }

class _ScenarioShowcase extends StatefulWidget {
  const _ScenarioShowcase();

  @override
  State<_ScenarioShowcase> createState() => _ScenarioShowcaseState();
}

class _ScenarioShowcaseState extends State<_ScenarioShowcase> {
  _Scenario _selected = _Scenario.load;
  bool _running = false;
  bool _failed = false;
  bool _hasData = false;
  bool _actionDone = false;
  bool _failNextPage = false;
  int _itemCount = 5;
  Timer? _timer;

  void _select(_Scenario value) {
    _timer?.cancel();
    setState(() {
      _selected = value;
      _running = false;
      _failed = false;
      _hasData = value != _Scenario.load;
      _actionDone = false;
      _failNextPage = false;
      _itemCount = 5;
    });
  }

  void _run({bool fail = false}) {
    if (_running) return;
    setState(() {
      _running = true;
      _failed = false;
      if (_selected == _Scenario.action) _actionDone = false;
    });
    _timer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _running = false;
        _failed = fail;
        if (!fail) {
          _hasData = true;
          if (_selected == _Scenario.action) _actionDone = true;
          if (_selected == _Scenario.pagination) _itemCount += 3;
        }
        if (_selected == _Scenario.pagination) _failNextPage = false;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    color: _ink,
    padding: const EdgeInsets.symmetric(vertical: 64),
    child: _PageWidth(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'INTERACTIVE EXAMPLES',
            style: TextStyle(
              color: Color(0xFF9EA2FF),
              fontWeight: FontWeight.w900,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Try the states your app actually hits.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 40,
              height: 1.05,
              letterSpacing: -1.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Each example runs locally. Trigger the slow path, the failure path, and the retry.',
            style: TextStyle(color: Color(0xFFBFC1BC), fontSize: 17),
          ),
          const SizedBox(height: 26),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ScenarioChip(
                label: 'Initial load',
                selected: _selected == _Scenario.load,
                onTap: () => _select(_Scenario.load),
              ),
              _ScenarioChip(
                label: 'Refresh',
                selected: _selected == _Scenario.refresh,
                onTap: () => _select(_Scenario.refresh),
              ),
              _ScenarioChip(
                label: 'Submit action',
                selected: _selected == _Scenario.action,
                onTap: () => _select(_Scenario.action),
              ),
              _ScenarioChip(
                label: 'Pagination',
                selected: _selected == _Scenario.pagination,
                onTap: () => _select(_Scenario.pagination),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ScenarioPanel(
            selected: _selected,
            running: _running,
            failed: _failed,
            hasData: _hasData,
            actionDone: _actionDone,
            failNextPage: _failNextPage,
            itemCount: _itemCount,
            onRun: () =>
                _run(fail: _selected == _Scenario.pagination && _failNextPage),
            onFail: () => _run(fail: true),
            onTogglePageFailure: (value) =>
                setState(() => _failNextPage = value),
          ),
        ],
      ),
    ),
  );
}

class _ScenarioChip extends StatelessWidget {
  const _ScenarioChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
    showCheckmark: false,
    selectedColor: _indigo,
    backgroundColor: const Color(0xFF292A29),
    side: BorderSide(color: selected ? _indigo : const Color(0xFF4C4E4B)),
    labelStyle: TextStyle(
      color: selected ? Colors.white : const Color(0xFFD6D7D3),
      fontWeight: FontWeight.w800,
    ),
  );
}

class _ScenarioPanel extends StatelessWidget {
  const _ScenarioPanel({
    required this.selected,
    required this.running,
    required this.failed,
    required this.hasData,
    required this.actionDone,
    required this.failNextPage,
    required this.itemCount,
    required this.onRun,
    required this.onFail,
    required this.onTogglePageFailure,
  });

  final _Scenario selected;
  final bool running;
  final bool failed;
  final bool hasData;
  final bool actionDone;
  final bool failNextPage;
  final int itemCount;
  final VoidCallback onRun;
  final VoidCallback onFail;
  final ValueChanged<bool> onTogglePageFailure;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(12),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final controls = _ScenarioControls(
          selected: selected,
          running: running,
          failed: failed,
          failNextPage: failNextPage,
          onRun: onRun,
          onFail: onFail,
          onTogglePageFailure: onTogglePageFailure,
        );
        final preview = _ScenarioPreview(
          selected: selected,
          running: running,
          failed: failed,
          hasData: hasData,
          actionDone: actionDone,
          itemCount: itemCount,
        );
        return compact
            ? Column(children: [controls, preview])
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 310, child: controls),
                  Expanded(child: preview),
                ],
              );
      },
    ),
  );
}

class _ScenarioControls extends StatelessWidget {
  const _ScenarioControls({
    required this.selected,
    required this.running,
    required this.failed,
    required this.failNextPage,
    required this.onRun,
    required this.onFail,
    required this.onTogglePageFailure,
  });

  final _Scenario selected;
  final bool running;
  final bool failed;
  final bool failNextPage;
  final VoidCallback onRun;
  final VoidCallback onFail;
  final ValueChanged<bool> onTogglePageFailure;

  String get _title => switch (selected) {
    _Scenario.load => 'Screen load',
    _Scenario.refresh => 'Refresh with old data',
    _Scenario.action => 'Protected checkout',
    _Scenario.pagination => 'Append next page',
  };

  String get _body => switch (selected) {
    _Scenario.load =>
      'Test success, failure, and retry without replacing the Future.',
    _Scenario.refresh => 'The current list stays usable while new data loads.',
    _Scenario.action => 'A second tap is dropped while payment is running.',
    _Scenario.pagination => 'Loaded rows survive an append failure.',
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(right: BorderSide(color: _line)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 9),
        Text(_body, style: const TextStyle(color: _muted, height: 1.4)),
        const SizedBox(height: 22),
        if (selected == _Scenario.pagination)
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Fail next append',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            value: failNextPage,
            onChanged: running ? null : onTogglePageFailure,
          ),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: running ? null : onRun,
            style: FilledButton.styleFrom(backgroundColor: _indigo),
            child: Text(
              running
                  ? 'Running…'
                  : failed
                  ? 'Retry'
                  : _primaryLabel,
            ),
          ),
        ),
        if (selected == _Scenario.load) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: running ? null : onFail,
              child: const Text('Load with error'),
            ),
          ),
        ],
      ],
    ),
  );

  String get _primaryLabel => switch (selected) {
    _Scenario.load => 'Load successfully',
    _Scenario.refresh => 'Refresh data',
    _Scenario.action => 'Pay ₹1,499',
    _Scenario.pagination => 'Load next page',
  };
}

class _ScenarioPreview extends StatelessWidget {
  const _ScenarioPreview({
    required this.selected,
    required this.running,
    required this.failed,
    required this.hasData,
    required this.actionDone,
    required this.itemCount,
  });

  final _Scenario selected;
  final bool running;
  final bool failed;
  final bool hasData;
  final bool actionDone;
  final int itemCount;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 360,
    child: Container(
      padding: const EdgeInsets.all(24),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: switch (selected) {
          _Scenario.load => _loadPreview(),
          _Scenario.refresh => _refreshPreview(),
          _Scenario.action => _actionPreview(),
          _Scenario.pagination => _paginationPreview(),
        },
      ),
    ),
  );

  Widget _loadPreview() {
    if (running) {
      return const Center(
        key: ValueKey('load-running'),
        child: CircularProgressIndicator(),
      );
    }
    if (failed) {
      return const _DemoMessage(
        key: ValueKey('load-error'),
        icon: Icons.cloud_off_outlined,
        title: 'Could not load projects',
        body: 'The retry control uses the same Future factory safely.',
        error: true,
      );
    }
    if (!hasData) {
      return const _DemoMessage(
        key: ValueKey('load-idle'),
        icon: Icons.play_circle_outline,
        title: 'Ready to load',
        body: 'Choose success or error from the controls.',
      );
    }
    return const _ProjectList(key: ValueKey('load-data'));
  }

  Widget _refreshPreview() => Stack(
    key: const ValueKey('refresh'),
    children: [
      const _ProjectList(),
      if (running)
        const Align(
          alignment: Alignment.topCenter,
          child: LinearProgressIndicator(),
        ),
      if (failed)
        const Align(
          alignment: Alignment.bottomCenter,
          child: _InlineError('Refresh failed · existing projects kept'),
        ),
    ],
  );

  Widget _actionPreview() => Center(
    key: const ValueKey('action'),
    child: Container(
      width: 360,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pro plan', style: TextStyle(fontWeight: FontWeight.w900)),
              Text('₹1,499', style: TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 18),
          if (running) const LinearProgressIndicator(),
          if (actionDone) const _InlineSuccess('Payment completed once'),
          if (!running && !actionDone)
            const Text(
              'The action button is disabled until this request finishes.',
              style: TextStyle(color: _muted),
            ),
        ],
      ),
    ),
  );

  Widget _paginationPreview() => Column(
    key: const ValueKey('pagination'),
    children: [
      Expanded(
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.1,
          ),
          itemCount: itemCount,
          itemBuilder: (context, index) => Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _line),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Item ${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
      if (running) const LinearProgressIndicator(),
      if (failed) _InlineError('Append failed · $itemCount items kept'),
    ],
  );
}

class _ProjectList extends StatelessWidget {
  const _ProjectList({super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: const [
      _ProjectRow('Mobile checkout', 'Updated 2 min ago', _mint),
      _ProjectRow('Admin dashboard', 'Updated yesterday', _indigo),
      _ProjectRow('Marketing site', 'Updated 4 days ago', Color(0xFFE59A35)),
    ],
  );
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow(this.name, this.meta, this.color);

  final String name;
  final String meta;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        Text(meta, style: const TextStyle(color: _muted, fontSize: 12)),
      ],
    ),
  );
}

class _DemoMessage extends StatelessWidget {
  const _DemoMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.error = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool error;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 42, color: error ? Colors.red.shade700 : _indigo),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted),
        ),
      ],
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xFFFFE9E7),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.w800),
    ),
  );
}

class _InlineSuccess extends StatelessWidget {
  const _InlineSuccess(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xFFE4F5EC),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: const TextStyle(color: _mint, fontWeight: FontWeight.w900),
    ),
  );
}
