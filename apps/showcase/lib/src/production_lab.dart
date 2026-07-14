part of '../showcase.dart';

class _ProductionLab extends StatefulWidget {
  const _ProductionLab();

  @override
  State<_ProductionLab> createState() => _ProductionLabState();
}

class _ProductionLabState extends State<_ProductionLab> {
  late final _LabObserver _observer;
  late final SteadyAsyncController<String> _request;
  late final SteadyPagedController<String, int> _pager;
  Duration _nextDuration = const Duration(milliseconds: 250);
  int _failuresRemaining = 0;
  int _cancelCount = 0;
  String _source = 'Team A';

  @override
  void initState() {
    super.initState();
    _observer = _LabObserver();
    _request = SteadyAsyncController<String>.cancellable(
      _makeRequest,
      requestPolicy: SteadyRequestPolicy(
        timeout: const Duration(milliseconds: 600),
        retry: SteadyRetryPolicy.fixed(
          maxAttempts: 2,
          delay: const Duration(milliseconds: 250),
        ),
      ),
      observer: _observer,
      operationLabel: 'request-lab',
    );
    _pager = SteadyPagedController<String, int>.cancellable(
      firstPageKey: 0,
      sourceKey: _source,
      seed: SteadyPagedSeed(
        items: const ['Cached report', 'Cached invoice'],
        nextKey: 1,
        lastUpdatedAt: DateTime.now().subtract(const Duration(minutes: 8)),
      ),
      itemKey: (item) => item,
      loadPage: _loadPage,
      observer: _observer,
      operationLabel: 'workspace-grid',
    );
  }

  SteadyCancellableOperation<String> _makeRequest() {
    final completer = Completer<String>();
    final timer = Timer(_nextDuration, () {
      if (_failuresRemaining > 0) {
        _failuresRemaining--;
        completer.completeError(StateError('Temporary API failure'));
      } else {
        completer.complete('Completed in ${_nextDuration.inMilliseconds} ms');
      }
    });
    return SteadyCancellableOperation(
      future: completer.future,
      cancel: () {
        timer.cancel();
        _cancelCount++;
        if (mounted) setState(() {});
      },
    );
  }

  SteadyCancellableOperation<SteadyPage<String, int>> _loadPage(int page) {
    final completer = Completer<SteadyPage<String, int>>();
    final source = _source;
    final timer = Timer(const Duration(milliseconds: 320), () {
      final offset = page * 4;
      completer.complete(
        SteadyPage(
          items: List.generate(
            4,
            (index) => '$source item ${offset + index + 1}',
          ),
          nextKey: page >= 2 ? null : page + 1,
        ),
      );
    });
    return SteadyCancellableOperation(
      future: completer.future,
      cancel: timer.cancel,
    );
  }

  void _runFast() {
    _nextDuration = const Duration(milliseconds: 250);
    _failuresRemaining = 0;
    unawaited(_request.reload());
  }

  void _runRetry() {
    _nextDuration = const Duration(milliseconds: 180);
    _failuresRemaining = 1;
    unawaited(_request.reload());
  }

  void _runTimeout() {
    _nextDuration = const Duration(milliseconds: 900);
    _failuresRemaining = 0;
    unawaited(_request.reload());
  }

