import 'dart:async';
import 'package:flutter/foundation.dart';

import '../battle_buddy_engine.dart';
import '../price/price_feed.dart';
import '../models/ladder_policy.dart';
import '../models/allocation_target.dart';
import '../models/execution_mode.dart';
import '../models/status_snapshot.dart';
import '../models/execution_intent.dart';
import '../models/alert_event.dart';
import '../models/deployment_plan.dart';
import '../models/feed_health.dart';
import '../models/threshold_step_state.dart';

class PollingEngine {
  // Debug toggle for poll logs.
  static const bool _kPollDebug = false;
  static const String _kTickReasonStart = 'STARTUP';
  static const String _kTickReasonInterval = 'INTERVAL';
  static const String _kTickReasonOnDemand = 'ON_DEMAND';
  static const String _kTickReasonConnectivityNudge = 'CONNECTIVITY_NUDGE';
  static const String _kTickReasonAssetsChanged = 'ASSETSCHANGED';

  final BattleBuddyEngine engine;
  final PriceFeed feed;
  final Duration interval;
  Timer? _timer;
  int _runToken = 0;
  List<AlertEvent> _alerts = [];
  List<String> _symbols = const <String>[];
  bool _loggedSymbolMismatchOnce = false;
  Map<String, List<double>>? _buyZonesBySymbol;
  Map<String, List<double>>? _sellZonesBySymbol;
  List<AllocationTarget>? _targets;
  LadderPolicy? _policy;
  ExecutionMode? _mode;
  Future<void> Function(
    StatusSnapshot snapshot,
    ExecutionIntent intent,
    Map<String, Map<String, ThresholdStepState>> thresholdStateDelta,
    bool freshMarketDataAvailable,
  )? _onTick;
  DateTime? _lastPollLogTs;
  String? _lastPollSig;
  DateTime? _lastPollPriceKeysLogTs;
  DateTime? _lastConnectivityNudgeAt;
  DateTime? _lastTickStartTs;
  static const Duration _minTickSpacing = Duration(seconds: 1);
  static const Duration _connectivityNudgeCooldown = Duration(seconds: 20);
  bool _tickInProgress = false;
  // Rate-limit backoff (CoinGecko 429). We do NOT want 429 to drive HEALTH -> DOWN.
  int _rateLimitStrikeCount = 0;
  DateTime? _rateLimitUntil;

  List<AlertEvent> get alerts => List.unmodifiable(_alerts);
  bool get isTicking => _tickInProgress;
  StatusSnapshot? _lastSnapshot;

  PollingEngine({
    required this.engine,
    required this.feed,
    this.interval = const Duration(seconds: 30),
  });

  Future<void> refreshOnce({
    String reason = _kTickReasonOnDemand,
  }) async {
    final token = _runToken;
    await _tickOnce(token, triggerReason: reason);
  }

  List<String> _normalizeSymbols(List<String> symbols) {
    // normalize uppercase, de-dupe, stable sort
    final deduped = <String>{};
    for (final raw in symbols) {
      final symbol = raw.trim().toUpperCase();
      if (symbol.isNotEmpty) {
        deduped.add(symbol);
      }
    }
    final out = deduped.toList()..sort();
    return out;
  }

  /// Update symbol list without restarting timer/poller.
  /// This prevents restart storms that trigger CoinGecko 429.
  Future<void> updateSymbols(List<String> symbols, {String reason = _kTickReasonAssetsChanged}) async {
    _symbols = _normalizeSymbols(symbols);
    _loggedSymbolMismatchOnce = false;
    await refreshOnce(reason: reason);
  }

