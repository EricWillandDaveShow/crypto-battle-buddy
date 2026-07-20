import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/threshold_step_state.dart';
import '../models/threshold_execution_event.dart';

class ThresholdStateStore {
  static String _key(String symbol) => 'threshold_state_${symbol.toUpperCase()}';
  static const String _execPrefix = 'threshold_exec_';
  static String _execKey(String symbol) => '$_execPrefix${symbol.toUpperCase()}';
  static String _cycleStartKey(String symbol) =>
      'threshold_cycle_start_${symbol.toUpperCase()}';

  static Future<void> saveStepStates({
    required String symbol,
    required Map<String, ThresholdStepState> states,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode({
      for (final e in states.entries) e.key: e.value.toJson(),
    });
    await prefs.setString(_key(symbol), encoded);
  }

  /// Load all per-step states for an asset symbol.
  static Future<Map<String, ThresholdStepState>> loadStepStates({
    required String symbol,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(symbol));
    if (raw == null || raw.isEmpty) return <String, ThresholdStepState>{};

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final out = <String, ThresholdStepState>{};
      for (final entry in map.entries) {
        final stepId = entry.key;
        final v = entry.value;
        if (v is Map<String, dynamic>) {
          out[stepId] = ThresholdStepState.fromJson(v, stepId);
        }
      }
      return out;
    } catch (_) {
      return <String, ThresholdStepState>{};
    }
  }

  /// Set a specific step state (persisted).
  static Future<void> setStepState({
    required String symbol,
    required String stepId,
    required ThresholdStepStatus status,
    bool? wasTriggered,
    bool? wasCompleted,
  }) async {
    final current = await loadStepStates(symbol: symbol);
    final existing = current[stepId];
    current[stepId] = ThresholdStepState(
      stepId: stepId,
      status: status,
      updatedAt: DateTime.now(),
      wasTriggered: wasTriggered ?? existing?.wasTriggered ?? false,
      wasCompleted: wasCompleted ?? existing?.wasCompleted ?? false,
    );
    await saveStepStates(symbol: symbol, states: current);
  }

  /// Load execution/audit events for a symbol (most recent last).
  static Future<List<ThresholdExecutionEvent>> loadExecutionEvents({
    required String symbol,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_execKey(symbol));
    if (raw == null || raw.isEmpty) return <ThresholdExecutionEvent>[];

    try {
      final list = jsonDecode(raw);
      if (list is! List) return <ThresholdExecutionEvent>[];
      return list
          .whereType<Map<String, dynamic>>()
          .map(ThresholdExecutionEvent.fromJson)
          .toList(growable: false);
    } catch (_) {
      return <ThresholdExecutionEvent>[];
    }
  }

  /// Load the newest execution/audit event across all persisted symbols.
  static Future<ThresholdExecutionEvent?> loadLatestExecutionEvent() async {
    final prefs = await SharedPreferences.getInstance();
    ThresholdExecutionEvent? latest;

    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_execPrefix)) continue;
      final symbol = key.substring(_execPrefix.length);
      if (symbol.isEmpty) continue;

      final events = await loadExecutionEvents(symbol: symbol);
      for (final event in events) {
        if (latest == null || event.createdAt.isAfter(latest.createdAt)) {
          latest = event;
        }
      }
    }

    return latest;
  }

  static Future<DateTime?> loadCycleStart({
    required String symbol,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cycleStartKey(symbol));
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static Future<void> saveCycleStart({
    required String symbol,
    required DateTime cycleStart,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cycleStartKey(symbol),
      cycleStart.toIso8601String(),
    );
  }

  /// Append an execution event to the per-symbol ledger.
  static Future<void> appendExecutionEvent({
    required String symbol,
    required ThresholdExecutionEvent event,
    int maxEvents = 200,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadExecutionEvents(symbol: symbol);
    final next = <ThresholdExecutionEvent>[...current, event];
    // keep the newest maxEvents
    final trimmed =
        (next.length <= maxEvents) ? next : next.sublist(next.length - maxEvents);
    final encoded = jsonEncode(trimmed.map((e) => e.toJson()).toList());
    await prefs.setString(_execKey(symbol), encoded);
  }

  static Future<void> removeStepStates({
    required String symbol,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(symbol));
  }

  static Future<void> removeExecutionEvents({
    required String symbol,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_execKey(symbol));
  }

  static Future<void> removeCycleStart({
    required String symbol,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cycleStartKey(symbol));
  }

  static Future<void> removeAllThresholdStateForSymbol({
    required String symbol,
  }) async {
    await removeStepStates(symbol: symbol);
    await removeExecutionEvents(symbol: symbol);
    await removeCycleStart(symbol: symbol);
  }
}
