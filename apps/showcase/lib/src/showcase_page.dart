part of '../showcase.dart';

class ShowcasePage extends StatefulWidget {
  const ShowcasePage({super.key});

  @override
  State<ShowcasePage> createState() => _ShowcasePageState();
}

class _ShowcasePageState extends State<ShowcasePage> {
  final _demoKey = GlobalKey();
  final _featuresKey = GlobalKey();
  final _adaptersKey = GlobalKey();
  double _latency = 800;
  double _failureRate = 20;
  bool _refreshing = true;
  bool _lastFailed = false;
  Timer? _timer;

  static const _users = [
    _User('AL', 'Alice Lee', 'alice.lee@example.com', true, Color(0xFFE8E5FF)),
    _User(
      'BM',
      'Bruno Martin',
      'bruno.martin@example.com',
      true,
      Color(0xFFDFF4E9),
    ),
    _User(
      'CW',
      'Chloe Wang',
      'chloe.wang@example.com',
      false,
      Color(0xFFF7ECD6),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _runRequest();
  }

  void _runRequest() {
    _timer?.cancel();
    setState(() {
      _refreshing = true;
      _lastFailed = false;
    });
    _timer = Timer(Duration(milliseconds: _latency.round()), () {
      if (!mounted) return;
      setState(() {
        _refreshing = false;
        _lastFailed = Random().nextDouble() * 100 < _failureRate;
      });
    });
  }

  Future<void> _copyInstall() async {
    final copied = await copyText('flutter pub add steady_async');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          copied
              ? 'Install command copied'
              : 'Copy blocked — select the command and copy it manually',
        ),
      ),
    );
  }

  Future<void> _scrollTo(GlobalKey key) async {
    final target = key.currentContext;
    if (target == null) return;
    await Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: .08,
    );
  }

  Future<void> _open(String url) async {
    final opened = await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open link')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SelectionArea(
      child: CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _TopBarDelegate(
              child: _TopBar(
                onDemo: () => _scrollTo(_demoKey),
                onFeatures: () => _scrollTo(_featuresKey),
                onAdapters: () => _scrollTo(_adaptersKey),
                onDocs: () => _open(
                  'https://github.com/MohammedSafwan10/steady_async#readme',
                ),
                onGitHub: () =>
                    _open('https://github.com/MohammedSafwan10/steady_async'),
                onCopy: _copyInstall,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: KeyedSubtree(
              key: _demoKey,
              child: _Hero(
                latency: _latency,
                failureRate: _failureRate,
                refreshing: _refreshing,
                lastFailed: _lastFailed,
                users: _users,
                onLatency: (value) => setState(() => _latency = value),
                onFailureRate: (value) => setState(() => _failureRate = value),
                onRun: _runRequest,
                onCopy: _copyInstall,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: _ProofStrip()),
          SliverToBoxAdapter(
            child: _Comparison(
              refreshing: _refreshing,
              users: _users,
              onRun: _runRequest,
            ),
          ),
          const SliverToBoxAdapter(child: _ScenarioShowcase()),
          const SliverToBoxAdapter(child: _ProductionLab()),
          SliverToBoxAdapter(
            child: KeyedSubtree(key: _featuresKey, child: const _FeatureGrid()),
          ),
          const SliverToBoxAdapter(child: _CodeSection()),
          SliverToBoxAdapter(
            child: KeyedSubtree(
              key: _adaptersKey,
              child: const _PackagesSection(),
            ),
          ),
          const SliverToBoxAdapter(child: _Footer()),
        ],
      ),
    ),
  );

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
