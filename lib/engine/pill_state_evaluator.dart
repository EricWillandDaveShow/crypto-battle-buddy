import '../models/threshold_step_state.dart';

enum PillState {
  idle,
  approaching,
  action,
  complete,
}

class PillEvaluationResult {
  final PillState pillState;
  final String? activeStepId;
  final double? nextTriggerPrice;
  final String? nextActionLabel;
  final int remainingStepCount;
  final double disciplineScore;
  final double consequenceUsd;

  // D3-E: Intelligence signals (pure metadata; UI may choose to show later)
  final String? zoneLabel; // BUY ZONE / SELL ZONE / NEUTRAL / DEEP BUY / DEEP SELL / UNKNOWN
  final double? distanceToNextPercent; // 0.02 = 2%
  final double? nextTriggerDeltaUsd; // signed: (current - trigger) for context

  const PillEvaluationResult({
    required this.pillState,
    required this.activeStepId,
    required this.nextTriggerPrice,
    required this.nextActionLabel,
    required this.remainingStepCount,
    required this.disciplineScore,
    required this.consequenceUsd,
    required this.zoneLabel,
    required this.distanceToNextPercent,
    required this.nextTriggerDeltaUsd,
  });
}

/// Internal normalized view of a threshold step.
/// Evaluator-only adapter to avoid coupling to plan models.
class _EvalStep {
  final String stepId;
  final double triggerPriceUsd;
  final String actionLabel; // BUY or SELL

  const _EvalStep({
    required this.stepId,
    required this.triggerPriceUsd,
    required this.actionLabel,
  });

  bool get isSell => actionLabel.toUpperCase() == 'SELL';
  bool get isBuy => actionLabel.toUpperCase() == 'BUY';
}

class PillStateEvaluator {
  static const double _actionPercent = 0.02; // 2%
  static const double _trackingPercent = 0.12; // 12%

