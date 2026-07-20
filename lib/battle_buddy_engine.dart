import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'engine/allocation_engine.dart';
import 'engine/decision_engine.dart';
import 'engine/status_engine.dart';
import 'engine/alert_engine.dart';
import 'engine/ladder_engine.dart';
import 'engine/execution_engine.dart';
import 'engine/pill_state_evaluator.dart';
import 'models/decision_result.dart';
import 'models/status_snapshot.dart';
import 'models/allocation_target.dart';
import 'models/deployment_plan.dart';
import 'models/monthly_budget.dart';
import 'models/alert_event.dart';
import 'models/cooldown_store.dart';
import 'models/ladder_policy.dart';
import 'models/execution_intent.dart';
import 'models/execution_mode.dart';
import 'models/zone_state_store.dart';
import 'models/sell_plan.dart';
import 'models/sell_policy.dart';
import 'price/price_feed.dart';
import 'storage/storage_backend.dart';
import 'storage/cooldown_persistence.dart';
import 'storage/snapshot_persistence.dart';
import 'storage/profile_persistence.dart';
import 'storage/report_persistence.dart';
import 'storage/lockdown_persistence.dart';
import 'models/position.dart';
import 'models/pnl_report.dart';
import 'models/rebalance_report.dart';
import 'models/strategy_report.dart';
import 'models/heat_mode.dart';
import 'models/feed_health.dart';
import 'models/lockdown.dart';
import 'models/threshold_execution_event.dart';
import 'models/threshold_plan.dart';
import 'models/threshold_step_state.dart';
import 'alerts_engine.dart' as alerts_engine;
import 'alerts_store.dart' as alerts_store;
import 'engine/pnl_engine.dart';
import 'engine/heat_engine.dart';
import 'engine/sell_engine.dart';
import 'engine/rebalance_engine.dart';
import 'engine/report_engine.dart';
import 'engine/observed_threshold_step_state_reconcile.dart';
import 'storage/threshold_state_store.dart';

class ExecutionGateResult {
  final bool canExecute;
  final String statusText;
  final String nextActionText;
  final List<String> blockers;
  final double maxSpendUsd;

  const ExecutionGateResult({
    required this.canExecute,
    required this.statusText,
    required this.nextActionText,
    required this.blockers,
    required this.maxSpendUsd,
  });
}

enum StrategyMode { conservative, balanced, aggressive }

class DisciplineState {
  double currentCycle;
  double lifetime;

  DisciplineState({
    required this.currentCycle,
    required this.lifetime,
  });
}

class BattleBuddyEngine {
  static const String _kHoldingsKey = 'engine_holdings_v1';

  // Prices (USD)
  double btc = 0.0;
  double eth = 0.0;
  double sol = 0.0;
  Map<String, double> latestPrices = <String, double>{};
  Map<String, double> holdings = <String, double>{};
  DisciplineState discipline = DisciplineState(
    currentCycle: 1.0,
    lifetime: 1.0,
  );
  ThresholdExecutionEvent? _lastPersistedFeedbackEvent;
  Map<String, alerts_engine.AlertRule> _alertRules = {};
  alerts_engine.AlertsResult? _lastAlerts;

  DateTime? lastUpdated;

  // Mode + controls
  StrategyMode mode = StrategyMode.balanced;

  // “Confidence” here is an engine output (0–100).
  int _confidence = 50;
  String _bias = 'NEUTRAL';

  // Allocation weights per mode (must sum to ~1.0; we normalize).
  final Map<StrategyMode, Map<String, double>> _weights = {
    StrategyMode.conservative: {'BTC': 0.75, 'ETH': 0.20, 'SOL': 0.05},
    StrategyMode.balanced: {'BTC': 0.60, 'ETH': 0.30, 'SOL': 0.10},
    StrategyMode.aggressive: {'BTC': 0.45, 'ETH': 0.35, 'SOL': 0.20},
  };

  // Guardrails
  double cashHoldbackPct = 0.00; // 0.00-0.50 typical
  double maxPerAssetPct = 0.85;  // cap any single asset allocation
  bool enableDampener = false;   // optional dampener
  double dampenerStrength = 0.25; // 0-1

  final AllocationEngine _allocationEngine = AllocationEngine();
  final ZoneStateStore _zoneStateStore = ZoneStateStore();
  late final DecisionEngine _decisionEngine = DecisionEngine(zoneStore: _zoneStateStore);
  final CooldownStore _cooldownStore = CooldownStore();
  final StorageBackend _storage;
  late final CooldownPersistence _cooldownPersistence = CooldownPersistence(backend: _storage);
  late final SnapshotPersistence _snapshotPersistence = SnapshotPersistence(backend: _storage);
  final LadderEngine _ladderEngine = LadderEngine();
  final ExecutionEngine _executionEngine = ExecutionEngine();
  late final ProfilePersistence _profilePersistence = ProfilePersistence(backend: _storage);
  late final ReportPersistence _reportPersistence = ReportPersistence(backend: _storage);
  late final LockdownPersistence _lockdownPersistence = LockdownPersistence(backend: _storage);
  final PnlEngine _pnlEngine = PnlEngine();
  final HeatEngine _heatEngine = HeatEngine();
  final SellEngine _sellEngine = SellEngine();
  final RebalanceEngine _rebalanceEngine = RebalanceEngine();
  final ReportEngine _reportEngine = ReportEngine();
  MonthlyBudget? _budget;
  Map<String, double>? _lastUiWeights;

  // Action memory (history)
  final List<Map<String, dynamic>> _history = [];
  Map<String, String>? _lastActions; // snapshot

  BattleBuddyEngine({StorageBackend? storageBackend})
      : _storage = storageBackend ?? createStorageBackend();

  // -----------------------------
  // PUBLIC API used by main.dart
  // -----------------------------

