import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThresholdStep {
  final double triggerPriceUsd;
  final String action;
  final int percentOfPosition;

  const ThresholdStep({
    required this.triggerPriceUsd,
    required this.action,
    required this.percentOfPosition,
  });

  Map<String, dynamic> toJson() => {
        'triggerPriceUsd': triggerPriceUsd,
        'action': action,
        'percentOfPosition': percentOfPosition,
      };

  factory ThresholdStep.fromJson(Map<String, dynamic> json) {
    return ThresholdStep(
      triggerPriceUsd: (json['triggerPriceUsd'] as num).toDouble(),
      action: json['action'] as String,
      percentOfPosition: (json['percentOfPosition'] as num).toInt(),
    );
  }
}

class ThresholdPlan {
  final String assetSymbol;
  final double anchorPriceUsd;
  final List<ThresholdStep> steps;
  final bool seededFromLive;

  const ThresholdPlan({
    required this.assetSymbol,
    required this.anchorPriceUsd,
    required this.steps,
    this.seededFromLive = false,
  });

  Map<String, dynamic> toJson() => {
        'assetSymbol': assetSymbol,
        'anchorPriceUsd': anchorPriceUsd,
        'steps': steps.map((s) => s.toJson()).toList(),
        'seededFromLive': seededFromLive,
      };

  factory ThresholdPlan.fromJson(Map<String, dynamic> json) {
    final stepsList = (json['steps'] as List?) ?? const [];
    final steps = stepsList
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .map(ThresholdStep.fromJson)
        .toList();

    return ThresholdPlan(
      assetSymbol: json['assetSymbol'] as String,
      anchorPriceUsd: (json['anchorPriceUsd'] as num).toDouble(),
      steps: steps,
      seededFromLive: (json['seededFromLive'] as bool?) ?? false,
    );
  }

  static ThresholdPlan defaultFor(String assetSymbol) =>
      _defaultPlanFor(assetSymbol);

  ThresholdPlan reseedToLive(double livePriceUsd) {
    if (livePriceUsd <= 0 ||
        anchorPriceUsd != 1.0 ||
        seededFromLive ||
        steps.isEmpty) {
      return this;
    }

    final scaledSteps = steps
        .map((st) => ThresholdStep(
              triggerPriceUsd: st.triggerPriceUsd.toDouble() * livePriceUsd,
              action: st.action,
              percentOfPosition: st.percentOfPosition,
            ))
        .toList(growable: false);

    return ThresholdPlan(
      assetSymbol: assetSymbol,
      anchorPriceUsd: livePriceUsd,
      steps: scaledSteps,
      seededFromLive: true,
    );
  }
}

ThresholdPlan _defaultPlanFor(String assetSymbol) {
  final s = assetSymbol.toUpperCase();

  // D3-A: Universal default should be price-scale agnostic.
  // Seed a relative ladder around anchor=1.0 so any asset can be edited immediately.
  // (Operator/UI can later re-anchor to live price if desired.)
  const double anchor = 1.0;
  return ThresholdPlan(
    assetSymbol: s,
    anchorPriceUsd: anchor,
    steps: const [
      ThresholdStep(triggerPriceUsd: 0.90, action: 'BUY', percentOfPosition: 25),
      ThresholdStep(triggerPriceUsd: 0.80, action: 'BUY', percentOfPosition: 25),
      ThresholdStep(triggerPriceUsd: 1.10, action: 'SELL', percentOfPosition: 25),
      ThresholdStep(triggerPriceUsd: 1.25, action: 'SELL', percentOfPosition: 25),
    ],
  );
}

String _thresholdPlanKey(String symbol) => 'threshold_plan_${symbol.toUpperCase()}';

enum PersistedThresholdPlanLoadStatus {
  valid,
  missing,
  invalid,
}

class PersistedThresholdPlanLoadResult {
  final PersistedThresholdPlanLoadStatus status;
  final ThresholdPlan? plan;

  const PersistedThresholdPlanLoadResult({
    required this.status,
    required this.plan,
  });
}

ThresholdPlan _decodeThresholdPlan(String raw) {
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  return ThresholdPlan.fromJson(decoded);
}

bool _isValidPersistedThresholdPlan(
  ThresholdPlan plan,
  String expectedSymbol,
) {
  if (plan.assetSymbol.trim().toUpperCase() !=
      expectedSymbol.trim().toUpperCase()) {
    return false;
  }
  if (!plan.anchorPriceUsd.isFinite || plan.anchorPriceUsd <= 0) {
    return false;
  }
  if (plan.steps.isEmpty) return false;
  return plan.steps.every(
    (step) => step.triggerPriceUsd.isFinite && step.triggerPriceUsd > 0,
  );
}

Future<PersistedThresholdPlanLoadResult> loadPersistedThresholdPlanStrict(
  String assetSymbol,
) async {
  final key = _thresholdPlanKey(assetSymbol);
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return const PersistedThresholdPlanLoadResult(
        status: PersistedThresholdPlanLoadStatus.missing,
        plan: null,
      );
    }

    final plan = _decodeThresholdPlan(raw);
    if (!_isValidPersistedThresholdPlan(plan, assetSymbol)) {
      return const PersistedThresholdPlanLoadResult(
        status: PersistedThresholdPlanLoadStatus.invalid,
        plan: null,
      );
    }
    return PersistedThresholdPlanLoadResult(
      status: PersistedThresholdPlanLoadStatus.valid,
      plan: plan,
    );
  } catch (_) {
    return const PersistedThresholdPlanLoadResult(
      status: PersistedThresholdPlanLoadStatus.invalid,
      plan: null,
    );
  }
}

Future<ThresholdPlan> loadThresholdPlan(String assetSymbol) async {
  final key = _thresholdPlanKey(assetSymbol);
  final result = await loadPersistedThresholdPlanStrict(assetSymbol);
  if (result.status == PersistedThresholdPlanLoadStatus.valid) {
    if (kDebugMode) {
      debugPrint('THRESH-PLAN load key=$key default=false');
    }
    return result.plan!;
  }
  if (kDebugMode) {
    debugPrint('THRESH-PLAN load key=$key default=true');
  }
  return _defaultPlanFor(assetSymbol);
}

Future<void> saveThresholdPlan(
  ThresholdPlan plan, {
  String source = 'unknown',
}) async {
  final key = _thresholdPlanKey(plan.assetSymbol);
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(plan.toJson());

    // Idempotence: avoid repeated identical writes (prevents save-churn during enable/seed/UI open).
    final existing = prefs.getString(key);
    if (existing == raw) {
      if (kDebugMode) {
        debugPrint(
            'THRESH-PLAN save skipped unchanged source=$source key=$key steps=${plan.steps.length}');
      }
      return;
    }

    await prefs.setString(key, raw);
    if (kDebugMode) {
      debugPrint(
          'THRESH-PLAN save written source=$source key=$key steps=${plan.steps.length}');
    }
  } catch (_) {
    if (kDebugMode) {
      debugPrint('THRESH-PLAN save key=$key failed');
    }
  }
}
