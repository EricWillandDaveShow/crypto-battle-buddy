import '../models/threshold_step_state.dart';

Map<String, Map<String, ThresholdStepState>> mergeExternalStepStates({
  required Map<String, Map<String, ThresholdStepState>> current,
  required Map<String, Map<String, ThresholdStepState>> incoming,
}) {
  final merged = <String, Map<String, ThresholdStepState>>{
    for (final entry in current.entries)
      entry.key.toUpperCase():
          Map<String, ThresholdStepState>.from(entry.value),
  };

  for (final symbolEntry in incoming.entries) {
    final symbol = symbolEntry.key.toUpperCase();
    final symbolStates = merged.putIfAbsent(
      symbol,
      () => <String, ThresholdStepState>{},
    );

    for (final stepEntry in symbolEntry.value.entries) {
      final local = symbolStates[stepEntry.key];
      final external = stepEntry.value;
      if (_shouldAcceptExternal(local: local, external: external)) {
        symbolStates[stepEntry.key] = external;
      }
    }
  }

  return merged;
}

bool _shouldAcceptExternal({
  required ThresholdStepState? local,
  required ThresholdStepState external,
}) {
  if (local == null) return true;
  if (_isTerminal(external.status)) return true;
  if (external.updatedAt.isAfter(local.updatedAt)) return true;

  return !(_isTerminal(local.status) &&
      local.updatedAt.isAfter(external.updatedAt));
}

bool _isTerminal(ThresholdStepStatus status) {
  return status == ThresholdStepStatus.executed ||
      status == ThresholdStepStatus.dismissed;
}
