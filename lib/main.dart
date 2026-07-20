import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'battle_buddy_engine.dart';
import 'models/status_snapshot.dart';
import 'models/alert_event.dart';
import 'models/monthly_budget.dart';
import 'models/execution_mode.dart';
import 'models/feed_health.dart';
import 'models/strategy_profile.dart';
import 'models/confirm_window.dart';
import 'models/lockdown.dart';
import 'models/heat_mode.dart';
import 'models/strategy_report.dart';
import 'models/deployment_plan.dart';
import 'models/sell_plan.dart';
import 'models/position.dart';
import 'models/threshold_step_state.dart';
import 'assets/asset_catalog_store.dart';
import 'assets/asset_registry.dart';
import 'assets/dynamic_asset_store.dart';
import 'assets/removed_asset_purge_policy.dart';
import 'price/price_feed.dart';
import 'price/coingecko_price_feed.dart';
import 'price/coinbase_price_feed.dart';
import 'price/binance_price_feed.dart';
import 'price/kraken_price_feed.dart';
import 'engine/polling_engine.dart';
import 'engine/threshold_step_state_merge.dart';
import 'engine/threshold_triggered_report_assembly.dart';
import 'engine/market_regime_engine.dart';
import 'portfolio_math.dart';
import 'alerts_engine.dart' as alerts_engine;
import 'strategy/profiles.dart';
import 'utils/report_exporter.dart';
import 'utils/report_exporter_selector.dart';
import 'ui/debug_screen.dart';
import 'ui/operator_screen.dart';

const String _onboardingKey = 'seen_onboarding_v1';
const String _operatorArmedSymbolsKey = 'operator_armed_symbols_v1';
const bool kAssetDebugLogs = false;
const Color _kBackground = Color(0xFF081321);
const Color _kSurfaceStrong = Color(0xFF12273A);
const Color _kTextStrong = Color(0xFFFFFFFF);
const Color _kTextMuted = Color(0xFF90A0AE);

void main() {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final deferFirstFrame =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  if (deferFirstFrame) {
    binding.deferFirstFrame();
  }
  final showDebug = Uri.base.queryParameters['debug'] == '1';
  runApp(CryptoBattleBuddyApp(showDebug: showDebug));
}

class CryptoBattleBuddyApp extends StatelessWidget {
  final bool showDebug;
  const CryptoBattleBuddyApp({super.key, required this.showDebug});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crypto Battle Buddy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: FirstRunGate(showDebug: showDebug && kDebugMode),
    );
  }
}

class FirstRunGate extends StatefulWidget {
  final bool showDebug;
  const FirstRunGate({super.key, required this.showDebug});

  @override
  State<FirstRunGate> createState() => _FirstRunGateState();
}

class _FirstRunGateState extends State<FirstRunGate> {
  bool _hasSeenOnboarding = false;
  bool _isLoadingOnboarding = true;
  bool _startupStarted = false;