  void start({
    required List<String> symbols,
    required Map<String, List<double>> buyZonesBySymbol,
    required Map<String, List<double>> sellZonesBySymbol,
    required List<AllocationTarget> targets,
    required LadderPolicy policy,
    required ExecutionMode mode,
    required Future<void> Function(
      StatusSnapshot snapshot,
      ExecutionIntent intent,
      Map<String, Map<String, ThresholdStepState>> thresholdStateDelta,
      bool freshMarketDataAvailable,
    ) onTick,
    String startReason = _kTickReasonStart,
  }) {
    stop();
    _runToken++; // invalidate any prior timers/callbacks
    final token = _runToken;
    _symbols = _normalizeSymbols(symbols);
    _loggedSymbolMismatchOnce = false;
    _buyZonesBySymbol = buyZonesBySymbol;
    _sellZonesBySymbol = sellZonesBySymbol;
    _targets = targets;
    _policy = policy;
    _mode = mode;
    _onTick = onTick;
    if (_kPollDebug) {
      // ignore: avoid_print
      print('POLL_START_SYMBOLS_COUNT: ${_symbols.length}');
      // ignore: avoid_print
      print('POLL_START_SYMBOLS: ${_symbols.join(", ")}');
    }

    _tickOnce(token, triggerReason: startReason);
    _timer = Timer.periodic(interval, (_) async {
      await _tickOnce(token, triggerReason: _kTickReasonInterval);
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _runToken++; // invalidate any in-flight tick
  }

  void _logPollStart({
    required String reason,
    required FeedStatus status,
    required String healthMsg,
    DateTime? snapTs,
    int? ttlSec,
  }) {
    // Rate-limit to ~1 log / 5s unless state changes
    final now = DateTime.now();
    final sig = 'START|$reason|$status|$healthMsg|${snapTs?.millisecondsSinceEpoch}|$ttlSec';
    final recently = _lastPollLogTs != null && now.difference(_lastPollLogTs!).inSeconds < 5;
    if (recently && sig == _lastPollSig) return;
    _lastPollLogTs = now;
    _lastPollSig = sig;

    final s = status.toString().split('.').last.toUpperCase();
    final ts = snapTs?.toIso8601String() ?? 'null';
    final ttl = ttlSec?.toString() ?? 'null';
    if (kDebugMode) {
      debugPrint('[POLL] START status=$s reason=$reason healthMsg="$healthMsg" snapTs=$ts ttlSec=$ttl');
    }
  }

  void _logPollResult({
    required FeedStatus status,
    required String reason,
    required bool attemptSucceeded,
    required bool usedCache,
    DateTime? snapTs,
  }) {
    final s = status.toString().split('.').last.toUpperCase();
    final ts = snapTs?.toIso8601String() ?? 'null';
    if (kDebugMode) {
      debugPrint(
        '[POLL] RESULT status=$s reason=$reason attemptSucceeded=$attemptSucceeded usedCache=$usedCache snapTs=$ts',
      );
    }
  }

  Duration _computeRateLimitBackoff() {
    // Exponential-ish backoff capped at 10 minutes.
    // 1st strike: 15s, 2nd: 30s, 3rd: 60s, 4th: 120s, ... up to 600s.
    final exp = (_rateLimitStrikeCount - 1).clamp(0, 6) as int; // 0..6
    final secs = (15 * (1 << exp)).clamp(15, 600) as int; // 15..600
    return Duration(seconds: secs);
  }

  void _applyRateLimitBackoff(FeedHealth health) {
    _rateLimitStrikeCount = ((_rateLimitStrikeCount + 1).clamp(1, 10) as int);
    final backoff = _computeRateLimitBackoff();
    _rateLimitUntil = DateTime.now().add(backoff);
    feed.updateHealth(
      health.copyWith(
        status: FeedStatus.rateLimited,
        message: 'Rate limited (429) — backing off ${backoff.inSeconds}s',
      ),
    );
  }

  bool _looksLikeRateLimit(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('429') || s.contains('rate limit') || s.contains('too many requests');
  }

  String _resolveTickReason({
    required String triggerReason,
    required FeedStatus statusAtStart,
  }) {
    final normalized = triggerReason.trim().toUpperCase();
    if (normalized == _kTickReasonOnDemand &&
        statusAtStart != FeedStatus.healthy) {
      // ON_DEMAND is reserved for explicit user actions.
      // Automatic retries while unhealthy are logged as connectivity nudges.
      return _kTickReasonConnectivityNudge;
    }
    if (normalized.isEmpty) return _kTickReasonOnDemand;
    return normalized;
  }

  bool _shouldRunConnectivityNudge(DateTime now) {
    final last = _lastConnectivityNudgeAt;
    if (last == null) {
      _lastConnectivityNudgeAt = now;
      return true;
    }
    final elapsed = now.difference(last);
    if (elapsed >= _connectivityNudgeCooldown) {
      _lastConnectivityNudgeAt = now;
      return true;
    }
    final remaining = _connectivityNudgeCooldown - elapsed;
    final sec = remaining.inSeconds <= 0 ? 1 : remaining.inSeconds;
    if (kDebugMode) {
      debugPrint('[POLL] SKIP reason=CONNECTIVITY_NUDGE cooldownRemainingSec=$sec');
    }
    return false;
  }

  Future<void> _tickOnce(int token, {required String triggerReason}) async {
    final now = DateTime.now();
    if (token != _runToken) return;
    if (_lastTickStartTs != null &&
        now.difference(_lastTickStartTs!) < _minTickSpacing) {
      return;
    }
    if (_tickInProgress) return;
    _tickInProgress = true;
    _lastTickStartTs = now;
    final requestedSymbols = _symbols;
    final buyZonesBySymbol = _buyZonesBySymbol;
    final sellZonesBySymbol = _sellZonesBySymbol;
    final targets = _targets;
    final policy = _policy;
    final mode = _mode;
    final onTick = _onTick;
    final statusAtStart = feed.health.status;
    final reason = _resolveTickReason(
      triggerReason: triggerReason,
      statusAtStart: statusAtStart,
    );
    try {
      if (buyZonesBySymbol == null ||
          sellZonesBySymbol == null ||
          targets == null ||
          policy == null ||
          mode == null ||
          onTick == null) {
        return;
      }
      if (token != _runToken) return;
      // If we are currently backing off due to 429, skip this cycle quietly.
      if (_rateLimitUntil != null && now.isBefore(_rateLimitUntil!)) {
        // Keep existing snapshot/health as-is while backing off.
        _logPollResult(
          status: feed.health.status,
          reason: 'RATE_LIMIT_BACKOFF',
          attemptSucceeded: false,
          usedCache: _lastSnapshot != null,
          snapTs: _lastSnapshot?.timestamp,
        );
        return;
      }
      if (token != _runToken) return;
      if (reason == _kTickReasonConnectivityNudge &&
          !_shouldRunConnectivityNudge(now)) {
        return;
      }
      _logPollStart(
        reason: reason,
        status: feed.health.status,
        healthMsg: 'starting',
        snapTs: _lastSnapshot?.timestamp,
        ttlSec: interval.inSeconds,
      );
      // Log the actual symbol list being requested each tick (pre-feed).
      if (_kPollDebug) {
        final syms = _symbols
            .map((s) => s.toUpperCase())
            .toList()
          ..sort();
        // ignore: avoid_print
        print('POLL_REQ_SYMBOLS: ${syms.join(", ")}');
      }

      final currentBudget = engine.getCurrentBudget(DateTime.now());
      // Fetch prices for all requested symbols captured in start().
      final fetchedPrices = await feed.fetchPrices(symbols: requestedSymbols);
      final requestedSymbolSet = _normalizeSymbols(requestedSymbols).toSet();
      final sanitizedPrices = <String, double>{};
      for (final entry in fetchedPrices.entries) {
        final symbol = entry.key.trim().toUpperCase();
        final price = entry.value;
        if (requestedSymbolSet.contains(symbol) &&
            price.isFinite &&
            price > 0) {
          sanitizedPrices[symbol] = price;
        }
      }
      final freshMarketDataAvailable = sanitizedPrices.isNotEmpty;
      final crossingDelta = await engine.observeThresholdCrossings(
        prices: sanitizedPrices,
      );

      if (_kPollDebug) {
        final nowForKeys = DateTime.now();
        final canLogKeys = _lastPollPriceKeysLogTs == null ||
            nowForKeys.difference(_lastPollPriceKeysLogTs!).inSeconds >= 30;
        if (canLogKeys) {
          _lastPollPriceKeysLogTs = nowForKeys;
          if (sanitizedPrices.isNotEmpty) {
            final got = sanitizedPrices.keys.toList()..sort();
            debugPrint('POLL_GOT_PRICE_KEYS: ${got.join(", ")}');
          } else {
            debugPrint('POLL_GOT_PRICE_KEYS: (empty)');
          }
        }
      }

      // One-time mismatch proof log for missing symbols.
      if (!_loggedSymbolMismatchOnce &&
          requestedSymbols.isNotEmpty &&
          sanitizedPrices.isNotEmpty &&
          sanitizedPrices.length < requestedSymbols.length) {
        _loggedSymbolMismatchOnce = true;
        debugPrint(
          '[POLL] SYMBOLS requested=${requestedSymbols.length} returned=${sanitizedPrices.length} '
          'missing=${requestedSymbols.where((s) => !sanitizedPrices.containsKey(s)).take(10).join(", ")}',
        );
      }

      // Success clears rate-limit state.
      _rateLimitStrikeCount = 0;
      _rateLimitUntil = null;

      final snapshot = engine.buildStatusSnapshot(
        prices: sanitizedPrices,
        buyZonesBySymbol: buyZonesBySymbol,
        sellZonesBySymbol: sellZonesBySymbol,
        deploymentPlan: null,
      );

      var resultReason = reason;
      if (statusAtStart != FeedStatus.healthy && feed.health.status == FeedStatus.healthy) {
        resultReason = 'CONNECTIVITY_RESTORED';
      }
      _logPollResult(
        status: feed.health.status,
        reason: resultReason,
        attemptSucceeded: true,
        usedCache: false,
        snapTs: snapshot.timestamp,
      );

      final fired = engine.generateAlertsFromSnapshot(
        snapshot: snapshot,
        cooldown: const Duration(minutes: 30),
      );
      _alerts = fired;

      final plan = engine.buildDeploymentFromAlerts(
        alerts: fired,
        targets: targets,
        budget: currentBudget,
        policy: policy,
      );

      final updatedBudget = engine.applySpend(
        budget: currentBudget,
        plan: plan,
      );
      engine.setMonthlyBudget(updatedBudget);

      final intent = engine.buildExecutionIntent(
        plan: plan,
        mode: mode,
      );

      final snapshotWithPlan = engine.buildStatusSnapshot(
        prices: sanitizedPrices,
        buyZonesBySymbol: buyZonesBySymbol,
        sellZonesBySymbol: sellZonesBySymbol,
        deploymentPlan: plan,
      );

      if (freshMarketDataAvailable) {
        _lastSnapshot = snapshotWithPlan;
      }
      await onTick(
        snapshotWithPlan,
        intent,
        crossingDelta,
        freshMarketDataAvailable,
      );
    } catch (e) {
      // Special case: CoinGecko 429 should not drive the feed to DOWN.
      if (_looksLikeRateLimit(e)) {
        _applyRateLimitBackoff(feed.health);
        _logPollResult(
          status: feed.health.status,
          reason: 'RATE_LIMITED',
          attemptSucceeded: false,
          usedCache: _lastSnapshot != null,
          snapTs: _lastSnapshot?.timestamp,
        );
        return; // do NOT rethrow
      }

      // Deterministic failure semantics: never leave a failed attempt as healthy.
      final h = feed.health;
      final nextFailureStatus = h.status == FeedStatus.healthy
          ? FeedStatus.degraded
          : FeedStatus.down;
      feed.updateHealth(
        h.copyWith(
          status: nextFailureStatus,
          timestamp: DateTime.now(),
          message: 'Poll exception: $e',
        ),
      );

      final fallbackIntent = engine.buildExecutionIntent(
        plan: const DeploymentPlan(
          perAssetAmounts: {},
          totalToDeploy: 0,
          message: 'No deployment',
        ),
        mode: mode!,
      );
      if (_lastSnapshot != null) {
        await onTick!(
          _lastSnapshot!,
          fallbackIntent,
          const <String, Map<String, ThresholdStepState>>{},
          false,
        );
      } else {
        final emptySnapshot = engine.buildStatusSnapshot(
          prices: const {},
          buyZonesBySymbol: buyZonesBySymbol!,
          sellZonesBySymbol: sellZonesBySymbol!,
          deploymentPlan: null,
        );
        await onTick!(
          emptySnapshot,
          fallbackIntent,
          const <String, Map<String, ThresholdStepState>>{},
          false,
        );
      }
      _logPollResult(
        status: feed.health.status,
        reason: reason,
        attemptSucceeded: false,
        usedCache: _lastSnapshot != null,
        snapTs: _lastSnapshot?.timestamp,
      );
    } finally {
      _tickInProgress = false;
    }
  }
}
