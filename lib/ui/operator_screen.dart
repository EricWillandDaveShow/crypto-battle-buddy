import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/alert_event.dart';
import '../models/confirm_window.dart';
import '../models/feed_health.dart';
import '../models/lockdown.dart';
import '../models/monthly_budget.dart';
import '../models/strategy_profile.dart';
import '../assets/asset_catalog_store.dart';
import '../assets/asset_registry.dart';
import '../assets/dynamic_asset_store.dart';
import 'asset_change_notification_policy.dart';
import 'budget_hero_card.dart';
import 'manage_assets_universal_screen.dart';
import 'models/crypto_asset.dart';
import '../battle_buddy_engine.dart';
import '../engine/threshold_pill_display_state.dart';
import '../engine/threshold_step_state_merge.dart';
import '../engine/threshold_tier_row_state.dart';
import '../storage/threshold_state_store.dart';
import 'package:intl/intl.dart';
import 'package:crypto_battle_buddy/models/threshold_plan.dart';
import '../engine/pill_state_evaluator.dart';
import '../models/threshold_step_state.dart';

class AssetRuntimeState {
  final double units;
  final double price;
  final double value;
  final bool hasPlan;
  final bool isArmed;
  final bool hasPrice;
  final bool hasPosition;
  final bool hasHistory;
  final String? emptyStateMessage;
  final ThresholdPlan? plan;
  final Map<String, ThresholdStepState> states;
  final PillEvaluationResult? evaluation;

  const AssetRuntimeState({
    required this.units,
    required this.price,
    required this.value,
    required this.hasPlan,
    required this.isArmed,
    required this.hasPrice,
    required this.hasPosition,
    required this.hasHistory,
    required this.emptyStateMessage,
    required this.plan,
    required this.states,
    required this.evaluation,
  });
}

class SymbolViewState {
  final String symbol;
  final double units;
  final double livePriceUsd;
  final double marketValueUsd;
  final bool hasPlan;
  final bool isArmed;
  final bool hasPrice;
  final bool hasPosition;
  final bool hasHistory;
  final String? emptyStateMessage;
  final ThresholdPlan? plan;
  final Map<String, ThresholdStepState> states;
  final PillEvaluationResult? evaluation;

  const SymbolViewState({
    required this.symbol,
    required this.units,
    required this.livePriceUsd,
    required this.marketValueUsd,
    required this.hasPlan,
    required this.isArmed,
    required this.hasPrice,
    required this.hasPosition,
    required this.hasHistory,
    required this.emptyStateMessage,
    required this.plan,
    required this.states,
    required this.evaluation,
  });

  AssetRuntimeState toRuntime() {
    return AssetRuntimeState(
      units: units,
      price: livePriceUsd,
      value: marketValueUsd,
      hasPlan: hasPlan,
      isArmed: isArmed,
      hasPrice: hasPrice,
      hasPosition: hasPosition,
      hasHistory: hasHistory,
      emptyStateMessage: emptyStateMessage,
      plan: plan,
      states: states,
      evaluation: evaluation,
    );
  }
}

class _SymbolVisualState {
  final String badgeText;
  final Color badgeColor;
  final Color accentColor;
  final bool showExecuteAccent;

  const _SymbolVisualState({
    required this.badgeText,
    required this.badgeColor,
    required this.accentColor,
    required this.showExecuteAccent,
  });
}

class OperatorScreen extends StatefulWidget {
  final StrategyProfile selectedProfile;
  final bool lockdownEnabled;
  final String lockdownMessage;
  final ReleaseChecklist checklist;
  final void Function(ReleaseChecklist) onChecklistChanged;
  final void Function(bool enabled) onLockdownChanged;
  final Set<String> armedSymbols;
  final void Function(String symbolUpper, bool armed) onArmChanged;
  final ConfirmWindow confirmWindow;
  final VoidCallback onConfirm;
  final String heatForceMessage;
  final List<AlertEvent> alerts;
  final String pnlSummary;
  final String rebalanceSummary;
  final String budgetSummary;
  final String reportPretty;
  final String copyStatus;
  final VoidCallback onCopyReport;
  final VoidCallback onExportReport;
  final Map<String, double> livePricesUsd;
  final Map<String, Map<String, ThresholdStepState>>
      thresholdStepStatesBySymbol;
  final FeedHealth feedHealth;
  final String feedName;
  final List<String> availableFeedIds;
  final String selectedFeedId;
  final ValueChanged<String> onFeedChanged;
  final String? statusText;
  final String? nextActionText;
  final String readyLabel;
  final String readyTooltip;
  final bool isReady;
  final VoidCallback onRefresh;
  final Future<void> Function()? onAssetsChanged;
  final void Function(String symbolUpper)? onThresholdCycleReset;

  const OperatorScreen({
    super.key,
    required this.selectedProfile,
    required this.lockdownEnabled,
    required this.lockdownMessage,
    required this.checklist,
    required this.onChecklistChanged,
    required this.onLockdownChanged,
    required this.armedSymbols,
    required this.onArmChanged,
    required this.confirmWindow,
    required this.onConfirm,
    required this.heatForceMessage,
    required this.alerts,
    required this.pnlSummary,
    required this.rebalanceSummary,
    required this.budgetSummary,
    required this.reportPretty,
    required this.copyStatus,
    required this.onCopyReport,
    required this.onExportReport,
    required this.livePricesUsd,
    required this.thresholdStepStatesBySymbol,
    required this.feedHealth,
    required this.feedName,
    required this.availableFeedIds,
    required this.selectedFeedId,
    required this.onFeedChanged,
    required this.readyLabel,
    required this.readyTooltip,
    required this.isReady,
    required this.onRefresh,
    this.onAssetsChanged,
    this.onThresholdCycleReset,
    this.statusText,
    this.nextActionText,
  });

  @override
  State<OperatorScreen> createState() => _OperatorScreenState();
}

CryptoAsset? _assetFromSymbol(String symbol) {
  final s = symbol.toUpperCase();
  for (final asset in CryptoAsset.values) {
    if (asset.symbol == s) return asset;
  }
  return null;
}

class _OperatorScreenState extends State<OperatorScreen> {
  // -----------------------------
  // PRICE SAFETY (LOCKED)
  // Missing price MUST remain null (never coerced to 0.0).
  // UI must show "—" for missing/invalid prices.
  // -----------------------------
  double? _priceUsdOrNull(String symbol) {
    final s = symbol.toUpperCase();
    final v = _resolvePriceUsdForSymbol(s);
    if (v != null && v > 0) return v;
    return null;
  }

  String _usdOrDash(double? price) {
    // Missing/invalid price must render as an em dash.
    if (price == null || price <= 0) return '—';
    return '\$${price.toStringAsFixed(2)}';
  }

  // UI constants (keep near top so everything can reference them)
  static const double _kPillRadius = 22.0;
  static const double _kPillElevation = 0.0;
  static const double _s8 = 8.0;
  static const double _s12 = 12.0;
  static const double _s16 = 16.0;

  static const Color _kNavyBase = Color(0xFF0C1B2A);
  static const Color _kNavyTop = Color(0xFF0F2234);
  static const Color _kNavySelected = Color(0xFF12273A);
  static const Color _kNavyDeep = Color(0xFF081321);
  TextStyle get _tTitle =>
      (Theme.of(context).textTheme.titleMedium ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      );
  TextStyle get _tValue =>
      (Theme.of(context).textTheme.titleSmall ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      );
  TextStyle get _tLabel =>
      (Theme.of(context).textTheme.labelMedium ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.12,
      );

  // Tactical contrast tokens (brand-forward, not washed out)
  static const Color _kTextStrong = Color(0xFFFFFFFF);
  static const Color _kTextBody = Color(0xFFE6EEF5);
  static const Color _kTextSubtle = Color(0xFFB7C4D0);
  static const Color _kTextMuted = Color(0xFF90A0AE);

  // ---------------------------------------------------------------------------
  // TACTICAL OPERATOR “hero pill” is the canonical surface language.
  // Use this for ALL pills (collapsed) and ALL expanded panels.
  // ---------------------------------------------------------------------------
  BoxDecoration _opsSurfaceDecoration({
    required Color accentColor,
    required bool isSelected,
    required _SymbolVisualState visual,
    double radius = 12,
  }) {
    final Color base = Color.alphaBlend(
      accentColor.withOpacity(isSelected ? 0.040 : 0.028),
      _kNavyBase,
    );
    return BoxDecoration(
      color: base.withOpacity(0.55),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: visual.accentColor.withOpacity(
          _outlineOpacityForVisual(
            visual,
            isExpanded: false,
            isSelected: isSelected,
          ),
        ),
        width: _outlineWidthForVisual(visual),
      ),
      // Subtle engineered depth (no glow / no haze).
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.16),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  final ScrollController _scrollController = ScrollController();
  // Main screen declutter flags (temporary, reversible).
  static const bool _showLegacyControls = false;
  static const bool kUiPriceKeyDebug = false;
  static const double _budgetMin = 0;
  static const double _budgetMax = 2000;

  // Path B: universal enabled symbols + catalog (CoinGecko id map)
  final AssetCatalogStore _catalogStore = AssetCatalogStore();
  final DynamicAssetStore _dynamicStore = DynamicAssetStore();
  Set<String> _universalEnabledSymbols = <String>{};
  Map<String, String> _universalCatalog = const <String, String>{};
  // Prevent rapid successive ASSETSCHANGED restarts from hammering CoinGecko.
  DateTime? _lastAssetsChangedRestartTs;
  DateTime? _lastUiPriceKeysLogTs;
  bool _isSystemReady = false;
  String? _openAssetPanelSymbol;
  String? _primarySymbolSticky;
  // ============================================================
  // R2-B (Option B): Multi-asset engine scaffold
  // ============================================================
  // Maps are symbol-driven for enabled assets so the expanded operator panel
  // scales symmetrically across assets.
  final Map<String, ThresholdPlan?> _plansBySymbol = <String, ThresholdPlan?>{};
  Map<String, SymbolViewState> _latestViewStateBySymbol =
      <String, SymbolViewState>{};
  final Map<String, Map<String, ThresholdStepState>> _stepStatesBySymbol =
      <String, Map<String, ThresholdStepState>>{};
  final Map<String, Map<int, double>> _tierDraftPriceBySymbol =
      <String, Map<int, double>>{};
  final Set<String> _optimisticArmedSymbols = <String>{};
  bool _supportsTiers(String symbolUpper) {
    final assetDef = AssetRegistry.bySymbol(symbolUpper);
    return assetDef?.supportsTiers ?? true;
  }

  Set<String> _filterTierSymbols(Iterable<String> symbols) {
    return symbols
        .map((s) => s.toUpperCase())
        .where((s) => _supportsTiers(s))
        .toSet();
  }

  Set<String> _uiEnabledSymbols([Iterable<String>? symbols]) {
    final source = symbols ?? _universalEnabledSymbols;
    return source.map((s) => s.toUpperCase()).toSet();
  }

