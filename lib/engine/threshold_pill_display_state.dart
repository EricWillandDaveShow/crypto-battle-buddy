import '../models/threshold_step_state.dart';
import 'pill_state_evaluator.dart';

enum ThresholdPillDisplayState {
  evaluator,
  durableTriggered,
}

ThresholdPillDisplayState resolveThresholdPillDisplayState({
  required PillEvaluationResult? evaluation,
  required Map<String, ThresholdStepState> stepStates,
}) {
  if (_hasLiveAction(evaluation)) {
    return ThresholdPillDisplayState.evaluator;
  }

  final hasUnresolvedTriggeredStep = stepStates.values.any((state) {
    return state.wasTriggered &&
        state.status != ThresholdStepStatus.executed &&
        state.status != ThresholdStepStatus.dismissed;
  });

  return hasUnresolvedTriggeredStep
      ? ThresholdPillDisplayState.durableTriggered
      : ThresholdPillDisplayState.evaluator;
}

bool _hasLiveAction(PillEvaluationResult? evaluation) {
  if (evaluation == null || evaluation.pillState != PillState.action) {
    return false;
  }
  return evaluation.activeStepId != null &&
      evaluation.activeStepId!.trim().isNotEmpty;
}
