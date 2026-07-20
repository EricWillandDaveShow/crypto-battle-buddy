import 'package:crypto_battle_buddy/engine/pill_state_evaluator.dart';
import 'package:crypto_battle_buddy/engine/threshold_pill_display_state.dart';
import 'package:crypto_battle_buddy/models/threshold_step_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ThresholdStepState stepState({
    required String stepId,
    required ThresholdStepStatus status,
    required bool wasTriggered,
  }) {
    return ThresholdStepState(
      stepId: stepId,
      status: status,
      updatedAt: DateTime.utc(2026, 6, 16, 12),
      wasTriggered: wasTriggered,
    );
  }

  PillEvaluationResult evaluation(PillState pillState) {
    return PillEvaluationResult(
      pillState: pillState,
      activeStepId: pillState == PillState.action ? 'BTC:0' : null,
      nextTriggerPrice: 38000,
      nextActionLabel: 'BUY',
      remainingStepCount: 1,
      disciplineScore: 1,
      consequenceUsd: 0,
      zoneLabel: 'UNKNOWN',
      distanceToNextPercent: null,
      nextTriggerDeltaUsd: null,
    );
  }

  group('resolveThresholdPillDisplayState', () {
    test('pending wasTriggered state produces durable triggered display', () {
      final result = resolveThresholdPillDisplayState(
        evaluation: evaluation(PillState.idle),
        stepStates: {
          'BTC:0': stepState(
            stepId: 'BTC:0',
            status: ThresholdStepStatus.pending,
            wasTriggered: true,
          ),
        },
      );

      expect(result, ThresholdPillDisplayState.durableTriggered);
    });

    test('executed wasTriggered state does not keep durable triggered display',
        () {
      final result = resolveThresholdPillDisplayState(
        evaluation: evaluation(PillState.idle),
        stepStates: {
          'BTC:0': stepState(
            stepId: 'BTC:0',
            status: ThresholdStepStatus.executed,
            wasTriggered: true,
          ),
        },
      );

      expect(result, ThresholdPillDisplayState.evaluator);
    });

    test('dismissed wasTriggered state does not keep durable triggered display',
        () {
      final result = resolveThresholdPillDisplayState(
        evaluation: evaluation(PillState.idle),
        stepStates: {
          'BTC:0': stepState(
            stepId: 'BTC:0',
            status: ThresholdStepStatus.dismissed,
            wasTriggered: true,
          ),
        },
      );

      expect(result, ThresholdPillDisplayState.evaluator);
    });

    test('live action evaluator display is preserved', () {
      final result = resolveThresholdPillDisplayState(
        evaluation: evaluation(PillState.action),
        stepStates: {
          'BTC:0': stepState(
            stepId: 'BTC:0',
            status: ThresholdStepStatus.pending,
            wasTriggered: true,
          ),
        },
      );

      expect(result, ThresholdPillDisplayState.evaluator);
    });
  });
}
