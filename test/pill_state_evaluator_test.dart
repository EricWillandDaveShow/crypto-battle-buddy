import 'package:crypto_battle_buddy/engine/pill_state_evaluator.dart';
import 'package:crypto_battle_buddy/models/threshold_plan.dart';
import 'package:crypto_battle_buddy/models/threshold_step_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const symbol = 'BTC';

  ThresholdStep step(String action, double triggerPriceUsd) => ThresholdStep(
        triggerPriceUsd: triggerPriceUsd,
        action: action,
        percentOfPosition: 25,
      );

  ThresholdStepState state(String stepId, ThresholdStepStatus status) =>
      ThresholdStepState(
        stepId: stepId,
        status: status,
        updatedAt: DateTime.utc(2026),
      );

  PillEvaluationResult evaluate({
    required double currentPriceUsd,
    required List<ThresholdStep> steps,
    Map<String, ThresholdStepState> states =
        const <String, ThresholdStepState>{},
  }) {
    return PillStateEvaluator.evaluate(
      currentPriceUsd: currentPriceUsd,
      thresholdPlanSteps: steps,
      persistedStepStates: states,
      stepIdPrefix: symbol,
    );
  }

  group('PillStateEvaluator Model A semantics', () {
    test('BUY pre-cross within 2% tracks but does not action', () {
      final result = evaluate(
        currentPriceUsd: 100,
        steps: [step('BUY', 99)],
      );

      expect(result.pillState, PillState.approaching);
      expect(result.activeStepId, 'BTC:0');
      expect(result.nextActionLabel, 'BUY');
      expect(result.distanceToNextPercent, closeTo(0.01, 0.000001));
    });

    test('BUY crossed within 2% actions', () {
      final result = evaluate(
        currentPriceUsd: 100,
        steps: [step('BUY', 101)],
      );

      expect(result.pillState, PillState.action);
      expect(result.activeStepId, 'BTC:0');
      expect(result.nextActionLabel, 'BUY');
      expect(result.distanceToNextPercent, closeTo(0.01, 0.000001));
    });

    test('SELL pre-cross within 2% tracks but does not action', () {
      final result = evaluate(
        currentPriceUsd: 100,
        steps: [step('SELL', 101)],
      );

      expect(result.pillState, PillState.approaching);
      expect(result.activeStepId, 'BTC:0');
      expect(result.nextActionLabel, 'SELL');
      expect(result.distanceToNextPercent, closeTo(0.01, 0.000001));
    });

    test('SELL crossed within 2% actions', () {
      final result = evaluate(
        currentPriceUsd: 100,
        steps: [step('SELL', 99)],
      );

      expect(result.pillState, PillState.action);
      expect(result.activeStepId, 'BTC:0');
      expect(result.nextActionLabel, 'SELL');
      expect(result.distanceToNextPercent, closeTo(0.01, 0.000001));
    });

    test('crossed tracking beats closer uncrossed tracking', () {
      final result = evaluate(
        currentPriceUsd: 100,
        steps: [
          step('SELL', 94),
          step('BUY', 99.5),
        ],
      );

      expect(result.pillState, PillState.approaching);
      expect(result.activeStepId, 'BTC:0');
      expect(result.nextActionLabel, 'SELL');
      expect(result.distanceToNextPercent, closeTo(0.06, 0.000001));
    });

    test('executed steps are excluded from eligibility', () {
      final result = evaluate(
        currentPriceUsd: 100,
        steps: [
          step('SELL', 99),
          step('SELL', 105),
        ],
        states: {
          'BTC:0': state('BTC:0', ThresholdStepStatus.executed),
          'BTC:1': state('BTC:1', ThresholdStepStatus.pending),
        },
      );

      expect(result.pillState, PillState.approaching);
      expect(result.activeStepId, 'BTC:1');
      expect(result.nextActionLabel, 'SELL');
      expect(result.distanceToNextPercent, closeTo(0.05, 0.000001));
    });

    test('dismissed steps are excluded from eligibility', () {
      final result = evaluate(
        currentPriceUsd: 100,
        steps: [
          step('BUY', 101),
          step('BUY', 106),
        ],
        states: {
          'BTC:0': state('BTC:0', ThresholdStepStatus.dismissed),
          'BTC:1': state('BTC:1', ThresholdStepStatus.pending),
        },
      );

      expect(result.pillState, PillState.approaching);
      expect(result.activeStepId, 'BTC:1');
      expect(result.nextActionLabel, 'BUY');
      expect(result.distanceToNextPercent, closeTo(0.06, 0.000001));
    });

    test('reset-cycle pending states are eligible', () {
      final result = evaluate(
        currentPriceUsd: 100,
        steps: [
          step('BUY', 101),
          step('SELL', 110),
        ],
        states: {
          'BTC:0': state('BTC:0', ThresholdStepStatus.pending),
          'BTC:1': state('BTC:1', ThresholdStepStatus.pending),
        },
      );

      expect(result.pillState, PillState.action);
      expect(result.activeStepId, 'BTC:0');
      expect(result.nextActionLabel, 'BUY');
      expect(result.distanceToNextPercent, closeTo(0.01, 0.000001));
    });

    test('identical-distance action ties keep plan-order winner', () {
      final result = evaluate(
        currentPriceUsd: 100,
        steps: [
          step('BUY', 101),
          step('SELL', 99),
        ],
      );

      expect(result.pillState, PillState.action);
      expect(result.activeStepId, 'BTC:0');
      expect(result.nextActionLabel, 'BUY');
      expect(result.distanceToNextPercent, closeTo(0.01, 0.000001));
    });
  });
}