  Future<void> _switchSource(String source) async {
    setState(() => _source = source);
    await _pager.replaceCancellableSource(
      sourceKey: source,
      firstPageKey: 0,
      loadPage: _loadPage,
      seed: SteadyPagedSeed(
        items: ['$source cached item'],
        nextKey: 1,
        lastUpdatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  void _optimisticEdit() {
    final items = _pager.value.items;
    if (items.isEmpty) return;
    final current = items.first;
    final handle = _pager.optimisticUpdateByKey(
      current,
      (item) => '$item · edited',
    );
    handle.commit();
  }

  void _optimisticDeleteAndRollback() {
    final items = _pager.value.items;
    if (items.isEmpty) return;
    final handle = _pager.optimisticRemoveByKey(items.first);
    Timer(const Duration(milliseconds: 800), handle.rollback);
  }

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFEDECF8),
    padding: const EdgeInsets.symmetric(vertical: 72),
    child: _PageWidth(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PRODUCTION LAB',
            style: TextStyle(
              color: _indigo,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'The awkward cases, running for real.',
            style: TextStyle(
              color: _ink,
              fontSize: 40,
              height: 1.05,
              letterSpacing: -1.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Trigger retries, a real timeout cancellation, cached hydration, source changes, and optimistic rollback.',
            style: TextStyle(color: _muted, fontSize: 17),
          ),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [_requestCard(), _dataCard(), _telemetryCard()];
              if (constraints.maxWidth < 900) {
                return Column(
                  children: [
                    for (final card in cards) ...[
                      card,
                      const SizedBox(height: 16),
                    ],
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
        ],
      ),
    ),
  );

  Widget _requestCard() => _LabCard(
    title: 'Retry + timeout',
    caption: 'The timeout path invokes the operation’s cancel callback.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder(
          valueListenable: _request,
          builder: (context, state, _) => Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _paper,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(switch (state) {
              SteadyLoading<String>(:final attempt) =>
                'Running attempt $attempt',
              SteadyData<String>(:final value) => value,
              SteadyError<String>(:final error) =>
                error is SteadyTimeoutException
                    ? 'Timed out after 600 ms'
                    : 'Failed: $error',
              _ => 'Ready',
            }, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(onPressed: _runFast, child: const Text('Fast')),
            OutlinedButton(
              onPressed: _runRetry,
              child: const Text('Fail once'),
            ),
            OutlinedButton(
              onPressed: _runTimeout,
              child: const Text('Timeout'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Real cancellations: $_cancelCount',
          style: const TextStyle(color: _muted),
        ),
      ],
    ),
  );

  Widget _dataCard() => _LabCard(
    title: 'Cache + source + optimistic UI',
    caption:
        'Cached items show immediately. Switching users clears the old source.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Team A'),
              selected: _source == 'Team A',
              onSelected: (_) => unawaited(_switchSource('Team A')),
            ),
            ChoiceChip(
              label: const Text('Team B'),
              selected: _source == 'Team B',
              onSelected: (_) => unawaited(_switchSource('Team B')),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 190,
          child: CustomScrollView(
            slivers: [
              SteadyPagedSliverGrid<String, int>(
                controller: _pager,
                prefetchItemCount: 2,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.4,
                ),
                itemBuilder: (context, item, index) => DecoratedBox(
                  decoration: BoxDecoration(
                    color: _paper,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _line),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(item, textAlign: TextAlign.center),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: _optimisticEdit,
              child: const Text('Edit instantly'),
            ),
            OutlinedButton(
              onPressed: _optimisticDeleteAndRollback,
              child: const Text('Delete, then rollback'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _telemetryCard() => _LabCard(
    title: 'Payload-free telemetry',
    caption:
        'Events include timing and attempts—never response values or source keys.',
    child: AnimatedBuilder(
      animation: _observer,
      builder: (context, _) => Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 250),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _ink,
          borderRadius: BorderRadius.circular(8),
        ),
        child: _observer.lines.isEmpty
            ? const Text(
                'Run an operation to inspect events.',
                style: TextStyle(color: Colors.white70),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in _observer.lines.take(9))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Text(
                        line,
                        style: const TextStyle(
                          color: Color(0xFFD7D8FF),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                ],
              ),
      ),
    ),
  );

  @override
  void dispose() {
    _request.dispose();
    _pager.dispose();
    _observer.dispose();
    super.dispose();
  }
}

class _LabCard extends StatelessWidget {
  const _LabCard({
    required this.title,
    required this.caption,
    required this.child,
  });

  final String title;
  final String caption;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 7),
        Text(caption, style: const TextStyle(color: _muted, height: 1.4)),
        const SizedBox(height: 18),
        child,
      ],
    ),
  );
}

class _LabObserver extends ChangeNotifier implements SteadyObserver {
  final List<String> lines = [];

  @override
  void onEvent(SteadyLifecycleEvent event) {
    final elapsed = event.elapsed?.inMilliseconds ?? 0;
    lines.insert(
      0,
      '${event.controllerType} #${event.operationId}  ${event.kind.name}  ${elapsed}ms',
    );
    if (lines.length > 12) lines.removeLast();
    notifyListeners();
  }
}
