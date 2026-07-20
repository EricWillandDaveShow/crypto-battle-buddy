import 'dart:convert';

/// Immutable execution/audit record for a tier action.
/// Persisted as a JSON list per asset symbol.
class ThresholdExecutionEvent {
  final String symbolUpper;
  final String stepId;
  final int tierIndex; // 0-based
  final String action; // e.g., SELL
  final double triggerPriceUsd;
  final double? observedPriceUsd; // optional snapshot at execution time
  final int? percentOfPositionSnapshot;
  final double? positionUnitsSnapshot;
  final double? notionalUsdSnapshot;
  final String? sizingSource;
  final String reason; // e.g., "manual_toggle" | "price_cross"
  final DateTime createdAt;

  const ThresholdExecutionEvent({
    required this.symbolUpper,
    required this.stepId,
    required this.tierIndex,
    required this.action,
    required this.triggerPriceUsd,
    required this.observedPriceUsd,
    required this.percentOfPositionSnapshot,
    required this.positionUnitsSnapshot,
    required this.notionalUsdSnapshot,
    required this.sizingSource,
    required this.reason,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'symbolUpper': symbolUpper,
        'stepId': stepId,
        'tierIndex': tierIndex,
        'action': action,
        'triggerPriceUsd': triggerPriceUsd,
        'observedPriceUsd': observedPriceUsd,
        'percentOfPositionSnapshot': percentOfPositionSnapshot,
        'positionUnitsSnapshot': positionUnitsSnapshot,
        'notionalUsdSnapshot': notionalUsdSnapshot,
        'sizingSource': sizingSource,
        'reason': reason,
        'createdAt': createdAt.toIso8601String(),
      };

  static ThresholdExecutionEvent fromJson(Map<String, dynamic> m) {
    return ThresholdExecutionEvent(
      symbolUpper: (m['symbolUpper'] ?? '').toString().toUpperCase(),
      stepId: (m['stepId'] ?? '').toString(),
      tierIndex: (m['tierIndex'] is num) ? (m['tierIndex'] as num).toInt() : 0,
      action: (m['action'] ?? 'SELL').toString(),
      triggerPriceUsd: (m['triggerPriceUsd'] is num) ? (m['triggerPriceUsd'] as num).toDouble() : 0.0,
      observedPriceUsd: (m['observedPriceUsd'] is num) ? (m['observedPriceUsd'] as num).toDouble() : null,
      percentOfPositionSnapshot: (m['percentOfPositionSnapshot'] is num)
          ? (m['percentOfPositionSnapshot'] as num).toInt()
          : null,
      positionUnitsSnapshot: (m['positionUnitsSnapshot'] is num)
          ? (m['positionUnitsSnapshot'] as num).toDouble()
          : null,
      notionalUsdSnapshot: (m['notionalUsdSnapshot'] is num)
          ? (m['notionalUsdSnapshot'] as num).toDouble()
          : null,
      sizingSource: m['sizingSource']?.toString(),
      reason: (m['reason'] ?? 'unknown').toString(),
      createdAt: DateTime.tryParse((m['createdAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }

  @override
  String toString() => jsonEncode(toJson());
}
