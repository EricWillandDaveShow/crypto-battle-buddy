import '../models/threshold_step_state.dart';

enum ThresholdTierRowDisplayState {
  pending,
  triggered,
  executed,
  missed,
}

class ThresholdTierRowState {
  final ThresholdTierRowDisplayState displayState;
  final String? labelText;
  final String helperText;
  final bool canExecute;
  final bool canMarkMissed;

  const ThresholdTierRowState({
    required this.displayState,
    required this.labelText,
    required this.helperText,
    required this.canExecute,
    required this.canMarkMissed,
  });
}

ThresholdTierRowState evaluateThresholdTierRowState({
  required ThresholdStepState? state,
  required bool isArmed,
  required bool isActiveStep,
  required bool isActionState,
  required bool hasPlan,
  required bool hasPrice,
  required bool hasRequiredPosition,
}) {
  final status = state?.status ?? ThresholdStepStatus.pending;
  final isExecuted = status == ThresholdStepStatus.executed;
  final isMissed = status == ThresholdStepStatus.dismissed;
  final isDone = isExecuted || isMissed;
  final isTriggered = !isDone && state?.wasTriggered == true;

  final canExecute = !isDone &&
      isArmed &&
      isActiveStep &&
      isActionState &&
      hasPlan &&
      hasPrice &&
      hasRequiredPosition;
  final canMarkMissed = !isDone &&
      isArmed &&
      hasPlan &&
      hasPrice &&
      (isActiveStep || isTriggered);

  if (isExecuted) {
    return ThresholdTierRowState(
      displayState: ThresholdTierRowDisplayState.executed,
      labelText: 'EXECUTED',
      helperText: 'EXECUTED — within plan',
      canExecute: canExecute,
      canMarkMissed: canMarkMissed,
    );
  }

  if (isMissed) {
    return ThresholdTierRowState(
      displayState: ThresholdTierRowDisplayState.missed,
      labelText: 'MISSED',
      helperText: 'MISSED — price moved beyond execution range',
      canExecute: canExecute,
      canMarkMissed: canMarkMissed,
    );
  }

  if (isTriggered) {
    return ThresholdTierRowState(
      displayState: ThresholdTierRowDisplayState.triggered,
      labelText: 'TRIGGERED',
      helperText: 'TRIGGERED — review execution',
      canExecute: canExecute,
      canMarkMissed: canMarkMissed,
    );
  }

  return ThresholdTierRowState(
    displayState: ThresholdTierRowDisplayState.pending,
    labelText: null,
    helperText: 'Adjust for plan',
    canExecute: canExecute,
    canMarkMissed: canMarkMissed,
  );
}
