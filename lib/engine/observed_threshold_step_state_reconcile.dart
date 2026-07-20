import '../models/threshold_step_state.dart';

Map<String, ThresholdStepState> reconcileObservedThresholdStepStates({
  required Map<String, ThresholdStepState> originallyLoaded,
  required Map<String, ThresholdStepState> observed,
  required Map<String, ThresholdStepState> latestPersisted,
}) {
  final reconciled = Map<String, ThresholdStepState>.from(latestPersisted);

  for (final entry in observed.entries) {
    final stepId = entry.key;
    final observedState = entry.value;
    final latestState = latestPersisted[stepId];
    final wasOriginallyLoaded = originallyLoaded.containsKey(stepId);

    if (latestState == null) {
      if (!wasOriginallyLoaded) {
        reconciled[stepId] = observedState;
      }
      continue;
    }

    if (_isTerminal(latestState.status) ||
        latestState.updatedAt.isAfter(observedState.updatedAt)) {
      reconciled[stepId] = latestState;
      continue;
    }

    reconciled[stepId] = observedState;
  }

  return reconciled;
}

bool _isTerminal(ThresholdStepStatus status) {
  return status == ThresholdStepStatus.executed ||
      status == ThresholdStepStatus.dismissed;
}
