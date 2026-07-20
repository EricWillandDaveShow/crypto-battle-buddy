import '../models/threshold_plan.dart';
import '../models/threshold_step_state.dart';

List<Map<String, dynamic>> buildThresholdTriggeredStepReportEntries({
  required Map<String, Map<String, ThresholdStepState>> statesBySymbol,
  required Map<String, ThresholdPlan> plansBySymbol,
  Map<String, double> pricesUsd = const <String, double>{},
}) {
  final entries = <Map<String, dynamic>>[];
  final stateEntries = statesBySymbol.entries.toList()
    ..sort((a, b) => a.key.toUpperCase().compareTo(b.key.toUpperCase()));

  for (final symbolEntry in stateEntries) {
    final symbol = symbolEntry.key.toUpperCase();
    final plan = _planForSymbol(plansBySymbol, symbolEntry.key);
    if (plan == null) continue;

    final stepEntries = symbolEntry.value.entries.toList()
      ..sort((a, b) {
        final aIndex = _stepIndexFromId(a.value.stepId);
        final bIndex = _stepIndexFromId(b.value.stepId);
        if (aIndex != null && bIndex != null && aIndex != bIndex) {
          return aIndex.compareTo(bIndex);
        }
        return a.key.compareTo(b.key);
      });

    for (final stateEntry in stepEntries) {
      final state = stateEntry.value;
      if (!state.wasTriggered) continue;

      final stepIndex = _stepIndexFromId(state.stepId);
      if (stepIndex == null ||
          stepIndex < 0 ||
          stepIndex >= plan.steps.length) {
        continue;
      }

      final step = plan.steps[stepIndex];
      final entry = <String, dynamic>{
        'symbol': symbol,
        'stepId': state.stepId,
        'tier': stepIndex + 1,
        'action': step.action,
        'triggerPriceUsd': step.triggerPriceUsd,
        'status': state.status.name,
        'wasTriggered': true,
        'updatedAt': state.updatedAt.toIso8601String(),
      };

      final currentPriceUsd = _priceForSymbol(pricesUsd, symbolEntry.key);
      if (currentPriceUsd != null) {
        entry['currentPriceUsd'] = currentPriceUsd;
      }

      entries.add(entry);
    }
  }

  return entries;
}

ThresholdPlan? _planForSymbol(
  Map<String, ThresholdPlan> plansBySymbol,
  String symbol,
) {
  return plansBySymbol[symbol] ??
      plansBySymbol[symbol.toUpperCase()] ??
      plansBySymbol[symbol.toLowerCase()];
}

double? _priceForSymbol(Map<String, double> pricesUsd, String symbol) {
  return pricesUsd[symbol] ??
      pricesUsd[symbol.toUpperCase()] ??
      pricesUsd[symbol.toLowerCase()];
}

int? _stepIndexFromId(String stepId) {
  final parts = stepId.split(':');
  if (parts.length < 2) return null;
  return int.tryParse(parts.last);
}