  bool get _showAndroidSplash =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startupStarted) return;
    _startupStarted = true;
    _loadOnboarding();
  }

  Future<bool> _readOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_onboardingKey) ?? false;
    } catch (e, st) {
      debugPrint('Failed to load onboarding: $e');
      debugPrintStack(stackTrace: st);
      return false;
    }
  }

  Future<void> _loadOnboarding() async {
    final onboardingFuture = _readOnboarding();

    if (_showAndroidSplash) {
      try {
        await precacheImage(
          const AssetImage('assets/images/splash.png'),
          context,
        );
      } catch (e, st) {
        debugPrint('Failed to preload splash: $e');
        debugPrintStack(stackTrace: st);
      } finally {
        WidgetsBinding.instance.allowFirstFrame();
      }
      await WidgetsBinding.instance.waitUntilFirstFrameRasterized;
      await Future<void>.delayed(const Duration(milliseconds: 3000));
    }

    final hasSeenOnboarding = await onboardingFuture;
    if (!mounted) return;
    setState(() {
      _hasSeenOnboarding = hasSeenOnboarding;
      _isLoadingOnboarding = false;
    });
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    if (!mounted) return;
    setState(() {
      _hasSeenOnboarding = true;
    });
  }

  Widget _buildMainApp() {
    return AppShell(showDebug: widget.showDebug);
  }

  Widget _buildOnboarding() {
    return Scaffold(
      backgroundColor: _kBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DEFINE',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _kTextStrong,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Set your tiers before execution',
                style: TextStyle(fontSize: 13, color: _kTextMuted),
              ),
              const SizedBox(height: 24),
              const Text(
                'ARM',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _kTextStrong,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Activate the plan',
                style: TextStyle(fontSize: 13, color: _kTextMuted),
              ),
              const SizedBox(height: 24),
              const Text(
                'EXECUTE',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _kTextStrong,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Act when triggered',
                style: TextStyle(fontSize: 13, color: _kTextMuted),
              ),
              const SizedBox(height: 24),
              const Text(
                'REVIEW',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _kTextStrong,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Measure discipline',
                style: TextStyle(fontSize: 13, color: _kTextMuted),
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: _completeOnboarding,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _kSurfaceStrong,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'ENTER',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _kTextStrong,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingOnboarding) {
      if (_showAndroidSplash) {
        return Scaffold(
          backgroundColor: const Color(0xFF0A1F44),
          body: SizedBox.expand(
            child: Image.asset(
              'assets/images/splash.png',
              fit: BoxFit.cover,
            ),
          ),
        );
      }
      return const Scaffold(
        backgroundColor: _kBackground,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return _hasSeenOnboarding ? _buildMainApp() : _buildOnboarding();
  }
}

class AppShell extends StatefulWidget {
  final bool showDebug;
  final BattleBuddyEngine? _engineOverride;
  final PriceFeed? _feedOverride;

  const AppShell({super.key, required this.showDebug})
      : _engineOverride = null,
        _feedOverride = null;

  @visibleForTesting
  const AppShell.forTesting({
    super.key,
    required this.showDebug,
    required BattleBuddyEngine engine,
    required PriceFeed feed,
  })  : _engineOverride = engine,
        _feedOverride = feed;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final BattleBuddyEngine engine;
  PollingEngine? _poller;
  final AssetCatalogStore _catalogStore = AssetCatalogStore();
  final DynamicAssetStore _dynamicStore = DynamicAssetStore();
  late PriceFeed _feed;
  Timer? _readyRefreshTimer;
  Timer? _offlineRetryTimer;
  DateTime? _lastOfflineRetryAttemptTs;
  late final ReportExporter reportExporter;
  final List<String> availableFeedIds = const [
    'CoinGecko',
    'Coinbase',
    'Binance',
    'Kraken'
  ];
  late String selectedFeedId;

  StrategyProfile selectedProfile = balanced;
  StatusSnapshot? snapshot;
  List<AlertEvent> alerts = [];
  String snapshotPretty = '';
  String error = '';
  FeedHealth? health;
  MonthlyBudget? budget;
  Map<String, double> livePricesUsd = {};
  Map<String, Map<String, ThresholdStepState>> thresholdStepStatesBySymbol =
      <String, Map<String, ThresholdStepState>>{};
  String pnlSummary = '';
  String rebalanceSummary = '';
  Set<String> armedSymbols = <String>{};
  String heatForceMessage = '';
  ConfirmWindow confirmWindow = ConfirmWindow(expiresAt: null);
  String reportPretty = '';
  Map<String, dynamic>? lastReportJson;
  String copyStatus = '';
  String statusText = '';
  String nextActionText = '';
  bool _didPruneCatalogStx = false;
  bool _startPollingInFlight = false;
  int _startPollingGen = 0;
  List<String> _activeSymbols = const [];
  DateTime? _lastStartPollingAt;
  String? _lastStartPollingSig;
  MarketRegimeResult? lastRegime;
  RegimePolicyKnobs? lastRegimeKnobs;
  PortfolioSummary? lastPortfolio;
  alerts_engine.AlertsResult? lastAlertsResult;
  String alertsSummary = '';
  List<String> alertsLines = const [];
  LockdownState lockdown = LockdownState(
    enabled: false,
    checklist: ReleaseChecklist(
      reviewedZones: false,
      reviewedBudget: false,
      reviewedHeat: false,
      reviewedExecutionMode: false,
    ),
  );
  String lockdownMessage = '';
  StrategyReport? currentReport;

  PriceFeed _createFeed(String id) {
    switch (id) {
      case 'CoinGecko':
        return CoinGeckoPriceFeed();
      case 'Coinbase':
        return CoinbasePriceFeed();
      case 'Binance':
        return BinancePriceFeed();
      case 'Kraken':
        return KrakenPriceFeed();
      default:
        return CoinGeckoPriceFeed();
    }
  }

  String _boundedSymbolsForLog(Iterable<String> symbols) {
    final list = symbols.map((e) => e.toUpperCase()).toSet().toList()..sort();
    const cap = 30;
    if (list.length <= cap) {
      return '[${list.join(", ")}]';
    }
    final head = list.take(cap).join(', ');
    return '[$head, ...(+${list.length - cap})]';
  }

  Future<Set<String>> _normalizeEnabledSymbolsOnStartup() async {
    final anchors = <String>{};
    final rawCatalog = await _catalogStore.loadCatalog();
    final catalog = <String, String>{
      for (final e in rawCatalog.entries) e.key.toUpperCase(): e.value,
    };
    final dyn = await _dynamicStore.loadAll();
    final before = (await _catalogStore.loadEnabledSymbols())
        .map((e) => e.toUpperCase())
        .toSet();

    if (!_didPruneCatalogStx) {
      _didPruneCatalogStx = true;
      final enabledHasStx = before.contains('STX');
      final dynHasStx = dyn.any((a) => a.symbol.toUpperCase() == 'STX');
      final anchorHasStx = anchors.contains('STX');
      final catalogHasStx = catalog.keys.any((k) => k.toUpperCase() == 'STX');
      var stxRemoved = false;
      var pruneReason = 'catalogMissingStx';
      if (catalogHasStx) {
        if (!enabledHasStx && !dynHasStx && !anchorHasStx) {
          catalog.removeWhere((k, _) => k.toUpperCase() == 'STX');
          await _catalogStore.saveCatalog(catalog);
          stxRemoved = true;
          pruneReason = 'pruned';
        } else {
          pruneReason = 'kept';
        }
      }
      if (kDebugMode && kAssetDebugLogs) {
        // ignore: avoid_print
        print(
          'CATALOG_PRUNED_STX: removed=$stxRemoved reason=$pruneReason '
          'enabledHasStx=$enabledHasStx dynHasStx=$dynHasStx',
        );
      }
    }

    final allowed = <String>{
      ...anchors,
      ...catalog.keys.map((e) => e.toUpperCase()),
      ...dyn.map((a) => a.symbol.toUpperCase()),
    };
    final dropped = before.where((s) => !allowed.contains(s)).toSet();
    final addedAnchors = anchors.where((a) => !before.contains(a)).toSet();
    final after = <String>{
      ...before.where((s) => allowed.contains(s)),
      ...anchors,
    };

    if (!setEquals(before, after)) {
      await _catalogStore.saveEnabledSymbols(after);
    }

    if (kDebugMode && kAssetDebugLogs) {
      // ignore: avoid_print
      print(
        'ENABLED_NORMALIZED: before=${_boundedSymbolsForLog(before)} '
        'after=${_boundedSymbolsForLog(after)} '
        'dropped=${_boundedSymbolsForLog(dropped)} '
        'addedAnchors=${_boundedSymbolsForLog(addedAnchors)}',
      );
    }
    return after;
  }

  Future<void> _setSelectedFeed(String id) async {
    if (id == selectedFeedId) return;
    final newFeed = _createFeed(id);
    setState(() {
      selectedFeedId = id;
      _feed = newFeed;
      livePricesUsd = {};
      snapshot = null;
      health = _feed.health;
    });
    _stopTickerIfNotNeeded();
    await _startPolling(reason: 'feedChanged');
    _syncOfflineRetry();
  }

  @override
  void initState() {
    super.initState();
    engine = widget._engineOverride ?? BattleBuddyEngine();
    selectedFeedId = 'CoinGecko';
    _feed = widget._feedOverride ?? _createFeed(selectedFeedId);
    debugPrint('FEED INIT: $selectedFeedId');
    health = _feed.health;
    reportExporter = createReportExporter();
    _init();
  }

  @override
  void dispose() {
    _readyRefreshTimer?.cancel();
    _offlineRetryTimer?.cancel();
    _poller?.stop();
    super.dispose();
  }

  Set<String> _normalizeArmedSymbols(Iterable<String> symbols) {
    return symbols
        .map((s) => s.trim().toUpperCase())
        .where((s) => s.isNotEmpty)
        .toSet();
  }

  Future<Set<String>> _loadPersistedArmedSymbols() async {
    final prefs = await SharedPreferences.getInstance();
    return _normalizeArmedSymbols(
      prefs.getStringList(_operatorArmedSymbolsKey) ?? const <String>[],
    );
  }

  Future<void> _savePersistedArmedSymbols(Set<String> symbols) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = _normalizeArmedSymbols(symbols).toList()..sort();
    await prefs.setStringList(_operatorArmedSymbolsKey, normalized);
  }

  Future<void> _init() async {
    await engine.clearTransientMarketCaches();
    final persistedArmedSymbols = await _loadPersistedArmedSymbols();
    if (mounted) {
      setState(() {
        armedSymbols = persistedArmedSymbols;
      });
    } else {
      armedSymbols = persistedArmedSymbols;
    }
    await engine.loadState();
    await engine.loadHoldings();
    await engine.loadAlertRules();
    final saved = await engine.loadSelectedProfile();
    if (saved != null) {
      final match = allProfiles.firstWhere(
        (p) => p.name == saved,
        orElse: () => balanced,
      );
      selectedProfile = match;
    }
    lockdown = LockdownState(
      enabled: false,
      checklist: ReleaseChecklist(
        reviewedZones: false,
        reviewedBudget: false,
        reviewedHeat: false,
        reviewedExecutionMode: false,
      ),
    );
    await engine.saveLockdown(lockdown);
    engine.setMonthlyBudget(
      MonthlyBudget(
        monthlyLimit: 500,
        spentThisMonth: 0,
        month: DateTime(DateTime.now().year, DateTime.now().month, 1),
      ),
    );

    await _startPolling(reason: 'init');
  }

  Future<void> _startPolling({String reason = 'unknown'}) async {
    if (_startPollingInFlight) {
      // ignore: avoid_print
      print('POLL_START_GUARD: dropped reason=inFlight source=$reason');
      return;
    }
    _startPollingInFlight = true;
    final gen = ++_startPollingGen;
    try {
      final pollingInterval = selectedProfile.pollingInterval;
      final enabled = await _normalizeEnabledSymbolsOnStartup();
      final symbols = enabled.toList()..sort();
      _activeSymbols = symbols;
      final sig =
          '${_feed.name}|${pollingInterval.inSeconds}|${symbols.join(",")}';
      final now = DateTime.now();
      if (_lastStartPollingAt != null &&
          now.difference(_lastStartPollingAt!).inMilliseconds < 2000 &&
          _lastStartPollingSig == sig) {
        print('POLL_START_THROTTLE: dropped reason=$reason sig=$sig');
        return;
      }
      _lastStartPollingAt = now;
      _lastStartPollingSig = sig;

      _poller?.stop();

      final targets = selectedProfile.targets;
      final policy = selectedProfile.ladderPolicy;

      final Map<String, List<double>> buyZones = const <String, List<double>>{};
      final Map<String, List<double>> sellZones =
          const <String, List<double>>{};

      _poller = PollingEngine(
        engine: engine,
        feed: _feed,
        interval: pollingInterval,
      );
      // --- R5: Asset symbol integrity check (non-crashing, always-on) ---
      final enabledUpper = enabled.map((e) => e.toUpperCase()).toSet();
      final symbolsUpper = symbols.map((e) => e.toUpperCase()).toSet();

      if (!setEquals(enabledUpper, symbolsUpper)) {
        final missingFromPoll = enabledUpper.difference(symbolsUpper);
        final extraInPoll = symbolsUpper.difference(enabledUpper);

        print(
          'ASSET_SYMBOLS_MISMATCH: '
          'enabled=${enabledUpper.toList()..sort()} '
          'poll=${symbolsUpper.toList()..sort()} '
          'missingFromPoll=${missingFromPoll.toList()..sort()} '
          'extraInPoll=${extraInPoll.toList()..sort()}',
        );
      }
      // --- end R5 integrity check ---
      if (kDebugMode && kAssetDebugLogs) {
        // ignore: avoid_print
        print('ASSET_SYMBOLS_FOR_POLL: ${_boundedSymbolsForLog(symbols)}');
      }

      _poller!.start(
        symbols: symbols,
        buyZonesBySymbol: buyZones,
        sellZonesBySymbol: sellZones,
        targets: targets,
        policy: policy,
        mode: ExecutionMode.dryRun,
        startReason: reason,
        onTick: (
          snap,
          intent,
          thresholdStateDelta,
          freshMarketDataAvailable,
        ) async {
          if (!freshMarketDataAvailable) {
            if (!mounted) return;
            setState(() {
              health = _feed.health;
            });
            _stopTickerIfNotNeeded();
            _syncOfflineRetry();
            return;
          }

          final now = DateTime.now();
          final currentBudget = engine.getCurrentBudget(now);

          final List<AlertEvent> guardedAlerts =
              engine.generateAlertsFromSnapshot(
            snapshot: snap,
            cooldown: const Duration(minutes: 30),
          );

          final plan = engine.buildDeploymentFromAlerts(
            alerts: guardedAlerts,
            targets: targets,
            budget: currentBudget,
            policy: policy,
          );

          final updatedBudget = engine.applySpendToBudget(
            budget: currentBudget,
            plan: plan,
          );

          engine.setMonthlyBudget(updatedBudget);

          final positions = {
            for (final entry in engine.holdings.entries)
              entry.key.toUpperCase(): Position(
                symbol: entry.key.toUpperCase(),
                units: entry.value,
                costBasisUsd:
                    entry.value * (snap.prices[entry.key.toUpperCase()] ?? 0.0),
                avgCostUsd: snap.prices[entry.key.toUpperCase()] ?? 0.0,
              ),
          };

          final sellPolicy = selectedProfile.sellPolicy;
          final sellPlan = engine.buildSellPlanFromAlerts(
            alerts: guardedAlerts,
            positions: positions,
            prices: snap.prices,
            policy: sellPolicy,
          );

          final pnl =
              engine.buildPnl(positions: positions, prices: snap.prices);
          final rebalance = engine.buildRebalance(
            positions: positions,
            prices: snap.prices,
            targets: targets,
          );
          const mode = ExecutionMode.dryRun;
          final execIntent =
              engine.buildExecutionIntent(plan: plan, mode: mode);

          final alertsResult = engine.evaluateAlerts(
            prices: snap.prices,
          );
          final regimeResult = computeMarketRegime(
            pricesUsd: snap.prices,
            heatStatusTextOrFlag: null,
          );
          final modeLabel = _modeLabelFromProfile(selectedProfile.name);
          final regimeKnobs =
              mapRegimeToKnobs(modeLabel: modeLabel, regime: regimeResult);
          final includedSymbols = List<String>.from(_activeSymbols);
          final portfolioSummary = computePortfolioSummary(
            includedSymbols: includedSymbols,
            holdingsBySymbol: engine.holdings,
            pricesUsd: snap.prices,
            targetWeights: {
              for (final t in selectedProfile.targets)
                t.symbol.toUpperCase(): t.weight,
            },
          );
          final regimeStatus =
              _buildStatusText(regimeResult, regimeKnobs, portfolioSummary);
          final regimeAction = _buildNextActionText(
            buySymbols: guardedAlerts
                .where((AlertEvent a) => a.type == AlertType.buyZone)
                .map((a) => a.symbol.toUpperCase())
                .toSet(),
            sellSymbols: guardedAlerts
                .where((AlertEvent a) => a.type == AlertType.sellZone)
                .map((a) => a.symbol.toUpperCase())
                .toSet(),
            deploymentPlan: plan,
            sellPlan: sellPlan,
            budgetRemaining: updatedBudget.remaining,
            knobs: regimeKnobs,
            portfolioSummary: portfolioSummary,
          );
          final regimeJson = {
            ...regimeResult.toJson(),
            'mode': modeLabel,
            'knobs': regimeKnobs.toJson(),
            'heat': '',
          };
          final gate = engine.evaluateExecutionGate(
            budgetRemainingUsd: updatedBudget.remaining,
            buyAlertsCount: alertsResult.buyCount,
            sellAlertsCount: alertsResult.sellCount,
            modeLabel: modeLabel,
          );
          final perActions = engine.perAssetActions(gate: gate);
          final holdingsValue = {
            for (final entry in engine.holdings.entries)
              entry.key.toUpperCase(): {
                'units': entry.value,
                'value_usd': snap.prices[entry.key.toUpperCase()] == null
                    ? 0.0
                    : entry.value *
                        (snap.prices[entry.key.toUpperCase()] ?? 0.0),
              }
          };

          final top3 = rebalance.lines.take(3).toList();
          if (top3.isEmpty) {
            rebalanceSummary = 'Rebalance: no data (no market value yet).';
          } else {
            final parts = top3.map((l) {
              final action = l.deltaUsd >= 0 ? 'WATCH' : 'PROFIT';
              return '$action ${l.symbol} \$${l.deltaUsd.abs().toStringAsFixed(2)}';
            }).join(' | ');
            rebalanceSummary =
                'Rebalance (top 3): $parts (Total MV \$${rebalance.totalMarketValueUsd.toStringAsFixed(2)})';
          }

          final budgetJson = {
            'month':
                DateTime(updatedBudget.month.year, updatedBudget.month.month, 1)
                    .toIso8601String(),
            'monthlyLimit': updatedBudget.monthlyLimit,
            'spentThisMonth': updatedBudget.spentThisMonth,
            'remaining': updatedBudget.remaining,
          };

          final positionsJson =
              positions.map((k, v) => MapEntry(k, v.toJson()));
          final alertsJson = guardedAlerts
              .map((a) => a.toJson())
              .toList()
              .cast<Map<String, dynamic>>();
          final snapshotJson = snap.toJson();
          final pnlJson = pnl.toJson();
          final rebalanceJson = rebalance.toJson();
          final lastLedger = null;
          final normalizedPrices = <String, double>{
            for (final entry in snap.prices.entries)
              entry.key.toUpperCase(): entry.value,
          };
          final thresholdTriggeredSteps =
              await buildThresholdTriggeredStepsForReport(
            symbols: includedSymbols,
            thresholdStateDelta: thresholdStateDelta,
            pricesUsd: normalizedPrices,
          );

          final report = engine.buildReport(
            profileName: selectedProfile.name,
            modeLabel: modeLabel,
            feedLabel: _feed.name,
            feedHealth: _feed.health,
            heat: HeatModeState(isHot: false, message: ''),
            snapshotJson: snapshotJson,
            alertsJson: alertsJson,
            deploymentPlan: plan,
            intent: execIntent,
            budgetJson: budgetJson,
            positionsJson: positionsJson,
            pnlJson: pnlJson,
            rebalanceJson: rebalanceJson,
            lastLedgerRecord: lastLedger,
            marketRegime: regimeJson,
            guidance: {
              'statusText': regimeStatus,
              'nextActionText': regimeAction,
            },
            holdings: holdingsValue,
            portfolio: portfolioSummary.toJson(),
            alertsSummary: alertsResult.summaryLine,
            alertsEvents: alertsResult.events
                .map((e) => {
                      'asset': e.asset,
                      'kind': e.kind.name,
                      'message': e.message,
                      'price': e.price,
                    })
                .toList(),
            executionGate: {
              'canExecute': gate.canExecute,
              'blockers': gate.blockers,
              'maxSpendUsd': gate.maxSpendUsd,
              'max_spend_now': gate.maxSpendUsd,
              'statusText': gate.statusText,
              'nextActionText': gate.nextActionText,
              'allowed': gate.canExecute,
              'blocked_by': gate.blockers.isEmpty
                  ? 'none'
                  : gate.blockers.first.toLowerCase(),
              'reason': gate.statusText,
              'budget_left': updatedBudget.remaining,
              'mode': modeLabel,
              'alerts_buy': alertsResult.buyCount,
              'alerts_sell': alertsResult.sellCount,
            },
            perAssetActions: perActions,
            monthlyBudget: updatedBudget.monthlyLimit,
            monthlySpent: updatedBudget.spentThisMonth,
            monthlyRemaining: updatedBudget.remaining,
            buyAlerts: alertsResult.buyCount,
            sellAlerts: alertsResult.sellCount,
            thresholdTriggeredSteps: thresholdTriggeredSteps,
          );

          final pretty =
              const JsonEncoder.withIndent('  ').convert(report.toJson());

          setState(() {
            snapshot = snap;
            livePricesUsd = Map<String, double>.from(normalizedPrices);
            if (thresholdStateDelta.isNotEmpty) {
              thresholdStepStatesBySymbol = mergeExternalStepStates(
                current: thresholdStepStatesBySymbol,
                incoming: thresholdStateDelta,
              );
            }
            alerts = _poller?.alerts ?? [];
            snapshotPretty = pretty;
            health = _feed.health;
            budget = updatedBudget;
            pnlSummary = report.summary;
            this.rebalanceSummary = rebalanceSummary;
            heatForceMessage = heatForceMessage;
            reportPretty = pretty;
            lastReportJson = report.toJson();
            copyStatus = '';
            currentReport = report;
            statusText = regimeStatus;
            nextActionText = regimeAction;
            lastRegime = regimeResult;
            lastRegimeKnobs = regimeKnobs;
            lastPortfolio = portfolioSummary;
            lastAlertsResult = alertsResult;
            alertsSummary = alertsResult.summaryLine;
            alertsLines =
                alertsResult.events.take(3).map((e) => e.message).toList();
          });
          _stopTickerIfNotNeeded();
          _startTickerIfNeeded();
          _syncOfflineRetry();

          await engine.saveLastReport(report);
        },
      );
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      if (gen == _startPollingGen) _startPollingInFlight = false;
    }
  }

  void _startTickerIfNeeded() {
    final feedHealth = health ?? _feed.health;
    final eval = evaluateReady(
      feedHealth: feedHealth,
      snapshot: snapshot,
      livePricesUsd: livePricesUsd,
      pollingInterval: selectedProfile.pollingInterval,
      now: DateTime.now(),
    );
    final needsTicker = eval.hasSnapshot &&
        eval.hasPrices &&
        feedHealth.status == FeedStatus.healthy;
    if (needsTicker && _readyRefreshTimer == null) {
      _readyRefreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _stopTickerIfNotNeeded() {
    final feedHealth = health ?? _feed.health;
    final eval = evaluateReady(
      feedHealth: feedHealth,
      snapshot: snapshot,
      livePricesUsd: livePricesUsd,
      pollingInterval: selectedProfile.pollingInterval,
      now: DateTime.now(),
    );
    final needsTicker = eval.hasSnapshot &&
        eval.hasPrices &&
        feedHealth.status == FeedStatus.healthy;
    if (!needsTicker) {
      _readyRefreshTimer?.cancel();
      _readyRefreshTimer = null;
    }
  }

  void _stopOfflineRetry() {
    _offlineRetryTimer?.cancel();
    _offlineRetryTimer = null;
  }

  void _syncOfflineRetry() {
    if (!mounted) return;
    final st = (health ?? _feed.health).status;
    if (st != FeedStatus.healthy) {
      if (_offlineRetryTimer != null) return;
      _offlineRetryTimer =
          Timer.periodic(const Duration(seconds: 5), (_) async {
        if (!mounted) return;
        final poller = _poller;
        if (poller == null) return;
        if (poller.isTicking) return;

        final st2 = (health ?? _feed.health).status;
        if (st2 == FeedStatus.healthy) {
          _stopOfflineRetry();
          return;
        }
        final now = DateTime.now();
        final last = _lastOfflineRetryAttemptTs;
        if (last != null && now.difference(last) < const Duration(seconds: 5)) {
          return;
        }
        _lastOfflineRetryAttemptTs = now;
        await poller.refreshOnce();
      });
    } else {
      _stopOfflineRetry();
    }
  }

  void _onProfileChanged(StrategyProfile profile) async {
    if (lockdown.enabled) return;
    setState(() {
      selectedProfile = profile;
    });
    await engine.saveSelectedProfile(profile.name);
    await _startPolling(reason: 'profileChanged');
  }

  void _onArmChanged(String symbolUpper, bool armed) async {
    if (lockdown.enabled) return;
    final symbol = symbolUpper.toUpperCase();
    if (symbol.isEmpty) return;
    final next = Set<String>.from(armedSymbols);
    if (armed) {
      next.add(symbol);
    } else {
      next.remove(symbol);
    }
    setState(() {
      armedSymbols = next;
    });
    await _savePersistedArmedSymbols(next);
  }

  void _onThresholdCycleReset(String symbolUpper) {
    final symbol = symbolUpper.toUpperCase();
    if (symbol.isEmpty) return;
    setState(() {
      thresholdStepStatesBySymbol =
          Map<String, Map<String, ThresholdStepState>>.from(
        thresholdStepStatesBySymbol,
      )..remove(symbol);
    });
  }

  void _clearUserFacingCachesAfterAssetRemoval() {
    alerts = [];
    lastAlertsResult = null;
    alertsSummary = '';
    alertsLines = const [];
    pnlSummary = '';
    rebalanceSummary = '';
    reportPretty = '';
    lastReportJson = null;
    currentReport = null;
    snapshotPretty = '';
    copyStatus = '';
    statusText = '';
    nextActionText = '';
  }

  void _onConfirm() {
    if (lockdown.enabled) return;
    setState(() {
      confirmWindow = ConfirmWindow(
          expiresAt: DateTime.now().add(const Duration(seconds: 60)));
    });
  }

  void _onChecklistChanged(ReleaseChecklist newChecklist) async {
    setState(() {
      lockdown =
          LockdownState(enabled: lockdown.enabled, checklist: newChecklist);
    });
    await engine.saveLockdown(lockdown);
  }

  void _onLockdownChanged(bool enabled) async {
    if (!enabled && !lockdown.checklist.isComplete) {
      setState(() {
        lockdownMessage = 'Complete checklist to disable lockdown.';
      });
      return;
    }
    setState(() {
      lockdown = LockdownState(enabled: enabled, checklist: lockdown.checklist);
      lockdownMessage = '';
    });
    if (enabled) {
      setState(() {
        armedSymbols = <String>{};
        confirmWindow = ConfirmWindow(expiresAt: null);
      });
      await _savePersistedArmedSymbols(<String>{});
    }
    await engine.saveLockdown(lockdown);
  }

  Future<void> _copyReport() async {
    if (reportPretty.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: reportPretty));
    setState(() {
      copyStatus = 'Copied.';
    });
  }

  Future<void> _exportReport() async {
    if (currentReport == null) return;
    await reportExporter.export(currentReport!);
    setState(() {
      copyStatus = 'Exported.';
    });
  }

  String _buildStatusText(
    MarketRegimeResult regime,
    RegimePolicyKnobs knobs,
    PortfolioSummary? portfolio,
  ) {
    final base = '${regime.regime} regime (${regime.confidence}%)';
    final knobPart =
        'cadence ${knobs.buyCadence}, bias ${knobs.allocationBias}, profits ${knobs.profitTightness}';
    String portfolioHint = '';
    if (portfolio != null && portfolio.rows.isNotEmpty) {
      final firstUnder = portfolio.rows.firstWhere(
        (r) => r.label == 'Under',
        orElse: () => portfolio.rows.first,
      );
      final firstOver = portfolio.rows.firstWhere(
        (r) => r.label == 'Over',
        orElse: () => portfolio.rows.first,
      );
      if (firstUnder.label == 'Under') {
        portfolioHint = ' Underweight ${firstUnder.symbol}.';
      } else if (firstOver.label == 'Over') {
        portfolioHint = ' Overweight ${firstOver.symbol}.';
      } else {
        portfolioHint = ' Portfolio near target.';
      }
    }
    final reason =
        regime.reasons.isNotEmpty ? 'Reason: ${regime.reasons.first}' : '';
    return reason.isEmpty
        ? '$base — $knobPart.$portfolioHint'
        : '$base — $knobPart. $reason$portfolioHint';
  }

  String _buildNextActionText({
    required Set<String> buySymbols,
    required Set<String> sellSymbols,
    required DeploymentPlan deploymentPlan,
    required SellPlan sellPlan,
    required double? budgetRemaining,
    required RegimePolicyKnobs knobs,
    required PortfolioSummary portfolioSummary,
  }) {
    final budgetLine = budgetRemaining == null
        ? ''
        : ' Budget left \$${budgetRemaining.toStringAsFixed(2)}.';

    String? portfolioHint;
    final under = portfolioSummary.rows.firstWhere(
      (r) => r.label == 'Under' && r.deltaPct <= -2.0,
      orElse: () => portfolioSummary.rows.isNotEmpty
          ? portfolioSummary.rows.first
          : const PortfolioAssetRow(
              symbol: '',
              units: 0,
              priceUsd: 0,
              valueUsd: 0,
              allocPct: 0,
              targetPct: 0,
              deltaPct: 0,
              label: 'On target'),
    );
    final over = portfolioSummary.rows.firstWhere(
      (r) => r.label == 'Over' && r.deltaPct >= 2.0,
      orElse: () => portfolioSummary.rows.isNotEmpty
          ? portfolioSummary.rows.first
          : const PortfolioAssetRow(
              symbol: '',
              units: 0,
              priceUsd: 0,
              valueUsd: 0,
              allocPct: 0,
              targetPct: 0,
              deltaPct: 0,
              label: 'On target'),
    );

    if (sellPlan.totalUsd > 0) {
      final sellList = sellPlan.perAssetUsd.keys
          .map((s) => s.toUpperCase())
          .toList()
        ..sort();
      final sellTargets = sellList.isEmpty ? 'positions' : sellList.join('/');
      return 'Take profits (${knobs.profitTightness}) on $sellTargets (~\$${sellPlan.totalUsd.toStringAsFixed(2)}).';
    }

    if (buySymbols.isNotEmpty) {
      final symbols = buySymbols.toList()..sort();
      if (deploymentPlan.totalToDeploy <= 0) {
        return 'Watch levels hit for ${symbols.join('/')} but budget is exhausted — monitor.';
      }
      if (knobs.buyCadence == 'PAUSE') {
        return 'Signals in ${symbols.join('/')} but cadence is PAUSE — hold fire.';
      }
      final cadenceText = knobs.buyCadence == 'AGGRESSIVE'
          ? 'step in aggressively'
          : 'ladder in';
      return 'Deploy \$${deploymentPlan.totalToDeploy.toStringAsFixed(2)} to ${symbols.join('/')} ($cadenceText).$budgetLine';
    }

    if (sellSymbols.isNotEmpty) {
      final symbols = sellSymbols.toList()..sort();
      return 'Profit levels pinged for ${symbols.join('/')} but no position sized sells yet.';
    }

    if (portfolioSummary.rows.isNotEmpty) {
      if (under.symbol.isNotEmpty &&
          knobs.buyCadence != 'PAUSE' &&
          under.deltaPct <= -2.0) {
        portfolioHint = 'Underweight in ${under.symbol} — monitor allocation.';
      } else if (over.symbol.isNotEmpty &&
          (knobs.profitTightness == 'TIGHT' ||
              knobs.profitTightness == 'NORMAL') &&
          over.deltaPct >= 2.0) {
        portfolioHint =
            'Overweight in ${over.symbol} — monitor for rebalancing.';
      }
    }

    if (portfolioHint != null) return portfolioHint;

    return 'Monitor — no levels hit.';
  }

  String _modeLabelFromProfile(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('conservative')) return 'Chill';
    if (lower.contains('aggressive')) return 'YOLO';
    return 'Balanced';
  }

  @override
  Widget build(BuildContext context) {
    final showDebug = widget.showDebug && kDebugMode;
    final budgetSummary = budget == null
        ? 'Budget: -'
        : 'Budget: limit=\$${budget!.monthlyLimit.toStringAsFixed(2)} '
            'spent=\$${budget!.spentThisMonth.toStringAsFixed(2)} '
            'remaining=\$${budget!.remaining.toStringAsFixed(2)}';

    if (showDebug) {
      return DebugScreen(
        profiles: allProfiles,
        selectedProfile: selectedProfile,
        onProfileChanged: _onProfileChanged,
        lockdownEnabled: lockdown.enabled,
        lockdownMessage: lockdownMessage,
        checklist: lockdown.checklist,
        onChecklistChanged: _onChecklistChanged,
        onLockdownChanged: _onLockdownChanged,
        confirmWindow: confirmWindow,
        onConfirm: _onConfirm,
        heatForceMessage: heatForceMessage,
        alerts: alerts,
        pnlSummary: pnlSummary,
        rebalanceSummary: rebalanceSummary,
        budgetSummary: budgetSummary,
        reportPretty: reportPretty,
        copyStatus: copyStatus,
        onCopyReport: _copyReport,
        onExportReport: _exportReport,
        feedName: _feed.name,
        snapshotPretty: snapshotPretty,
        hasLastReport: lastReportJson != null,
      );
    }

    final feedHealth = health ?? _feed.health;
    final snap = snapshot;
    final readyEval = evaluateReady(
      feedHealth: feedHealth,
      snapshot: snap,
      livePricesUsd: livePricesUsd,
      pollingInterval: selectedProfile.pollingInterval,
      now: DateTime.now(),
    );
    final isReady = readyEval.isReady;
    final status = feedHealth.status;
    final ageSeconds = (snap == null)
        ? null
        : DateTime.now().difference(snap.timestamp).inSeconds;
    String readyLabel;
    String readyTooltip;
    if (status == FeedStatus.down) {
      readyLabel = 'OFFLINE';
      readyTooltip = 'Feed unreachable or no connectivity.';
    } else if (status == FeedStatus.degraded) {
      readyLabel = 'DEGRADED';
      readyTooltip = 'Feed is intermittently failing.';
    } else if (!readyEval.hasSnapshot || !readyEval.hasPrices) {
      readyLabel = 'LOADING';
      readyTooltip = 'Waiting for first live prices.';
    } else if (!readyEval.isFresh) {
      readyLabel = 'STALE';
      readyTooltip = ageSeconds == null
          ? 'Last update age unknown.'
          : 'Last update ${ageSeconds}s ago.';
    } else {
      readyLabel = 'READY';
      readyTooltip = 'Data is current and healthy.';
    }

    return OperatorScreen(
      selectedProfile: selectedProfile,
      lockdownEnabled: lockdown.enabled,
      lockdownMessage: lockdownMessage,
      checklist: lockdown.checklist,
      onChecklistChanged: _onChecklistChanged,
      onLockdownChanged: _onLockdownChanged,
      armedSymbols: armedSymbols,
      onArmChanged: _onArmChanged,
      confirmWindow: confirmWindow,
      onConfirm: _onConfirm,
      heatForceMessage: heatForceMessage,
      alerts: alerts,
      pnlSummary: pnlSummary,
      rebalanceSummary: rebalanceSummary,
      budgetSummary: budgetSummary,
      reportPretty: reportPretty,
      copyStatus: copyStatus,
      onCopyReport: _copyReport,
      onExportReport: _exportReport,
      livePricesUsd: livePricesUsd,
      thresholdStepStatesBySymbol: thresholdStepStatesBySymbol,
      feedHealth: feedHealth,
      feedName: _feed.name,
      statusText: statusText,
      nextActionText: nextActionText,
      availableFeedIds: availableFeedIds,
      selectedFeedId: selectedFeedId,
      onFeedChanged: _setSelectedFeed,
      readyLabel: readyLabel,
      readyTooltip: readyTooltip,
      isReady: isReady,
      onRefresh: () async {
        await _poller?.refreshOnce();
      },
      onThresholdCycleReset: _onThresholdCycleReset,
      onAssetsChanged: () async {
        // IMPORTANT: do NOT restart polling on every toggle (causes CoinGecko 429).
        // Update symbols in-place and trigger a single on-demand tick.
        final previousActive = _activeSymbols;
        final enabled = await _normalizeEnabledSymbolsOnStartup();
        final removed = computeRemovedAssetSymbols(
          previousSymbols: previousActive,
          nextSymbols: enabled,
        );
        for (final symbol in removed) {
          await engine.purgeAsset(symbol);
        }
        if (removed.isNotEmpty) {
          final normalizedRemoved = removed.map((s) => s.toUpperCase()).toSet();
          final nextArmed = Set<String>.from(armedSymbols)
            ..removeWhere((s) => normalizedRemoved.contains(s.toUpperCase()));
          final armedChanged = !setEquals(armedSymbols, nextArmed);
          setState(() {
            livePricesUsd = Map<String, double>.from(livePricesUsd)
              ..removeWhere(
                (key, _) => normalizedRemoved.contains(key.toUpperCase()),
              );
            thresholdStepStatesBySymbol =
                Map<String, Map<String, ThresholdStepState>>.from(
              thresholdStepStatesBySymbol,
            )..removeWhere(
                    (key, _) => normalizedRemoved.contains(key.toUpperCase()),
                  );
            armedSymbols = nextArmed;
            _clearUserFacingCachesAfterAssetRemoval();
          });
          if (armedChanged) {
            await _savePersistedArmedSymbols(nextArmed);
          }
        }
        final previousActiveSet =
            previousActive.map((s) => s.toUpperCase()).toSet();
        final added = enabled.difference(previousActiveSet);
        for (final symbol in added) {
          await engine.resetExecutionStateForSymbol(symbol);
        }
        final symbols = enabled.toList()..sort();
        _activeSymbols = symbols;
        final poller = _poller;
        if (poller == null) {
          await _startPolling(reason: 'assetsChanged');
          return;
        }
        await poller.updateSymbols(
          symbols,
          reason: 'ASSETSCHANGED',
        );
      },
    );
  }
}

class ReadyEvaluation {
  final bool hasSnapshot;
  final bool hasPrices;
  final bool isFresh;
  final bool isReady;

  const ReadyEvaluation({
    required this.hasSnapshot,
    required this.hasPrices,
    required this.isFresh,
    required this.isReady,
  });
}

ReadyEvaluation evaluateReady({
  required FeedHealth feedHealth,
  required StatusSnapshot? snapshot,
  required Map<String, double> livePricesUsd,
  required Duration pollingInterval,
  required DateTime now,
}) {
  final hasSnapshot = snapshot != null;
  final age = hasSnapshot ? now.difference(snapshot.timestamp) : Duration.zero;
  final ttl = pollingInterval + const Duration(seconds: 5);
  final isFresh = hasSnapshot && age <= ttl;
  final hasPrices = livePricesUsd.isNotEmpty;
  final isReady = hasSnapshot &&
      feedHealth.status == FeedStatus.healthy &&
      hasPrices &&
      isFresh;
  return ReadyEvaluation(
    hasSnapshot: hasSnapshot,
    hasPrices: hasPrices,
    isFresh: isFresh,
    isReady: isReady,
  );
}