  void _purgeInvalidSymbols([Set<String>? validSymbols]) {
    if (_universalEnabledSymbols.isEmpty && validSymbols == null) return;

    final valid = validSymbols ?? _uiEnabledSymbols();
    _plansBySymbol.removeWhere(
      (key, _) => !valid.contains(key.toUpperCase()),
    );
    _stepStatesBySymbol.removeWhere(
      (key, _) => !valid.contains(key.toUpperCase()),
    );
    _latestViewStateBySymbol.removeWhere(
      (key, _) => !valid.contains(key.toUpperCase()),
    );
    _tierDraftPriceBySymbol.removeWhere(
      (key, _) => !valid.contains(key.toUpperCase()),
    );
    _openTierIndexBySymbol.removeWhere(
      (key, _) => !valid.contains(key.toUpperCase()),
    );
    if (_openAssetPanelSymbol != null &&
        !valid.contains(_openAssetPanelSymbol!.toUpperCase())) {
      _openAssetPanelSymbol = null;
    }
    if (_primarySymbolSticky != null &&
        !valid.contains(_primarySymbolSticky!.toUpperCase())) {
      _primarySymbolSticky = null;
    }
  }

  // Tier doctrine: only enabled symbols that support tiers render threshold UI.
  Set<String> get _tierAssets => _filterTierSymbols(_enabledSymbolSet());
  // Open tier (expanded row) per symbol. Needed so tier expand/collapse works
  // for all enabled assets.
  final Map<String, int?> _openTierIndexBySymbol = <String, int?>{};
  // D3-D2: Prevent concurrent threshold prewarm runs (avoids double seed/re-anchor saves).
  bool _thresholdPrewarmInFlight = false;
  final Set<String> _thresholdPrewarmInFlightSymbols = <String>{};
  // D4-A: Late reseed guard (when prices arrive after initial prewarm)
  final Set<String> _lateReseedInFlight = <String>{};
  void _maybeLateReseedPlanFromLive({
    required String symbolUpper,
    required double? livePriceUsd,
  }) {
    if (livePriceUsd == null || livePriceUsd <= 0) return;

    final s = symbolUpper.toUpperCase();
    final plan = _planFor(s);
    if (plan.steps.isEmpty) return;

    // Only reseed if still at universal default scale and not yet seeded.
    if (plan.anchorPriceUsd != 1.0 || plan.seededFromLive) return;

    // Prevent repeat scheduling.
    if (_lateReseedInFlight.contains(s)) return;
    _lateReseedInFlight.add(s);

    Future.microtask(() async {
      try {
        final scaledSteps = plan.steps
            .map((st) => ThresholdStep(
                  triggerPriceUsd:
                      (st.triggerPriceUsd.toDouble() * livePriceUsd),
                  action: st.action,
                  percentOfPosition: st.percentOfPosition,
                ))
            .toList(growable: false);

        final updated = ThresholdPlan(
          assetSymbol: plan.assetSymbol,
          anchorPriceUsd: livePriceUsd,
          steps: scaledSteps,
          seededFromLive: true,
        );

        await saveThresholdPlan(updated, source: 'late_seed');
        if (!mounted) return;

        setState(() {
          _setPlanFor(s, updated);
          _tierDraftPriceBySymbol.remove(s); // reset drafts after reseed
        });

        if (kDebugMode) {
          debugPrint(
              'THRESH-LATE-SEED $s anchor=$livePriceUsd steps=${updated.steps.length}');
        }
      } finally {
        _lateReseedInFlight.remove(s);
      }
    });
  }

