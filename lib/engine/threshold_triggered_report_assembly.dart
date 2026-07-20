import '../models/threshold_plan.dart';
import '../models/threshold_step_state.dart';
import '../storage/threshold_state_store.dart';
import 'threshold_step_state_merge.dart';
import 'threshold_triggered_report_mapper.dart';

Future<List<Map<String, dynamic>>> buildThresholdTriggeredStepsForReport({
  required Iterable<String> symbols,
  required Map<String, Map<String, ThresholdStepState>> thresholdStateDelta,
  required Map<String, double> pricesUsd,
}) async {
  final statesBySymbol = await _loadReportThresholdStepStates(
    symbols: symbols,
    thresholdStateDelta: thresholdStateDelta,
  );
  final plansBySymbol = await _loadReportThresholdPlans(statesBySymbol);

  return buildThresholdTriggeredStepReportEntries(
    statesBySymbol: statesBySymbol,
    plansBySymbol: plansBySymbol,
    pricesUsd: pricesUsd,
  );
}

Future<Map<String, Map<String, ThresholdStepState>>>
    _loadReportThresholdStepStates({
  required Iterable<String> symbols,
  required Map<String, Map<String, ThresholdStepState>> thresholdStateDelta,
}) async {
  final reportSymbols = <String>{
    ...symbols.map((s) => s.toUpperCase()).where((s) => s.isNotEmpty),
    ...thresholdStateDelta.keys
        .map((s) => s.toUpperCase())
        .where((s) => s.isNotEmpty),
  }.toList()
    ..sort();

  final entries = await Future.wait(reportSymbols.map((symbol) async {
    return MapEntry<String, Map<String, ThresholdStepState>>(
      symbol,
      await ThresholdStateStore.loadStepStates(symbol: symbol),
    );
  }));
  final persistedStates = <String, Map<String, ThresholdStepState>>{
    for (final entry in entries)
      if (entry.value.isNotEmpty) entry.key: entry.value,
  };

  if (thresholdStateDelta.isEmpty) return persistedStates;
  return mergeExternalStepStates(
    current: persistedStates,
    incoming: thresholdStateDelta,
  );
}

Future<Map<String, ThresholdPlan>> _loadReportThresholdPlans(
  Map<String, Map<String, ThresholdStepState>> statesBySymbol,
) async {
  final symbols = statesBySymbol.entries
      .where((entry) => entry.value.values.any((state) => state.wasTriggered))
      .map((entry) => entry.key.toUpperCase())
      .toSet()
      .toList()
    ..sort();

  final entries = await Future.wait(symbols.map((symbol) async {
    return MapEntry<String, ThresholdPlan>(
      symbol,
      await loadThresholdPlan(symbol),
    );
  }));
  return <String, ThresholdPlan>{
    for (final entry in entries) entry.key: entry.value,
  };
}