  /// PURE evaluator:
  /// - No writes
  /// - No side effects
  static PillEvaluationResult evaluate({
    required double? currentPriceUsd,
    required List<dynamic> thresholdPlanSteps,
    required Map<String, ThresholdStepState> persistedStepStates,
    String stepIdPrefix = 'BTC',
  }) {
    // Normalize steps defensively.
    final normalizedSteps = <_EvalStep>[];
    for (var i = 0; i < thresholdPlanSteps.length; i++) {
      final raw = thresholdPlanSteps[i];
      try {
        final trigger = (raw.triggerPriceUsd as num).toDouble();

        // Prefer real action if present; fallback to SELL for legacy safety.
        String action = 'SELL';
        try {
          final a = raw.action;
          if (a is String && a.isNotEmpty) action = a;
        } catch (_) {
          // ignore
        }

        normalizedSteps.add(
          _EvalStep(
            stepId: '$stepIdPrefix:$i', // stable per plan order for now
            triggerPriceUsd: trigger,
            actionLabel: action.toUpperCase(),
          ),
        );
      } catch (_) {
        // Skip steps we cannot parse.
      }
    }

    final eligibleSteps = normalizedSteps.where((step) {
      final status =
          persistedStepStates[step.stepId]?.status ?? ThresholdStepStatus.pending;
      return status != ThresholdStepStatus.executed &&
          status != ThresholdStepStatus.dismissed;
    }).toList();
    final states = persistedStepStates;
    final consequenceUsd = (currentPriceUsd == null || currentPriceUsd <= 0)
        ? 0.0
        : _computeConsequence(
            steps: normalizedSteps,
            states: states,
            livePrice: currentPriceUsd,
          );

    if (eligibleSteps.isEmpty) {
      return PillEvaluationResult(
        pillState: PillState.complete,
        activeStepId: null,
        nextTriggerPrice: null,
        nextActionLabel: null,
        remainingStepCount: 0,
        disciplineScore: _computeDiscipline(states),
        consequenceUsd: consequenceUsd,
        zoneLabel: 'UNKNOWN',
        distanceToNextPercent: null,
        nextTriggerDeltaUsd: null,
      );
    }

    // If we have no price, fall back to first eligible step for continuity.
    if (currentPriceUsd == null || currentPriceUsd <= 0) {
      final fallback = eligibleSteps.first;
      return PillEvaluationResult(
        pillState: PillState.idle,
        activeStepId: fallback.stepId,
        nextTriggerPrice: fallback.triggerPriceUsd,
        nextActionLabel: fallback.actionLabel,
        remainingStepCount: eligibleSteps.length,
        disciplineScore: _computeDiscipline(states),
        consequenceUsd: consequenceUsd,
        zoneLabel: 'UNKNOWN',
        distanceToNextPercent: null,
        nextTriggerDeltaUsd: null,
      );
    }

    // --- D3-E: Compute zone label (BUY/SELL/NEUTRAL) from tier topology ---
    final buyTriggers = <double>[];
    final sellTriggers = <double>[];
    for (final s in eligibleSteps) {
      if (s.isBuy) buyTriggers.add(s.triggerPriceUsd);
      if (s.isSell) sellTriggers.add(s.triggerPriceUsd);
    }

    String zone = 'NEUTRAL';
    if (buyTriggers.isEmpty && sellTriggers.isEmpty) {
      zone = 'UNKNOWN';
    } else {
      final buyMax = buyTriggers.isEmpty ? null : buyTriggers.reduce((a, b) => a > b ? a : b);
      final buyMin = buyTriggers.isEmpty ? null : buyTriggers.reduce((a, b) => a < b ? a : b);
      final sellMin = sellTriggers.isEmpty ? null : sellTriggers.reduce((a, b) => a < b ? a : b);
      final sellMax = sellTriggers.isEmpty ? null : sellTriggers.reduce((a, b) => a > b ? a : b);

      if (buyMin != null && currentPriceUsd <= buyMin) {
        zone = 'DEEP BUY';
      } else if (buyMax != null && currentPriceUsd < buyMax) {
        zone = 'BUY ZONE';
      } else if (sellMax != null && currentPriceUsd >= sellMax) {
        zone = 'DEEP SELL';
      } else if (sellMin != null && currentPriceUsd > sellMin) {
        zone = 'SELL ZONE';
      } else {
        zone = 'NEUTRAL';
      }
    }

    // STEP 34.4 — Split tracking proximity from executable action eligibility.
    bool isStepExecuted(_EvalStep step) {
      final status = states[step.stepId]?.status;
      return status == ThresholdStepStatus.executed;
    }

    _EvalStep? trackingCandidate;
    double trackingDistance = double.infinity;
    _EvalStep? actionCandidate;
    double actionDistance = double.infinity;
    _EvalStep? crossedTrackingCandidate;
    double crossedTrackingDistance = double.infinity;

    for (final step in eligibleSteps) {
      if (isStepExecuted(step)) {
        continue;
      }

      final distance = (step.triggerPriceUsd - currentPriceUsd).abs();
      if (distance < trackingDistance) {
        trackingDistance = distance;
        trackingCandidate = step;
      }

      if (step.isSell && currentPriceUsd < step.triggerPriceUsd) {
        continue;
      }
      if (step.isBuy && currentPriceUsd > step.triggerPriceUsd) {
        continue;
      }

      if (distance < actionDistance) {
        actionDistance = distance;
        actionCandidate = step;
      }
      if (distance < crossedTrackingDistance) {
        crossedTrackingDistance = distance;
        crossedTrackingCandidate = step;
      }
    }

    PillState pillState;
    _EvalStep? activeStep;
    double? distPct;

    final actionDistPct = actionCandidate == null
        ? null
        : (actionDistance / currentPriceUsd)
            .clamp(0.0, double.infinity)
            .toDouble();
    if (actionCandidate != null && actionDistPct! <= _actionPercent) {
      pillState = PillState.action;
      activeStep = actionCandidate;
      distPct = actionDistPct;
    } else {
      final crossedTrackingDistPct = crossedTrackingCandidate == null
          ? null
          : (crossedTrackingDistance / currentPriceUsd)
              .clamp(0.0, double.infinity)
              .toDouble();
      if (crossedTrackingCandidate != null &&
          crossedTrackingDistPct! <= _trackingPercent) {
        pillState = PillState.approaching;
        activeStep = crossedTrackingCandidate;
        distPct = crossedTrackingDistPct;
      } else {
        final trackingDistPct = trackingCandidate == null
            ? null
            : (trackingDistance / currentPriceUsd)
                .clamp(0.0, double.infinity)
                .toDouble();
        if (trackingCandidate != null && trackingDistPct! <= _trackingPercent) {
          pillState = PillState.approaching;
          activeStep = trackingCandidate;
          distPct = trackingDistPct;
        } else {
          pillState = PillState.idle;
          activeStep = null;
          distPct = null;
        }
      }
    }

    final activeStepId = activeStep?.stepId;
    final deltaUsd = activeStep == null
        ? null
        : currentPriceUsd - activeStep.triggerPriceUsd;

    return PillEvaluationResult(
      pillState: pillState,
      activeStepId: activeStepId,
      nextTriggerPrice: activeStep?.triggerPriceUsd,
      nextActionLabel: activeStep?.actionLabel,
      remainingStepCount: eligibleSteps.length,
      disciplineScore: _computeDiscipline(states),
      consequenceUsd: consequenceUsd,
      zoneLabel: zone,
      distanceToNextPercent: distPct,
      nextTriggerDeltaUsd: deltaUsd,
    );
  }
}

double _computeDiscipline(Map<String, ThresholdStepState> states) {
  if (states.isEmpty) return 1.0;

  int expected = 0;
  int completed = 0;

  for (final s in states.values) {
    expected++;

    if (s.status == ThresholdStepStatus.executed) {
      completed++;
    }
  }

  if (expected == 0) return 1.0;

  return (completed / expected).clamp(0.0, 1.0).toDouble();
}

double _computeConsequence({
  required List<_EvalStep> steps,
  required Map<String, ThresholdStepState> states,
  required double livePrice,
}) {
  if (steps.isEmpty) return 0.0;

  double impact = 0.0;

  for (final step in steps) {
    final state = states[step.stepId];
    if (state == null) continue;

    final delta = livePrice - step.triggerPriceUsd;

    if (state.status == ThresholdStepStatus.executed) {
      impact += delta;
    }

    if (state.status == ThresholdStepStatus.dismissed) {
      impact -= delta;
    }
  }

  return impact;
}