  Future<bool> fetchLivePrices() async {
    try {
      // CoinGecko simple price endpoint (no key required in most cases).
      final uri = Uri.parse(
        'https://api.coingecko.com/api/v3/simple/price'
        '?ids=bitcoin,ethereum,solana&vs_currencies=usd',
      );

      final resp = await http.get(uri, headers: {
        'accept': 'application/json',
      });

      if (resp.statusCode != 200) {
        // keep existing prices; mark not live
        _recomputeSignal(live: false);
        return false;
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      btc = _asDouble(data['bitcoin']?['usd']);
      eth = _asDouble(data['ethereum']?['usd']);
      sol = _asDouble(data['solana']?['usd']);
      latestPrices = <String, double>{
        'BTC': btc,
        'ETH': eth,
        'SOL': sol,
      };

      lastUpdated = DateTime.now();
      _recomputeSignal(live: true);
      return true;
    } catch (_) {
      _recomputeSignal(live: false);
      return false;
    }
  }

  String lastUpdatedText() {
    if (lastUpdated == null) return 'Last update: —';
    return 'Last update: ${lastUpdated!.toLocal()}';
  }

  String marketBiasLabel() => 'Market Bias: $_bias (${confidence()}%)';

  String marketBias() => _bias;

  int confidence() => _confidence;

  Map<String, double> weightsForMode(StrategyMode m) {
    final w = Map<String, double>.from(_weights[m] ?? {'BTC': 0.6, 'ETH': 0.3, 'SOL': 0.1});
    return _normalizedWeights(w);
  }

  void setWeight(StrategyMode m, String asset, double value) {
    final w = _weights[m] ?? {'BTC': 0.6, 'ETH': 0.3, 'SOL': 0.1};
    w[asset] = value.clamp(0.0, 1.0);
    _weights[m] = _normalizedWeights(w);
  }

  Map<String, String> perAssetActions({ExecutionGateResult? gate}) {
    final b = _bias;
    final c = _confidence;

    if (gate != null && !gate.canExecute) {
      return {
        'BTC': 'HOLD',
        'ETH': 'HOLD',
        'SOL': 'HOLD',
      };
    }

    String decide(String asset) {
      // Simple deterministic rules:
      // - If bullish and confidence high -> BUY
      // - If bearish and confidence high -> HOLD/WAIT (or SELL later if you add that)
      // - If neutral -> HOLD
      if (b == 'BULLISH' && c >= _buyThreshold(asset)) return 'BUY';
      if (b == 'BEARISH' && c >= 70) return 'HOLD';
      return 'HOLD';
    }

    return {
      'BTC': decide('BTC'),
      'ETH': decide('ETH'),
      'SOL': decide('SOL'),
    };
  }

  /// Returns a human-readable change note per asset compared to last snapshot.
  Map<String, String> actionChanges(Map<String, String> currentActions) {
    final prev = _lastActions;
    final out = <String, String>{};

    for (final a in ['BTC', 'ETH', 'SOL']) {
      final now = currentActions[a] ?? 'HOLD';
      if (prev == null) {
        out[a] = 'No prior snapshot.';
      } else {
        final was = prev[a] ?? 'HOLD';
        out[a] = (was == now) ? 'Unchanged ($now).' : 'Changed: $was → $now.';
      }
    }
    return out;
  }

  void commitActionSnapshot(Map<String, String> currentActions) {
    _lastActions = Map<String, String>.from(currentActions);

    _history.add({
      'ts': DateTime.now().toIso8601String(),
      'mode': _modeLabel(mode),
      'bias': _bias,
      'confidence': _confidence,
      'prices': {'BTC': btc, 'ETH': eth, 'SOL': sol},
      'actions': currentActions,
    });

    // keep history from growing forever
    if (_history.length > 100) {
      _history.removeRange(0, _history.length - 100);
    }
  }

  List<Map<String, dynamic>> history() => List<Map<String, dynamic>>.from(_history);

  double effectiveCashHoldbackUsd(double budget) {
    final pct = cashHoldbackPct.clamp(0.0, 0.9);
    return (budget * pct).clamp(0.0, budget);
  }

  DecisionResult evaluatePosition({
    required String symbol,
    required double price,
    required List<double> buyZones,
    required List<double> sellZones,
  }) {
    return _decisionEngine.evaluate(
      symbol: symbol,
      currentPrice: price,
      buyZones: buyZones,
      sellZones: sellZones,
    );
  }

  DeploymentPlan planDeployment({
    required List<AllocationTarget> targets,
    required MonthlyBudget budget,
    required double deployNowAmount,
  }) {
    return _allocationEngine.buildDeploymentPlan(
      targets: targets,
      budget: budget,
      deployNowAmount: deployNowAmount,
    );
  }

  StatusSnapshot buildStatusSnapshot({
    required Map<String, double> prices,
    required Map<String, List<double>> buyZonesBySymbol,
    required Map<String, List<double>> sellZonesBySymbol,
    DeploymentPlan? deploymentPlan,
  }) {
    latestPrices = <String, double>{
      for (final entry in prices.entries) entry.key.toUpperCase(): entry.value,
    };
    if (latestPrices.containsKey('BTC')) btc = latestPrices['BTC']!;
    if (latestPrices.containsKey('ETH')) eth = latestPrices['ETH']!;
    if (latestPrices.containsKey('SOL')) sol = latestPrices['SOL']!;

    return StatusEngine(decisionEngine: _decisionEngine).buildSnapshot(
      timestamp: DateTime.now(),
      prices: prices,
      buyZonesBySymbol: buyZonesBySymbol,
      sellZonesBySymbol: sellZonesBySymbol,
      deploymentPlan: deploymentPlan,
    );
  }

  Future<StatusSnapshot> buildSnapshotFromFeed({
    required PriceFeed feed,
    required List<String> symbols,
    required Map<String, List<double>> buyZonesBySymbol,
    required Map<String, List<double>> sellZonesBySymbol,
    DeploymentPlan? deploymentPlan,
  }) async {
    final prices = await feed.fetchPrices(symbols: symbols);

    return buildStatusSnapshot(
      prices: prices,
      buyZonesBySymbol: buyZonesBySymbol,
      sellZonesBySymbol: sellZonesBySymbol,
      deploymentPlan: deploymentPlan,
    );
  }

  List<AlertEvent> generateAlertsFromSnapshot({
    required StatusSnapshot snapshot,
    Duration cooldown = const Duration(minutes: 30),
  }) {
    final engine = AlertEngine(cooldownStore: _cooldownStore, cooldown: cooldown);
    return engine.evaluateAlerts(snapshot);
  }

  DeploymentPlan buildDeploymentFromAlerts({
    required List<AlertEvent> alerts,
    required List<AllocationTarget> targets,
    required MonthlyBudget budget,
    required LadderPolicy policy,
  }) {
    return _ladderEngine.buildPlanFromAlerts(
      alerts: alerts,
      targets: targets,
      budget: budget,
      policy: policy,
    );
  }

  ExecutionIntent buildExecutionIntent({
    required DeploymentPlan plan,
    required ExecutionMode mode,
  }) {
    return _executionEngine.buildIntent(plan: plan, mode: mode);
  }

  MonthlyBudget applySpend({
    required MonthlyBudget budget,
    required DeploymentPlan plan,
  }) {
    return _ladderEngine.applySpend(budget: budget, plan: plan);
  }

  MonthlyBudget applySpendToBudget({
    required MonthlyBudget budget,
    required DeploymentPlan plan,
  }) {
    return _ladderEngine.applySpend(budget: budget, plan: plan);
  }

  Future<void> saveSelectedProfile(String name) async {
    await _profilePersistence.save(name);
  }

  Future<String?> loadSelectedProfile() async {
    return _profilePersistence.load();
  }

  Future<void> saveLastReport(StrategyReport report) async {
    await _reportPersistence.save(report);
  }

  Future<Map<String, dynamic>?> loadLastReportJson() async {
    return _reportPersistence.loadJson();
  }

  Future<LockdownState> loadLockdown() => _lockdownPersistence.load();

  Future<void> saveLockdown(LockdownState state) => _lockdownPersistence.save(state);

  SellPlan buildSellPlanFromAlerts({
    required List<AlertEvent> alerts,
    required Map<String, Position> positions,
    required Map<String, double> prices,
    required SellPolicy policy,
  }) {
    return _sellEngine.build(
      alerts: alerts,
      positions: positions,
      prices: prices,
      policy: policy,
    );
  }

  PnlReport buildPnl({
    required Map<String, Position> positions,
    required Map<String, double> prices,
  }) {
    return _pnlEngine.build(positions: positions, prices: prices);
  }

  RebalanceReport buildRebalance({
    required Map<String, Position> positions,
    required Map<String, double> prices,
    required List<AllocationTarget> targets,
  }) {
    return _rebalanceEngine.build(
      positions: positions,
      prices: prices,
      targets: targets,
    );
  }

  StrategyReport buildReport({
    required String profileName,
    required String modeLabel,
    required String feedLabel,
    required FeedHealth feedHealth,
    required HeatModeState heat,
    required Map<String, dynamic> snapshotJson,
    required List<Map<String, dynamic>> alertsJson,
    required DeploymentPlan deploymentPlan,
    required ExecutionIntent intent,
    required Map<String, dynamic> budgetJson,
    required Map<String, dynamic> positionsJson,
    required Map<String, dynamic> pnlJson,
    required Map<String, dynamic> rebalanceJson,
    required Map<String, dynamic>? lastLedgerRecord,
    required Map<String, dynamic> marketRegime,
    required Map<String, String> guidance,
    required Map<String, dynamic> holdings,
    required Map<String, dynamic> portfolio,
    required String alertsSummary,
    required List<Map<String, dynamic>> alertsEvents,
    required Map<String, dynamic> executionGate,
    required Map<String, String> perAssetActions,
    required double monthlyBudget,
    required double monthlySpent,
    required double monthlyRemaining,
    required int buyAlerts,
    required int sellAlerts,
    List<Map<String, dynamic>> thresholdTriggeredSteps =
        const <Map<String, dynamic>>[],
  }) {
    return _reportEngine.build(
      profileName: profileName,
      mode: modeLabel,
      feed: feedLabel,
      feedHealth: feedHealth,
      heat: heat,
      snapshotJson: snapshotJson,
      alertsJson: alertsJson,
      deploymentPlan: deploymentPlan,
      intent: intent,
      budgetJson: budgetJson,
      positionsJson: positionsJson,
      pnlJson: pnlJson,

      rebalanceJson: rebalanceJson,
      lastLedgerRecord: lastLedgerRecord,
      marketRegime: marketRegime,
      guidance: guidance,
      holdings: holdings,
      portfolio: portfolio,
      alertsSummary: alertsSummary,
      alertsEvents: alertsEvents,
      executionGate: executionGate,
      perAssetActions: perAssetActions,
      monthlyBudget: monthlyBudget,
      monthlySpent: monthlySpent,
      monthlyRemaining: monthlyRemaining,
      buyAlerts: buyAlerts,
      sellAlerts: sellAlerts,
      thresholdTriggeredSteps: thresholdTriggeredSteps,
    );
  }

  HeatModeState evaluateHeat({
    required Map<String, double> prices,
    required HeatModeConfig config,
  }) {
    return _heatEngine.evaluate(prices: prices, config: config);
  }

  List<AlertEvent> generateAlertsWithHeatGuard({
    required StatusSnapshot snapshot,
    required HeatModeConfig heatConfig,
    Duration cooldown = const Duration(minutes: 30),
  }) {
    final heat = evaluateHeat(prices: snapshot.prices, config: heatConfig);
    if (heat.isHot) {
      return [];
    }
    return generateAlertsFromSnapshot(snapshot: snapshot, cooldown: cooldown);
  }

  void setMonthlyBudget(MonthlyBudget budget, {Map<String, double>? uiWeights}) {
    _budget = budget;
    _lastUiWeights = uiWeights;
  }

  MonthlyBudget getCurrentBudget(DateTime now) {
    if (_budget == null) {
      throw StateError('Monthly budget not set');
    }
    _budget = _budget!.rolloverIfNeeded(now);
    return _budget!;
  }

  Future<void> saveState({StatusSnapshot? snapshot}) async {
    await _cooldownPersistence.save(_cooldownStore);
    if (snapshot != null) {
      await _snapshotPersistence.save(snapshot);
    }
  }

  Future<void> loadState() async {
    await _refreshLatestPersistedFeedback();
    await _refreshDisciplineFromPersistedExecutionEvents();
  }

  Future<void> clearTransientMarketCaches() async {
    _cooldownStore.clear();
    await Future.wait<void>([
      _reportPersistence.clear(),
      _snapshotPersistence.clear(),
      _cooldownPersistence.clear(),
    ]);
  }

  Future<void> _refreshDisciplineFromPersistedExecutionEvents() async {
    const execPrefix = 'threshold_exec_';
    final prefs = await SharedPreferences.getInstance();

    var currentExecuted = 0;
    var currentMissed = 0;
    var lifetimeExecuted = 0;
    var lifetimeMissed = 0;

    for (final key in prefs.getKeys()) {
      if (!key.startsWith(execPrefix)) continue;
      final symbol = key.substring(execPrefix.length);
      if (symbol.isEmpty) continue;

      final events = await ThresholdStateStore.loadExecutionEvents(
        symbol: symbol,
      );
      final cycleStart = await ThresholdStateStore.loadCycleStart(
        symbol: symbol,
      );
      for (final event in events) {
        switch (event.reason) {
          case 'manual_execute':
            lifetimeExecuted++;
            if (cycleStart == null || !event.createdAt.isBefore(cycleStart)) {
              currentExecuted++;
            }
            break;
          case 'missed':
            lifetimeMissed++;
            if (cycleStart == null || !event.createdAt.isBefore(cycleStart)) {
              currentMissed++;
            }
            break;
        }
      }
    }

    final currentTotal = currentExecuted + currentMissed;
    final lifetimeTotal = lifetimeExecuted + lifetimeMissed;
    final currentScore =
        currentTotal == 0 ? 1.0 : currentExecuted / currentTotal;
    final lifetimeScore =
        lifetimeTotal == 0 ? 1.0 : lifetimeExecuted / lifetimeTotal;
    discipline.currentCycle = currentScore.clamp(0.0, 1.0).toDouble();
    discipline.lifetime = lifetimeScore.clamp(0.0, 1.0).toDouble();
  }

  Future<void> startNewThresholdCycle({
    required String symbol,
    required List<ThresholdStep> steps,
    required DateTime startedAt,
  }) async {
    final normalized = _normalizeSymbol(symbol);
    await ThresholdStateStore.saveCycleStart(
      symbol: normalized,
      cycleStart: startedAt,
    );

    final states = <String, ThresholdStepState>{};
    for (int i = 0; i < steps.length; i++) {
      final stepId = '$normalized:$i';
      states[stepId] = ThresholdStepState(
        stepId: stepId,
        status: ThresholdStepStatus.pending,
        updatedAt: startedAt,
        wasTriggered: false,
        wasCompleted: false,
      );
    }

    await ThresholdStateStore.saveStepStates(
      symbol: normalized,
      states: states,
    );
    await _refreshDisciplineFromPersistedExecutionEvents();
  }

  PillEvaluationResult evaluatePillState({
    required double currentPriceUsd,
    required List<ThresholdStep> thresholdPlanSteps,
    required Map<String, ThresholdStepState> persistedStepStates,
    required String stepIdPrefix,
  }) {
    return PillStateEvaluator.evaluate(
      currentPriceUsd: currentPriceUsd,
      thresholdPlanSteps: thresholdPlanSteps,
      persistedStepStates: persistedStepStates,
      stepIdPrefix: stepIdPrefix,
    );
  }

  Future<Map<String, Map<String, ThresholdStepState>>> observeThresholdCrossings({
    required Map<String, double> prices,
  }) async {
    final delta = <String, Map<String, ThresholdStepState>>{};

    for (final entry in prices.entries) {
      final symbol = _normalizeSymbol(entry.key);
      final livePrice = entry.value;
      if (symbol.isEmpty || !livePrice.isFinite || livePrice <= 0) {
        continue;
      }

      final strictPlan = await loadPersistedThresholdPlanStrict(symbol);
      ThresholdPlan? plan;
      if (strictPlan.status == PersistedThresholdPlanLoadStatus.valid) {
        plan = strictPlan.plan;
      } else {
        final initializedPlan =
            ThresholdPlan.defaultFor(symbol).reseedToLive(livePrice);
        await saveThresholdPlan(
          initializedPlan,
          source: 'crossing_initialization',
        );
        final verifiedPlan = await loadPersistedThresholdPlanStrict(symbol);
        if (verifiedPlan.status != PersistedThresholdPlanLoadStatus.valid) {
          continue;
        }
        plan = verifiedPlan.plan;
      }

      if (plan == null) continue;
      final originallyLoadedStates =
          await ThresholdStateStore.loadStepStates(symbol: symbol);
      if (plan.steps.isEmpty) {
        continue;
      }

      var changed = false;
      final now = DateTime.now();
      final updatedStates =
          Map<String, ThresholdStepState>.from(originallyLoadedStates);

      for (int i = 0; i < plan.steps.length; i++) {
        final step = plan.steps[i];
        final stepId = '$symbol:$i';
        final existing = updatedStates[stepId] ??
            ThresholdStepState(
              stepId: stepId,
              status: ThresholdStepStatus.pending,
              updatedAt: now,
            );
        if (existing.status == ThresholdStepStatus.executed ||
            existing.status == ThresholdStepStatus.dismissed ||
            existing.wasTriggered) {
          continue;
        }

        final action = step.action.toUpperCase();
        final trigger = step.triggerPriceUsd.toDouble();
        final crossed = action == 'BUY'
            ? livePrice <= trigger
            : action == 'SELL'
                ? livePrice >= trigger
                : false;
        if (!crossed) continue;

        updatedStates[stepId] = ThresholdStepState(
          stepId: existing.stepId,
          status: existing.status,
          updatedAt: now,
          wasTriggered: true,
          wasCompleted: existing.wasCompleted,
        );
        changed = true;
      }

      if (!changed) continue;

      final latestStates = await ThresholdStateStore.loadStepStates(
        symbol: symbol,
      );
      final reconciledStates = reconcileObservedThresholdStepStates(
        originallyLoaded: originallyLoadedStates,
        observed: updatedStates,
        latestPersisted: latestStates,
      );

      await ThresholdStateStore.saveStepStates(
        symbol: symbol,
        states: reconciledStates,
      );
      delta[symbol] = Map<String, ThresholdStepState>.from(reconciledStates);
    }

    return delta;
  }

  Future<void> saveHoldings() async {
    final prefs = await SharedPreferences.getInstance();

    final Map<String, dynamic> jsonMap = {};
    holdings.forEach((key, value) {
      jsonMap[key] = value;
    });

    final encoded = jsonEncode(jsonMap);
    await prefs.setString(_kHoldingsKey, encoded);
  }

  Future<void> loadHoldings() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(_kHoldingsKey);
    if (raw == null || raw.isEmpty) {
      holdings = <String, double>{};
      return;
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    final Map<String, double> loaded = {};
    decoded.forEach((key, value) {
      final amount = value is num ? value.toDouble() : double.nan;
      if (!amount.isFinite || amount <= 0) return;
      final symbol = _normalizeSymbol(key);
      if (symbol.isEmpty) return;
      loaded[symbol] = amount;
    });

    holdings = loaded;
  }

  Future<void> loadAlertRules() async {
    _alertRules = await alerts_store.loadAlertRules();
  }

  String _normalizeSymbol(String symbol) => symbol.toUpperCase();

  double holdingOf(String symbol) {
    return holdings[_normalizeSymbol(symbol)] ?? 0.0;
  }

  Future<void> setHoldings(Map<String, double> updated) async {
    final normalized = <String, double>{};
    for (final entry in updated.entries) {
      final sym = _normalizeSymbol(entry.key);
      final amount = entry.value;
      if (amount <= 0) continue;
      normalized[sym] = amount;
    }
    holdings = normalized;
    await saveHoldings();
  }

  Future<void> setHolding(String symbol, double amount) async {
    final sym = _normalizeSymbol(symbol);
    final next = Map<String, double>.from(holdings);
    if (amount > 0) {
      next[sym] = amount;
    } else {
      next.remove(sym);
    }
    holdings = next;
    await saveHoldings();
  }

  Future<bool> confirmExecution({
    required String symbolUpper,
    required ThresholdPlan plan,
    required int tierIndex,
    required String activeStepId,
    double? observedPriceUsd,
  }) async {
    final symbol = _normalizeSymbol(symbolUpper);
    if (tierIndex < 0 || tierIndex >= plan.steps.length) return false;

    final step = plan.steps[tierIndex];
    final stepId = '$symbol:$tierIndex';
    if (activeStepId != stepId) return false;

    final currentStates =
        await ThresholdStateStore.loadStepStates(symbol: symbol);
    final prev = currentStates[stepId]?.status;
    if (prev == ThresholdStepStatus.executed ||
        prev == ThresholdStepStatus.dismissed) {
      return false;
    }

    await ThresholdStateStore.setStepState(
      symbol: symbol,
      stepId: stepId,
      status: ThresholdStepStatus.executed,
    );

    final percentOfPositionSnapshot = step.percentOfPosition;
    final isSell = step.action.toUpperCase().contains('SELL');
    final affectedUnits = isSell
        ? ((holdings[symbol] ?? 0.0) * (percentOfPositionSnapshot / 100.0))
        : null;
    final observedForSnapshot =
        (observedPriceUsd != null && observedPriceUsd > 0)
            ? observedPriceUsd
            : null;

    final executionEvent = ThresholdExecutionEvent(
      symbolUpper: symbol,
      stepId: stepId,
      tierIndex: tierIndex,
      action: step.action.toUpperCase(),
      triggerPriceUsd: step.triggerPriceUsd.toDouble(),
      observedPriceUsd: observedForSnapshot,
      percentOfPositionSnapshot: percentOfPositionSnapshot,
      positionUnitsSnapshot: affectedUnits,
      notionalUsdSnapshot: affectedUnits != null && observedForSnapshot != null
          ? affectedUnits * observedForSnapshot
          : null,
      sizingSource: isSell ? 'position_percent' : 'notional_unavailable',
      reason: 'manual_execute',
      createdAt: DateTime.now(),
    );

    await ThresholdStateStore.appendExecutionEvent(
      symbol: symbol,
      event: executionEvent,
    );
    _lastPersistedFeedbackEvent = executionEvent;
    await _refreshDisciplineFromPersistedExecutionEvents();

    final observed = observedPriceUsd;
    if (observed != null && observed > 0) {
      latestPrices[symbol] = observed;
    }

    return true;
  }

  Future<bool> recordMissedExecution({
    required String symbolUpper,
    required ThresholdPlan plan,
    required int tierIndex,
    required String activeStepId,
    double? observedPriceUsd,
  }) async {
    final symbol = _normalizeSymbol(symbolUpper);
    if (tierIndex < 0 || tierIndex >= plan.steps.length) return false;

    final step = plan.steps[tierIndex];
    final stepId = '$symbol:$tierIndex';
    if (activeStepId != stepId) return false;

    final currentStates =
        await ThresholdStateStore.loadStepStates(symbol: symbol);
    final prev = currentStates[stepId]?.status;
    if (prev == ThresholdStepStatus.executed ||
        prev == ThresholdStepStatus.dismissed) {
      return false;
    }

    await ThresholdStateStore.setStepState(
      symbol: symbol,
      stepId: stepId,
      status: ThresholdStepStatus.dismissed,
    );

    final percentOfPositionSnapshot = step.percentOfPosition;
    final isSell = step.action.toString().toUpperCase().contains('SELL');
    final affectedUnits = isSell
        ? ((holdings[symbol] ?? 0.0) * (percentOfPositionSnapshot / 100.0))
        : null;
    final observedForSnapshot =
        (observedPriceUsd != null && observedPriceUsd > 0)
            ? observedPriceUsd
            : null;

    final missedEvent = ThresholdExecutionEvent(
      symbolUpper: symbol,
      stepId: stepId,
      tierIndex: tierIndex,
      action: step.action.toString().toUpperCase(),
      triggerPriceUsd: step.triggerPriceUsd.toDouble(),
      observedPriceUsd: observedForSnapshot,
      percentOfPositionSnapshot: percentOfPositionSnapshot,
      positionUnitsSnapshot: affectedUnits,
      notionalUsdSnapshot: affectedUnits != null && observedForSnapshot != null
          ? affectedUnits * observedForSnapshot
          : null,
      sizingSource: isSell ? 'position_percent' : 'notional_unavailable',
      reason: 'missed',
      createdAt: DateTime.now(),
    );

    await ThresholdStateStore.appendExecutionEvent(
      symbol: symbol,
      event: missedEvent,
    );
    _lastPersistedFeedbackEvent = missedEvent;
    await _refreshDisciplineFromPersistedExecutionEvents();

    final observed = observedPriceUsd;
    if (observed != null && observed > 0) {
      latestPrices[symbol] = observed;
    }

    return true;
  }

  DisciplineState getDiscipline() {
    return discipline;
  }

  double? getPriceFor(String symbol) {
    final normalized = _normalizeSymbol(symbol);
    final latest = latestPrices[normalized];
    if (latest != null && latest > 0) return latest;

    switch (normalized) {
      case 'BTC':
        return btc > 0 ? btc : null;
      case 'ETH':
        return eth > 0 ? eth : null;
      case 'SOL':
        return sol > 0 ? sol : null;
      default:
        return null;
    }
  }

  Future<void> resetExecutionStateForSymbol(String symbol) async {
    final sym = _normalizeSymbol(symbol);

    final lastPersistedFeedbackEvent = _lastPersistedFeedbackEvent;
    if (lastPersistedFeedbackEvent != null &&
        _normalizeSymbol(lastPersistedFeedbackEvent.symbolUpper) == sym) {
      _lastPersistedFeedbackEvent = null;
    }

    await ThresholdStateStore.removeStepStates(symbol: sym);
    await ThresholdStateStore.removeExecutionEvents(symbol: sym);
    await _refreshDisciplineFromPersistedExecutionEvents();
    await _refreshLatestPersistedFeedback();
  }

  Future<void> purgeAsset(String symbol) async {
    final sym = _normalizeSymbol(symbol);

    latestPrices.remove(sym);
    holdings.remove(sym);
    _alertRules.remove(sym);
    _lastActions?.remove(sym);
    _lastUiWeights?.remove(sym);
    _zoneStateStore.purgeSymbol(sym);

    switch (sym) {
      case 'BTC':
        btc = 0.0;
        break;
      case 'ETH':
        eth = 0.0;
        break;
      case 'SOL':
        sol = 0.0;
        break;
    }

    final lastPersistedFeedbackEvent = _lastPersistedFeedbackEvent;
    if (lastPersistedFeedbackEvent != null &&
        _normalizeSymbol(lastPersistedFeedbackEvent.symbolUpper) == sym) {
      _lastPersistedFeedbackEvent = null;
    }

    for (final entry in _history) {
      final prices = entry['prices'];
      if (prices is Map) {
        prices.remove(sym);
      }

      final actions = entry['actions'];
      if (actions is Map) {
        actions.remove(sym);
      }

      final holdingsMap = entry['holdings'];
      if (holdingsMap is Map) {
        holdingsMap.remove(sym);
      }
    }

    final lastAlerts = _lastAlerts;
    if (lastAlerts != null) {
      final filtered = lastAlerts.events
          .where((e) => e.asset.toUpperCase() != sym)
          .toList(growable: false);
      _lastAlerts = alerts_engine.AlertsResult(
        events: filtered,
        buyCount: filtered
            .where((e) => e.kind == alerts_engine.AlertKind.buy)
            .length,
        sellCount: filtered
            .where((e) => e.kind == alerts_engine.AlertKind.sell)
            .length,
        infoCount: filtered
            .where((e) => e.kind == alerts_engine.AlertKind.info)
            .length,
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('threshold_plan_$sym');
    await ThresholdStateStore.removeStepStates(symbol: sym);
    await ThresholdStateStore.removeExecutionEvents(symbol: sym);
    await ThresholdStateStore.removeCycleStart(symbol: sym);
    await _refreshDisciplineFromPersistedExecutionEvents();
    await _refreshLatestPersistedFeedback();

    await saveHoldings();
    await alerts_store.saveAlertRules(_alertRules);

  }

  String _computeFeedback() {
    final persisted = _lastPersistedFeedbackEvent;
    if (persisted != null) {
      return _computePersistedFeedback(persisted);
    }

    return '';
  }

  String getLastFeedback() {
    // Always return fresh computed feedback (no stale cache)
    return _computeFeedback();
  }

  Future<void> _refreshLatestPersistedFeedback() async {
    _lastPersistedFeedbackEvent =
        await ThresholdStateStore.loadLatestExecutionEvent();
  }

  String _computePersistedFeedback(ThresholdExecutionEvent event) {
    final symbol = event.symbolUpper.toUpperCase();
    final action = event.action.toUpperCase();
    final outcome =
        event.reason.toLowerCase() == 'missed' ? 'Missed' : 'Executed';
    final trigger = _formatFeedbackPrice(event.triggerPriceUsd);
    final observedPrice = event.observedPriceUsd;
    final observed = observedPrice == null
        ? 'observed price unavailable'
        : 'observed ${_formatFeedbackPrice(observedPrice)}';
    final executedAt = event.createdAt.toLocal().toString().split('.').first;
    String? consequenceLine;

    final units = event.positionUnitsSnapshot;
    if (action.contains('SELL') &&
        event.sizingSource == 'position_percent' &&
        units != null &&
        observedPrice != null &&
        event.triggerPriceUsd > 0) {
      if (event.reason == 'manual_execute') {
        final consequenceUsd =
            ((observedPrice - event.triggerPriceUsd).clamp(0.0, double.infinity) *
                    units)
                .toDouble();
        consequenceLine = 'Captured ~\$${consequenceUsd.toStringAsFixed(2)}';
      } else if (event.reason == 'missed') {
        final consequenceUsd =
            ((event.triggerPriceUsd - observedPrice).clamp(0.0, double.infinity) *
                    units)
                .toDouble();
        consequenceLine = 'Missed ~\$${consequenceUsd.toStringAsFixed(2)}';
      }
    }

    final base =
        '$symbol — $outcome $action — $executedAt\nTrigger $trigger • $observed';
    return consequenceLine == null ? base : '$base\n$consequenceLine';
  }

  String _formatFeedbackPrice(double price) {
    if (price <= 0) return 'n/a';
    if (price >= 1000) return '\$${price.toStringAsFixed(2)}';
    if (price >= 1) return '\$${price.toStringAsFixed(4)}';
    return '\$${price.toStringAsFixed(6)}';
  }

  double marketValueOf(String symbol, double price) {
    final units = holdingOf(symbol);
    return (units * price);
  }

  double computePortfolioValue(Map<String, double> prices) {
    double total = 0.0;

    holdings.forEach((symbol, amount) {
      final price = prices[symbol] ?? 0.0;
      total += amount * price;
    });

    return total;
  }

  Map<String, alerts_engine.AlertRule> get alertRules => _alertRules;

  alerts_engine.AlertsResult? get lastAlerts => _lastAlerts;

  Future<void> setAlertRule(alerts_engine.AlertRule rule) async {
    _alertRules = Map<String, alerts_engine.AlertRule>.from(_alertRules)
      ..[rule.asset.toUpperCase()] = rule;
    await alerts_store.saveAlertRules(_alertRules);
  }

  alerts_engine.AlertsResult evaluateAlerts({
    required Map<String, double> prices,
  }) {
    _lastAlerts = alerts_engine.evaluateAlerts(
      prices: prices,
      rules: _alertRules,
    );
    return _lastAlerts!;
  }

  ExecutionGateResult evaluateExecutionGate({
    required double budgetRemainingUsd,
    required int buyAlertsCount,
    required int sellAlertsCount,
    required String modeLabel,
  }) {
    return _evaluateExecutionGate(
      budgetRemainingUsd: budgetRemainingUsd,
      buyAlertsCount: buyAlertsCount,
      sellAlertsCount: sellAlertsCount,
      mode: modeLabel,
    );
  }

  ExecutionGateResult _evaluateExecutionGate({
    required double budgetRemainingUsd,
    required int buyAlertsCount,
    required int sellAlertsCount,
    required String mode,
  }) {
    // Budget
    if (budgetRemainingUsd <= 0) {
      return const ExecutionGateResult(
        canExecute: false,
        maxSpendUsd: 0,
        blockers: ['NO_BUDGET'],
        statusText: 'Budget used - no spend remaining.',
        nextActionText: 'Increase monthly budget or wait for reset.',
      );
    }

    // Alerts
    if ((buyAlertsCount + sellAlertsCount) == 0) {
      return const ExecutionGateResult(
        canExecute: false,
        maxSpendUsd: 0,
        blockers: ['NO_ALERTS'],
        statusText: 'No actionable alerts.',
        nextActionText: 'Hold and monitor; update thresholds if needed.',
      );
    }

    // F) Allowed
    double pct;
    double minChunk;
    double maxChunk;
    final lower = mode.toLowerCase();
    if (lower.contains('chill') || lower.contains('conservative')) {
      pct = 0.10;
      minChunk = 25;
      maxChunk = 150;
    } else if (lower.contains('yolo') || lower.contains('aggressive')) {
      pct = 0.35;
      minChunk = 100;
      maxChunk = 500;
    } else {
      pct = 0.20;
      minChunk = 50;
      maxChunk = 300;
    }
    double chunk = budgetRemainingUsd * pct;
    chunk = chunk.clamp(minChunk, maxChunk);
    chunk = chunk.clamp(0, budgetRemainingUsd);

    String nextAction;
    if (buyAlertsCount > 0) {
      nextAction = 'Watch alert active — review your plan.';
    } else if (sellAlertsCount > 0) {
      nextAction = 'Profit alert active — review your plan.';
    } else {
      nextAction = 'Hold.';
    }

    return ExecutionGateResult(
      canExecute: true,
      maxSpendUsd: chunk,
      blockers: const [],
      statusText: 'Market OK — execution allowed.',
      nextActionText: nextAction,
    );
  }

  /// Computes USD allocations from budget applying weights + guardrails.
  Map<String, double> allocationsUsd(double budget) {
    final b = budget.isNaN ? 0.0 : budget;
    if (b <= 0) return {'BTC': 0.0, 'ETH': 0.0, 'SOL': 0.0};

    final holdback = effectiveCashHoldbackUsd(b);
    final investable = (b - holdback).clamp(0.0, b);

    final w = weightsForMode(mode);

    // base allocations
    final raw = <String, double>{
      'BTC': investable * (w['BTC'] ?? 0.0),
      'ETH': investable * (w['ETH'] ?? 0.0),
      'SOL': investable * (w['SOL'] ?? 0.0),
    };

    // cap per-asset
    final capUsd = investable * maxPerAssetPct.clamp(0.1, 1.0);
    final capped = <String, double>{
      'BTC': raw['BTC']!.clamp(0.0, capUsd).toDouble(),
      'ETH': raw['ETH']!.clamp(0.0, capUsd).toDouble(),
      'SOL': raw['SOL']!.clamp(0.0, capUsd).toDouble(),
    };

    // optional dampener: reduces allocation when confidence is low
    if (enableDampener) {
      final strength = dampenerStrength.clamp(0.0, 1.0);
      final factor = (0.5 + (_confidence / 100.0) * 0.5); // 0.5..1.0
      final damp = (1.0 - strength) + strength * factor; // blend
      return {
        'BTC': (capped['BTC']! * damp),
        'ETH': (capped['ETH']! * damp),
        'SOL': (capped['SOL']! * damp),
      };
    }

    return capped;
  }

  String exportJson(double budget) {
    final actions = perAssetActions();
    final changes = actionChanges(actions);
    final alloc = allocationsUsd(budget);

    final payload = {
      'mode': _modeLabel(mode),
      'prices': {'BTC': btc, 'ETH': eth, 'SOL': sol},
      'bias': _bias,
      'confidence': _confidence,
      'actions': actions,
      'actionChanges': changes,
      'budget': budget,
      'cashHoldbackPct': cashHoldbackPct,
      'cashHoldbackUsd': effectiveCashHoldbackUsd(budget),
      'maxPerAssetPct': maxPerAssetPct,
      'enableDampener': enableDampener,
      'dampenerStrength': dampenerStrength,
      'allocationsUsd': alloc,
      'weights': weightsForMode(mode),
      'lastUpdated': lastUpdated?.toIso8601String(),
      'historyCount': _history.length,
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  // -----------------------------
  // INTERNALS
  // -----------------------------

  void _recomputeSignal({required bool live}) {
    // Simple heuristic:
    // If live prices exist, map bias/conf based on whether BTC is above/below rough anchors.
    // You can replace this later with your full engine.
    if (!live || btc <= 0 || eth <= 0 || sol <= 0) {
      _bias = 'NEUTRAL';
      _confidence = 50;
      return;
    }

    // crude anchors (not “predictions”, just a deterministic signal driver)
    final score = _scoreFromAnchors(
      btc: btc,
      eth: eth,
      sol: sol,
    );

    if (score >= 0.20) _bias = 'BULLISH';
    else if (score <= -0.20) _bias = 'BEARISH';
    else _bias = 'NEUTRAL';

    // confidence 50..95
    final conf = 50 + (score.abs() * 60).round();
    _confidence = conf.clamp(50, 95);
  }

  int _buyThreshold(String asset) {
    // Thresholds per mode (kept simple and stable)
    switch (mode) {
      case StrategyMode.conservative:
        return asset == 'BTC' ? 75 : (asset == 'ETH' ? 80 : 85);
      case StrategyMode.balanced:
        return asset == 'BTC' ? 70 : (asset == 'ETH' ? 70 : 80);
      case StrategyMode.aggressive:
        return asset == 'BTC' ? 60 : (asset == 'ETH' ? 60 : 65);
    }
  }

  Map<String, double> _normalizedWeights(Map<String, double> w) {
    final btcW = (w['BTC'] ?? 0.0).clamp(0.0, 1.0);
    final ethW = (w['ETH'] ?? 0.0).clamp(0.0, 1.0);
    final solW = (w['SOL'] ?? 0.0).clamp(0.0, 1.0);
    final sum = (btcW + ethW + solW);
    if (sum <= 0) return {'BTC': 0.6, 'ETH': 0.3, 'SOL': 0.1};
    return {'BTC': btcW / sum, 'ETH': ethW / sum, 'SOL': solW / sum};
  }

  double _asDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  String _modeLabel(StrategyMode m) {
    switch (m) {
      case StrategyMode.conservative:
        return 'Conservative';
      case StrategyMode.balanced:
        return 'Balanced';
      case StrategyMode.aggressive:
        return 'Aggressive';
    }
  }

  double _scoreFromAnchors({required double btc, required double eth, required double sol}) {
    // Deterministic score around “anchors”
    const btcAnchor = 85000.0;
    const ethAnchor = 2800.0;
    const solAnchor = 120.0;

    final btcDelta = (btc - btcAnchor) / btcAnchor;
    final ethDelta = (eth - ethAnchor) / ethAnchor;
    final solDelta = (sol - solAnchor) / solAnchor;

    // weighted score
    return (btcDelta * 0.5) + (ethDelta * 0.35) + (solDelta * 0.15);
  }
}