  // R9: Threshold UI pre-warm.
  // Any enabled symbol must have a ThresholdPlan + step state map available
  // so expanded panels don't render blank.
  Future<void> _ensureThresholdUiForEnabledSymbols(
      Set<String> enabledSymbols) async {
    if (_thresholdPrewarmInFlight) {
      if (kDebugMode) {
        debugPrint('THRESH-PREWARM skip (inFlight=true)');
      }
      return;
    }
    _thresholdPrewarmInFlight = true;

    final syms = enabledSymbols.map((e) => e.toUpperCase()).toSet();

    // Only load what we don't already have in memory.
    final toLoad = <String>[];
    for (final s in syms) {
      final existing = _plansBySymbol[s];

      // If we already have a plan but it's still the universal default scale (anchor=1.0)
      // and we haven't seeded from live yet, we MUST run the prewarm path to re-anchor.
      final bool needsAnchor = existing != null &&
          existing.steps.isNotEmpty &&
          existing.anchorPriceUsd == 1.0 &&
          !existing.seededFromLive;

      if (existing == null || existing.steps.isEmpty || needsAnchor) {
        toLoad.add(s);
      } else {
        _tierDraftPriceBySymbol.putIfAbsent(s, () => <int, double>{});
        _openTierIndexBySymbol.putIfAbsent(s, () => null);
      }
    }

    // Prevent per-symbol overlap inside rapid successive calls.
    toLoad.removeWhere((s) => _thresholdPrewarmInFlightSymbols.contains(s));
    _thresholdPrewarmInFlightSymbols.addAll(toLoad);

    if (toLoad.isEmpty) {
      _thresholdPrewarmInFlight = false;
      return;
    }

    try {
      // 1) Load/seed plans (loadThresholdPlan should return a default plan if missing)
      final planEntries = await Future.wait(toLoad.map((s) async {
        final loaded = await loadThresholdPlan(s);

        // D3-B: If the plan is a newly-seeded universal default (anchor=1.0),
        // re-anchor it to live price once so tiers are immediately meaningful.
        final live = _priceUsdOrNull(s);
        if (live != null &&
            live > 0 &&
            loaded.anchorPriceUsd == 1.0 &&
            !loaded.seededFromLive) {
          final scaledSteps = loaded.steps
              .map((st) => ThresholdStep(
                    triggerPriceUsd: (st.triggerPriceUsd.toDouble() * live),
                    action: st.action,
                    percentOfPosition: st.percentOfPosition,
                  ))
              .toList(growable: false);

          final updated = ThresholdPlan(
            assetSymbol: loaded.assetSymbol,
            anchorPriceUsd: live,
            steps: scaledSteps,
            seededFromLive: true,
          );

          await saveThresholdPlan(updated, source: 'prewarm');
          // D3-C: reset any stale tier draft values after re-anchor
          _tierDraftPriceBySymbol.remove(s);
          return MapEntry<String, ThresholdPlan>(s, updated);
        }

        return MapEntry<String, ThresholdPlan>(s, loaded);
      }));

      // 2) Load persisted step states (may be empty; that's fine)
      final stateEntries = await Future.wait(
        toLoad
            .map((s) async => MapEntry<String, Map<String, ThresholdStepState>>(
                  s,
                  await ThresholdStateStore.loadStepStates(symbol: s),
                )),
      );

      if (!mounted) return;
      setState(() {
        for (final e in planEntries) {
          _setPlanFor(e.key, e.value);
        }
        for (final e in stateEntries) {
          _setStatesFor(e.key, e.value);
        }
        for (final s in toLoad) {
          _tierDraftPriceBySymbol.putIfAbsent(s, () => <int, double>{});
          _openTierIndexBySymbol.putIfAbsent(s, () => null);
        }
      });

      if (kDebugMode) {
        for (final e in planEntries) {
          debugPrint(
              'THRESH-PREWARM loaded ${e.key} steps=${e.value.steps.length}');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('THRESH-PREWARM error: $e');
    } finally {
      _thresholdPrewarmInFlight = false;
      _thresholdPrewarmInFlightSymbols.removeAll(toLoad);
    }
  }

  // ------------------------------------------------------------
  // R3-B: Symbol-driven pill rendering helpers
  // ------------------------------------------------------------
  double? _resolvePriceUsdForSymbol(String symbolUpper) {
    final s = symbolUpper.toUpperCase();
    final m = widget.livePricesUsd;
    if (m.isEmpty) return null;

    // 1) direct symbol keys
    final direct = m[s] ?? m[s.toLowerCase()];
    if (direct != null) return direct;

    // 2) CoinGecko id keys (when feed uses ids)
    final id = _universalCatalog[s] ?? _universalCatalog[s.toLowerCase()];
    if (id != null && id.isNotEmpty) {
      final byId = m[id] ?? m[id.toLowerCase()];
      if (byId != null) return byId;
    }

    return null;
  }

  List<String> _orderedEnabledSymbolsForPills() {
    // R3: Universal enabled symbols must drive pill rendering.
    // Include dynamic enabled symbols (not in static registry) so "search -> add -> enable"
    // produces a real pill on the main screen.
    final enabled = _uiEnabledSymbols();

    // Registry symbols (static)
    final regAll = AssetRegistry.all.map((a) => a.symbol.toUpperCase()).toSet();

    // Enabled registry symbols
    final regEnabled = enabled.where((s) => regAll.contains(s)).toList()
      ..sort();

    // Enabled dynamic symbols = enabled but not in registry.
    final dynEnabled = enabled.where((s) => !regAll.contains(s)).toList()
      ..sort();

    // Doctrine order:
    // 1) enabled registry symbols
    // 2) enabled dynamic symbols (from CoinGecko search)
    final out = <String>[];
    for (final s in regEnabled) {
      if (!out.contains(s)) out.add(s);
    }
    out.addAll(dynEnabled);
    return out;
  }

  Future<Set<String>> _loadUniversalEnabledSymbolsAuthoritative() async {
    // SINGLE SOURCE OF TRUTH: asset_enabled_v1 (AssetCatalogStore).
    // This path must not inject defaults.
    final fromStore = await _catalogStore.loadEnabledSymbols();
    return fromStore.map((e) => e.toUpperCase()).toSet();
  }

  double _budgetValue = 0;
  Future<void> _refreshHoldingsFromEngine() async {
    final engine = _engine;
    if (engine == null) return;
    await engine.loadHoldings();
    if (!mounted) return;
    if (!_isSystemReady) return;
    setState(() {});
  }

  Future<void> _loadAll() async {
    await Future.wait<void>([
      _refreshHoldingsFromEngine(),
      _reloadUniversalPrefs(),
    ]);
    if (!mounted) return;
    setState(() {
      _isSystemReady = true;
    });
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadAll());
    _budgetValue = _initialBudgetValue();
  }

  Future<void> _reloadUniversalPrefs() async {
    try {
      final enabledSet = await _loadUniversalEnabledSymbolsAuthoritative();
      final catalog = await _catalogStore.loadCatalog();
      // Merge in dynamic store too (defensive; catalog should already be in sync)
      final dyn = await _dynamicStore.loadAll();
      final merged = <String, String>{...catalog};
      for (final a in dyn) {
        merged[a.symbol.toUpperCase()] = a.coingeckoId;
      }

      if (!mounted) return;
      void applyPrefs() {
        _universalEnabledSymbols = enabledSet;
        _universalCatalog = merged;
        final uiEnabledSymbols = _uiEnabledSymbols(enabledSet);
        _purgeInvalidSymbols(uiEnabledSymbols);
      }

      if (_isSystemReady) {
        setState(applyPrefs);
      } else {
        applyPrefs();
      }
      await _ensureThresholdUiForEnabledSymbols(
        _filterTierSymbols(enabledSet),
      );
    } catch (_) {
      // Silent: UI remains usable even if prefs not available yet.
    }
  }

  ThresholdPlan _planFor(String symbolUpper) {
    final s = symbolUpper.toUpperCase();
    if (!_enabledSymbolSet().contains(s) || !_supportsTiers(s)) {
      return ThresholdPlan(
          assetSymbol: s, anchorPriceUsd: 0.0, steps: const []);
    }
    var plan = _plansBySymbol[s];
    if (plan == null || plan.steps.isEmpty) {
      plan = ThresholdPlan.defaultFor(s);
      final livePrice = _priceUsdOrNull(s);
      if (livePrice != null && livePrice > 0) {
        plan = plan.reseedToLive(livePrice);
      }

      _setPlanFor(s, plan);
      _tierDraftPriceBySymbol.putIfAbsent(s, () => <int, double>{});
      _openTierIndexBySymbol.putIfAbsent(s, () => null);

      if (kDebugMode) {
        debugPrint(
            'THRESH-PLAN guarantee symbol=$s anchor=${plan.anchorPriceUsd} steps=${plan.steps.length}');
      }
    }

    _tierDraftPriceBySymbol.putIfAbsent(s, () => <int, double>{});
    _openTierIndexBySymbol.putIfAbsent(s, () => null);
    return plan;
  }

  Map<String, ThresholdStepState> _statesFor(String symbolUpper) {
    final s = symbolUpper.toUpperCase();
    return _stepStatesBySymbol[s] ?? const <String, ThresholdStepState>{};
  }

  // D1: map-first writes (maps are authoritative)
  void _setPlanFor(String symbolUpper, ThresholdPlan? plan) {
    final s = symbolUpper.toUpperCase();
    if (plan == null) {
      _plansBySymbol.remove(s);
    } else {
      _plansBySymbol[s] = plan;
    }
  }

  void _setStatesFor(
      String symbolUpper, Map<String, ThresholdStepState> states) {
    final s = symbolUpper.toUpperCase();
    _stepStatesBySymbol[s] = states;
  }

  void _applyExternalStepStates(
      Map<String, Map<String, ThresholdStepState>> statesBySymbol) {
    if (statesBySymbol.isEmpty) return;
    final merged = mergeExternalStepStates(
      current: _stepStatesBySymbol,
      incoming: statesBySymbol,
    );
    _stepStatesBySymbol
      ..clear()
      ..addAll(merged);
  }

  Map<int, double> _tierDraftFor(String symbolUpper) {
    final s = symbolUpper.toUpperCase();
    return _tierDraftPriceBySymbol.putIfAbsent(s, () => <int, double>{});
  }

  void updateTierPrice(String symbol, int index, double price) {
    final normalizedSymbol = symbol.toUpperCase();
    _tierDraftFor(normalizedSymbol)[index] = price;
  }

  Future<void> _reloadThresholdPlanFor(String symbolUpper) async {
    final updated = await loadThresholdPlan(symbolUpper);
    if (!mounted) return;
    setState(() {
      _setPlanFor(symbolUpper, updated);
    });
  }

  Future<void> _reloadStepStatesFor(String symbolUpper) async {
    final states =
        await ThresholdStateStore.loadStepStates(symbol: symbolUpper);
    if (!mounted) return;
    setState(() {
      _setStatesFor(symbolUpper, states);
    });
  }

  Future<void> _resetCycle(String symbolUpper) async {
    final s = symbolUpper.toUpperCase();

    // 1. Get current live price
    final price =
        widget.livePricesUsd[s] ?? widget.livePricesUsd[s.toLowerCase()];
    if (price == null || price <= 0) return;

    // 2. Load existing plan (for structure only)
    final oldPlan = _planFor(s);
    if (oldPlan.steps.isEmpty) return;
    if (oldPlan.anchorPriceUsd <= 0) return;

    // 3. Build NEW steps anchored to current price
    final List<ThresholdStep> newSteps = [];
    for (final step in oldPlan.steps) {
      final deltaPct = (step.triggerPriceUsd - oldPlan.anchorPriceUsd) /
          oldPlan.anchorPriceUsd;
      final newTrigger = price * (1 + deltaPct);
      newSteps.add(
        ThresholdStep(
          triggerPriceUsd: newTrigger,
          action: step.action,
          percentOfPosition: step.percentOfPosition,
        ),
      );
    }

    final newPlan = ThresholdPlan(
      assetSymbol: s,
      anchorPriceUsd: price,
      steps: newSteps,
    );

    // 4. Save new plan
    await saveThresholdPlan(newPlan, source: 'reset_cycle');
    _setPlanFor(s, newPlan);
    final cycleStart = DateTime.now();
    final engine = _engine;
    if (engine == null) {
      assert(() {
        debugPrint('_resetCycle requires BattleBuddyEngine');
        return true;
      }());
      return;
    }
    await engine.startNewThresholdCycle(
      symbol: s,
      steps: newSteps,
      startedAt: cycleStart,
    );

    // Clear stale state cache before reload.
    _stepStatesBySymbol[s] = <String, ThresholdStepState>{};

    // 6. Clear drafts (CRITICAL)
    _tierDraftPriceBySymbol[s] = <int, double>{};

    // 7. Force this symbol's execution gate back to idle.
    widget.onArmChanged(s, false);

    // 8. Reload everything clean
    await _reloadThresholdPlanFor(s);
    await _reloadStepStatesFor(s);
    widget.onThresholdCycleReset?.call(s);

    // 9. Refresh UI
    if (mounted) {
      setState(() {});
    }
  }

  ({String? line1, String? line2}) _getAssetStateLines(
    AssetRuntimeState runtime, {
    bool includeDurableTriggeredDisplay = false,
  }) {
    final eval = runtime.evaluation;
    if (includeDurableTriggeredDisplay &&
        _thresholdPillDisplayState(runtime) ==
            ThresholdPillDisplayState.durableTriggered) {
      return (line1: 'TRIGGERED', line2: null);
    }

    if (eval == null) {
      return (line1: null, line2: null);
    }

    final action = (eval.nextActionLabel ?? '').trim().toUpperCase();
    final nextTriggerPrice = eval.nextTriggerPrice;
    final distPct = eval.distanceToNextPercent;

    String? line1;
    if (action.isNotEmpty && nextTriggerPrice != null && nextTriggerPrice > 0) {
      line1 = 'NEXT: $action @ \$${_formatTierPrice(nextTriggerPrice)}';
    } else if (action.isNotEmpty) {
      line1 = 'NEXT: $action';
    } else {
      line1 = _pillStateLabel(eval.pillState);
    }

    final String? line2 =
        distPct == null ? null : 'DIST: ${(distPct * 100).toStringAsFixed(1)}%';

    return (line1: line1, line2: line2);
  }

  Widget _buildAssetStateText({
    required AssetRuntimeState runtime,
    required TextStyle style,
    bool includeDurableTriggeredDisplay = false,
  }) {
    final stateLines = _getAssetStateLines(
      runtime,
      includeDurableTriggeredDisplay: includeDurableTriggeredDisplay,
    );
    final line1 = stateLines.line1;
    final line2 = stateLines.line2;
    if (line1 == null || line1.isEmpty) {
      return const SizedBox.shrink();
    }
    if (line2 == null) {
      return Text(line1, style: style);
    }
    final visual = includeDurableTriggeredDisplay
        ? _visualStateForRuntime(runtime)
        : _visualStateForEvaluation(runtime.evaluation);
    final baseFontSize = style.fontSize ?? 14;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(line1, style: style),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              line2,
              style: style.copyWith(
                fontSize: baseFontSize - 2,
                color: visual.accentColor,
              ),
            ),
            if (runtime.evaluation != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: visual.badgeColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  visual.badgeText,
                  style: style.copyWith(
                    fontSize: baseFontSize - 3,
                    fontWeight: FontWeight.w700,
                    color: _badgeForegroundColorForVisual(visual),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  double _engineUnitsFor(String symbol) {
    final engine = _engine;
    if (engine == null) return 0.0;
    return (engine.holdings[symbol.toUpperCase()] ?? 0.0).toDouble();
  }

  bool _isExecutionArmedFor(String symbolUpper) {
    final s = symbolUpper.toUpperCase();
    return widget.armedSymbols.contains(s) ||
        _optimisticArmedSymbols.contains(s);
  }

  bool _hasDefinedHoldings() {
    final engine = _engine;
    if (engine == null) return false;
    for (final symbol in _enabledSymbolSet()) {
      if ((engine.holdings[symbol] ?? 0.0) > 0) return true;
    }
    return false;
  }

  Widget _buildInstructionBlock({
    required String title,
    String? subtitle,
    double titleFontSize = 12,
    double subtitleFontSize = 11,
    TextAlign textAlign = TextAlign.left,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
  }) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          title,
          textAlign: textAlign,
          style: TextStyle(
            fontSize: titleFontSize,
            color: _kTextMuted,
          ),
        ),
        if (subtitle != null && subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: textAlign,
            style: TextStyle(
              fontSize: subtitleFontSize,
              color: _kTextMuted.withOpacity(0.8),
            ),
          ),
        ],
      ],
    );
  }

  SymbolViewState _buildSymbolViewState(String symbolUpper) {
    final s = symbolUpper.toUpperCase();
    final supportsTiers = _supportsTiers(s);
    final isArmed = _isExecutionArmedFor(s);

    final units = _engineUnitsFor(s);
    final hasPosition = units > 0;
    final price = (_resolvePriceUsdForSymbol(s) ?? 0.0).toDouble();
    final hasPrice = price > 0;

    final ThresholdPlan? plan = supportsTiers ? _planFor(s) : null;
    final states =
        supportsTiers ? _statesFor(s) : const <String, ThresholdStepState>{};
    final hasPlan = plan?.steps.isNotEmpty ?? false;
    const hasHistory = false;

    if (!hasPrice) {
      return SymbolViewState(
        symbol: s,
        units: units,
        livePriceUsd: price,
        marketValueUsd: 0.0,
        hasPlan: hasPlan,
        isArmed: isArmed,
        hasPrice: false,
        hasPosition: hasPosition,
        hasHistory: hasHistory,
        emptyStateMessage: 'No price data',
        plan: plan,
        states: states,
        evaluation: null,
      );
    }

    final value = units * price;

    PillEvaluationResult? evaluation;

    if (hasPlan) {
      final activePlan = plan!;
      final engine = _engine;
      if (engine != null) {
        evaluation = engine.evaluatePillState(
          currentPriceUsd: price,
          thresholdPlanSteps: activePlan.steps,
          persistedStepStates: states,
          stepIdPrefix: s,
        );
      }
    }

    return SymbolViewState(
      symbol: s,
      units: units,
      livePriceUsd: price,
      marketValueUsd: value,
      hasPlan: hasPlan,
      isArmed: isArmed,
      hasPrice: true,
      hasPosition: hasPosition,
      hasHistory: hasHistory,
      emptyStateMessage: null,
      plan: plan,
      states: states,
      evaluation: evaluation,
    );
  }

  Map<String, SymbolViewState> _buildSymbolViewStates(
      Iterable<String> symbols) {
    final out = <String, SymbolViewState>{};
    for (final symbol in symbols) {
      final s = symbol.toUpperCase();
      out[s] = _buildSymbolViewState(s);
    }
    return out;
  }

  void _refreshLatestViewStateForSymbol(String symbolUpper) {
    final s = symbolUpper.toUpperCase();
    final refreshed = _buildSymbolViewState(s);
    _latestViewStateBySymbol = {
      ..._latestViewStateBySymbol,
      s: refreshed,
    };
  }

  AssetRuntimeState _runtimeForSymbolSnapshot(
    String symbolUpper,
    AssetRuntimeState fallback,
  ) {
    final s = symbolUpper.toUpperCase();
    return _latestViewStateBySymbol[s]?.toRuntime() ?? fallback;
  }

  _SymbolVisualState _visualStateForEvaluation(PillEvaluationResult? eval) {
    if (eval == null) {
      return const _SymbolVisualState(
        badgeText: 'IDLE',
        badgeColor: Colors.grey,
        accentColor: Colors.grey,
        showExecuteAccent: false,
      );
    }

    switch (eval.pillState) {
      case PillState.action:
        final bool hasActiveStep =
            eval.activeStepId != null && eval.activeStepId!.trim().isNotEmpty;
        if (!hasActiveStep) {
          return const _SymbolVisualState(
            badgeText: 'IDLE',
            badgeColor: Colors.grey,
            accentColor: Colors.grey,
            showExecuteAccent: false,
          );
        }
        return const _SymbolVisualState(
          badgeText: 'EXECUTE',
          badgeColor: Color(0xFFD32F2F),
          accentColor: Color(0xFFD32F2F),
          showExecuteAccent: true,
        );
      case PillState.approaching:
        return const _SymbolVisualState(
          badgeText: 'TRACKING',
          badgeColor: Color(0xFFFFC107),
          accentColor: Color(0xFFFFC107),
          showExecuteAccent: false,
        );
      case PillState.complete:
        return const _SymbolVisualState(
          badgeText: 'COMPLETE',
          badgeColor: Color(0xFF00C853),
          accentColor: Color(0xFF00C853),
          showExecuteAccent: false,
        );
      case PillState.idle:
        return const _SymbolVisualState(
          badgeText: 'IDLE',
          badgeColor: Colors.grey,
          accentColor: Colors.grey,
          showExecuteAccent: false,
        );
    }
  }

  ThresholdPillDisplayState _thresholdPillDisplayState(
    AssetRuntimeState runtime,
  ) {
    return resolveThresholdPillDisplayState(
      evaluation: runtime.evaluation,
      stepStates: runtime.states,
    );
  }

  _SymbolVisualState _visualStateForRuntime(AssetRuntimeState runtime) {
    if (_thresholdPillDisplayState(runtime) ==
        ThresholdPillDisplayState.durableTriggered) {
      return const _SymbolVisualState(
        badgeText: 'TRIGGERED',
        badgeColor: Color(0xFFD32F2F),
        accentColor: Color(0xFFD32F2F),
        showExecuteAccent: false,
      );
    }

    return _visualStateForEvaluation(runtime.evaluation);
  }

  double _outlineOpacityForVisual(
    _SymbolVisualState visual, {
    required bool isExpanded,
    required bool isSelected,
  }) {
    if (visual.showExecuteAccent) {
      return isExpanded ? 0.70 : 0.55;
    }
    switch (visual.badgeText) {
      case 'TRACKING':
        return isExpanded ? 0.48 : 0.38;
      case 'COMPLETE':
        return isExpanded ? 0.20 : 0.14;
      case 'IDLE':
      default:
        if (isExpanded) return isSelected ? 0.34 : 0.28;
        return isSelected ? 0.22 : 0.16;
    }
  }

  double _outlineWidthForVisual(_SymbolVisualState visual) {
    switch (visual.badgeText) {
      case 'ARMED':
        return 1.6;
      case 'TRACKING':
        return 1.4;
      case 'COMPLETE':
      case 'IDLE':
      default:
        return 1.2;
    }
  }

  double _statusOpacityForVisual(_SymbolVisualState visual) {
    return visual.badgeText == 'COMPLETE' ? 0.4 : 1.0;
  }

  Color _badgeForegroundColorForVisual(_SymbolVisualState visual) {
    return visual.badgeColor.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;
  }

  String _pillStateLabel(PillState state) {
    switch (state) {
      case PillState.action:
        return 'EXECUTE';
      case PillState.approaching:
        return 'TRACKING';
      case PillState.complete:
        return 'COMPLETE';
      case PillState.idle:
        return 'IDLE';
    }
  }

  bool _hasAccentForVisual(_SymbolVisualState visual) {
    return visual.showExecuteAccent || visual.badgeText == 'TRACKING';
  }

  Color _tierRowFillForVisual(
    _SymbolVisualState visual, {
    required bool isActiveStep,
    required bool isDone,
  }) {
    if (!isActiveStep || isDone || !_hasAccentForVisual(visual)) {
      return Colors.transparent;
    }
    return visual.accentColor.withOpacity(
      visual.showExecuteAccent ? 0.20 : 0.16,
    );
  }

  Color _accentTextColorForVisual(
    _SymbolVisualState visual, {
    required bool isActiveStep,
    required bool isDone,
    required Color fallback,
  }) {
    if (!isActiveStep || isDone || !_hasAccentForVisual(visual)) {
      return fallback;
    }
    return visual.accentColor;
  }

  double _portfolioValueFromEngine() {
    final engine = _engine;
    if (engine == null) return 0.0;
    final prices = widget.livePricesUsd;
    return engine.computePortfolioValue(prices);
  }

  int? _openTierIndexFor(String symbolUpper) {
    final s = symbolUpper.toUpperCase();
    return _openTierIndexBySymbol[s];
  }

  void _setOpenTierIndexFor(String symbolUpper, int? value) {
    final s = symbolUpper.toUpperCase();
    _openTierIndexBySymbol[s] = value;
  }

  Future<void> _persistTierTriggerFor(
      String symbolUpper, int index, double price) async {
    // Universal tier doctrine: persist for ANY enabled symbol (AXL, PIXEL, etc.)
    final plan = _planFor(symbolUpper);
    if (index < 0 || index >= plan.steps.length) return;

    final updatedSteps = List<ThresholdStep>.from(plan.steps);
    final step = updatedSteps[index];
    if (step.triggerPriceUsd.toDouble() == price) return;
    updatedSteps[index] = ThresholdStep(
      triggerPriceUsd: price,
      action: step.action,
      percentOfPosition: step.percentOfPosition,
    );

    final updatedPlan = ThresholdPlan(
      assetSymbol: plan.assetSymbol,
      anchorPriceUsd: plan.anchorPriceUsd,
      steps: updatedSteps,
      seededFromLive: plan.seededFromLive,
    );

    if (!mounted) return;
    setState(() {
      _plansBySymbol[symbolUpper] = updatedPlan;
    });
    await saveThresholdPlan(updatedPlan, source: 'tier_commit');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _logoPathForSymbol(String symbol) {
    return 'assets/logos/${symbol.toLowerCase()}.png';
  }

  Widget _buildAssetLogo(String symbol, Color fg, Color bg) {
    const double avatarSize = 20;
    const double imageSize = 18;
    return CircleAvatar(
      radius: avatarSize / 2,
      backgroundColor: bg,
      child: ClipOval(
        child: SizedBox(
          width: imageSize,
          height: imageSize,
          child: Image.asset(
            _logoPathForSymbol(symbol),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.paid,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant OperatorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newValue = _initialBudgetValue();
    if ((newValue - _budgetValue).abs() > 0.01) {
      _budgetValue = newValue;
    }
    if (!identical(
      oldWidget.thresholdStepStatesBySymbol,
      widget.thresholdStepStatesBySymbol,
    )) {
      _applyExternalStepStates(widget.thresholdStepStatesBySymbol);
    }
    _optimisticArmedSymbols.removeWhere(widget.armedSymbols.contains);
  }

  Color _statusBaseColor(ThemeData theme, Color accentColor, String label) {
    switch (label) {
      case 'READY':
        return accentColor;
      case 'LOADING':
        return theme.colorScheme.secondary;
      case 'STALE':
        return theme.colorScheme.tertiary;
      case 'DEGRADED':
        return Colors.orange.shade700;
      case 'REFRESH':
        return const Color(0xFF7AA6FF);
      case 'OFFLINE':
        return theme.colorScheme.error;
      default:
        return theme.colorScheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSystemReady) {
      return const Scaffold(
        backgroundColor: _kNavyDeep,
        body: Center(
          child: Text(
            'Initializing system',
            style: TextStyle(color: _kTextStrong),
          ),
        ),
      );
    }

    final engine = _engine;
    if (engine == null) {
      return const Scaffold(
        backgroundColor: _kNavyDeep,
        body: Center(
          child: Text(
            'Initializing system',
            style: TextStyle(color: _kTextStrong),
          ),
        ),
      );
    }

    final shouldLogUiPriceKeys =
        kUiPriceKeyDebug && widget.livePricesUsd.isNotEmpty;
    if (shouldLogUiPriceKeys) {
      final now = DateTime.now();
      final canLog = _lastUiPriceKeysLogTs == null ||
          now.difference(_lastUiPriceKeysLogTs!).inSeconds >= 30;
      if (canLog) {
        _lastUiPriceKeysLogTs = now;
        debugPrint('PRICE_KEYS: ${widget.livePricesUsd.keys.join(", ")}');
      }
    }

    final theme = Theme.of(context);
    final Color accentColor = this.accentColor;
    final enabledUiSymbols = _uiEnabledSymbols();
    final symbolsForPills = _orderedEnabledSymbolsForPills()
        .where(enabledUiSymbols.contains)
        .toList(growable: false);
    final Map<String, SymbolViewState> viewStateBySymbol =
        _buildSymbolViewStates(symbolsForPills);
    _latestViewStateBySymbol = viewStateBySymbol;
    final Map<String, AssetRuntimeState> runtimeBySymbol = {
      for (final entry in viewStateBySymbol.entries)
        entry.key: entry.value.toRuntime(),
    };
    final discipline = engine.getDiscipline();
    final currentDiscipline = discipline.currentCycle;
    final lifetimeDiscipline = discipline.lifetime;
    final Color statusBaseColor =
        _statusBaseColor(theme, accentColor, widget.readyLabel);

    final budgetNumbers = _budgetNumbers();
    final alertsPreview = widget.alerts.isEmpty
        ? <AlertEvent>[]
        : (List<AlertEvent>.from(widget.alerts)
              ..sort((a, b) => b.timestamp.compareTo(a.timestamp)))
            .take(3)
            .toList();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0B1B55), // deep blue top
              Color(0xFF2B2C8F), // mid blue/purple
              Color(0xFF0A0F2C), // deep navy bottom
            ],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          // Kill default AppBar chrome (leading icons / spacing). We render our own command strip.
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            toolbarHeight: 0,
          ),
          body: Stack(
            children: [
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        PillState? missionRingState;
                        bool hasArmedSignal = false;

                        for (final runtime in runtimeBySymbol.values) {
                          final eval = runtime.evaluation;
                          if (eval == null) continue;

                          if (runtime.isArmed &&
                              (eval.pillState == PillState.action ||
                                  eval.pillState == PillState.approaching)) {
                            hasArmedSignal = true;
                            if (eval.pillState == PillState.action) {
                              missionRingState = PillState.action;
                              break;
                            }
                            missionRingState ??= PillState.approaching;
                          }

                          if (!hasArmedSignal &&
                              missionRingState == null &&
                              eval.pillState == PillState.complete) {
                            missionRingState = PillState.complete;
                          }
                        }

                        return SingleChildScrollView(
                          controller: _scrollController,
                          padding:
                              const EdgeInsets.fromLTRB(_s16, 10, _s16, _s16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Container(
                                  width: 220,
                                  height: 220,
                                  margin: const EdgeInsets.only(top: 16),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CustomPaint(
                                        size: const Size(220, 220),
                                        painter: _DisciplineRingPainter(
                                          currentCycle: currentDiscipline,
                                          lifetime: lifetimeDiscipline,
                                          state: missionRingState,
                                        ),
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white24,
                                            width: 4,
                                          ),
                                        ),
                                      ),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _fmtUsd(
                                                _portfolioValueFromEngine()),
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'DISCIPLINE: ${(currentDiscipline * 100).toStringAsFixed(0)}%',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // STEP 34.1 — global execute banner removed
                              // execution is now tier-driven only
                              // STEP 35.2 — Operator Console is evaluator-driven only
                              // No execution history or summary rendering
                              const SizedBox(height: 10),
                              // Command strip (embedded, full authority).
                              Row(
                                children: [
                                  Text(
                                    'OPERATOR CONSOLE',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: _kTextStrong,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.2,
                                        ),
                                  ),
                                  const Spacer(),
                                  Tooltip(
                                    message: widget.readyTooltip,
                                    child: Semantics(
                                      label: 'System status',
                                      value: widget.readyLabel,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Color.alphaBlend(
                                            statusBaseColor.withOpacity(
                                                widget.isReady ? 0.20 : 0.16),
                                            _kNavyTop,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: statusBaseColor.withOpacity(
                                                widget.isReady ? 0.90 : 0.75),
                                            width: 1.05,
                                          ),
                                        ),
                                        child: Text(
                                          widget.readyLabel,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
                                                color: _kTextStrong,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: -0.1,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Builder(
                                builder: (context) {
                                  final feedback =
                                      engine.getLastFeedback().trim();
                                  if (feedback.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.18),
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'LAST ACTION',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.0,
                                              color: Colors.white
                                                  .withOpacity(0.62),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            feedback,
                                            textAlign: TextAlign.left,
                                            softWrap: true,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              height: 1.18,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 10),
                              _buildControls(
                                context,
                                budgetNumbers,
                                enabledUiSymbols: enabledUiSymbols,
                                symbolsForPills: symbolsForPills,
                                runtimeBySymbol: runtimeBySymbol,
                              ),
                              const SizedBox(height: 12),
                              const SizedBox(height: 24),
                              _buildAdvanced(context),
                            ],
                          ),
                        );
                      },
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

  Widget _buildAssets({
    required BuildContext context,
    required Color accentColor,
    required TextStyle? headerStyle,
    required List<Widget> pillChildren,
    required _BudgetSnapshot budgetNumbers,
  }) {
    final hasDefinedHoldings = _hasDefinedHoldings();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_showLegacyControls) ...[
          Semantics(
            header: true,
            label: 'Controls',
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 22,
                  decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(width: _s8),
                Text('Controls', style: headerStyle),
              ],
            ),
          ),
          const SizedBox(height: _s12),
          BudgetHeroCard(
            accentColor: accentColor,
            budgetValue: _budgetValue,
            minBudget: _budgetMin,
            maxBudget: _budgetMax,
            onBudgetChanged: _updateBudget,
            onBudgetChangeEnd: _updateBudget,
          ),
          const SizedBox(height: _s12),
        ],
        // Thresholds section removed; summary lives in per-asset pill panels.
        const SizedBox(height: _s12),
        Semantics(
          header: true,
          label: 'Assets',
          child: Row(
            children: [
              Text(
                'ASSETS',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: _kTextStrong,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
              ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  _openHoldingsEditor();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                      accentColor.withOpacity(0.12),
                      _kNavyTop,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accentColor.withOpacity(0.28),
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    'HOLDINGS',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: _kTextStrong,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.9,
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _openAssetsEditSheet,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                      accentColor.withOpacity(0.10),
                      _kNavyTop,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accentColor.withOpacity(0.22),
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    'EDIT',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: _kTextStrong,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.9,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: _s8),
        if (!hasDefinedHoldings) ...[
          _buildInstructionBlock(
            title: 'No positions defined',
            subtitle: 'Set position size to begin',
            titleFontSize: 13,
            subtitleFontSize: 12,
          ),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: pillChildren,
        ),
        const SizedBox(height: _s12),
      ],
    );
  }

  Widget _buildControls(
    BuildContext context,
    _BudgetSnapshot budgetNumbers, {
    required Set<String> enabledUiSymbols,
    required List<String> symbolsForPills,
    required Map<String, AssetRuntimeState> runtimeBySymbol,
  }) {
    final theme = Theme.of(context);
    final headerStyle =
        theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);

    return LayoutBuilder(
      builder: (context, _) {
        final _runtimeBySymbol = runtimeBySymbol;
        for (final symbolUpper in symbolsForPills) {
          final runtime = _runtimeBySymbol[symbolUpper];
          if (runtime == null) continue;
          final bool isTierAsset = _tierAssets.contains(symbolUpper);
          final price = runtime.price > 0 ? runtime.price : null;
          if (isTierAsset) {
            final plan = runtime.plan;
            if (plan != null && price != null && price > 0) {
              _maybeLateReseedPlanFromLive(
                  symbolUpper: symbolUpper, livePriceUsd: price);
            }
          }
        }

        final entries = _runtimeBySymbol.entries
            .where((entry) => entry.value.evaluation != null)
            .map((entry) => MapEntry(entry.key, entry.value.evaluation!))
            .toList();
        if (entries.isNotEmpty) {
          // Priority: action > approaching
          entries.sort((a, b) {
            int rank(PillEvaluationResult e) {
              switch (e.pillState) {
                case PillState.action:
                  return 0;
                case PillState.approaching:
                  return 1;
                default:
                  return 2;
              }
            }

            final ra = rank(a.value);
            final rb = rank(b.value);

            if (ra != rb) return ra.compareTo(rb);

            final da = a.value.distanceToNextPercent ?? double.infinity;
            final db = b.value.distanceToNextPercent ?? double.infinity;

            return da.compareTo(db);
          });

          final top = entries.first;

          final candidate = top.key;

          final isPriority = top.value.pillState == PillState.action ||
              top.value.pillState == PillState.approaching;

          if (isPriority) {
            if (_primarySymbolSticky == null) {
              _primarySymbolSticky = candidate;
            }
          }
        }

        if (_primarySymbolSticky != null) {
          final currentEval =
              _runtimeBySymbol[_primarySymbolSticky!]?.evaluation;

          final stillValid = currentEval != null &&
              (currentEval.pillState == PillState.action ||
                  currentEval.pillState == PillState.approaching);

          if (!stillValid) {
            _primarySymbolSticky = null;
          }
        }

        final pillChildren = symbolsForPills.map((symbolUpper) {
          final bool isSelected =
              (_openAssetPanelSymbol?.toUpperCase() == symbolUpper);
          final Color mood = theme.colorScheme.primary;
          const Color pillSplash = Color(0xFF4DA3FF);
          const Color pillSubtext = _kTextSubtle;
          final runtime = _runtimeBySymbol[symbolUpper]!;
          // (R3-B) Pills are symbol-driven. Execution logic is evaluator-driven.
          // "Expanded" for pill visuals means: its operator modal is open (selected).
          final isExpandedAssetPanel = isSelected;

          final Widget pillSurface = _buildAssetPillMao(
            symbolUpper: symbolUpper,
            runtime: runtime,
            mood: mood,
            accentColor: accentColor,
            textColor: pillSubtext,
            isExpanded: isExpandedAssetPanel,
          );

          final Widget pillInteractive = Material(
            color: Colors.transparent,
            elevation: _kPillElevation,
            borderRadius: BorderRadius.circular(_kPillRadius),
            child: InkWell(
              borderRadius: BorderRadius.circular(_kPillRadius),
              splashFactory: InkSparkle.splashFactory,
              splashColor: pillSplash.withOpacity(0.06),
              highlightColor: pillSplash.withOpacity(0.03),
              onTap: () async {
                if (!enabledUiSymbols.contains(symbolUpper)) return;
                if (mounted) {
                  setState(() {
                    _openAssetPanelSymbol = symbolUpper;
                  });
                }
                await _openAssetPanelModal(
                  symbolUpper: symbolUpper,
                  runtime: runtime,
                  accentColor: accentColor,
                );
                if (mounted &&
                    _openAssetPanelSymbol?.toUpperCase() == symbolUpper) {
                  setState(() {
                    _openAssetPanelSymbol = null;
                  });
                }
              },
              child: pillSurface,
            ),
          );

          return Tooltip(
            message: 'Open controls',
            child: Semantics(
              button: true,
              toggled: isSelected,
              label: 'Asset $symbolUpper',
              value: isSelected ? 'Active' : 'Not active',
              hint: 'Open controls',
              child: pillInteractive,
            ),
          );
        }).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAssets(
              context: context,
              accentColor: accentColor,
              headerStyle: headerStyle,
              pillChildren: pillChildren,
              budgetNumbers: budgetNumbers,
            ),
            const SizedBox(height: 20),
            Divider(
              color: _kTextMuted.withOpacity(0.25),
              thickness: 1,
            ),
            const SizedBox(height: 10),
            const SizedBox.shrink(),
            const SizedBox(height: 40),
          ],
        );
      },
    );
  }

  Future<void> _openAssetPanelModal({
    required String symbolUpper,
    required AssetRuntimeState runtime,
    required Color accentColor,
  }) async {
    if (!mounted) return;
    final enabledUiSymbols = _uiEnabledSymbols();
    if (!enabledUiSymbols.contains(symbolUpper.toUpperCase())) return;
    final theme = Theme.of(context);
    // Live price for this symbol (null/<=0 means "unavailable").
    final double? priceUsd = runtime.price > 0 ? runtime.price : null;
    AssetRuntimeState armPinnedRuntime = runtime;
    bool consumeArmPinnedRuntime = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) {
        // OPTIONAL ASSET RULE (A):
        // If live data is unavailable, show informational modal only.
        if (priceUsd == null || priceUsd <= 0) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: const BoxDecoration(
              color: _kNavyDeep,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  symbolUpper,
                  style: const TextStyle(
                    color: _kTextStrong,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  runtime.emptyStateMessage ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: _kTextMuted,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        }

        // IMPORTANT: Modal is its own route. OperatorScreen setState() does not
        // automatically rebuild the modal contents. Use a local StatefulBuilder
        // and "ping" it after mutations so tiers feel operational.
        return StatefulBuilder(
          builder: (ctx, modalSetState) {
            final useArmPinnedRuntime = consumeArmPinnedRuntime;
            final liveRuntime = useArmPinnedRuntime
                ? armPinnedRuntime
                : _runtimeForSymbolSnapshot(symbolUpper, runtime);
            if (useArmPinnedRuntime) {
              consumeArmPinnedRuntime = false;
            }
            final panel = _buildExpandedPanelForSymbol(
              symbolUpper: symbolUpper,
              accentColor: accentColor,
              mood: theme.colorScheme.primary,
              textColor: _kTextSubtle,
              runtime: liveRuntime,
              expanded: true,
              modalSetState: modalSetState,
              pinRuntimeForArmRepaint: () {
                armPinnedRuntime = liveRuntime;
                consumeArmPinnedRuntime = true;
              },
            );
            if (panel == null) return const SizedBox.shrink();

            return DraggableScrollableSheet(
              initialChildSize: 1.0,
              minChildSize: 1.0,
              maxChildSize: 1.0,
              builder: (_, controller) {
                final modalTheme = Theme.of(ctx);
                final modalBg = Color.alphaBlend(
                  accentColor.withOpacity(0.020),
                  _kNavyDeep,
                );
                return Material(
                  type: MaterialType.transparency,
                  child: SafeArea(
                    child: Container(
                      color: modalBg,
                      child: ListView(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                        children: [
                          // Top chrome: heavy / controlled / command feel.
                          Center(
                            child: Container(
                              width: 52,
                              height: 5,
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: _kTextMuted.withOpacity(0.45),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$symbolUpper OPERATIONS',
                                  style: modalTheme.textTheme.titleMedium
                                      ?.copyWith(
                                    color: _kTextStrong,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Exit',
                                onPressed: () => Navigator.of(ctx).pop(),
                                icon: const Icon(Icons.close_rounded),
                                color: _kTextStrong,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          panel,
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAssetPillMao({
    required String symbolUpper,
    required AssetRuntimeState runtime,
    required Color mood,
    required Color accentColor,
    required Color textColor,
    required bool isExpanded,
  }) {
    final double resolvedPriceUsd = runtime.price;

    // OPTIONAL ASSET RULE (LOCKED):
    // If the live price is missing/invalid, render as an "Unavailable" watchlist slot.
    if (resolvedPriceUsd <= 0) {
      return _buildUnavailableAssetPill(
        symbolUpper: symbolUpper,
        accentColor: accentColor,
        textColor: textColor,
        message: runtime.emptyStateMessage ?? '',
      );
    }

    // PRICE DISPLAY (LOCKED): missing/invalid prices must never render as $0.00.
    final String priceLabel = _usdOrDash(resolvedPriceUsd);
    const Color pillSteel = Color(0xFF5B6B7A);
    const Color pillMuted = _kTextMuted;

    final assetName = AssetRegistry.bySymbol(symbolUpper)?.name ?? symbolUpper;
    final String? coingeckoId = _universalCatalog[symbolUpper] ??
        _universalCatalog[symbolUpper.toLowerCase()];
    final bool isTierAsset = _tierAssets.contains(symbolUpper);
    final bool isSelected =
        (_openAssetPanelSymbol?.toUpperCase() == symbolUpper);
    final visual = isExpanded
        ? _visualStateForEvaluation(runtime.evaluation)
        : _visualStateForRuntime(runtime);

    final Color iconBg = isSelected
        ? accentColor.withOpacity(0.14)
        : pillSteel.withOpacity(0.20);

    final bool hasValue = runtime.value > 0;
    final bool hasUnits = runtime.units > 0;
    final String unitsLabel = hasUnits
        ? '${runtime.units >= 1 ? runtime.units.toStringAsFixed(4) : runtime.units.toStringAsFixed(8)} $symbolUpper'
        : '';
    final String holdingLabel =
        hasValue ? '\$${runtime.value.toStringAsFixed(2)}' : 'No position';
    final double statusOpacity = _statusOpacityForVisual(visual);
    // NOTE: UI below should mirror BTC pill hierarchy:
    // Title row (symbol + optional price + chip), then holdings, then next line when collapsed.

    return Opacity(
      opacity: 0.85,
      child: Container(
        constraints: const BoxConstraints(minHeight: 60.0),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: _opsSurfaceDecoration(
          accentColor: accentColor,
          isSelected: isSelected,
          visual: visual,
          radius: _kPillRadius,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAssetLogo(symbolUpper, mood, iconBg),
            const SizedBox(width: _s12),
            Flexible(
              fit: FlexFit.loose,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              symbolUpper,
                              style: _tTitle.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: _kTextStrong,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(width: _s8),
                            Expanded(
                              child: Text(
                                priceLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _tValue.copyWith(
                                  fontSize: 13,
                                  color: _kTextBody,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    assetName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _tLabel.copyWith(
                      color: _kTextSubtle,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                  if (!isTierAsset &&
                      coingeckoId != null &&
                      coingeckoId.isNotEmpty)
                    Text(
                      'ID: $coingeckoId',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _tLabel.copyWith(
                        color: _kTextMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Text(
                    holdingLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _tLabel.copyWith(
                      color: hasValue ? textColor : pillMuted,
                      fontSize: 11,
                    ),
                  ),
                  if (hasUnits)
                    Text(
                      unitsLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _tLabel.copyWith(
                        color: _kTextSubtle,
                        fontSize: 11,
                      ),
                    ),
                  if (!isExpanded) ...[
                    const SizedBox(height: 4),
                    Opacity(
                      opacity: statusOpacity,
                      child: _buildAssetStateText(
                        runtime: runtime,
                        includeDurableTriggeredDisplay: true,
                        style: _tValue.copyWith(
                          fontWeight: FontWeight.w900,
                          color: _kTextStrong.withOpacity(0.85),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnavailableAssetPill({
    required String symbolUpper,
    required Color accentColor,
    required Color textColor,
    required String message,
  }) {
    final String? coingeckoId = _universalCatalog[symbolUpper] ??
        _universalCatalog[symbolUpper.toLowerCase()];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Color.alphaBlend(accentColor.withOpacity(0.03), _kNavyBase),
        borderRadius: BorderRadius.circular(_kPillRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$symbolUpper  —',
                  style: TextStyle(
                    color: _kTextStrong.withOpacity(0.75),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              Text(
                'UNAVAILABLE',
                style: TextStyle(
                  color: textColor.withOpacity(0.65),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          if (coingeckoId != null && coingeckoId.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'ID: $coingeckoId',
              style: TextStyle(
                color: textColor.withOpacity(0.68),
                fontWeight: FontWeight.w600,
                fontSize: 11,
                letterSpacing: 0.2,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            message,
            style: TextStyle(
              fontSize: 12,
              color: _kTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  /// Extracted from the inline local builder so we can reuse it inside
  /// the full-screen Operator Panel route without changing functionality.
  Widget? _buildExpandedPanelForSymbol({
    required String symbolUpper,
    required Color accentColor,
    required Color mood,
    required Color textColor,
    required AssetRuntimeState runtime,
    required bool expanded,
    void Function(void Function())? modalSetState,
    VoidCallback? pinRuntimeForArmRepaint,
  }) {
    if (!expanded) return null;

    final theme = Theme.of(context);
    final effectiveEval = runtime.evaluation;
    final visual = _visualStateForEvaluation(effectiveEval);
    final panelAccent = visual.accentColor;
    // Expanded layer (A): industrial-clean, single surface, no nested card stack.
    final Color panelBaseSurface = Color.alphaBlend(
      accentColor.withOpacity(0.018),
      _kNavyDeep,
    );
    final Color panelGroupSurface = Color.alphaBlend(
      accentColor.withOpacity(0.040),
      _kNavySelected,
    );
    const Color panelTextStrong = _kTextStrong;
    const Color panelTextMedium = _kTextSubtle;
    const Color panelTextDisabled = _kTextMuted;

    void bumpModal(VoidCallback mutate) {
      if (!mounted) return;
      setState(mutate);
      // Repaint the modal route (separate from OperatorScreen rebuild).
      if (modalSetState != null) modalSetState(() {});
    }

    final isArmedForSymbol = _isExecutionArmedFor(symbolUpper);
    final livePriceUsd = runtime.hasPrice ? runtime.price : null;
    final mv = runtime.value > 0 ? runtime.value : null;
    final ThresholdPlan? planForSymbol = runtime.plan;
    final planSteps = planForSymbol?.steps ?? const <ThresholdStep>[];
    final states = runtime.states;
    final hasPlanForSymbol = runtime.hasPlan;
    List<Widget> buildTierRows() {
      return List<Widget>.generate(planSteps.length, (i) {
        final step = planSteps[i];
        final displayTierNumber = i + 1;
        final stepId = '$symbolUpper:$i';
        final stepState = states[stepId];
        final status = stepState?.status ?? ThresholdStepStatus.pending;
        final isExecuted = status == ThresholdStepStatus.executed;
        final isMissed = status == ThresholdStepStatus.dismissed;
        final isDone = isExecuted || isMissed;

        final action = step.action.toString().toUpperCase();
        final trigger = step.triggerPriceUsd.toDouble();
        final live = livePriceUsd;
        final base = (live != null && live > 0) ? live : trigger;
        final trigLabel = '\$${_formatTierPrice(trigger)}';

        final pct = step.percentOfPosition.toDouble();
        double? estUsd;
        if (pct > 0 && action.contains('SELL') && mv != null) {
          estUsd = mv * (pct / 100.0);
        }

        final left = 'Tier $displayTierNumber — $action at $trigLabel';
        final mid = estUsd != null ? ' • ~${_fmtUsd(estUsd)}' : '';
        final right = 'Trigger $trigLabel$mid';

        // Mode affects slider sensitivity only (existing behavior preserved).
        const int divisions = 1200;

        final isOpen = _openTierIndexFor(symbolUpper) == i;
        final tierDraftForSymbol = _tierDraftFor(symbolUpper);
        final double draft = (tierDraftForSymbol[i] ?? trigger).toDouble();
        final double minPrice =
            (base * 0.50).clamp(0.0, double.infinity).toDouble();
        final double maxPrice = base * 1.50;
        final double safeMin = minPrice <= maxPrice ? minPrice : maxPrice;
        double safeMax = maxPrice >= minPrice ? maxPrice : minPrice;
        if ((safeMax - safeMin).abs() < 1e-9) {
          safeMax = safeMin + (safeMin.abs() * 0.01 + 0.000001);
        }
        final double safeValue = draft.clamp(safeMin, safeMax).toDouble();
        final bool isActiveStep = stepId == effectiveEval?.activeStepId;
        final PillEvaluationResult? rowEval =
            isActiveStep ? effectiveEval : null;
        final bool isActionState = effectiveEval?.pillState == PillState.action;
        final bool hasRequiredPosition =
            !action.contains('SELL') || runtime.hasPosition;
        final tierRowState = evaluateThresholdTierRowState(
          state: stepState,
          isArmed: isArmedForSymbol,
          isActiveStep: isActiveStep,
          isActionState: isActionState,
          hasPlan: hasPlanForSymbol,
          hasPrice: runtime.hasPrice,
          hasRequiredPosition: hasRequiredPosition,
        );
        final labelText = tierRowState.labelText;
        final isTriggered =
            tierRowState.displayState == ThresholdTierRowDisplayState.triggered;
        final rowVisual = _visualStateForEvaluation(rowEval);
        final bgColor = _tierRowFillForVisual(
          rowVisual,
          isActiveStep: isActiveStep,
          isDone: isDone,
        );
        final bool canExecuteTier = tierRowState.canExecute;
        final executeAccentColor = rowVisual.showExecuteAccent
            ? rowVisual.accentColor
            : const Color(0xFF00E676);
        final observedForMissed = _priceUsdOrNull(symbolUpper);
        final bool rowMarkMissedState =
            tierRowState.canMarkMissed && observedForMissed != null &&
                observedForMissed > 0;

        return Opacity(
          opacity: isExecuted
              ? 0.55
              : isMissed
                  ? 0.35
                  : 1.0,
          child: Container(
            margin: EdgeInsets.only(
              bottom: i == planSteps.length - 1 ? 0 : 10,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                bumpModal(() {
                  _setOpenTierIndexFor(symbolUpper, isOpen ? null : i);
                });
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isExecuted) ...[
                          Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: const Color(0xFF00E676),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (isMissed) ...[
                          Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: const Color(0xFFFF5252),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            left,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: isExecuted
                                  ? panelTextDisabled
                                  : panelTextStrong,
                              decoration: isExecuted
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              decorationThickness: 2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (labelText != null)
                          Text(
                            labelText,
                            style: TextStyle(
                              color: isExecuted
                                  ? const Color(0xFF00E676)
                                  : isMissed
                                      ? const Color(0xFFFF5252)
                                      : isTriggered
                                          ? const Color(0xFFFFC107)
                                          : panelTextStrong,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            right,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: isExecuted
                                  ? panelTextDisabled
                                  : panelTextStrong,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: _s8),
                        Icon(
                          isOpen ? Icons.expand_less : Icons.expand_more,
                          color: panelTextMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      color: bgColor,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Trigger \$${_formatTierPrice(step.triggerPriceUsd.toDouble())}',
                              style: const TextStyle(
                                color: _kTextStrong,
                              ),
                            ),
                          ),
                          if (canExecuteTier)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () async {
                                if (!canExecuteTier) return;
                                final engine = _engine;
                                if (engine == null || planForSymbol == null) {
                                  return;
                                }
                                final activeStepId =
                                    effectiveEval?.activeStepId;
                                if (activeStepId == null) return;
                                final didExecute =
                                    await engine.confirmExecution(
                                  symbolUpper: symbolUpper,
                                  plan: planForSymbol,
                                  tierIndex: i,
                                  activeStepId: activeStepId,
                                  observedPriceUsd:
                                      _priceUsdOrNull(symbolUpper),
                                );
                                if (!didExecute) return;
                                await _reloadStepStatesFor(symbolUpper);
                                _refreshLatestViewStateForSymbol(symbolUpper);
                                bumpModal(() {});
                                if (!mounted) return;
                                final messenger = ScaffoldMessenger.of(context);
                                messenger.hideCurrentSnackBar();
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Action executed'),
                                    duration: Duration(milliseconds: 600),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isMissed
                                        ? const Color(0xFFFF5252)
                                        : executeAccentColor,
                                    width: 1.2,
                                  ),
                                ),
                                child: Text(
                                  'EXECUTE',
                                  style: TextStyle(
                                    color: isMissed
                                        ? const Color(0xFFFF5252)
                                        : executeAccentColor,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isOpen) ...[
                      const SizedBox(height: _s12),
                      Text(
                        tierRowState.helperText,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: panelTextStrong,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (rowMarkMissedState) ...[
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () async {
                            if (isExecuted || isMissed) return;
                            if (!isArmedForSymbol) return;
                            final engine = _engine;
                            final plan = planForSymbol;
                            final observed = _priceUsdOrNull(symbolUpper);
                            if (engine == null ||
                                plan == null ||
                                observed == null ||
                                observed <= 0) {
                              return;
                            }
                            final activeStepId = stepId;

                            final didMarkMissed =
                                await engine.recordMissedExecution(
                              symbolUpper: symbolUpper,
                              plan: plan,
                              tierIndex: i,
                              activeStepId: activeStepId,
                              observedPriceUsd: observed,
                            );
                            if (!didMarkMissed) return;

                            await _reloadStepStatesFor(symbolUpper);
                            _refreshLatestViewStateForSymbol(symbolUpper);
                            bumpModal(() {});
                            if (!mounted) return;
                            final messenger = ScaffoldMessenger.of(context);
                            messenger.hideCurrentSnackBar();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Action marked missed'),
                                duration: Duration(milliseconds: 600),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFFF5252),
                                width: 1.2,
                              ),
                            ),
                            child: const Text(
                              'MARK MISSED',
                              style: TextStyle(
                                color: Color(0xFFFF5252),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      // STEP 33.1 — REMOVE proximity clamp (±12%)
                      // slider now operates on absolute price space
                      Slider(
                        value: safeValue,
                        min: safeMin,
                        max: safeMax,
                        divisions: divisions,
                        onChanged: isExecuted
                            ? null
                            : (v) {
                                updateTierPrice(symbolUpper, i, v);
                                if (modalSetState != null) {
                                  modalSetState(() {});
                                }
                              },
                        onChangeEnd: isExecuted
                            ? null
                            : (v) async {
                                await _persistTierTriggerFor(symbolUpper, i, v);
                                _refreshLatestViewStateForSymbol(symbolUpper);
                                if (!mounted) return;
                                bumpModal(
                                    () => updateTierPrice(symbolUpper, i, v));
                              },
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current: \$${_formatTierPrice(trigger)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: panelTextMedium,
                            ),
                          ),
                          if (live != null && live > 0) ...[
                            const SizedBox(height: 2),
                            (() {
                              final deltaPct = ((trigger - live).abs() / live);

                              return Text(
                                'Δ: ${(deltaPct * 100).toStringAsFixed(1)}% from live',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                  color: _accentTextColorForVisual(
                                    rowVisual,
                                    isActiveStep: isActiveStep,
                                    isDone: isDone,
                                    fallback: panelTextMedium.withOpacity(0.92),
                                  ),
                                ),
                              );
                            })(),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      });
    }

    final panelBody = Container(
      margin: const EdgeInsets.only(top: 10, bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: panelBaseSurface,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            color: panelAccent.withOpacity(0.35),
            thickness: 1,
            height: 1,
          ),
          const SizedBox(height: 18),
          Text(
            'Execution MODE',
            style: theme.textTheme.titleSmall?.copyWith(
              color: _kTextSubtle,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 14),

          // State line only. Mission Control owns guidance.
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Opacity(
              opacity: _statusOpacityForVisual(visual),
              child: _buildAssetStateText(
                runtime: runtime,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: panelTextStrong,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),

          // TIERS (expanded panel) — only for tier-enabled assets (controlled).
          if (_tierAssets.contains(symbolUpper)) ...[
            const SizedBox(height: _s8),
            Text(
              'TIERS',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 0.25,
                color: panelTextStrong,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: panelGroupSurface,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: panelAccent.withOpacity(0.22), width: 1),
              ),
              child: !hasPlanForSymbol
                  ? const Text(
                      'No plan defined',
                      style: TextStyle(
                        color: panelTextMedium,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: buildTierRows(),
                    ),
            ),
            if (hasPlanForSymbol) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  await _resetCycle(symbolUpper);
                  _refreshLatestViewStateForSymbol(symbolUpper);
                  bumpModal(() {});
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF00E676),
                      width: 1.2,
                    ),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'NEW CYCLE',
                          style: TextStyle(
                            color: Color(0xFF00E676),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'reset all tiers',
                          style: TextStyle(
                            fontSize: 10,
                            color: _kTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (hasPlanForSymbol && !isArmedForSymbol) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final s = symbolUpper.toUpperCase();
                  pinRuntimeForArmRepaint?.call();
                  widget.onArmChanged(s, true);
                  if (mounted) {
                    setState(() {
                      _optimisticArmedSymbols.add(s);
                    });
                  }
                  bumpModal(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF00E676),
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ARM',
                          style: TextStyle(
                            color: Color(0xFF00E676),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'activate execution',
                          style: TextStyle(
                            fontSize: 10,
                            color: _kTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );

    return panelBody;
  }

  Widget _buildAdvanced(BuildContext context) {
    return ExpansionTile(
      title: const Text('Advanced'),
      initiallyExpanded: false,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed:
                widget.reportPretty.isEmpty ? null : widget.onExportReport,
            child: const Text('Export Summary'),
          ),
        ),
        if (widget.copyStatus.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(widget.copyStatus),
        ],
      ],
    );
  }

  // R7: Ensure dynamic symbol->CoinGecko-id mappings are visible before forcing
  // an immediate poll restart after exiting Manage Assets.
  Future<void> _ensureEnabledMappingsVisible(Set<String> enabled) async {
    final targets = enabled.map((e) => e.toUpperCase()).toSet();

    bool hasId(String symUpper) {
      return _universalCatalog.containsKey(symUpper) ||
          _universalCatalog.containsKey(symUpper.toLowerCase());
    }

    List<String> missingNow() {
      final miss = <String>[];
      for (final s in targets) {
        if (!hasId(s)) miss.add(s);
      }
      miss.sort();
      return miss;
    }

    // Fast path: already visible.
    var miss = missingNow();
    if (miss.isEmpty) return;

    // Slow path: bounded retries (covers SharedPreferences "apply visibility" window).
    const maxTries = 5;
    for (var i = 0; i < maxTries && miss.isNotEmpty; i++) {
      // small backoff: 100ms, 150ms, 200ms, 250ms, 300ms (total <= 1s)
      final delayMs = 100 + (i * 50);
      await Future<void>.delayed(Duration(milliseconds: delayMs));
      await _reloadUniversalPrefs();
      miss = missingNow();
    }
  }

  Future<void> _openAssetsEditSheet() async {
    // Pass the authoritative enabled set into the universal screen
    // (NOT the legacy registry-only visible set).
    final beforeEnabled = Set<String>.from(_universalEnabledSymbols);
    final enabledSymbols = Set<String>.from(_universalEnabledSymbols);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ManageAssetsUniversalScreen(
          enabledSymbols: enabledSymbols,
          onToggle: (symbolUpper, enabled) async {
            // Do NOT let legacy persistence override the universal store.
            // Universal screen already persisted asset_enabled_v1.
            final s = symbolUpper.toUpperCase();
            setState(() {
              if (enabled) {
                _universalEnabledSymbols.add(s);
              } else {
                _universalEnabledSymbols.remove(s);
              }
            });
            if (enabled) {
              await _refreshHoldingsFromEngine();
            }
            if (!enabled) {
              if (!mounted) return;
              setState(() {
                _purgeInvalidSymbols(_uiEnabledSymbols());
              });
            }
          },
        ),
      ),
    );

    // Reload from authoritative store after returning.
    await _reloadUniversalPrefs();
    final afterEnabled = Set<String>.from(_universalEnabledSymbols);
    if (widget.onAssetsChanged != null) {
      final now = DateTime.now();
      final last = _lastAssetsChangedRestartTs;
      const cooldown = Duration(seconds: 10);
      final shouldNotify = shouldNotifyAssetChange(
        beforeEnabled: beforeEnabled,
        afterEnabled: afterEnabled,
        now: now,
        lastNotifiedAt: last,
        cooldown: cooldown,
      );
      if (shouldNotify) {
        // Ensure any newly-added dynamic asset mappings (symbol -> CoinGecko id)
        // written during Manage Assets are loaded into memory BEFORE we trigger
        // a poll restart (prevents first-exit "missing symbol" behavior).
        await _reloadUniversalPrefs();

        // R7: if mappings are still not visible yet, retry briefly until they are.
        await _ensureEnabledMappingsVisible(afterEnabled);

        _lastAssetsChangedRestartTs = now;
        await widget.onAssetsChanged!();
      }
    }
  }

  // NOTE (LOCKED): Asset management is single-path via _openAssetsEditSheet()
  // (universal screen: search + toggle + inline CoinGecko).

  Set<String> _enabledSymbolSet() {
    return _uiEnabledSymbols();
  }

  String _modeLabelFromProfile(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('conservative')) return 'Chill';
    if (lower.contains('aggressive')) return 'YOLO';
    return 'Balanced';
  }

  Color get accentColor {
    final mode =
        _modeLabelFromProfile(widget.selectedProfile.name).toLowerCase();
    if (mode.contains('yolo') || mode.contains('aggress'))
      return const Color(0xFFD6455D);
    if (mode.contains('conserv') || mode.contains('chill'))
      return const Color(0xFF2F6FE4);
    if (mode.contains('balanced')) return const Color(0xFF2FBF71);
    return Theme.of(context).colorScheme.primary;
  }

  Color get accentSoft {
    final mode =
        _modeLabelFromProfile(widget.selectedProfile.name).toLowerCase();
    if (mode.contains('yolo') || mode.contains('aggress'))
      return const Color(0xFFFFE3E8);
    if (mode.contains('conserv') || mode.contains('chill'))
      return accentColor.withOpacity(0.18);
    if (mode.contains('balanced')) return accentColor.withOpacity(0.18);
    return accentColor.withOpacity(0.14);
  }

  double _initialBudgetValue() {
    final limit = _budgetNumbers().limit;
    if (limit != null) {
      return limit.clamp(_budgetMin, _budgetMax);
    }
    return 500;
  }

  _BudgetSnapshot _budgetNumbers() {
    final budget = _currentBudget();
    if (budget != null) {
      return _BudgetSnapshot(
        limit: budget.monthlyLimit,
        spent: budget.spentThisMonth,
        remaining: budget.remaining,
      );
    }
    final matchLimit =
        RegExp(r'limit=\$([0-9.,]+)').firstMatch(widget.budgetSummary);
    final matchSpent =
        RegExp(r'spent=\$([0-9.,]+)').firstMatch(widget.budgetSummary);
    final matchRem =
        RegExp(r'remaining=\$([0-9.,]+)').firstMatch(widget.budgetSummary);
    return _BudgetSnapshot(
      limit: _asDouble(matchLimit?.group(1)),
      spent: _asDouble(matchSpent?.group(1)),
      remaining: _asDouble(matchRem?.group(1)),
    );
  }

  void _updateBudget(double value) {
    final state = _findAppShellState();
    final current = _currentBudget();
    final now = DateTime.now();
    final month = current?.month ?? DateTime(now.year, now.month, 1);
    final updated = MonthlyBudget(
      monthlyLimit: value,
      spentThisMonth: current?.spentThisMonth ?? 0,
      month: DateTime(month.year, month.month, 1),
    );

    if (state != null) {
      try {
        final dynamic dynState = state;
        dynState.engine.setMonthlyBudget(updated);
        dynState.setState(() {
          dynState.budget = updated;
        });
      } catch (_) {
        // If shape changes, engine will sync on next poll.
      }
    }

    setState(() {
      _budgetValue = value;
    });
  }

  MonthlyBudget? _currentBudget() {
    final state = _findAppShellState();
    if (state == null) return null;
    try {
      return (state as dynamic).budget as MonthlyBudget?;
    } catch (_) {
      return null;
    }
  }

  double? _asDouble(String? input) {
    if (input == null) return null;
    return double.tryParse(input.replaceAll(',', ''));
  }

  BattleBuddyEngine? get _engine {
    final state = _findAppShellState();
    if (state == null) return null;
    try {
      return (state as dynamic).engine as BattleBuddyEngine;
    } catch (_) {
      return null;
    }
  }

  double? _priceFor(String symbol) {
    return _priceUsdOrNull(symbol);
  }

  String _fmtUsd(double? v) {
    if (v == null || v <= 0) {
      return '—';
    }
    final formatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    return formatter.format(v);
  }

  String _formatTierPrice(double price) {
    if (price >= 1000) return price.toStringAsFixed(0);
    if (price >= 1) return price.toStringAsFixed(2);
    if (price >= 0.01) return price.toStringAsFixed(4);
    return price.toStringAsFixed(6);
  }

  String _formatHoldingInput(double value) {
    if (value == 0) return '0';
    final fixed = value.toStringAsFixed(value >= 1 ? 4 : 8);
    return fixed
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  Future<void> _openHoldingsEditor() async {
    final engine = _engine;
    if (engine == null) return;

    final symbols = _enabledSymbolSet().toList()..sort();
    final controllers = <String, TextEditingController>{};
    for (final sym in symbols) {
      final symbol = sym.toUpperCase();
      final initial = (engine.holdings[symbol] ?? 0.0).toDouble();
      controllers[symbol] =
          TextEditingController(text: _formatHoldingInput(initial));
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: _s16,
            right: _s16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + _s12,
            top: _s16,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Holdings',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'Stored locally on this device',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                        ),
                  ),
                  const SizedBox(height: _s12),
                  ...symbols.map((sym) {
                    final symbol = sym.toUpperCase();
                    final controller = controllers[symbol]!;
                    final iconText = _assetFromSymbol(symbol)?.iconText ??
                        (symbol.isNotEmpty ? symbol.substring(0, 1) : '?');
                    final price = _priceFor(symbol);
                    final hasPrice = price != null && price > 0;
                    final parsed = double.tryParse(controller.text) ?? 0.0;
                    final mv = hasPrice ? parsed * price : 0.0;
                    final usdText =
                        hasPrice ? '~ \$${mv.toStringAsFixed(0)}' : '—';
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceVariant
                            .withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(iconText,
                                style: TextStyle(
                                    color: accentColor,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: _s12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(symbol,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              Text(
                                usdText,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.65)),
                              ),
                            ],
                          ),
                          const Spacer(),
                          SizedBox(
                            width: 140,
                            child: TextField(
                              controller: controller,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true, signed: false),
                              decoration: const InputDecoration(
                                labelText: 'Units',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => setModalState(() {}),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]')),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: _s12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: _s12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            for (final entry in controllers.entries) {
                              final sym = entry.key;
                              final parsed =
                                  double.tryParse(entry.value.text.trim()) ??
                                      0.0;
                              final clean = parsed < 0 ? 0.0 : parsed;
                              final rounded =
                                  double.parse(clean.toStringAsFixed(8));
                              await engine.setHolding(sym, rounded);
                            }
                            await engine.loadHoldings();
                            if (mounted) {
                              setState(() {});
                            }
                            if (!ctx.mounted) return;
                            Navigator.of(ctx).pop();
                          },
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    // After closing holdings editor, reload persisted holdings for a clean UI state.
    await _refreshHoldingsFromEngine();
  }

  State<StatefulWidget>? _findAppShellState() {
    State<StatefulWidget>? result;
    context.visitAncestorElements((element) {
      if (element is StatefulElement) {
        final state = element.state;
        try {
          if ((state as dynamic).engine != null) {
            result = state;
            return false;
          }
        } catch (_) {}
      }
      return true;
    });
    return result;
  }
}

class _BudgetSnapshot {
  final double? limit;
  final double? spent;
  final double? remaining;

  const _BudgetSnapshot({
    required this.limit,
    required this.spent,
    required this.remaining,
  });
}

class _DisciplineRingPainter extends CustomPainter {
  final double currentCycle;
  final double lifetime;
  final PillState? state;

  _DisciplineRingPainter({
    required this.currentCycle,
    required this.lifetime,
    required this.state,
  });

  Color _colorForState(PillState? state) {
    switch (state) {
      case PillState.action:
        return const Color(0xFFD32F2F); // red
      case PillState.approaching:
        return const Color(0xFFFFC107); // amber
      case PillState.complete:
        return const Color(0xFF00C853); // green
      default:
        return const Color(0xFF6B7280); // fallback
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    const double pi = 3.1415926535;
    const double strokeWidth = 5.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final outerRadius = (size.shortestSide / 2) - strokeWidth;
    final innerRadius = outerRadius - 9.0;
    final outerRect = Rect.fromCircle(center: center, radius: outerRadius);
    final innerRect = Rect.fromCircle(center: center, radius: innerRadius);

    final paintBg = Paint()
      ..color = const Color(0x24FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final paintCycle = Paint()
      ..color = _colorForState(state)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final paintLifetime = Paint()
      ..color = const Color(0x99FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      outerRect,
      -pi / 2,
      2 * pi,
      false,
      paintBg,
    );

    canvas.drawArc(
      innerRect,
      -pi / 2,
      2 * pi,
      false,
      paintBg,
    );

    canvas.drawArc(
      outerRect,
      -pi / 2,
      2 * pi * currentCycle.clamp(0.0, 1.0),
      false,
      paintCycle,
    );

    canvas.drawArc(
      innerRect,
      -pi / 2,
      2 * pi * lifetime.clamp(0.0, 1.0),
      false,
      paintLifetime,
    );
  }

  @override
  bool shouldRepaint(covariant _DisciplineRingPainter oldDelegate) {
    return oldDelegate.currentCycle != currentCycle ||
        oldDelegate.lifetime != lifetime ||
        oldDelegate.state != state;
  }
}
